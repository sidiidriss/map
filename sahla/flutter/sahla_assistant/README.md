# sahla_assistant

Package Flutter de **Sahla**, l'assistante IA de Sehelli : la mascotte animée (fidèle à la maquette « Mascotte — Sahla ») et l'écran de chat branché sur le serveur Sahla (`sahla/serveur`).

Aucune dépendance en dehors de `http` : la mascotte est dessinée en vectoriel par un `CustomPainter`, sans image ni Lottie.

## Installation

Dans le `pubspec.yaml` de l'app Sehelli :

```yaml
dependencies:
  sahla_assistant:
    git:
      url: https://github.com/sidiidriss/map.git
      path: sahla/flutter/sahla_assistant
```

(ou `path: ../map/sahla/flutter/sahla_assistant` pendant le développement). Flutter 3.27 ou plus récent.

## Intégration en 3 étapes

```dart
import 'package:sahla_assistant/sahla_assistant.dart';

// 1. Un contrôleur par session (le garder dans un State ou un provider).
final sahla = SahlaControleur(
  client: SahlaClient(
    urlServeur: Uri.parse('https://sahla.sehelli.mr/'),
    jeton: () async => 'Bearer ${await session.jeton()}', // null si non connecté
  ),
  langue: 'fr', // fr, ar, mey (hassaniya), ff (pulaar), snk (soninké), wo, en, es, pt, zh
  contexte: () => SahlaContexte(prenom: user.prenom, ecran: 'accueil', latitude: pos?.lat, longitude: pos?.lng),
);

// 2. Le bouton flottant ouvre le chat dans une feuille.
Scaffold(
  floatingActionButton: SahlaBoutonFlottant(
    controleur: sahla,
    onAction: (action) => Navigator.pushNamed(context, '/${action.ecran}', arguments: action.parametres),
  ),
);

// 3. Quand l'utilisateur a confirmé l'action proposée (course commandée, recharge réussie) :
sahla.celebrer(); // Sahla fait « Bravo ! »
```

Changer de langue : `sahla.langue = 'ar';` (l'écran passe de droite à gauche pour l'arabe et le hassaniya). Exemple complet : `example/main.dart`.

## Les boutons d'action

Sahla ne commande et ne paie jamais à la place de l'utilisateur. Elle propose un bouton ; l'app ouvre l'écran pré-rempli et l'utilisateur confirme.

| `action.ecran` | Paramètres possibles |
|---|---|
| `commander_course` | `depart_id`, `arrivee_id`, `categorie` |
| `commander_livraison` | `depart_id`, `arrivee_id`, `categorie` |
| `suivi_commande` | `commande_id` |
| `portefeuille`, `recharger_portefeuille`, `historique_commandes`, `profil`, `aide_contact` | — |

Les identifiants de lieux (`depart_id`, `arrivee_id`) sont ceux de l'API Sehelli (route `assistant/lieux`), ou `position_actuelle`.

## La mascotte seule

```dart
SahlaMascotte(pose: SahlaPose.search, taille: 120)
```

| Pose | Maquette | Quand |
|---|---|---|
| `hello` | Bonjour ! | accueil, réponse normale |
| `go` | En route | course ou livraison proposée / en cours |
| `search` | Je cherche… | Sahla réfléchit ou consulte les services |
| `bravo` | Bravo ! | action confirmée (`celebrer()`) |
| `oops` | Oups… | erreur, refus, hors zone |
| `empty` | Rien ici | aucune commande trouvée |

Le chat choisit la pose tout seul à partir des événements du serveur. La mascotte peut aussi servir ailleurs dans l'app (écrans de chargement, listes vides, erreurs de paiement). Elle respecte le réglage « réduire les animations » du téléphone.

## Textes de l'interface

`lib/src/textes.dart` est généré depuis `sahla/serveur/public/textes.js` (textes partagés avec la page de démo) :

```bash
node tool/generer_textes.mjs
```

Les textes en hassaniya, pulaar et wolof sont à faire relire par des locuteurs natifs ; le soninké utilise pour l'instant le français, avec une salutation soninké.

## Développement

```bash
flutter test     # client SSE, contrôleur, écran de chat, rendu des 6 poses
flutter analyze
```

Pour tester sur un émulateur Android avec le serveur en local (`http://10.0.2.2:8787/`), autoriser le HTTP en clair en développement (`android:usesCleartextTraffic="true"` dans le manifeste de debug). En production, utiliser HTTPS.
