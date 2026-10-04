import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'geometrie.dart';
import 'poses.dart';

/// Sahla, la mascotte Sehelli, animée dans l'une de ses 6 expressions.
///
/// ```dart
/// SahlaMascotte(pose: SahlaPose.search, taille: 120)
/// ```
class SahlaMascotte extends StatefulWidget {
  const SahlaMascotte({
    super.key,
    this.pose = SahlaPose.hello,
    this.taille = 120,
    this.etiquette,
  });

  final SahlaPose pose;
  final double taille;

  /// Texte lu par les lecteurs d'écran (ex. « Je cherche… »).
  final String? etiquette;

  @override
  State<SahlaMascotte> createState() => _SahlaMascotteState();
}

class _SahlaMascotteState extends State<SahlaMascotte> with SingleTickerProviderStateMixin {
  final _temps = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker((ecoule) => _temps.value = ecoule.inMicroseconds / 1e6);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecte le réglage « réduire les animations » du téléphone.
    final reduire = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduire && _ticker.isActive) _ticker.stop();
    if (!reduire && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _temps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.etiquette ?? 'Sahla',
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: SizedBox.square(
        dimension: widget.taille,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (enfant, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(animation), child: enfant),
          ),
          child: CustomPaint(
            key: ValueKey(widget.pose),
            size: Size.square(widget.taille),
            painter: PeintreSahla(definitionsPoses[widget.pose]!, _temps),
          ),
        ),
      ),
    );
  }
}

/// Dessine une pose à l'instant donné par [temps] (secondes).
class PeintreSahla extends CustomPainter {
  PeintreSahla(this.definition, this.temps) : super(repaint: temps);

  final DefinitionPose definition;
  final ValueListenable<double> temps;

  static const _regard = '0 0;-7 1;-7 1;-7 1;6 1;6 1;6 1;0 0';

  // Les pistes sont lues une seule fois, pas à chaque image.
  static final _pistes = <String, Piste>{};
  static Piste _piste(String valeurs, double duree, [double debut = 0]) =>
      _pistes.putIfAbsent('$valeurs|$duree|$debut', () => Piste(valeurs, duree: duree, debut: debut));

  @override
  void paint(Canvas canvas, Size size) {
    final t = temps.value;
    final p = definition;
    final dur = p.duree;

    // viewBox de la maquette : -130 -150 260 260.
    canvas.save();
    canvas.scale(size.width / 260, size.height / 260);
    canvas.translate(130, 150);

    final ptv = _piste(p.ptv, dur).a(t);
    final prv = _piste(p.prv, dur).a(t);
    canvas.transform(composer([
      rotation(p.rotationG),
      translation(ptv[0], ptv[1]),
      rotationAutour(prv[0], prv[1], prv[2]),
    ]).storage);

    // L'écharpe flotte : même rotation pour son calque et pour la découpe du bleu Confluence.
    final flv = _piste(p.flv, dur).a(t);
    final decoupe = cheminGoutteBasse.transform(
      composer([transformationEcharpe, rotationAutour(flv[0], flv[1], flv[2])]).storage,
    );

    for (final c in p.calques) {
      final dureeCalque = c.duree ?? dur;
      List<double> piste(String valeurs) => _piste(valeurs, dureeCalque, c.debut).a(t);

      final tv = c.ombre
          // L'ombre reste au sol pendant que Sahla sautille.
          ? ptv.map((v) => -v).toList()
          : piste(c.tv ?? (p.pose == SahlaPose.search && c.regard ? _regard : '0 0;0 0'));
      final Matrix4 rot;
      if (c.echarpe) {
        rot = rotationAutour(flv[0], 20 - c.ox, 44 - c.oy);
      } else {
        final rv = piste(c.rv ?? '0;0');
        rot = rv.length >= 3 ? rotationAutour(rv[0], rv[1], rv[2]) : rotation(rv[0]);
      }
      final sv = piste(c.sv ?? '1 1;1 1');
      final opacite = piste(c.ov ?? '${c.opacite};${c.opacite}')[0].clamp(0.0, 1.0);
      if (opacite <= 0) continue;

      canvas.save();
      if (c.decoupeParEcharpe) canvas.clipPath(decoupe);
      canvas.transform(composer([
        translation(c.ox, c.oy),
        translation(tv[0], tv[1]),
        rot,
        echelle(sv[0], sv[1]),
        translation(-c.ox, -c.oy),
        c.t,
      ]).storage);
      if (c.remplissage case final couleur?) {
        canvas.drawPath(c.forme, Paint()..color = couleur.withValues(alpha: couleur.a * opacite));
      }
      if (c.trait case final couleur?) {
        canvas.drawPath(
          c.forme,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = c.epaisseur
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = couleur.withValues(alpha: couleur.a * opacite),
        );
      }
      canvas.restore();
    }

    for (final z in p.textes) {
      final decalage = _piste('0 8;0 -14', dur, z.debut).a(t);
      final opacite = _piste('0;1;1;0', dur, z.debut).a(t)[0];
      final texte = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: z.taille,
            fontWeight: FontWeight.w700,
            color: z.couleur.withValues(alpha: opacite.clamp(0.0, 1.0)),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // En SVG, y désigne la ligne de base du texte.
      final ligneDeBase = texte.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      texte.paint(canvas, Offset(z.x + decalage[0], z.y + decalage[1] - ligneDeBase));
      texte.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(PeintreSahla ancien) => ancien.definition != definition;
}
