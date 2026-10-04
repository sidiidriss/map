import 'mascotte/poses.dart';

/// Bouton proposé par Sahla : l'app ouvre l'écran correspondant, pré-rempli,
/// et c'est l'utilisateur qui confirme.
class SahlaAction {
  const SahlaAction({required this.ecran, required this.libelle, this.parametres = const {}});

  /// commander_course, commander_livraison, suivi_commande, portefeuille,
  /// recharger_portefeuille, historique_commandes, profil ou aide_contact.
  final String ecran;
  final String libelle;

  /// Identifiants utiles : depart_id, arrivee_id, categorie, commande_id.
  final Map<String, String> parametres;

  factory SahlaAction.depuisJson(Map<String, dynamic> json) => SahlaAction(
        ecran: json['ecran'] as String,
        libelle: json['libelle'] as String,
        parametres: (json['parametres'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, '$v')),
      );
}

/// Informations de l'app transmises à Sahla à chaque message.
class SahlaContexte {
  const SahlaContexte({this.prenom, this.ecran, this.latitude, this.longitude});

  final String? prenom;

  /// Écran ouvert dans l'app (ex. « accueil », « suivi_commande »).
  final String? ecran;
  final double? latitude;
  final double? longitude;

  Map<String, dynamic> versJson() => {
        if (prenom != null) 'prenom': prenom,
        if (ecran != null) 'ecran': ecran,
        if (latitude != null && longitude != null) 'position': {'lat': latitude, 'lng': longitude},
      };
}

/// Événements diffusés par le serveur pendant une réponse.
sealed class SahlaEvenement {
  const SahlaEvenement();
}

class SahlaDebut extends SahlaEvenement {
  const SahlaDebut(this.conversationId);
  final String conversationId;
}

class SahlaTexte extends SahlaEvenement {
  const SahlaTexte(this.delta);
  final String delta;
}

/// Remplace tout le texte de la réponse en cours.
class SahlaRemplacer extends SahlaEvenement {
  const SahlaRemplacer(this.texte);
  final String texte;
}

class SahlaChangementPose extends SahlaEvenement {
  const SahlaChangementPose(this.pose);
  final SahlaPose pose;
}

class SahlaOutil extends SahlaEvenement {
  const SahlaOutil(this.nom, {required this.termine});
  final String nom;
  final bool termine;
}

class SahlaActionProposee extends SahlaEvenement {
  const SahlaActionProposee(this.action);
  final SahlaAction action;
}

class SahlaFin extends SahlaEvenement {
  const SahlaFin(this.conversationId, this.pose);
  final String conversationId;
  final SahlaPose pose;
}

/// Erreur : reseau, limite, refus, occupe, trop_long, indisponible, surcharge, non_connecte.
class SahlaErreur extends SahlaEvenement {
  const SahlaErreur(this.code);
  final String code;
}
