# Base de connaissances de Sahla

C'est ici qu'on « entraîne » Sahla. Chaque fichier `.md` de ce dossier est lu au démarrage du serveur et donné à l'assistante, dans l'ordre alphabétique (d'où les numéros 00, 10, 20…).

## Règles d'écriture
- Une information = une phrase claire. Sahla répète ce qui est écrit ici : si c'est faux ici, ce sera faux dans ses réponses.
- `[À COMPLÉTER : …]` marque une information que l'équipe doit fournir. Tant qu'elle reste, Sahla répond qu'elle n'a pas l'information et propose le support : elle n'invente jamais un prix ou une règle. Au démarrage, le serveur affiche combien il en reste.
- `<!-- … -->` : note pour l'équipe, invisible pour Sahla.
- Les fichiers qui commencent par `_` et ce README sont ignorés.
- Écrire en français suffit : Sahla traduit dans la langue de l'utilisateur. Le glossaire (`70-langues.md`) l'aide pour le hassaniya, le pulaar, le soninké et le wolof.

## Après une modification
1. Redémarrer le serveur : la base est lue une seule fois, au démarrage.
2. Lancer les évaluations (`npm run evals` dans `sahla/serveur`) pour vérifier que Sahla répond toujours correctement.

## Ce qui n'est pas ici
- Les données personnelles (commandes, solde, chauffeur) : Sahla les lit en direct via l'API Sehelli (outils).
- Les règles de comportement (sécurité, style, langues) : `sahla/serveur/src/prompt.ts`.
