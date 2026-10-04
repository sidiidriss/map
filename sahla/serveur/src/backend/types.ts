// Contrat entre Sahla et le backend Sehelli. Le backend réel (HttpBackend) doit
// exposer ces opérations ; le MockBackend les simule pour la démo et les tests.

export interface ContexteUtilisateur {
  /** En-tête Authorization de l'app, transmis tel quel à l'API Sehelli. */
  authorization?: string;
  langue?: string;
  position?: { lat: number; lng: number };
}

export interface Lieu {
  id: string;
  nom: string;
  quartier?: string;
  ville: string;
  lat: number;
  lng: number;
}

export type Service = "course" | "livraison";

export interface DemandeEstimation {
  service: Service;
  depart_id: string;
  arrivee_id: string;
  categorie?: string;
}

export interface Estimation {
  service: Service;
  categorie: string;
  depart: string;
  arrivee: string;
  distance_km: number;
  duree_min: number;
  prix_min: number;
  prix_max: number;
  devise: string;
  note?: string;
}

export interface Commande {
  id: string;
  service: Service;
  statut: "en_attente" | "en_route" | "en_cours" | "livree" | "terminee" | "annulee";
  depart: string;
  arrivee: string;
  date: string;
  montant: number;
  devise: string;
  chauffeur?: { prenom: string; vehicule: string; plaque: string };
  arrivee_estimee_min?: number;
}

export interface Portefeuille {
  solde: number;
  devise: string;
  dernieres_operations: { date: string; libelle: string; montant: number }[];
}

export interface DemandeTicket {
  categorie: string;
  resume: string;
  priorite: "normale" | "haute" | "urgente";
  commande_id?: string;
}

export interface Ticket {
  ticket_id: string;
  delai_reponse: string;
}

/** Erreur métier lisible par Sahla (ex. hors zone, non connecté). */
export class ErreurSehelli extends Error {
  constructor(
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export interface SehelliBackend {
  readonly nom: string;
  rechercherLieu(requete: string, ctx: ContexteUtilisateur): Promise<Lieu[]>;
  estimerPrix(demande: DemandeEstimation, ctx: ContexteUtilisateur): Promise<Estimation>;
  mesCommandes(
    filtre: { statut: "en_cours" | "terminees" | "toutes"; commande_id?: string; limite: number },
    ctx: ContexteUtilisateur,
  ): Promise<Commande[]>;
  portefeuille(ctx: ContexteUtilisateur): Promise<Portefeuille>;
  creerTicket(demande: DemandeTicket, ctx: ContexteUtilisateur): Promise<Ticket>;
}
