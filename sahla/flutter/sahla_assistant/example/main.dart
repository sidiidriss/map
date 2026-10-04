// Exemple d'intégration de Sahla dans l'app Sehelli.
import 'package:flutter/material.dart';
import 'package:sahla_assistant/sahla_assistant.dart';

void main() => runApp(const ExempleSehelli());

class ExempleSehelli extends StatefulWidget {
  const ExempleSehelli({super.key});

  @override
  State<ExempleSehelli> createState() => _ExempleSehelliState();
}

class _ExempleSehelliState extends State<ExempleSehelli> {
  final _messages = GlobalKey<ScaffoldMessengerState>();

  late final _sahla = SahlaControleur(
    client: SahlaClient(
      // Émulateur Android → serveur Sahla lancé sur l'ordinateur (npm run dev).
      // En production : l'adresse HTTPS du serveur Sahla.
      urlServeur: Uri.parse('http://10.0.2.2:8787/'),
      // Jeton de session de l'utilisateur connecté (null s'il ne l'est pas).
      jeton: () async => 'Bearer jeton-de-session',
    ),
    langue: 'fr', // la langue choisie dans l'app : fr, ar, mey, ff, snk, wo, en, es, pt, zh
    contexte: () => const SahlaContexte(prenom: 'Aminata', ecran: 'accueil'),
  );

  @override
  void dispose() {
    _sahla.dispose();
    super.dispose();
  }

  /// Sahla propose un bouton : l'app ouvre l'écran correspondant, pré-rempli.
  void _ouvrirEcran(SahlaAction action) {
    // Dans la vraie app : Navigator.pushNamed(context, '/${action.ecran}', arguments: action.parametres)
    _messages.currentState?.showSnackBar(
      SnackBar(content: Text('Ouvrir « ${action.ecran} » avec ${action.parametres}')),
    );
    // Quand l'utilisateur a confirmé (course commandée, recharge réussie…) :
    _sahla.celebrer();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sehelli',
      scaffoldMessengerKey: _messages,
      theme: ThemeData(colorSchemeSeed: SahlaCouleurs.confluence),
      home: Scaffold(
        appBar: AppBar(title: const Text('Sehelli')),
        body: const Center(child: Text('Écran d’accueil de Sehelli')),
        floatingActionButton: SahlaBoutonFlottant(controleur: _sahla, onAction: _ouvrirEcran),
      ),
    );
  }
}
