import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ici = path.dirname(fileURLToPath(import.meta.url));

// Variables d'environnement locales (copie de .env.example), si le fichier existe.
const fichierEnv = path.resolve(ici, "../.env");
if (fs.existsSync(fichierEnv)) process.loadEnvFile(fichierEnv);

type Effort = "low" | "medium" | "high" | "xhigh" | "max";

function nombre(nom: string, defaut: number): number {
  const brut = process.env[nom];
  if (brut === undefined || brut === "") return defaut;
  const n = Number(brut);
  if (!Number.isFinite(n)) throw new Error(`Variable ${nom} invalide : ${brut}`);
  return n;
}

export const config = {
  port: nombre("PORT", 8787),

  // Modèle Claude utilisé par Sahla. L'effort « low » garde des réponses rapides
  // pour un chat mobile ; passer à « medium » si les évaluations montrent un gain.
  modele: process.env.SAHLA_MODELE ?? "claude-opus-5-5",
  effort: (process.env.SAHLA_EFFORT ?? "low") as Effort,
  maxTokens: nombre("SAHLA_MAX_TOKENS", 16000),

  // Dossier de la base de connaissances (l'« entraînement » de Sahla).
  dossierConnaissances:
    process.env.SAHLA_CONNAISSANCES ?? path.resolve(ici, "../../connaissances"),
  dossierPublic: path.resolve(ici, "../public"),
  pageDemo: process.env.SAHLA_PAGE_DEMO !== "0",

  // API Sehelli. Sans URL, Sahla tourne avec des données de démonstration.
  sehelliApiUrl: process.env.SEHELLI_API_URL ?? "",
  sehelliApiCle: process.env.SEHELLI_API_CLE ?? "",

  originesAutorisees: (process.env.SAHLA_ORIGINES ?? "*").split(",").map((o) => o.trim()),

  limites: {
    messagesParMinute: nombre("SAHLA_LIMITE_MINUTE", 10),
    messagesParJour: nombre("SAHLA_LIMITE_JOUR", 200),
    caracteresParMessage: nombre("SAHLA_MAX_CARACTERES", 2000),
    toursParConversation: nombre("SAHLA_MAX_TOURS", 40),
    etapesOutilsParTour: 8,
    dureeConversationMs: nombre("SAHLA_DUREE_CONVERSATION_MIN", 120) * 60_000,
  },
};
