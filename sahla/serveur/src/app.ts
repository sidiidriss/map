import { createHash } from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { Assistant, type Evenement } from "./assistant.js";
import type { SehelliBackend } from "./backend/types.js";
import { Limiteur } from "./limites.js";
import { LANGUES, texteContexte } from "./prompt.js";
import { Conversations } from "./sessions.js";

export interface DependancesServeur {
  assistant: Assistant;
  backend: SehelliBackend;
  modele: string;
  dossierPublic?: string;
  originesAutorisees: string[];
  exigerConnexion: boolean;
  limites: {
    messagesParMinute: number;
    messagesParJour: number;
    caracteresParMessage: number;
    toursParConversation: number;
    dureeConversationMs: number;
  };
}

const TYPES_MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
};

// Supprime les caractères de contrôle d'un champ libre envoyé par l'app avant
// de l'insérer dans le contexte du modèle.
const champLibre = (max: number) =>
  z
    .string()
    .max(max)
    .transform((s) => s.replace(/[\u0000-\u001f\u007f<>]/g, " ").trim())
    .optional();

export function creerServeur(deps: DependancesServeur): http.Server {
  const conversations = new Conversations(deps.limites.dureeConversationMs);
  const limiteur = new Limiteur(deps.limites.messagesParMinute, deps.limites.messagesParJour);
  const limiteurIp = new Limiteur(deps.limites.messagesParMinute * 3, deps.limites.messagesParJour * 3);

  const Corps = z.object({
    conversation_id: z.string().max(64).optional(),
    message: z.string().trim().min(1).max(deps.limites.caracteresParMessage),
    langue: z.enum(Object.keys(LANGUES) as [string, ...string[]]).optional(),
    // voix : l'app transcrit la parole de l'utilisateur et lira la réponse à voix haute.
    canal: z.enum(["voix", "texte"]).default("texte"),
    contexte: z
      .object({
        prenom: champLibre(40),
        ecran: champLibre(40),
        position: z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) }).optional(),
      })
      .optional(),
  });

  const fichiersPublics = new Map<string, string>();
  if (deps.dossierPublic && fs.existsSync(deps.dossierPublic)) {
    for (const f of fs.readdirSync(deps.dossierPublic)) {
      if (TYPES_MIME[path.extname(f)]) fichiersPublics.set(`/${f}`, path.join(deps.dossierPublic, f));
    }
    if (fichiersPublics.has("/index.html")) fichiersPublics.set("/", path.join(deps.dossierPublic, "index.html"));
  }

  function appliquerCors(req: http.IncomingMessage, res: http.ServerResponse) {
    const origine = req.headers.origin;
    if (!origine) return;
    if (deps.originesAutorisees.includes("*") || deps.originesAutorisees.includes(origine)) {
      res.setHeader("Access-Control-Allow-Origin", origine);
      res.setHeader("Vary", "Origin");
      res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
      res.setHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS");
    }
  }

  function json(res: http.ServerResponse, statut: number, corps: unknown) {
    res.writeHead(statut, { "Content-Type": "application/json; charset=utf-8" });
    res.end(JSON.stringify(corps));
  }

  function identifiant(req: http.IncomingMessage): { cle: string; ip: string } {
    const ip = req.socket.remoteAddress ?? "inconnue";
    const auth = req.headers.authorization;
    const cle = auth ? `jeton:${createHash("sha256").update(auth).digest("hex").slice(0, 32)}` : `ip:${ip}`;
    return { cle, ip };
  }

  async function lireCorps(req: http.IncomingMessage, max = 64_000): Promise<unknown> {
    let taille = 0;
    const morceaux: Buffer[] = [];
    for await (const morceau of req) {
      taille += (morceau as Buffer).length;
      if (taille > max) throw new Error("corps trop volumineux");
      morceaux.push(morceau as Buffer);
    }
    return JSON.parse(Buffer.concat(morceaux).toString("utf8"));
  }

  async function message(req: http.IncomingMessage, res: http.ServerResponse) {
    const { cle, ip } = identifiant(req);
    if (deps.exigerConnexion && !req.headers.authorization) {
      return json(res, 401, { erreur: "non_connecte" });
    }

    let corps: z.infer<typeof Corps>;
    try {
      const analyse = Corps.safeParse(await lireCorps(req));
      if (!analyse.success) {
        const tropLong = analyse.error.issues.some((i) => i.path[0] === "message" && i.code === "too_big");
        return json(res, 400, { erreur: tropLong ? "trop_long" : "requete_invalide" });
      }
      corps = analyse.data;
    } catch {
      return json(res, 400, { erreur: "requete_invalide" });
    }

    if (!limiteurIp.autoriser(`ip:${ip}`) || !limiteur.autoriser(cle)) {
      return json(res, 429, { erreur: "limite" });
    }

    let conversation = conversations.obtenirOuCreer(corps.conversation_id, cle);
    if (conversation.occupee) return json(res, 409, { erreur: "occupe" });
    if (conversation.tours >= deps.limites.toursParConversation) {
      // Conversation trop longue : on en recommence une, l'app affiche un nouveau fil.
      conversation = conversations.obtenirOuCreer(undefined, cle);
    }

    res.writeHead(200, {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    const envoyer = (evenement: string, donnees: unknown) => {
      if (!res.writableEnded) res.write(`event: ${evenement}\ndata: ${JSON.stringify(donnees)}\n\n`);
    };
    const ping = setInterval(() => !res.writableEnded && res.write(": ping\n\n"), 15_000);
    const annulation = new AbortController();
    res.on("close", () => {
      if (!res.writableEnded) annulation.abort();
    });

    conversation.occupee = true;
    conversation.derniereActivite = Date.now();
    envoyer("debut", { conversation_id: conversation.id });

    try {
      const fin = await deps.assistant.repondre({
        conversation,
        message: corps.message,
        contexte: texteContexte({
          langue: corps.langue,
          canal: corps.canal,
          prenom: corps.contexte?.prenom || undefined,
          ecran: corps.contexte?.ecran || undefined,
          connecte: Boolean(req.headers.authorization),
          positionPartagee: Boolean(corps.contexte?.position),
        }),
        utilisateur: {
          authorization: req.headers.authorization,
          langue: corps.langue,
          position: corps.contexte?.position,
        },
        emettre: (e: Evenement) => {
          const { type, ...donnees } = e;
          envoyer(type, donnees);
        },
        signal: annulation.signal,
      });
      if (fin.statut === "refus") envoyer("erreur", { code: "refus" });
      else envoyer("fin", { conversation_id: conversation.id, pose: fin.pose });
    } catch (err) {
      if (!(err instanceof Anthropic.APIUserAbortError)) {
        console.error("[sahla] échec du tour :", err);
        const code = err instanceof Anthropic.RateLimitError || (err instanceof Anthropic.APIError && err.status === 529)
          ? "surcharge"
          : "indisponible";
        envoyer("erreur", { code });
      }
    } finally {
      clearInterval(ping);
      conversation.occupee = false;
      conversation.derniereActivite = Date.now();
      res.end();
    }
  }

  return http.createServer(async (req, res) => {
    appliquerCors(req, res);
    const url = new URL(req.url ?? "/", "http://localhost");
    try {
      if (req.method === "OPTIONS") {
        res.writeHead(204);
        return res.end();
      }
      if (req.method === "GET" && url.pathname === "/sante") {
        return json(res, 200, { ok: true, modele: deps.modele, backend: deps.backend.nom, conversations: conversations.taille });
      }
      if (req.method === "POST" && url.pathname === "/v1/sahla/message") {
        return await message(req, res);
      }
      const suppression = url.pathname.match(/^\/v1\/sahla\/conversations\/([\w-]{1,64})$/);
      if (req.method === "DELETE" && suppression) {
        conversations.supprimer(suppression[1], identifiant(req).cle);
        res.writeHead(204);
        return res.end();
      }
      const fichier = req.method === "GET" ? fichiersPublics.get(url.pathname) : undefined;
      if (fichier) {
        res.writeHead(200, { "Content-Type": TYPES_MIME[path.extname(fichier)] });
        return fs.createReadStream(fichier).pipe(res);
      }
      json(res, 404, { erreur: "introuvable" });
    } catch (err) {
      console.error("[sahla] erreur :", err);
      if (!res.headersSent) json(res, 500, { erreur: "interne" });
      else res.end();
    }
  });
}
