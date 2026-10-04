import 'package:flutter/material.dart';

import 'controleur.dart';
import 'mascotte/sahla_mascotte.dart';
import 'modeles.dart';
import 'sahla_chat.dart';
import 'textes.dart';
import 'theme.dart';

/// Ouvre le chat Sahla dans une feuille qui remonte du bas de l'écran.
Future<void> ouvrirSahla(
  BuildContext context, {
  required SahlaControleur controleur,
  void Function(SahlaAction action)? onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (contexteFeuille) => FractionallySizedBox(
      heightFactor: 0.94,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SahlaChat(
          controleur: controleur,
          surFermer: () => Navigator.of(contexteFeuille).pop(),
          onAction: onAction == null
              ? null
              : (action) {
                  Navigator.of(contexteFeuille).pop();
                  onAction(action);
                },
        ),
      ),
    ),
  );
}

/// Bouton flottant avec Sahla, à placer dans `Scaffold.floatingActionButton`.
class SahlaBoutonFlottant extends StatelessWidget {
  const SahlaBoutonFlottant({super.key, required this.controleur, this.onAction});

  final SahlaControleur controleur;
  final void Function(SahlaAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controleur,
      builder: (context, _) => Semantics(
        button: true,
        label: 'Sahla, ${SahlaTextes.pour(controleur.langue).sousTitre}',
        child: Material(
          color: SahlaCouleurs.blanc,
          shape: const CircleBorder(side: BorderSide(color: SahlaCouleurs.bordure)),
          elevation: 4,
          shadowColor: SahlaCouleurs.navy.withValues(alpha: 0.3),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => ouvrirSahla(context, controleur: controleur, onAction: onAction),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ExcludeSemantics(child: SahlaMascotte(pose: controleur.pose, taille: 60)),
            ),
          ),
        ),
      ),
    );
  }
}
