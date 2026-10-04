import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahla_assistant/sahla_assistant.dart';

String sse(List<(String, Map<String, dynamic>)> evenements) =>
    evenements.map((e) => 'event: ${e.$1}\ndata: ${jsonEncode(e.$2)}\n\n').join();

/// Serveur simulé : la réponse SSE n'est envoyée que quand le test le décide.
class ServeurSimule {
  final requetes = <String>[];
  StreamController<List<int>>? _flux;

  late final client = SahlaClient(
    urlServeur: Uri.parse('https://sahla.example/'),
    client: MockClient.streaming((requete, corps) async {
      requetes.add(await corps.bytesToString());
      _flux = StreamController<List<int>>();
      return http.StreamedResponse(_flux!.stream, 200, headers: {'content-type': 'text/event-stream'});
    }),
  );

  void repondre(List<(String, Map<String, dynamic>)> evenements, {bool terminer = true}) {
    _flux!.add(utf8.encode(sse(evenements)));
    if (terminer) _flux!.close();
  }
}

Widget app(SahlaControleur controleur, {void Function(SahlaAction)? onAction}) => MaterialApp(
      home: Scaffold(body: SahlaChat(controleur: controleur, onAction: onAction)),
    );

void main() {
  testWidgets('accueil, question, réponse diffusée, bouton d’action et expressions de Sahla', (tester) async {
    final serveur = ServeurSimule();
    final controleur = SahlaControleur(
      client: serveur.client,
      langue: 'fr',
      contexte: () => const SahlaContexte(ecran: 'accueil'),
    );
    SahlaAction? actionRecue;
    await tester.pumpWidget(app(controleur, onAction: (a) => actionRecue = a));

    expect(find.text('Bonjour, je suis Sahla !'), findsOneWidget);
    await tester.tap(find.text("Combien pour aller à l'aéroport ?"));
    await tester.pump();

    // Pendant la réflexion : « Je cherche… ».
    expect(controleur.pose, SahlaPose.search);
    expect(find.text('Je cherche…'), findsOneWidget);
    expect(jsonDecode(serveur.requetes.single)['contexte'], {'ecran': 'accueil'});

    serveur.repondre([
      ('debut', {'conversation_id': 'c1'}),
      ('pose', {'pose': 'go'}),
      ('action', {
        'action': {'ecran': 'commander_course', 'libelle': 'Commander la course', 'parametres': {'arrivee_id': 'nkc-aeroport'}}
      }),
      ('texte', {'delta': 'Environ **800 MRU**.\n- Prix indicatif'}),
      ('fin', {'conversation_id': 'c1', 'pose': 'go'}),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controleur.pose, SahlaPose.go);
    expect(find.text('En route'), findsOneWidget);
    expect(find.textContaining('800 MRU', findRichText: true), findsOneWidget);
    expect(find.textContaining('Prix indicatif', findRichText: true), findsOneWidget);

    await tester.tap(find.text('Commander la course'));
    expect(actionRecue?.parametres['arrivee_id'], 'nkc-aeroport');

    // L'app confirme la commande : Sahla fête ça, puis revient à l'accueil.
    controleur.celebrer();
    await tester.pump();
    expect(find.text('Bravo !'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(controleur.pose, SahlaPose.hello);

    // Le message suivant réutilise la même conversation.
    await tester.enterText(find.byType(TextField), 'Merci');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(jsonDecode(serveur.requetes.last)['conversation_id'], 'c1');
    serveur.repondre([('fin', {'conversation_id': 'c1', 'pose': 'hello'})]);
    // La mascotte s'anime en continu : on avance le temps au lieu d'attendre la fin des animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controleur.enCours, isFalse);
  });

  testWidgets('affiche les erreurs dans la langue choisie, de droite à gauche en hassaniya', (tester) async {
    final serveur = ServeurSimule();
    final controleur = SahlaControleur(client: serveur.client, langue: 'mey');
    await tester.pumpWidget(app(controleur));

    expect(find.text('السلام عليكم، آن سهلة!'), findsOneWidget);
    final direction = tester.widget<Directionality>(
      find.descendant(of: find.byType(SahlaChat), matching: find.byType(Directionality)).first,
    );
    expect(direction.textDirection, TextDirection.rtl);

    await tester.enterText(find.byType(TextField), 'شنهو هذا؟');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    serveur.repondre([('erreur', {'code': 'refus'})]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controleur.pose, SahlaPose.oops);
    expect(find.text('ما نكدر نعاونك في هذا.'), findsOneWidget);
    expect(find.text('اسمح لي…'), findsOneWidget);
  });

  testWidgets('la mascotte dessine ses 6 expressions sans erreur', (tester) async {
    for (final pose in SahlaPose.values) {
      await tester.pumpWidget(Center(child: SahlaMascotte(pose: pose, taille: 200)));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 137));
      }
      expect(tester.takeException(), isNull, reason: pose.name);
    }
  });
}
