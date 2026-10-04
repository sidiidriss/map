import http from "node:http";
import type { AddressInfo } from "node:net";

// Faux serveur de l'API Messages : rejoue des réponses scriptées au format SSE
// et enregistre les requêtes reçues, pour tester tout le circuit sans clé API.

export type Bloc =
  | { type: "thinking"; thinking: string; signature: string }
  | { type: "text"; text: string }
  | { type: "tool_use"; id: string; name: string; input: unknown; jsonBrut?: string };

export interface ReponseScriptee {
  blocs: Bloc[];
  stop_reason: "end_turn" | "tool_use" | "refusal" | "max_tokens";
  /** Répond avec une erreur HTTP au lieu d'un flux. */
  statutHttp?: number;
}

export interface RequeteRecue {
  entetes: http.IncomingHttpHeaders;
  corps: any;
}

export async function demarrerFauxAnthropic(script: ReponseScriptee[]) {
  const requetes: RequeteRecue[] = [];
  const serveur = http.createServer(async (req, res) => {
    let brut = "";
    for await (const morceau of req) brut += morceau;
    requetes.push({ entetes: req.headers, corps: JSON.parse(brut) });
    const reponse = script.shift();
    if (!reponse) {
      res.writeHead(500, { "content-type": "application/json" });
      return res.end(JSON.stringify({ type: "error", error: { type: "api_error", message: "script épuisé" } }));
    }
    if (reponse.statutHttp) {
      res.writeHead(reponse.statutHttp, { "content-type": "application/json" });
      return res.end(JSON.stringify({ type: "error", error: { type: "rate_limit_error", message: "trop de requêtes" } }));
    }
    res.writeHead(200, { "content-type": "text/event-stream" });
    const envoyer = (type: string, data: object) => res.write(`event: ${type}\ndata: ${JSON.stringify({ type, ...data })}\n\n`);
    envoyer("message_start", {
      message: {
        id: `msg_${requetes.length}`, type: "message", role: "assistant", model: "claude-opus-5-5",
        content: [], stop_reason: null, stop_sequence: null,
        usage: { input_tokens: 10, output_tokens: 0 },
      },
    });
    reponse.blocs.forEach((bloc, index) => {
      if (bloc.type === "text") {
        envoyer("content_block_start", { index, content_block: { type: "text", text: "" } });
        // Découpe en deux morceaux pour simuler la diffusion.
        const milieu = Math.ceil(bloc.text.length / 2);
        for (const morceau of [bloc.text.slice(0, milieu), bloc.text.slice(milieu)]) {
          if (morceau) envoyer("content_block_delta", { index, delta: { type: "text_delta", text: morceau } });
        }
      } else if (bloc.type === "thinking") {
        envoyer("content_block_start", { index, content_block: { type: "thinking", thinking: "", signature: "" } });
        envoyer("content_block_delta", { index, delta: { type: "thinking_delta", thinking: bloc.thinking } });
        envoyer("content_block_delta", { index, delta: { type: "signature_delta", signature: bloc.signature } });
      } else {
        envoyer("content_block_start", { index, content_block: { type: "tool_use", id: bloc.id, name: bloc.name, input: {} } });
        const json = bloc.jsonBrut ?? JSON.stringify(bloc.input);
        envoyer("content_block_delta", { index, delta: { type: "input_json_delta", partial_json: json } });
      }
      envoyer("content_block_stop", { index });
    });
    envoyer("message_delta", { delta: { stop_reason: reponse.stop_reason, stop_sequence: null }, usage: { output_tokens: 20 } });
    envoyer("message_stop", {});
    res.end();
  });
  await new Promise<void>((ok) => serveur.listen(0, "127.0.0.1", ok));
  const { port } = serveur.address() as AddressInfo;
  return {
    url: `http://127.0.0.1:${port}`,
    requetes,
    script,
    fermer: () => new Promise<void>((ok) => serveur.close(() => ok())),
  };
}
