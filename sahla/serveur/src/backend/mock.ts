import { randomInt } from "node:crypto";
import { LIEUX_NOUAKCHOTT } from "./lieux-nouakchott.js";
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

const NOTE_DEMO = "Données de démonstration : tarifs et commandes fictifs.";

/** Minuscules, sans accents, alifs/ya/ta marbouta arabes unifiés, sans tashkeel. */
export function normaliser(texte: string): string {
  return texte
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[\u064B-\u065F\u0670\u0640]/g, "") // tashkeel, hamza suscrite/souscrite, tatweel
    .replace(/[أإآ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[’'`-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function distanceKm(a: { lat: number; lng: number }, b: { lat: number; lng: number }): number {
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}

const arrondir10 = (n: number) => Math.round(n / 10) * 10;

const TARIFS: Record<string, { base: number; parKm: number; service: "course" | "livraison" }> = {
  standard: { base: 100, parKm: 30, service: "course" },
  confort: { base: 150, parKm: 42, service: "course" },
  petit_colis: { base: 80, parKm: 20, service: "livraison" },
  gros_colis: { base: 150, parKm: 30, service: "livraison" },
};

export class MockBackend implements SehelliBackend {
  readonly nom = "démo";

  async rechercherLieu(requete: string): Promise<Lieu[]> {
    const q = normaliser(requete);
    if (q.length < 2) return [];
    const scores = LIEUX_NOUAKCHOTT.map((lieu) => {
      let score = 0;
      for (const alias of [lieu.nom, ...lieu.alias].map(normaliser)) {
        if (alias === q) score = Math.max(score, 3);
        else if (q.includes(alias) && alias.length >= 3) score = Math.max(score, 2);
        else if (alias.includes(q) && q.length >= 3) score = Math.max(score, 1);
      }
      return { lieu, score };
    });
    return scores
      .filter((s) => s.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, 5)
      .map(({ lieu: { alias: _alias, ...lieu } }) => lieu);
  }

  private resoudre(id: string, ctx: ContexteUtilisateur): { nom: string; lat: number; lng: number } {
    if (id === "position_actuelle") {
      if (!ctx.position) {
        throw new ErreurSehelli("position_inconnue", "La position de l'utilisateur n'est pas partagée par l'app.");
      }
      return { nom: "Votre position", ...ctx.position };
    }
    const lieu = LIEUX_NOUAKCHOTT.find((l) => l.id === id);
    if (!lieu) throw new ErreurSehelli("lieu_inconnu", `Lieu inconnu : ${id}. Utilise rechercher_lieu d'abord.`);
    return lieu;
  }

  async estimerPrix(demande: DemandeEstimation, ctx: ContexteUtilisateur): Promise<Estimation> {
    const depart = this.resoudre(demande.depart_id, ctx);
    const arrivee = this.resoudre(demande.arrivee_id, ctx);
    const categorie = demande.categorie ?? (demande.service === "course" ? "standard" : "petit_colis");
    const tarif = TARIFS[categorie];
    if (!tarif || tarif.service !== demande.service) {
      const valides = Object.entries(TARIFS)
        .filter(([, t]) => t.service === demande.service)
        .map(([c]) => c);
      throw new ErreurSehelli("categorie_inconnue", `Catégories disponibles pour ${demande.service} : ${valides.join(", ")}.`);
    }
    const km = distanceKm(depart, arrivee) * 1.3;
    if (km > 60) throw new ErreurSehelli("hors_zone", "Trajet hors de la zone desservie (Nouakchott).");
    const prix = tarif.base + tarif.parKm * km;
    return {
      service: demande.service,
      categorie,
      depart: depart.nom,
      arrivee: arrivee.nom,
      distance_km: Math.round(km * 10) / 10,
      duree_min: Math.round((km / 25) * 60 + 3),
      prix_min: arrondir10(prix * 0.9),
      prix_max: arrondir10(prix * 1.1),
      devise: "MRU",
      note: NOTE_DEMO,
    };
  }

  async mesCommandes(
    filtre: { statut: "en_cours" | "terminees" | "toutes"; commande_id?: string; limite: number },
    ctx: ContexteUtilisateur,
  ): Promise<Commande[]> {
    // Jeton spécial pour tester l'état « liste vide » de la mascotte.
    if (ctx.authorization === "Bearer demo-vide") return [];
    const ilYA = (heures: number) => new Date(Date.now() - heures * 3_600_000).toISOString();
    const commandes: Commande[] = [
      { id: "CMD-1042", service: "course", statut: "en_route", depart: "Tevragh Zeina", arrivee: "Aéroport Oumtounsy",
        date: ilYA(0.1), montant: 750, devise: "MRU", arrivee_estimee_min: 6,
        chauffeur: { prenom: "Mohamed", vehicule: "Toyota Corolla grise", plaque: "1234 AA 00" } },
      { id: "CMD-1031", service: "livraison", statut: "livree", depart: "Marché Capitale", arrivee: "Ksar",
        date: ilYA(26), montant: 180, devise: "MRU" },
      { id: "CMD-1017", service: "course", statut: "terminee", depart: "Ksar", arrivee: "Sebkha",
        date: ilYA(75), montant: 260, devise: "MRU" },
    ];
    const enCours = new Set(["en_attente", "en_route", "en_cours"]);
    return commandes
      .filter((c) => !filtre.commande_id || c.id === filtre.commande_id)
      .filter((c) =>
        filtre.statut === "toutes" ? true : filtre.statut === "en_cours" ? enCours.has(c.statut) : !enCours.has(c.statut),
      )
      .slice(0, filtre.limite);
  }

  async portefeuille(): Promise<Portefeuille> {
    const ilYA = (jours: number) => new Date(Date.now() - jours * 86_400_000).toISOString().slice(0, 10);
    return {
      solde: 1250,
      devise: "MRU",
      dernieres_operations: [
        { date: ilYA(1), libelle: "Livraison CMD-1031", montant: -180 },
        { date: ilYA(2), libelle: "Recharge", montant: 1000 },
        { date: ilYA(3), libelle: "Course CMD-1017", montant: -260 },
      ],
    };
  }

  async creerTicket(_demande: DemandeTicket): Promise<Ticket> {
    return { ticket_id: `SUP-${randomInt(100000, 999999)}`, delai_reponse: "(démo) réponse sous 2 heures" };
  }
}
