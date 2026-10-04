import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

import '../theme.dart';
import 'geometrie.dart';

/// Les 6 expressions de Sahla, une par moment clé de l'app.
enum SahlaPose {
  /// « Bonjour ! » : accueil, onboarding, première ouverture.
  hello,

  /// « En route » : course Wassalni, livraison en cours.
  go,

  /// « Je cherche… » : chargement, réflexion, recherche de chauffeur.
  search,

  /// « Bravo ! » : commande confirmée, recharge réussie.
  bravo,

  /// « Oups… » : erreur, paiement refusé, hors zone.
  oops,

  /// « Rien ici » : liste vide (commandes, notifications).
  empty;

  static SahlaPose depuisNom(String? nom) =>
      SahlaPose.values.firstWhere((p) => p.name == nom, orElse: () => SahlaPose.hello);
}

// Les deux gouttes du logo Sehelli, reprises de la maquette « Mascotte — Sahla ».
const _top =
    'M100.0 26.5C99.4 26.2 97.5 25.0 96.2 24.3C94.9 23.5 93.6 22.8 92.3 22.1C91.0 21.4 89.7 20.7 88.4 19.9C87.1 19.2 85.8 18.5 84.5 17.8C83.2 17.2 81.8 16.5 80.5 15.8C79.2 15.1 77.9 14.4 76.6 13.8C75.3 13.1 73.9 12.5 72.6 11.8C71.3 11.2 69.9 10.5 68.6 9.9C67.2 9.3 65.9 8.7 64.6 8.1C63.2 7.5 61.9 6.9 60.5 6.3C59.1 5.8 57.8 5.2 56.4 4.6C55.0 4.1 53.7 3.6 52.3 3.1C50.9 2.6 49.5 2.1 48.0 1.7C46.6 1.3 45.2 0.9 43.7 0.6C42.2 0.4 40.7 0.2 39.2 0.1C37.7 -0.0 36.1 -0.0 34.6 0.1C33.1 0.2 31.6 0.4 30.1 0.7C28.7 1.0 27.2 1.4 25.9 2.0C24.5 2.5 23.2 3.2 21.9 4.0C20.7 4.7 19.5 5.6 18.4 6.6C17.3 7.6 16.3 8.7 15.5 9.9C14.6 11.1 13.8 12.4 13.2 13.7C12.5 15.0 11.9 16.4 11.5 17.8C11.1 19.2 10.7 20.6 10.5 22.1C10.3 23.6 10.1 25.1 10.1 26.6C10.1 28.1 10.3 29.7 10.5 31.1C10.7 32.6 11.1 34.1 11.5 35.5C12.0 36.9 12.5 38.3 13.2 39.6C13.8 40.9 14.6 42.2 15.5 43.3C16.4 44.5 17.4 45.6 18.5 46.6C19.5 47.6 20.7 48.5 22.0 49.2C23.2 50.0 24.5 50.6 25.9 51.1C27.3 51.7 28.7 52.1 30.2 52.3C31.6 52.6 33.2 52.8 34.7 52.9C36.2 53.0 37.7 53.0 39.3 52.9C40.8 52.8 42.3 52.5 43.8 52.3C45.2 52.0 46.7 51.6 48.1 51.3C49.6 50.9 51.0 50.4 52.4 49.9C53.8 49.4 55.1 48.9 56.5 48.4C57.9 47.8 59.2 47.2 60.6 46.7C62.0 46.1 63.3 45.5 64.7 44.9C66.0 44.3 67.3 43.7 68.7 43.0C70.0 42.4 71.3 41.8 72.7 41.1C74.0 40.5 75.3 39.8 76.6 39.2C78.0 38.5 79.3 37.8 80.6 37.2C81.9 36.5 83.2 35.8 84.5 35.1C85.8 34.4 87.2 33.7 88.5 33.0C89.8 32.3 91.1 31.6 92.4 30.9C93.7 30.2 95.0 29.5 96.3 28.8C97.6 28.1 99.4 26.9 100.0 26.5Z';
const _bot =
    'M0.0 65.5C0.6 65.8 2.5 66.9 3.8 67.7C5.1 68.4 6.4 69.0 7.7 69.8C9.1 70.5 10.4 71.2 11.7 71.9C13.0 72.6 14.3 73.3 15.6 73.9C16.9 74.6 18.2 75.3 19.5 76.0C20.8 76.7 22.1 77.4 23.4 78.0C24.8 78.7 26.1 79.4 27.4 80.0C28.7 80.7 30.1 81.3 31.4 81.9C32.7 82.6 34.1 83.2 35.4 83.8C36.7 84.4 38.1 85.0 39.4 85.6C40.8 86.2 42.2 86.8 43.5 87.3C44.9 87.8 46.3 88.4 47.7 88.8C49.1 89.3 50.5 89.8 51.9 90.1C53.4 90.5 54.8 90.9 56.3 91.1C57.8 91.4 59.3 91.6 60.8 91.6C62.3 91.7 63.9 91.7 65.4 91.6C66.9 91.6 68.4 91.4 69.9 91.1C71.3 90.8 72.8 90.4 74.1 89.8C75.5 89.3 76.8 88.7 78.1 87.9C79.3 87.1 80.5 86.2 81.6 85.2C82.7 84.3 83.7 83.1 84.6 82.0C85.4 80.8 86.2 79.5 86.9 78.2C87.5 76.9 88.1 75.5 88.5 74.1C88.9 72.7 89.3 71.2 89.5 69.8C89.7 68.3 89.8 66.8 89.8 65.3C89.8 63.7 89.7 62.2 89.5 60.7C89.2 59.3 88.9 57.8 88.4 56.4C88.0 55.0 87.4 53.6 86.7 52.3C86.1 51.0 85.3 49.8 84.4 48.6C83.5 47.4 82.5 46.3 81.4 45.3C80.3 44.3 79.1 43.4 77.9 42.7C76.7 41.9 75.3 41.3 74.0 40.7C72.6 40.2 71.2 39.8 69.7 39.5C68.2 39.2 66.7 39.0 65.2 38.9C63.7 38.8 62.2 38.8 60.7 38.9C59.2 39.0 57.6 39.2 56.2 39.5C54.7 39.8 53.2 40.1 51.8 40.5C50.4 40.9 49.0 41.4 47.6 41.9C46.2 42.3 44.8 42.9 43.4 43.4C42.1 44.0 40.7 44.5 39.4 45.1C38.0 45.7 36.7 46.3 35.3 46.9C34.0 47.5 32.6 48.1 31.3 48.8C30.0 49.4 28.7 50.1 27.3 50.7C26.0 51.4 24.7 52.1 23.4 52.7C22.1 53.4 20.8 54.1 19.5 54.8C18.1 55.5 16.8 56.2 15.5 56.8C14.2 57.5 12.9 58.2 11.6 58.9C10.3 59.6 9.0 60.3 7.7 61.0C6.4 61.7 5.1 62.4 3.8 63.2C2.5 63.9 0.6 65.1 0.0 65.5Z';

final Path cheminGoutteHaute = lireCheminSvg(_top);
final Path cheminGoutteBasse = lireCheminSvg(_bot);

final Matrix4 transformationCorps = composer([rotation(-68), echelle(1.9), translation(-40, -26.5)]);
final Matrix4 transformationEcharpe =
    composer([translation(20, 44), rotation(-14), echelle(0.92), translation(-65, -65)]);
Matrix4 _goutte(double x, double y, double a, double s) =>
    composer([translation(x, y), rotation(a), echelle(s), translation(-40, -26.5)]);

/// Un calque de la mascotte, avec ses animations (valeurs SMIL de la maquette).
class Calque {
  Calque({
    required this.forme,
    Matrix4? t,
    this.remplissage,
    this.trait,
    this.epaisseur = 0,
    this.opacite = 1,
    this.decoupeParEcharpe = false,
    this.ombre = false,
    this.echarpe = false,
    this.regard = false,
    this.ox = 0,
    this.oy = 0,
    this.tv,
    this.rv,
    this.sv,
    this.ov,
    this.duree,
    this.debut = 0,
  }) : t = t ?? Matrix4.identity();

  final Path forme;
  final Matrix4 t;
  final Color? remplissage;
  final Color? trait;
  final double epaisseur;
  final double opacite;
  final bool decoupeParEcharpe;
  final bool ombre;
  final bool echarpe;
  final bool regard;
  final double ox;
  final double oy;
  final String? tv;
  final String? rv;
  final String? sv;
  final String? ov;
  final double? duree;
  final double debut;
}

class TexteZ {
  const TexteZ(this.x, this.y, this.taille, this.couleur, this.debut);
  final double x;
  final double y;
  final double taille;
  final Color couleur;
  final double debut;
}

class DefinitionPose {
  DefinitionPose({
    required this.pose,
    required this.rotationG,
    required this.duree,
    required this.ptv,
    required this.prv,
    required this.flv,
    required this.calques,
    this.textes = const [],
  });

  final SahlaPose pose;
  final double rotationG;
  final double duree;
  final String ptv;
  final String prv;
  final String flv;
  final List<Calque> calques;
  final List<TexteZ> textes;
}

const _ciel = SahlaCouleurs.ciel;
const _navy = SahlaCouleurs.navy;
const _conf = SahlaCouleurs.confluence;
const _blanc = Color(0xFFFFFFFF);
const _clignement = '1 1;1 1;1 1;1 1;1 1;1 1;1 1;1 1;1 1;1 0.08;1 1';

Calque _bras(double x, double y, double a, [String? rv, double px = 0, double py = 0]) => Calque(
      forme: cheminGoutteHaute,
      t: _goutte(x, y, a, 0.32),
      remplissage: _navy,
      rv: rv,
      ox: rv == null ? 0 : px,
      oy: rv == null ? 0 : py,
    );

List<Calque> _yeuxOuverts([double dx = 0, double dy = 0]) => [
      Calque(forme: ellipses([[-19, -12, 10, 12], [15, -14, 10, 12]]), remplissage: _blanc, sv: _clignement, oy: -13),
      Calque(
          forme: ellipses([[-19 + dx, -10 + dy, 5, 6], [15 + dx, -12 + dy, 5, 6]]),
          remplissage: _navy,
          sv: _clignement,
          oy: -13,
          regard: true),
      Calque(
          forme: ellipses([[-17 + dx, -13 + dy, 1.8, 1.8], [17 + dx, -15 + dy, 1.8, 1.8]]),
          remplissage: _blanc,
          sv: _clignement,
          oy: -13,
          regard: true),
    ];

List<Calque> _yeuxFermes(String d) => [Calque(forme: lireCheminSvg(d), trait: _navy, epaisseur: 4)];

Calque _trait(String d, [double epaisseur = 4]) => Calque(forme: lireCheminSvg(d), trait: _navy, epaisseur: epaisseur);

List<Calque> _base(Calque brasG, Calque brasD, List<Calque> visage,
        {List<Calque> derriere = const [], List<Calque> devant = const []}) =>
    [
      Calque(forme: ellipses([[0, 82, 42, 7]]), remplissage: _navy, opacite: 0.12, ombre: true),
      ...derriere,
      brasG,
      Calque(forme: cheminGoutteHaute, t: transformationCorps, remplissage: _ciel),
      Calque(forme: cheminGoutteBasse, t: transformationEcharpe, remplissage: _navy, echarpe: true),
      Calque(forme: cheminGoutteHaute, t: transformationCorps, remplissage: _conf, decoupeParEcharpe: true),
      brasD,
      Calque(forme: ellipses([[-32, 6, 6, 3.5], [30, 3, 6, 3.5]]), remplissage: _conf, opacite: 0.28),
      ...visage,
      ...devant,
    ];

Calque _mini(double x, double y, double a, double s, Color couleur,
        {String? tv, String? ov, double? duree, double debut = 0}) =>
    Calque(
      forme: cheminGoutteHaute,
      t: _goutte(x, y, a, s),
      remplissage: couleur,
      tv: tv,
      ov: ov,
      duree: duree,
      debut: debut,
    );

String _f(double v) => v.toStringAsFixed(1);

final Map<SahlaPose, DefinitionPose> definitionsPoses = {
  SahlaPose.hello: DefinitionPose(
    pose: SahlaPose.hello,
    rotationG: 0,
    duree: 2.4,
    ptv: '0 0;0 0',
    prv: '0 0 70;-3 0 70;0 0 70;3 0 70;0 0 70',
    flv: '0 65 65;5 65 65;0 65 65;-4 65 65;0 65 65',
    calques: _base(
      _bras(-60, 20, 165),
      _bras(48, -30, -62, '0;-30;8;-30;8;-30;0;0;0;0', 36, -6),
      [..._yeuxOuverts(), _trait('M-12 10 Q0 24 14 8')],
    ),
  ),
  SahlaPose.go: DefinitionPose(
    pose: SahlaPose.go,
    rotationG: 12,
    duree: 0.6,
    ptv: '0 0;0 -7;0 0',
    prv: '0 0 0;0 0 0',
    flv: '0 65 65;9 65 65;0 65 65',
    calques: _base(
      _bras(-58, 24, 175, '0;-18;0', -42, 14),
      _bras(50, 18, 10, '0;18;0', 38, 10),
      [..._yeuxOuverts(4, 0), _trait('M-10 10 Q2 22 14 8')],
      derriere: [
        for (final (k, debut) in [(0, 0.0), (1, -0.2), (2, -0.4)])
          _mini(-92 + (k % 2) * -18, -8 + k * 22.0, 0, 0.3 - k * 0.04, _ciel, tv: '0 0;-30 0', ov: '0.75;0', debut: debut),
      ],
    ),
  ),
  SahlaPose.search: DefinitionPose(
    pose: SahlaPose.search,
    rotationG: -4,
    duree: 2.8,
    ptv: '0 0;0 0',
    prv: '-3 0 70;3 0 70;-3 0 70',
    flv: '0 65 65;4 65 65;0 65 65',
    calques: _base(
      _bras(-60, 18, 165),
      _bras(46, 2, -40),
      [..._yeuxOuverts(3, -5), _trait('M-6 13 L10 11')],
      devant: [
        for (final (k, x, y, c) in [(0, 52.0, -78.0, _ciel), (1, 72.0, -92.0, _conf), (2, 92.0, -104.0, _navy)])
          _mini(x, y, 0, 0.18, c, ov: '0.15;1;0.15', tv: '0 0;0 -5;0 0', duree: 0.9, debut: -0.9 + k * 0.3),
      ],
    ),
  ),
  SahlaPose.bravo: DefinitionPose(
    pose: SahlaPose.bravo,
    rotationG: 0,
    duree: 1.4,
    ptv: '0 0;0 -22;0 0;0 0;0 0',
    prv: '0 0 0;0 0 0',
    flv: '0 65 65;10 65 65;0 65 65;-4 65 65;0 65 65',
    calques: _base(
      _bras(-46, -32, -118, '0;14;0;-8;0', -30, -14),
      _bras(46, -32, -62, '0;-14;0;8;0', 30, -14),
      [
        ..._yeuxFermes('M-28 -10 Q-19 -22 -10 -10M6 -12 Q15 -24 24 -12'),
        Calque(forme: lireCheminSvg('M-13 4 Q1 30 17 2 Z'), remplissage: _navy),
      ],
      devant: [
        for (var i = 0; i < 10; i++)
          () {
            final a = -90 + (i - 4.5) * 24;
            final c = math.cos(a * math.pi / 180), s = math.sin(a * math.pi / 180);
            return _mini(104 * c, -10 + 104 * s, a, 0.2, [_ciel, _navy, _conf][i % 3],
                tv: '${_f(-c * 22)} ${_f(-s * 22)};0 0;${_f(c * 10)} ${_f(s * 10)};${_f(c * 10)} ${_f(s * 10)}',
                ov: '0;1;1;0',
                debut: -i * 0.05);
          }(),
      ],
    ),
  ),
  SahlaPose.oops: DefinitionPose(
    pose: SahlaPose.oops,
    rotationG: -6,
    duree: 2,
    ptv: '0 0;-5 0;5 0;-5 0;5 0;0 0;0 0;0 0;0 0;0 0',
    prv: '0 0 0;0 0 0',
    flv: '0 65 65;3 65 65;0 65 65',
    calques: _base(
      _bras(-56, 30, 155),
      _bras(46, 30, 30),
      [
        ..._yeuxOuverts(-2, 4),
        _trait('M-29 -30 L-11 -26M5 -28 L23 -33', 3.5),
        Calque(forme: ellipses([[2, 15, 4.5, 5.5]]), remplissage: _navy, sv: '1 1;1 1.25;1 1', oy: 15),
      ],
      devant: [_mini(64, -62, 90, 0.22, _conf, tv: '0 -4;0 -4;0 4;0 20', ov: '0;1;1;0')],
    ),
  ),
  SahlaPose.empty: DefinitionPose(
    pose: SahlaPose.empty,
    rotationG: 4,
    duree: 3.6,
    ptv: '0 0;0 4;0 0',
    prv: '0 0 70;-2 0 70;0 0 70',
    flv: '0 65 65;2 65 65;0 65 65',
    calques: _base(
      _bras(-58, 28, 170),
      _bras(46, 30, 15),
      [..._yeuxFermes('M-28 -10 Q-19 -4 -10 -10M6 -12 Q15 -6 24 -12'), _trait('M-3 13 Q2 16 7 13', 3.5)],
    ),
    textes: const [TexteZ(52, -60, 26, _navy, 0), TexteZ(72, -86, 20, _ciel, -1.8)],
  ),
};
