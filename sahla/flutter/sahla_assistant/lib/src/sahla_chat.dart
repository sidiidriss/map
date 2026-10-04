import 'package:flutter/material.dart';

import 'controleur.dart';
import 'mascotte/poses.dart';
import 'mascotte/sahla_mascotte.dart';
import 'modeles.dart';
import 'textes.dart';
import 'theme.dart';

/// Écran de chat avec Sahla.
///
/// [onAction] reçoit les boutons proposés par Sahla (ex. commander_course) :
/// l'app ouvre l'écran correspondant et l'utilisateur y confirme lui-même.
class SahlaChat extends StatefulWidget {
  const SahlaChat({super.key, required this.controleur, this.onAction, this.surFermer});

  final SahlaControleur controleur;
  final void Function(SahlaAction action)? onAction;

  /// Si fourni, affiche un bouton de fermeture dans l'en-tête.
  final VoidCallback? surFermer;

  @override
  State<SahlaChat> createState() => _SahlaChatState();
}

class _SahlaChatState extends State<SahlaChat> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();

  SahlaControleur get _c => widget.controleur;

  @override
  void initState() {
    super.initState();
    _c.addListener(_majEtDefiler);
  }

  @override
  void didUpdateWidget(SahlaChat ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.controleur != widget.controleur) {
      ancien.controleur.removeListener(_majEtDefiler);
      widget.controleur.addListener(_majEtDefiler);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_majEtDefiler);
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
  }

  void _majEtDefiler() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defilement.hasClients) {
        _defilement.animateTo(
          _defilement.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _envoyer([String? texte]) {
    final message = texte ?? _saisie.text;
    if (message.trim().isEmpty || _c.enCours) return;
    if (texte == null) _saisie.clear();
    _c.envoyer(message);
  }

  @override
  Widget build(BuildContext context) {
    final t = SahlaTextes.pour(_c.langue);
    return Directionality(
      textDirection: SahlaTextes.droiteAGauche(_c.langue) ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: SahlaCouleurs.fond,
        child: Column(
          children: [
            _Entete(controleur: _c, textes: t, surFermer: widget.surFermer),
            Expanded(
              child: _c.messages.isEmpty
                  ? _Accueil(textes: t, surSuggestion: _envoyer)
                  : ListView.separated(
                      controller: _defilement,
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      itemCount: _c.messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _Message(
                        message: _c.messages[i],
                        textes: t,
                        enAttente: _c.enCours && i == _c.messages.length - 1,
                        onAction: widget.onAction,
                      ),
                    ),
            ),
            _Saisie(controleur: _saisie, textes: t, actif: !_c.enCours, surEnvoi: _envoyer),
          ],
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete({required this.controleur, required this.textes, this.surFermer});

  final SahlaControleur controleur;
  final SahlaTextes textes;
  final VoidCallback? surFermer;

  @override
  Widget build(BuildContext context) {
    final pose = controleur.pose;
    final statut = pose == SahlaPose.hello ? textes.sousTitre : textes.poses[pose]!;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 8, 6),
      decoration: const BoxDecoration(
        color: SahlaCouleurs.blanc,
        border: Border(bottom: BorderSide(color: SahlaCouleurs.bordure)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SahlaMascotte(pose: pose, taille: 54, etiquette: textes.poses[pose]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SahlaLogotype(taille: 24),
                  const SizedBox(height: 2),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      statut,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: SahlaCouleurs.texteTertiaire),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: textes.nouvelle,
              onPressed: controleur.enCours || controleur.messages.isEmpty ? null : controleur.nouvelleConversation,
              icon: const Icon(Icons.refresh_rounded, color: SahlaCouleurs.navy),
            ),
            if (surFermer != null)
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: surFermer,
                icon: const Icon(Icons.close_rounded, color: SahlaCouleurs.navy),
              ),
          ],
        ),
      ),
    );
  }
}

/// Le nom « Sahla » aux couleurs de la mascotte (Sa navy, h confluence, la ciel).
class SahlaLogotype extends StatelessWidget {
  const SahlaLogotype({super.key, this.taille = 24});

  final double taille;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: taille,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.5,
      height: 1,
    );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: 'Sa', style: style.copyWith(color: SahlaCouleurs.navy)),
        TextSpan(text: 'h', style: style.copyWith(color: SahlaCouleurs.confluence)),
        TextSpan(text: 'la', style: style.copyWith(color: SahlaCouleurs.ciel)),
      ]),
      textDirection: TextDirection.ltr,
      semanticsLabel: 'Sahla',
    );
  }
}

class _Accueil extends StatelessWidget {
  const _Accueil({required this.textes, required this.surSuggestion});

  final SahlaTextes textes;
  final void Function(String) surSuggestion;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          SahlaMascotte(taille: 170, etiquette: textes.poses[SahlaPose.hello]),
          const SizedBox(height: 8),
          Text(
            textes.titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: SahlaCouleurs.navy),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              textes.intro,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: SahlaCouleurs.texteSecondaire),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in textes.suggestions)
                OutlinedButton(
                  onPressed: () => surSuggestion(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SahlaCouleurs.navy,
                    backgroundColor: SahlaCouleurs.blanc,
                    side: const BorderSide(color: SahlaCouleurs.bordure),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.textes, required this.enAttente, this.onAction});

  final SahlaMessage message;
  final SahlaTextes textes;
  final bool enAttente;
  final void Function(SahlaAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final moi = message.auteur == SahlaAuteur.utilisateur;
    final erreur = message.erreur;
    final Widget contenu;
    if (moi) {
      contenu = Text(message.texte, style: const TextStyle(color: SahlaCouleurs.blanc, fontSize: 15, height: 1.45));
    } else if (erreur != null) {
      contenu = Text(
        textes.erreur(erreur),
        style: const TextStyle(color: SahlaCouleurs.texteSecondaire, fontSize: 15, fontStyle: FontStyle.italic),
      );
    } else if (message.texte.isEmpty && enAttente) {
      contenu = const _Points();
    } else {
      contenu = TexteSahla(message.texte);
    }

    final rayon = const Radius.circular(18);
    final bulle = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: moi ? SahlaCouleurs.navy : SahlaCouleurs.blanc,
          border: moi ? null : Border.all(color: SahlaCouleurs.bordure),
          borderRadius: BorderRadiusDirectional.only(
            topStart: rayon,
            topEnd: rayon,
            bottomStart: moi ? rayon : const Radius.circular(6),
            bottomEnd: moi ? const Radius.circular(6) : rayon,
          ),
        ),
        child: contenu,
      ),
    );

    return Column(
      crossAxisAlignment: moi ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        bulle,
        for (final action in message.actions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton(
              onPressed: onAction == null ? null : () => onAction!(action),
              style: FilledButton.styleFrom(
                backgroundColor: SahlaCouleurs.confluence,
                foregroundColor: SahlaCouleurs.blanc,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              // Le style est fusionné avec celui du thème, pour garder la police de l'app.
              child: Text(action.libelle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

/// Affiche le texte de Sahla : paragraphes, listes à puces et **gras**.
class TexteSahla extends StatelessWidget {
  const TexteSahla(this.texte, {super.key});

  final String texte;

  static final _puce = RegExp(r'^\s*(?:[-•*]|\d+[.)])\s+(.*)$');
  static final _gras = RegExp(r'\*\*(.+?)\*\*');

  List<TextSpan> _segments(String ligne) {
    final segments = <TextSpan>[];
    var debut = 0;
    for (final m in _gras.allMatches(ligne)) {
      if (m.start > debut) segments.add(TextSpan(text: ligne.substring(debut, m.start)));
      segments.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      debut = m.end;
    }
    if (debut < ligne.length) segments.add(TextSpan(text: ligne.substring(debut)));
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: SahlaCouleurs.navy, fontSize: 15, height: 1.45);
    final lignes = texte.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, ligne) in lignes.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: switch (_puce.firstMatch(ligne)) {
              final m? => Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: style),
                    Expanded(child: Text.rich(TextSpan(children: _segments(m.group(1)!)), style: style)),
                  ],
                ),
              null => Text.rich(TextSpan(children: _segments(ligne)), style: style),
            },
          ),
      ],
    );
  }
}

class _Points extends StatefulWidget {
  const _Points();

  @override
  State<_Points> createState() => _PointsState();
}

class _PointsState extends State<_Points> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const couleurs = [SahlaCouleurs.ciel, SahlaCouleurs.confluence, SahlaCouleurs.navy];
    return SizedBox(
      height: 20,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Builder(builder: (context) {
                final phase = ((_animation.value - i * 0.15) % 1.0);
                final saut = phase < 0.4 ? Curves.easeInOut.transform(phase < 0.2 ? phase / 0.2 : (0.4 - phase) / 0.2) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Transform.translate(
                    offset: Offset(0, -5 * saut),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: couleurs[i].withValues(alpha: 0.5 + 0.5 * saut),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _Saisie extends StatelessWidget {
  const _Saisie({required this.controleur, required this.textes, required this.actif, required this.surEnvoi});

  final TextEditingController controleur;
  final SahlaTextes textes;
  final bool actif;
  final VoidCallback surEnvoi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: SahlaCouleurs.blanc,
        border: Border(top: BorderSide(color: SahlaCouleurs.bordure)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controleur,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => surEnvoi(),
                style: const TextStyle(fontSize: 15, color: SahlaCouleurs.navy),
                decoration: InputDecoration(
                  hintText: textes.saisie,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: SahlaCouleurs.fond,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: SahlaCouleurs.bordure),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: SahlaCouleurs.bordure),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: SahlaCouleurs.ciel),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: textes.envoyer,
              onPressed: actif ? surEnvoi : null,
              style: IconButton.styleFrom(
                backgroundColor: SahlaCouleurs.confluence,
                disabledBackgroundColor: SahlaCouleurs.bordure,
                fixedSize: const Size(46, 46),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, color: SahlaCouleurs.blanc),
            ),
          ],
        ),
      ),
    );
  }
}
