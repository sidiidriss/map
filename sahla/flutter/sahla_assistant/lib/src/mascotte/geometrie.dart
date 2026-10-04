import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

/// Lit le sous-ensemble de la syntaxe SVG utilisé par la maquette :
/// M, L, C, Q et Z, en coordonnées absolues.
Path lireCheminSvg(String d) {
  final jetons = RegExp(r'[MLCQZ]|-?\d*\.?\d+').allMatches(d).map((m) => m.group(0)!).toList();
  final chemin = Path();
  var i = 0;
  String? commande;
  double n() => double.parse(jetons[i++]);
  while (i < jetons.length) {
    if (RegExp(r'^[MLCQZ]$').hasMatch(jetons[i])) commande = jetons[i++];
    switch (commande) {
      case 'M':
        chemin.moveTo(n(), n());
        commande = 'L'; // des coordonnées après M continuent en L
      case 'L':
        chemin.lineTo(n(), n());
      case 'C':
        chemin.cubicTo(n(), n(), n(), n(), n(), n());
      case 'Q':
        chemin.quadraticBezierTo(n(), n(), n(), n());
      case 'Z':
        chemin.close();
        commande = null;
      default:
        throw FormatException('Commande SVG non prise en charge', d, i);
    }
  }
  return chemin;
}

/// Ellipses de centre (cx, cy) et rayons (rx, ry), regroupées dans un seul chemin.
Path ellipses(List<List<double>> e) {
  final chemin = Path();
  for (final [cx, cy, rx, ry] in e) {
    chemin.addOval(Rect.fromCenter(center: Offset(cx, cy), width: 2 * rx, height: 2 * ry));
  }
  return chemin;
}

double _rad(double degres) => degres * math.pi / 180;

Matrix4 translation(double x, double y) => Matrix4.translationValues(x, y, 0);
Matrix4 rotation(double degres) => Matrix4.rotationZ(_rad(degres));
Matrix4 echelle(double sx, [double? sy]) => Matrix4.diagonal3Values(sx, sy ?? sx, 1);

/// rotate(a, cx, cy) en SVG.
Matrix4 rotationAutour(double degres, double cx, double cy) =>
    translation(cx, cy)..multiply(rotation(degres))..multiply(translation(-cx, -cy));

/// Produit d'une liste de transformations SVG, appliquées de droite à gauche.
Matrix4 composer(List<Matrix4> transformations) {
  final m = Matrix4.identity();
  for (final t in transformations) {
    m.multiply(t);
  }
  return m;
}

/// Valeurs d'une animation SMIL (« 0 0;0 -7;0 0 ») interpolées linéairement.
class Piste {
  Piste(String valeurs, {required this.duree, this.debut = 0})
      : _cles = valeurs
            .split(';')
            .map((v) => v.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map(double.parse).toList())
            .toList();

  final List<List<double>> _cles;
  final double duree;
  final double debut;

  /// Valeur à l'instant [t] (secondes), l'animation tournant en boucle.
  List<double> a(double t) {
    if (_cles.length == 1 || duree <= 0) return _cles.first;
    final local = ((t - debut) % duree) / duree;
    final position = local * (_cles.length - 1);
    final k = position.floor().clamp(0, _cles.length - 2);
    final f = position - k;
    final de = _cles[k];
    final vers = _cles[k + 1];
    return List.generate(de.length, (j) => de[j] + (vers[j] - de[j]) * f);
  }
}
