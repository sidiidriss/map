import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sahla_assistant/sahla_assistant.dart';

String sse(List<(String, Map<String, dynamic>)> evenements) =>
    evenements.map((e) => 'event: ${e.$1}\ndata: ${jsonEncode(e.$2)}\n\n').join();

SahlaClient clientAvec(Future<http.StreamedResponse> Function(http.BaseRequest) reponse, {List<http.BaseRequest>? journal}) =>
    SahlaClient(
      urlServeur: Uri.parse('https://sahla.example/'),
      jeton: () => 'Bearer jeton-test',
      client: MockClient.streaming((requete, _) {
        journal?.add(requete);
        return reponse(requete);
      }),
    );

http.StreamedResponse flux(String corps, {int statut = 200}) => http.StreamedResponse(
      Stream.fromIterable([utf8.encode(corps)]),
      statut,
      headers: {'content-type': statut == 200 ? 'text/event-stream' : 'application/json'},
    );

void main() {
  test('lit un flux SSE découpé n’importe où, accents et arabe compris', () async {
    final corps = utf8.encode(sse([
      ('debut', {'conversation_id': 'c1'}),
      ('texte', {'delta': 'Bonjour, '}),
      ('texte', {'delta': 'السلام عليكم'}),
      ('pose', {'pose': 'go'}),
      ('action', {
        'action': {'ecran': 'commander_course', 'libelle': 'Commander', 'parametres': {'arrivee_id': 'nkc-aeroport'}}
      }),
      ('fin', {'conversation_id': 'c1', 'pose': 'go'}),
    ]));
    // Découpe en morceaux de 7 octets, au milieu des caractères multi-octets.
    final morceaux = [for (var i = 0; i < corps.length; i += 7) corps.sublist(i, (i + 7).clamp(0, corps.length))];
    final evenements = await lireSse(Stream.fromIterable(morceaux)).toList();

    expect(evenements.whereType<SahlaTexte>().map((e) => e.delta).join(), 'Bonjour, السلام عليكم');
    expect(evenements.whereType<SahlaChangementPose>().single.pose, SahlaPose.go);
    final action = evenements.whereType<SahlaActionProposee>().single.action;
    expect(action.ecran, 'commander_course');
    expect(action.parametres['arrivee_id'], 'nkc-aeroport');
    expect(evenements.last, isA<SahlaFin>());
  });

  test('envoie le message, la langue, le contexte et le jeton', () async {
    final journal = <http.BaseRequest>[];
    final client = clientAvec((_) async => flux(sse([('fin', {'conversation_id': 'c1', 'pose': 'hello'})])), journal: journal);
    await client
        .envoyer(
          message: 'Salam',
          langue: 'mey',
          conversationId: 'c0',
          contexte: const SahlaContexte(prenom: 'Aminata', latitude: 18.09, longitude: -15.97),
          canal: SahlaCanal.voix,
        )
        .toList();

    final requete = journal.single as http.Request;
    expect(requete.url.toString(), 'https://sahla.example/v1/sahla/message');
    expect(requete.headers['Authorization'], 'Bearer jeton-test');
    final corps = jsonDecode(requete.body) as Map<String, dynamic>;
    expect(corps['message'], 'Salam');
    expect(corps['langue'], 'mey');
    expect(corps['canal'], 'voix');
    expect(corps['conversation_id'], 'c0');
    expect(corps['contexte'], {
      'prenom': 'Aminata',
      'position': {'lat': 18.09, 'lng': -15.97},
    });
  });

  test('traduit les erreurs HTTP en codes Sahla', () async {
    final client = clientAvec((_) async => flux('{"erreur":"limite"}', statut: 429));
    final evenements = await client.envoyer(message: 'x', langue: 'fr').toList();
    expect((evenements.single as SahlaErreur).code, 'limite');
  });

  test('signale une coupure réseau avant la fin de la réponse', () async {
    final client = clientAvec((_) async => flux(sse([('texte', {'delta': 'Bonj'})])));
    final evenements = await client.envoyer(message: 'x', langue: 'fr').toList();
    expect(evenements.last, isA<SahlaErreur>().having((e) => e.code, 'code', 'reseau'));
  });

  test('a des textes pour les 10 langues, dont l’arabe et le hassaniya de droite à gauche', () {
    for (final langue in ['fr', 'ar', 'mey', 'ff', 'snk', 'wo', 'en', 'es', 'pt', 'zh']) {
      final t = SahlaTextes.pour(langue);
      expect(t.suggestions, hasLength(4), reason: langue);
      expect(t.poses.keys, containsAll(SahlaPose.values), reason: langue);
      for (final code in ['reseau', 'limite', 'refus', 'occupe', 'trop_long', 'indisponible', 'surcharge', 'non_connecte']) {
        expect(t.erreurs[code], isNotNull, reason: '$langue/$code');
      }
    }
    expect(SahlaTextes.droiteAGauche('ar'), isTrue);
    expect(SahlaTextes.droiteAGauche('mey'), isTrue);
    expect(SahlaTextes.droiteAGauche('wo'), isFalse);
  });
}
