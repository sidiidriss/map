import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mascotte/poses.dart';
import 'modeles.dart';

/// Fournit l'en-tête Authorization de l'utilisateur connecté (ex. « Bearer … »),
/// ou null s'il n'est pas connecté.
typedef FournisseurJeton = FutureOr<String?> Function();

/// Client du serveur Sahla (POST /v1/sahla/message, réponse en Server-Sent Events).
class SahlaClient {
  SahlaClient({required this.urlServeur, this.jeton, http.Client? client}) : _http = client ?? http.Client();

  /// Adresse du serveur Sahla, ex. https://sahla.sehelli.mr/
  final Uri urlServeur;
  final FournisseurJeton? jeton;
  final http.Client _http;

  Future<Map<String, String>> _entetes() async {
    final auth = await jeton?.call();
    return {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      if (auth != null) 'Authorization': auth,
    };
  }

  /// Envoie un message et diffuse la réponse de Sahla au fil de l'eau.
  ///
  /// [canal] vaut `SahlaCanal.voix` quand le message est une transcription de la
  /// voix de l'utilisateur et que la réponse sera lue à voix haute : Sahla
  /// répond alors en phrases courtes, sans mise en forme.
  Stream<SahlaEvenement> envoyer({
    required String message,
    required String langue,
    String? conversationId,
    SahlaContexte? contexte,
    SahlaCanal canal = SahlaCanal.texte,
  }) async* {
    final requete = http.Request('POST', urlServeur.resolve('v1/sahla/message'))
      ..headers.addAll(await _entetes())
      ..body = jsonEncode({
        'message': message,
        'langue': langue,
        'canal': canal.name,
        if (conversationId != null) 'conversation_id': conversationId,
        if (contexte != null) 'contexte': contexte.versJson(),
      });

    final http.StreamedResponse reponse;
    try {
      reponse = await _http.send(requete).timeout(const Duration(seconds: 30));
    } catch (_) {
      yield const SahlaErreur('reseau');
      return;
    }

    if (reponse.statusCode != 200) {
      final corps = await reponse.stream.bytesToString().catchError((_) => '');
      String? code;
      try {
        code = (jsonDecode(corps) as Map<String, dynamic>)['erreur'] as String?;
      } catch (_) {}
      yield SahlaErreur(code ?? 'indisponible');
      return;
    }

    var fini = false;
    try {
      await for (final evenement in lireSse(reponse.stream.cast<List<int>>())) {
        if (evenement case SahlaFin() || SahlaErreur()) fini = true;
        yield evenement;
      }
    } catch (_) {
      if (!fini) yield const SahlaErreur('reseau');
      return;
    }
    // Flux coupé avant la fin (perte de réseau) : on le signale.
    if (!fini) yield const SahlaErreur('reseau');
  }

  /// Oublie une conversation côté serveur.
  Future<void> supprimerConversation(String conversationId) async {
    try {
      await _http.delete(urlServeur.resolve('v1/sahla/conversations/$conversationId'), headers: await _entetes());
    } catch (_) {
      // Sans importance : la conversation expirera d'elle-même.
    }
  }

  void fermer() => _http.close();
}

/// Transforme un flux SSE brut en événements Sahla.
Stream<SahlaEvenement> lireSse(Stream<List<int>> octets) async* {
  String? nom;
  final donnees = StringBuffer();
  await for (final ligne in octets.transform(utf8.decoder).transform(const LineSplitter())) {
    if (ligne.isEmpty) {
      if (nom != null && donnees.isNotEmpty) {
        final evenement = _convertir(nom, jsonDecode(donnees.toString()) as Map<String, dynamic>);
        if (evenement != null) yield evenement;
      }
      nom = null;
      donnees.clear();
    } else if (ligne.startsWith('event:')) {
      nom = ligne.substring(6).trim();
    } else if (ligne.startsWith('data:')) {
      donnees.write(ligne.substring(5).trimLeft());
    }
  }
}

SahlaEvenement? _convertir(String nom, Map<String, dynamic> d) => switch (nom) {
      'debut' => SahlaDebut(d['conversation_id'] as String),
      'texte' => SahlaTexte(d['delta'] as String),
      'remplacer' => SahlaRemplacer(d['texte'] as String),
      'pose' => SahlaChangementPose(SahlaPose.depuisNom(d['pose'] as String?)),
      'outil' => SahlaOutil(d['nom'] as String, termine: d['etat'] == 'fin'),
      'action' => SahlaActionProposee(SahlaAction.depuisJson(d['action'] as Map<String, dynamic>)),
      'fin' => SahlaFin(d['conversation_id'] as String, SahlaPose.depuisNom(d['pose'] as String?)),
      'erreur' => SahlaErreur(d['code'] as String? ?? 'indisponible'),
      _ => null,
    };
