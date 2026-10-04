import Anthropic from "@anthropic-ai/sdk";
import { creerServeur } from "./app.js";
import { Assistant } from "./assistant.js";
import { HttpBackend } from "./backend/http.js";
import { MockBackend } from "./backend/mock.js";
import { config } from "./config.js";
import { chargerConnaissances, construirePromptSysteme } from "./prompt.js";

const base = chargerConnaissances(config.dossierConnaissances);
console.log(`[sahla] base de connaissances : ${base.fichiers.length} fichiers (${base.fichiers.join(", ")})`);
if (base.aCompleter > 0) {
  console.warn(`[sahla] ${base.aCompleter} informations [À COMPLÉTER] : Sahla dira qu'elle ne les connaît pas.`);
}

const backend = config.sehelliApiUrl ? new HttpBackend(config.sehelliApiUrl, config.sehelliApiCle) : new MockBackend();
if (backend.nom === "démo") {
  console.warn("[sahla] SEHELLI_API_URL absent : données de démonstration (lieux, prix et commandes fictifs).");
}

// Le client lit ANTHROPIC_API_KEY dans l'environnement.
const assistant = new Assistant(new Anthropic(), backend, construirePromptSysteme(base), {
  modele: config.modele,
  effort: config.effort,
  maxTokens: config.maxTokens,
  etapesMax: config.limites.etapesOutilsParTour,
});

const serveur = creerServeur({
  assistant,
  backend,
  modele: config.modele,
  dossierPublic: config.pageDemo ? config.dossierPublic : undefined,
  originesAutorisees: config.originesAutorisees,
  exigerConnexion: process.env.SAHLA_CONNEXION_OBLIGATOIRE === "1",
  limites: config.limites,
});

serveur.listen(config.port, () => {
  console.log(`[sahla] prête sur http://localhost:${config.port} (modèle ${config.modele}, effort ${config.effort})`);
  if (config.pageDemo) console.log(`[sahla] page de démo : http://localhost:${config.port}/`);
});
