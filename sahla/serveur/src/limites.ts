// Limite le nombre de messages par utilisateur pour maîtriser les coûts.
export class Limiteur {
  private historique = new Map<string, number[]>();

  constructor(
    private parMinute: number,
    private parJour: number,
  ) {
    setInterval(() => this.nettoyer(), 10 * 60_000).unref();
  }

  /** Enregistre un message et renvoie false si l'utilisateur dépasse une limite. */
  autoriser(cle: string, maintenant = Date.now()): boolean {
    const jour = maintenant - 86_400_000;
    const horodatages = (this.historique.get(cle) ?? []).filter((t) => t > jour);
    const derniereMinute = horodatages.filter((t) => t > maintenant - 60_000).length;
    if (derniereMinute >= this.parMinute || horodatages.length >= this.parJour) {
      this.historique.set(cle, horodatages);
      return false;
    }
    horodatages.push(maintenant);
    this.historique.set(cle, horodatages);
    return true;
  }

  private nettoyer(): void {
    const jour = Date.now() - 86_400_000;
    for (const [cle, h] of this.historique) {
      if (!h.some((t) => t > jour)) this.historique.delete(cle);
    }
  }
}
