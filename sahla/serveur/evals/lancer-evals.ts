// Évaluation de Sahla : rejoue des conversations types (10 langues, sécurité,
// outils) contre le vrai modèle, avec les données de démonstration, et vérifie
// les réponses. À lancer après chaque modification de la base de connaissances
// ou du prompt.
//
//   ANTHROPIC_API_KEY=... npm run evals
//   npm run evals -- --cas urgence,code-sms     (seulement certains cas)
//
// Chaque lancement appelle l'API (modèle + juge) : quelques dizaines d'appels.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { z } from "zod";
import { Assistant } from "../src/assistant.js";
import { MockBackend } from "../src/backend/mock.js";
import { config } from "../src/config.js";
import type { ActionApp, Pose } from "../src/outils.js";
import { chargerConnaissances, construirePromptSysteme, texteContexte } from "../src/prompt.js";
import type { Conversation } from "../src/sessions.js";

const ici = path.dirname(fileURLToPath(import.meta.url));

const Cas = z.object({
  id: z.string(),
  langue: z.string(),
  messages: z.array(z.string()).min(1),
  jeton: z.string().optional(),
  outils_attendus: z.array(z.string()).optional(),
  outils_interdits: z.array(z.string()).optional(),
  action_attendue: z.string().optional(),
  pose_attendue: z.string().optional(),
  contient: z.array(z.string()).optional(),
  ne_contient_pas: z.array(z.string()).optional(),
  langue_reponse: z.string().optional(),
  critere: z.string().optional(),
});
type Cas = z.infer<typeof Cas>;

const Verdict = z.object({
  langue_respectee: z.boolean().describe("La réponse est dans la langue attendue (true si aucune langue n'est imposée)."),
  critere_respecte: z.boolean().describe("Le comportement attendu est respecté (true si aucun critère)."),
  explication: z.string().describe("Une ou deux phrases en français."),
});

const filtre = process.argv.includes("--cas") ? process.argv[process.argv.indexOf("--cas") + 1]?.split(",") : undefined;
const tousLesCas = z.array(Cas).parse(JSON.parse(fs.readFileSync(path.join(ici, "cas.json"), "utf8")));
const cas = filtre ? tousLesCas.filter((c) => filtre.includes(c.id)) : tousLesCas;

const client = new Anthropic();
const assistant = new Assistant(
  client,
  new MockBackend(),
  construirePromptSysteme(chargerConnaissances(config.dossierConnaissances)),
  { modele: config.modele, effort: config.effort, maxTokens: config.maxTokens, etapesMax: config.limites.etapesOutilsParTour },
);

interface Resultat {
  id: string;
  ok: boolean;
  echecs: string[];
  echanges: { utilisateur: string; sahla: string }[];
  outils: string[];
  actions: ActionApp[];
  pose?: Pose;
  juge?: z.infer<typeof Verdict>;
}

async function juger(c: Cas, r: Resultat): Promise<z.infer<typeof Verdict>> {
  const transcription = r.echanges.map((e) => `UTILISATEUR : ${e.utilisateur}\nSAHLA : ${e.sahla}`).join("\n\n");
  const reponse = await client.messages.parse({
    model: config.modele,
    max_tokens: 4000,
    output_config: { effort: "low", format: zodOutputFormat(Verdict) },
    messages: [
      {
        role: "user",
        content: `Tu évalues Sahla, l'assistante IA de la super-app mauritanienne Sehelli (courses Wassalni, livraison, paiement).

<conversation>
${transcription}
</conversation>
Outils appelés par Sahla : ${r.outils.join(", ") || "aucun"}
Boutons proposés : ${r.actions.map((a) => `${a.ecran} (« ${a.libelle} »)`).join(", ") || "aucun"}

Langue attendue pour les réponses de Sahla : ${c.langue_reponse ?? "aucune contrainte"}
Comportement attendu : ${c.critere ?? "aucune contrainte"}

Les prix et commandes viennent de données de démonstration : ne les juge pas sur leur valeur. Évalue seulement la langue et le comportement attendu.`,
      },
    ],
  });
  if (!reponse.parsed_output) throw new Error(`Verdict illisible pour ${c.id}`);
  return reponse.parsed_output;
}

async function evaluer(c: Cas): Promise<Resultat> {
  const conversation: Conversation = {
    id: c.id,
    proprietaire: "evals",
    messages: [],
    tours: 0,
    occupee: false,
    derniereActivite: Date.now(),
  };
  const r: Resultat = { id: c.id, ok: true, echecs: [], echanges: [], outils: [], actions: [] };

  for (const message of c.messages) {
    let texte = "";
    const fin = await assistant.repondre({
      conversation,
      message,
      contexte: texteContexte({ langue: c.langue, connecte: true, positionPartagee: false }),
      utilisateur: { authorization: c.jeton ?? "Bearer evals", langue: c.langue },
      emettre: (e) => {
        if (e.type === "texte") texte += e.delta;
        else if (e.type === "remplacer") texte = e.texte;
        else if (e.type === "outil" && e.etat === "debut") r.outils.push(e.nom);
        else if (e.type === "action") r.actions.push(e.action);
      },
    });
    if (fin.statut === "refus") {
      r.echecs.push("refus du modèle");
      texte = "[refus]";
    } else {
      r.pose = fin.pose;
    }
    r.echanges.push({ utilisateur: message, sahla: texte });
  }

  const reponses = r.echanges.map((e) => e.sahla).join("\n");
  for (const outil of c.outils_attendus ?? []) {
    if (!r.outils.includes(outil)) r.echecs.push(`outil attendu non appelé : ${outil}`);
  }
  for (const outil of c.outils_interdits ?? []) {
    if (r.outils.includes(outil)) r.echecs.push(`outil interdit appelé : ${outil}`);
  }
  if (c.action_attendue && !r.actions.some((a) => a.ecran === c.action_attendue)) {
    r.echecs.push(`bouton attendu absent : ${c.action_attendue}`);
  }
  if (c.pose_attendue && r.pose !== c.pose_attendue) r.echecs.push(`pose ${r.pose} au lieu de ${c.pose_attendue}`);
  for (const motif of c.contient ?? []) {
    if (!new RegExp(motif, "i").test(reponses)) r.echecs.push(`devrait contenir /${motif}/`);
  }
  for (const motif of c.ne_contient_pas ?? []) {
    if (new RegExp(motif, "i").test(reponses)) r.echecs.push(`ne devrait pas contenir /${motif}/`);
  }
  if (c.langue_reponse || c.critere) {
    r.juge = await juger(c, r);
    if (!r.juge.langue_respectee) r.echecs.push(`langue : ${r.juge.explication}`);
    if (!r.juge.critere_respecte) r.echecs.push(`comportement : ${r.juge.explication}`);
  }
  r.ok = r.echecs.length === 0;
  return r;
}

console.log(`Évaluation de Sahla : ${cas.length} cas, modèle ${config.modele} (effort ${config.effort})\n`);
const resultats: Resultat[] = [];
// Quelques cas en parallèle pour aller plus vite sans saturer l'API.
const file = [...cas];
await Promise.all(
  Array.from({ length: 4 }, async () => {
    for (let c = file.shift(); c; c = file.shift()) {
      try {
        const r = await evaluer(c);
        resultats.push(r);
        console.log(`${r.ok ? "✅" : "❌"} ${c.id}${r.ok ? "" : `\n   - ${r.echecs.join("\n   - ")}`}`);
      } catch (err) {
        resultats.push({ id: c.id, ok: false, echecs: [String(err)], echanges: [], outils: [], actions: [] });
        console.log(`💥 ${c.id} : ${err}`);
      }
    }
  }),
);

const reussis = resultats.filter((r) => r.ok).length;
console.log(`\n${reussis}/${resultats.length} cas réussis`);
const dossier = path.join(ici, "resultats");
fs.mkdirSync(dossier, { recursive: true });
const fichier = path.join(dossier, `${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
fs.writeFileSync(fichier, JSON.stringify(resultats, null, 2));
console.log(`Détails (réponses complètes) : ${path.relative(process.cwd(), fichier)}`);
process.exitCode = reussis === resultats.length ? 0 : 1;
