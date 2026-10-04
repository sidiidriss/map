import 'dart:async';

import 'package:flutter/foundation.dart';

import 'client.dart';
import 'mascotte/poses.dart';
import 'modeles.dart';

enum SahlaAuteur { utilisateur, sahla }

class SahlaMessage {
  SahlaMessage(this.auteur, [this.texte = '']);

  final SahlaAuteur auteur;
  String texte;

  /// Code d'erreur (affiché dans la langue de l'utilisateur), ou null.
  String? erreur;
  final List<SahlaAction> actions = [];
}

/// État d'une conversation avec Sahla : messages, expression de la mascotte, envoi.
class SahlaControleur extends ChangeNotifier {
  SahlaControleur({required this.client, String langue = 'fr', this.contexte}) : _langue = langue;

  final SahlaClient client;

  /// Informations de l'app envoyées avec chaque message (prénom, position, écran).
  final FutureOr<SahlaContexte?> Function()? contexte;

  final List<SahlaMessage> messages = [];
  SahlaPose _pose = SahlaPose.hello;
  bool _enCours = false;
  String _langue;
  String? _conversationId;
  Timer? _retourAccueil;
  bool _libere = false;

  SahlaPose get pose => _pose;
  bool get enCours => _enCours;

  /// Code de langue (fr, ar, mey, ff, snk, wo, en, es, pt, zh).
  String get langue => _langue;
  set langue(String valeur) {
    if (valeur == _langue) return;
    _langue = valeur;
    notifyListeners();
  }

  void _poser(SahlaPose pose) {
    _retourAccueil?.cancel();
    _pose = pose;
  }

  /// Envoie un message et met à jour la conversation au fil de la réponse.
  Future<void> envoyer(String texte) async {
    texte = texte.trim();
    if (texte.isEmpty || _enCours) return;
    final reponse = SahlaMessage(SahlaAuteur.sahla);
    messages
      ..add(SahlaMessage(SahlaAuteur.utilisateur, texte))
      ..add(reponse);
    _enCours = true;
    _poser(SahlaPose.search);
    notifyListeners();

    try {
      final infos = await contexte?.call();
      final flux = client.envoyer(message: texte, langue: _langue, conversationId: _conversationId, contexte: infos);
      await for (final evenement in flux) {
        if (_libere) return;
        switch (evenement) {
          case SahlaDebut(:final conversationId):
            _conversationId = conversationId;
          case SahlaTexte(:final delta):
            reponse.texte += delta;
          case SahlaRemplacer(:final texte):
            reponse.texte = texte;
          case SahlaChangementPose(:final pose):
            _poser(pose);
          case SahlaOutil():
            break;
          case SahlaActionProposee(:final action):
            reponse.actions.add(action);
          case SahlaFin(:final conversationId, :final pose):
            _conversationId = conversationId;
            _poser(pose);
          case SahlaErreur(:final code):
            reponse
              ..erreur = code
              ..texte = ''
              ..actions.clear();
            _poser(SahlaPose.oops);
        }
        notifyListeners();
      }
    } catch (_) {
      reponse.erreur = 'reseau';
      _poser(SahlaPose.oops);
    } finally {
      if (!_libere) {
        // Flux terminé sans texte ni bouton : on l'affiche comme une erreur plutôt qu'une bulle vide.
        if (reponse.texte.trim().isEmpty && reponse.erreur == null && reponse.actions.isEmpty) {
          reponse.erreur = 'indisponible';
          _poser(SahlaPose.oops);
        }
        _enCours = false;
        notifyListeners();
      }
    }
  }

  /// À appeler par l'app quand l'utilisateur a confirmé une action proposée
  /// (course commandée, recharge réussie) : Sahla fait « Bravo ! ».
  void celebrer() {
    _poser(SahlaPose.bravo);
    notifyListeners();
    _retourAccueil = Timer(const Duration(milliseconds: 2800), () {
      if (_libere || _enCours) return;
      _pose = SahlaPose.hello;
      notifyListeners();
    });
  }

  /// Efface la conversation et repart de l'accueil.
  void nouvelleConversation() {
    if (_enCours) return;
    final id = _conversationId;
    if (id != null) unawaited(client.supprimerConversation(id));
    _conversationId = null;
    messages.clear();
    _poser(SahlaPose.hello);
    notifyListeners();
  }

  @override
  void dispose() {
    _libere = true;
    _retourAccueil?.cancel();
    super.dispose();
  }
}
