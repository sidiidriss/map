import Anthropic from "@anthropic-ai/sdk";
import type { ContexteUtilisateur, SehelliBackend } from "./backend/types.js";
import { executerOutil, OUTILS, type ActionApp, type Pose } from "./outils.js";
import type { Conversation } from "./sessions.js";

/** Événements diffusés à l'app pendant un tour (voir le protocole SSE dans index.ts). */
export type Evenement =
  | { type: "texte"; delta: string }
  /** Remplace tout le texte du tour (après une relance interne). */
  | { type: "remplacer"; texte: string }
  | { type: "outil"; nom: string; etat: "debut" | "fin" }
  | { type: "pose"; pose: Pose }
  | { type: "action"; action: ActionApp };

export type FinTour = { statut: "ok"; pose: Pose } | { statut: "refus" };

export interface OptionsAssistant {
  modele: string;
  effort: "low" | "medium" | "high" | "xhigh" | "max";
  maxTokens: number;
  etapesMax: number;
}

export interface Tour {
  conversation: Conversation;
  message: string;
  /** Texte du contexte de l'app (langue, connexion, heure…), ajouté en message système. */
  contexte: string;
  utilisateur: ContexteUtilisateur;
  emettre: (evenement: Evenement) => void;
  signal?: AbortSignal;
}

class EntreeOutilTronquee extends Error {}

export class Assistant {
  constructor(
    private client: Anthropic,
    private backend: SehelliBackend,
    private promptSysteme: string,
    private options: OptionsAssistant,
  ) {}

  async repondre(tour: Tour): Promise<FinTour> {
    const { conversation, emettre } = tour;
    const messages = conversation.messages;
    // En cas d'échec, on revient exactement à cette longueur : l'historique
    // reste un préfixe déjà envoyé, donc le cache et les blocs de réflexion restent valides.
    const longueurInitiale = messages.length;
    messages.push({ role: "user", content: tour.message });
    messages.push({ role: "system", content: tour.contexte });

    // L'app affiche « Je cherche… » dès l'envoi ; on n'annonce que les changements.
    let pose: Pose = "hello";
    let poseAffichee: Pose = "search";
    const annoncer = (p: Pose) => {
      if (p === poseAffichee) return;
      poseAffichee = p;
      emettre({ type: "pose", pose: p });
    };
    let texteValide = ""; // texte des étapes terminées, affiché à l'utilisateur
    let relancesJson = 0;

    try {
      for (let etape = 0; etape < this.options.etapesMax; etape++) {
        let texteEtape = "";
        let nouveauBloc = false;
        const flux = this.client.beta.messages.stream(
          {
            model: this.options.modele,
            max_tokens: this.options.maxTokens,
            // Si un filtre de sécurité refuse à tort, l'API relance sur le modèle de secours recommandé.
            betas: ["server-side-fallback-2026-07-01"],
            fallbacks: "default",
            thinking: { type: "adaptive" },
            output_config: { effort: this.options.effort },
            // Cache : préfixe partagé (outils + système) et historique de la conversation.
            cache_control: { type: "ephemeral" },
            system: [{ type: "text", text: this.promptSysteme, cache_control: { type: "ephemeral" } }],
            tools: OUTILS,
            messages,
          },
          { signal: tour.signal },
        );
        flux.on("streamEvent", (evenement) => {
          if (evenement.type === "content_block_start" && evenement.content_block.type === "text") nouveauBloc = true;
        });
        flux.on("text", (delta) => {
          if (poseAffichee === "search") annoncer(pose);
          if (nouveauBloc && (texteValide || texteEtape)) {
            texteEtape += "\n\n";
            emettre({ type: "texte", delta: "\n\n" });
          }
          nouveauBloc = false;
          texteEtape += delta;
          emettre({ type: "texte", delta });
        });

        let reponse: Anthropic.Beta.BetaMessage;
        try {
          reponse = await flux.finalMessage();
          relancesJson = 0;
        } catch (err) {
          // Seule une entrée d'outil illisible (JSON incomplet) justifie de relancer l'étape :
          // le SDK la signale par une AnthropicError qui n'est pas une erreur d'API.
          const jsonIllisible = err instanceof Anthropic.AnthropicError && !(err instanceof Anthropic.APIError);
          if (!jsonIllisible || relancesJson++ >= 2) throw err;
          console.warn("[sahla] entrée d'outil illisible, nouvelle tentative de l'étape");
          emettre({ type: "remplacer", texte: texteValide });
          etape--;
          continue;
        }

        if (reponse.stop_reason === "refusal") {
          messages.length = longueurInitiale;
          return { statut: "refus" };
        }

        const appels = reponse.content.filter((b): b is Anthropic.Beta.BetaToolUseBlock => b.type === "tool_use");
        if (appels.length > 0 && reponse.stop_reason === "max_tokens") {
          throw new EntreeOutilTronquee("Entrée d'outil tronquée par max_tokens");
        }

        // Le contenu complet (réflexion, blocs de secours…) est renvoyé tel quel aux tours suivants.
        messages.push({ role: "assistant", content: reponse.content as Anthropic.Beta.BetaContentBlockParam[] });
        texteValide += texteEtape;

        if (reponse.stop_reason === "pause_turn") continue;
        if (appels.length === 0) {
          conversation.tours++;
          return { statut: "ok", pose };
        }

        annoncer("search");
        let poseOutils: Pose | undefined;
        const resultats = await Promise.all(
          appels.map(async (appel): Promise<Anthropic.Beta.BetaToolResultBlockParam> => {
            emettre({ type: "outil", nom: appel.name, etat: "debut" });
            const resultat = await executerOutil(appel.name, appel.input, this.backend, tour.utilisateur);
            emettre({ type: "outil", nom: appel.name, etat: "fin" });
            if (resultat.action) emettre({ type: "action", action: resultat.action });
            if (resultat.pose) poseOutils = resultat.pose;
            return {
              type: "tool_result",
              tool_use_id: appel.id,
              content: resultat.contenu,
              ...(resultat.estErreur ? { is_error: true } : {}),
            };
          }),
        );
        if (poseOutils) {
          pose = poseOutils;
          annoncer(pose);
        }
        // Tous les résultats dans un seul message, pour garder les appels parallèles.
        messages.push({ role: "user", content: resultats });
      }
      throw new Error(`Plus de ${this.options.etapesMax} étapes d'outils dans un seul tour`);
    } catch (err) {
      messages.length = longueurInitiale;
      throw err;
    }
  }
}
