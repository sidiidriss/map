import type Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { ErreurSehelli, type ContexteUtilisateur, type SehelliBackend } from "./backend/types.js";

/** Les 6 expressions animées de la mascotte (voir la maquette Sahla). */
export type Pose = "hello" | "go" | "search" | "bravo" | "oops" | "empty";

export const ECRANS = [
  "commander_course",
  "commander_livraison",
  "suivi_commande",
  "portefeuille",
  "recharger_portefeuille",
  "historique_commandes",
  "profil",
  "aide_contact",
] as const;

/** Bouton que l'app affiche sous la réponse de Sahla. */
export interface ActionApp {
  ecran: (typeof ECRANS)[number];
  libelle: string;
  parametres: Record<string, string>;
}

export interface ResultatOutil {
  contenu: string;
  estErreur: boolean;
  action?: ActionApp;
  pose?: Pose;
}

const schemas = {
  rechercher_lieu: z.object({ requete: z.string().min(1).max(200) }),
  estimer_prix: z.object({
    service: z.enum(["course", "livraison"]),
    depart_id: z.string().min(1),
    arrivee_id: z.string().min(1),
    categorie: z.string().optional(),
  }),
  mes_commandes: z.object({
    statut: z.enum(["en_cours", "terminees", "toutes"]).default("en_cours"),
    commande_id: z.string().optional(),
    limite: z.number().int().min(1).max(10).default(5),
  }),
  mon_portefeuille: z.object({}),
  ouvrir_ecran: z.object({
    ecran: z.enum(ECRANS),
    libelle_bouton: z.string().min(1).max(40),
    depart_id: z.string().optional(),
    arrivee_id: z.string().optional(),
    categorie: z.string().optional(),
    commande_id: z.string().optional(),
  }),
  creer_ticket_support: z.object({
    categorie: z.enum(["paiement", "remboursement", "course", "livraison", "objet_perdu", "securite", "compte", "autre"]),
    resume: z.string().min(10).max(2000),
    priorite: z.enum(["normale", "haute", "urgente"]),
    commande_id: z.string().optional(),
  }),
};

type NomOutil = keyof typeof schemas;

// L'ordre et le contenu des outils doivent rester stables : ils font partie du
// préfixe mis en cache par l'API.
export const OUTILS: Anthropic.Beta.BetaTool[] = [
  {
    name: "rechercher_lieu",
    description:
      "Cherche un lieu (quartier, marché, aéroport, hôpital, adresse connue) dans la zone desservie par Sehelli et renvoie son identifiant. À utiliser avant estimer_prix ou ouvrir_ecran dès que l'utilisateur nomme un lieu. Accepte le nom dans n'importe quelle langue ou écriture (ex. « tevragh zeina », « تفرغ زينة »). Si plusieurs lieux correspondent, demande à l'utilisateur lequel.",
    input_schema: {
      type: "object",
      properties: { requete: { type: "string", description: "Nom du lieu tel que l'utilisateur l'a écrit." } },
      required: ["requete"],
    },
  },
  {
    name: "estimer_prix",
    description:
      "Estime le prix et la durée d'une course Wassalni ou d'une livraison Sehelli entre deux lieux. Le résultat est une fourchette indicative, jamais un prix garanti : présente-le comme une estimation.",
    input_schema: {
      type: "object",
      properties: {
        service: { type: "string", enum: ["course", "livraison"] },
        depart_id: {
          type: "string",
          description: "Identifiant renvoyé par rechercher_lieu, ou \"position_actuelle\" si l'app a partagé la position de l'utilisateur.",
        },
        arrivee_id: { type: "string", description: "Identifiant renvoyé par rechercher_lieu, ou \"position_actuelle\"." },
        categorie: {
          type: "string",
          description: "Optionnel. Catégorie de véhicule ou de colis ; laisser vide pour la catégorie par défaut.",
        },
      },
      required: ["service", "depart_id", "arrivee_id"],
    },
  },
  {
    name: "mes_commandes",
    description:
      "Liste les commandes de l'utilisateur connecté (courses et livraisons) avec leur statut, le chauffeur et l'heure d'arrivée estimée. Utilise-le pour « où est mon chauffeur », « ma livraison », « ma dernière course », etc.",
    input_schema: {
      type: "object",
      properties: {
        statut: { type: "string", enum: ["en_cours", "terminees", "toutes"], description: "Par défaut : en_cours." },
        commande_id: { type: "string", description: "Optionnel. Identifiant précis, ex. CMD-1042." },
        limite: { type: "integer", minimum: 1, maximum: 10, description: "Nombre maximum de commandes. Par défaut : 5." },
      },
    },
  },
  {
    name: "mon_portefeuille",
    description: "Renvoie le solde du portefeuille Sehelli de l'utilisateur connecté et ses dernières opérations.",
    input_schema: { type: "object", properties: {} },
  },
  {
    name: "ouvrir_ecran",
    description:
      "Affiche sous ta réponse un bouton qui ouvre un écran de l'app Sehelli, pré-rempli quand c'est possible. C'est l'utilisateur qui vérifie et confirme dans l'app : tu ne passes jamais toi-même une commande, un paiement ou une annulation. Un seul bouton par réponse, quand l'utilisateur veut agir.",
    input_schema: {
      type: "object",
      properties: {
        ecran: { type: "string", enum: [...ECRANS] },
        libelle_bouton: {
          type: "string",
          description: "Texte du bouton, 2 à 4 mots, dans la langue de l'utilisateur (ex. « Commander la course »).",
        },
        depart_id: { type: "string", description: "Optionnel, pour commander_course / commander_livraison." },
        arrivee_id: { type: "string", description: "Optionnel, pour commander_course / commander_livraison." },
        categorie: { type: "string", description: "Optionnel." },
        commande_id: { type: "string", description: "Optionnel, pour suivi_commande." },
      },
      required: ["ecran", "libelle_bouton"],
    },
  },
  {
    name: "creer_ticket_support",
    description:
      "Transmet un problème à l'équipe support humaine de Sehelli. À utiliser quand tu ne peux pas résoudre toi-même (remboursement, litige de prix, objet perdu, compte bloqué, incident de sécurité, réclamation contre un chauffeur ou un livreur), après avoir résumé le problème à l'utilisateur et obtenu son accord.",
    input_schema: {
      type: "object",
      properties: {
        categorie: {
          type: "string",
          enum: ["paiement", "remboursement", "course", "livraison", "objet_perdu", "securite", "compte", "autre"],
        },
        resume: {
          type: "string",
          description: "Résumé factuel en français pour l'agent : ce qui s'est passé, quand, montants et identifiants utiles.",
        },
        priorite: {
          type: "string",
          enum: ["normale", "haute", "urgente"],
          description: "urgente uniquement pour la sécurité des personnes.",
        },
        commande_id: { type: "string", description: "Optionnel, si le problème concerne une commande." },
      },
      required: ["categorie", "resume", "priorite"],
    },
  },
].map((outil) => ({
  ...outil,
  // Les entrées d'outils sont diffusées au fil de l'eau ; elles sont validées
  // par les schémas zod ci-dessus avant exécution.
  eager_input_streaming: true,
})) as Anthropic.Beta.BetaTool[];

const POSES_ERREUR = new Set(["hors_zone", "non_connecte", "position_inconnue"]);

// En mode démo, les données personnelles sont fictives : Sahla doit le dire.
const noteDemo = (backend: SehelliBackend) =>
  backend.nom === "démo" ? { note: "Données de démonstration : commandes et solde fictifs." } : {};

type Executeurs = {
  [K in NomOutil]: (
    entree: z.infer<(typeof schemas)[K]>,
    backend: SehelliBackend,
    ctx: ContexteUtilisateur,
  ) => Promise<ResultatOutil>;
};

const executeurs: Executeurs = {
  async rechercher_lieu({ requete }, backend, ctx) {
    return { contenu: JSON.stringify({ lieux: await backend.rechercherLieu(requete, ctx) }), estErreur: false };
  },
  async estimer_prix(demande, backend, ctx) {
    return { contenu: JSON.stringify(await backend.estimerPrix(demande, ctx)), estErreur: false };
  },
  async mes_commandes(filtre, backend, ctx) {
    const commandes = await backend.mesCommandes(filtre, ctx);
    return {
      contenu: JSON.stringify({ commandes, ...noteDemo(backend) }),
      estErreur: false,
      pose: commandes.length === 0 ? "empty" : undefined,
    };
  },
  async mon_portefeuille(_entree, backend, ctx) {
    return { contenu: JSON.stringify({ ...(await backend.portefeuille(ctx)), ...noteDemo(backend) }), estErreur: false };
  },
  async ouvrir_ecran({ ecran, libelle_bouton, ...reste }) {
    const parametres = Object.fromEntries(
      Object.entries(reste).filter((e): e is [string, string] => typeof e[1] === "string"),
    );
    const enRoute = ecran === "commander_course" || ecran === "commander_livraison" || ecran === "suivi_commande";
    return {
      contenu: JSON.stringify({ ok: true, info: "Bouton affiché sous ta réponse ; l'utilisateur confirmera dans l'app." }),
      estErreur: false,
      action: { ecran, libelle: libelle_bouton, parametres },
      pose: enRoute ? "go" : undefined,
    };
  },
  async creer_ticket_support(demande, backend, ctx) {
    return { contenu: JSON.stringify(await backend.creerTicket(demande, ctx)), estErreur: false };
  },
};

export async function executerOutil(
  nom: string,
  entree: unknown,
  backend: SehelliBackend,
  ctx: ContexteUtilisateur,
): Promise<ResultatOutil> {
  if (!Object.hasOwn(schemas, nom)) {
    return { contenu: JSON.stringify({ erreur: "outil_inconnu", nom }), estErreur: true };
  }
  const nomOutil = nom as NomOutil;
  // Les entrées diffusées au fil de l'eau peuvent être tronquées : on valide
  // toujours avant d'exécuter.
  const analyse = schemas[nomOutil].safeParse(entree);
  if (!analyse.success) {
    return {
      contenu: JSON.stringify({ erreur: "entree_invalide", details: analyse.error.issues.map((i) => i.message) }),
      estErreur: true,
    };
  }

  try {
    return await executeurs[nomOutil](analyse.data as never, backend, ctx);
  } catch (err) {
    if (err instanceof ErreurSehelli) {
      return {
        contenu: JSON.stringify({ erreur: err.code, message: err.message }),
        estErreur: true,
        pose: POSES_ERREUR.has(err.code) || err.code.startsWith("http_") ? "oops" : undefined,
      };
    }
    console.error(`[sahla] outil ${nom} :`, err);
    return {
      contenu: JSON.stringify({ erreur: "service_indisponible", message: "Service Sehelli momentanément indisponible." }),
      estErreur: true,
      pose: "oops",
    };
  }
}
