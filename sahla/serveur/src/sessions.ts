import { randomUUID } from "node:crypto";
import type Anthropic from "@anthropic-ai/sdk";

export interface Conversation {
  id: string;
  /** Empreinte de l'utilisateur propriétaire : une conversation n'est lisible que par lui. */
  proprietaire: string;
  /**
   * Historique complet envoyé à l'API, blocs de réflexion compris. Il ne doit
   * être modifié qu'en ajoutant à la fin (ou en revenant à une longueur
   * antérieure après un échec) pour que les blocs de réflexion restent valides.
   */
  messages: Anthropic.Beta.BetaMessageParam[];
  tours: number;
  occupee: boolean;
  derniereActivite: number;
}

// Stockage en mémoire : suffisant pour une instance. Pour plusieurs instances
// derrière un répartiteur, remplacer par Redis en gardant la même interface.
export class Conversations {
  private parId = new Map<string, Conversation>();

  constructor(private dureeMs: number) {
    setInterval(() => this.nettoyer(), 60_000).unref();
  }

  obtenirOuCreer(id: string | undefined, proprietaire: string): Conversation {
    if (id) {
      const existante = this.parId.get(id);
      if (existante && existante.proprietaire === proprietaire) return existante;
    }
    const conversation: Conversation = {
      id: randomUUID(),
      proprietaire,
      messages: [],
      tours: 0,
      occupee: false,
      derniereActivite: Date.now(),
    };
    this.parId.set(conversation.id, conversation);
    return conversation;
  }

  supprimer(id: string, proprietaire: string): boolean {
    const conversation = this.parId.get(id);
    if (!conversation || conversation.proprietaire !== proprietaire) return false;
    return this.parId.delete(id);
  }

  get taille(): number {
    return this.parId.size;
  }

  private nettoyer(): void {
    const limite = Date.now() - this.dureeMs;
    for (const [id, c] of this.parId) {
      if (!c.occupee && c.derniereActivite < limite) this.parId.delete(id);
    }
  }
}
