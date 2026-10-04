import {
  ErreurSehelli,
  type Commande,
  type ContexteUtilisateur,
  type DemandeEstimation,
  type DemandeTicket,
  type Estimation,
  type Lieu,
  type Portefeuille,
  type SehelliBackend,
  type Ticket,
} from "./types.js";

// Branche Sahla sur la vraie API Sehelli. Les routes ci-dessous sont le contrat
// proposé (voir sahla/README.md) : l'équipe backend peut les adapter ici.
export class HttpBackend implements SehelliBackend {
  readonly nom = "api";
  private baseUrl: string;

  constructor(
    baseUrl: string,
    private cleServeur: string,
  ) {
    // Garde le chemin de base (ex. https://api.sehelli.mr/v1/) lors de la résolution des routes.
    this.baseUrl = baseUrl.endsWith("/") ? baseUrl : `${baseUrl}/`;
  }

  private async appeler<T>(
    methode: "GET" | "POST",
    chemin: string,
    ctx: ContexteUtilisateur,
    corps?: unknown,
  ): Promise<T> {
    const entetes: Record<string, string> = { Accept: "application/json" };
    if (ctx.authorization) entetes.Authorization = ctx.authorization;
    if (this.cleServeur) entetes["X-Sahla-Cle"] = this.cleServeur;
    if (ctx.langue) entetes["Accept-Language"] = ctx.langue;
    if (corps !== undefined) entetes["Content-Type"] = "application/json";

    const reponse = await fetch(new URL(chemin, this.baseUrl), {
      method: methode,
      headers: entetes,
      body: corps === undefined ? undefined : JSON.stringify(corps),
      signal: AbortSignal.timeout(10_000),
    });
    if (reponse.status === 401 || reponse.status === 403) {
      throw new ErreurSehelli("non_connecte", "L'utilisateur doit être connecté à son compte Sehelli.");
    }
    if (!reponse.ok) {
      // Le backend peut renvoyer { code, message } pour une erreur métier (ex. hors_zone).
      const detail = (await reponse.json().catch(() => null)) as { code?: string; message?: string } | null;
      throw new ErreurSehelli(detail?.code ?? `http_${reponse.status}`, detail?.message ?? "Service Sehelli indisponible.");
    }
    return (await reponse.json()) as T;
  }

  rechercherLieu(requete: string, ctx: ContexteUtilisateur): Promise<Lieu[]> {
    const params = new URLSearchParams({ q: requete });
    if (ctx.position) {
      params.set("lat", String(ctx.position.lat));
      params.set("lng", String(ctx.position.lng));
    }
    return this.appeler("GET", `assistant/lieux?${params}`, ctx);
  }

  estimerPrix(demande: DemandeEstimation, ctx: ContexteUtilisateur): Promise<Estimation> {
    return this.appeler("POST", "assistant/estimations", ctx, { ...demande, position: ctx.position });
  }

  mesCommandes(
    filtre: { statut: "en_cours" | "terminees" | "toutes"; commande_id?: string; limite: number },
    ctx: ContexteUtilisateur,
  ): Promise<Commande[]> {
    const params = new URLSearchParams({ statut: filtre.statut, limite: String(filtre.limite) });
    if (filtre.commande_id) params.set("id", filtre.commande_id);
    return this.appeler("GET", `assistant/commandes?${params}`, ctx);
  }

  portefeuille(ctx: ContexteUtilisateur): Promise<Portefeuille> {
    return this.appeler("GET", "assistant/portefeuille", ctx);
  }

  creerTicket(demande: DemandeTicket, ctx: ContexteUtilisateur): Promise<Ticket> {
    return this.appeler("POST", "assistant/tickets", ctx, demande);
  }
}
