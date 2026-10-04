# La voix de Sahla : guide d'enregistrement

Sahla est d'abord une assistante **vocale**. Elle parle avec deux types de voix :

1. **Les phrases enregistrées** (ce dossier) : 23 phrases fixes, dites par la vraie voix de Sahla, que l'app joue aux moments clés (accueil, « je cherche… », « bravo ! », « oups… », urgence…). Chacune est liée à une expression animée de la mascotte. Elles sont authentiques dans toutes les langues, y compris le hassaniya, le pulaar, le soninké et le wolof, que les voix de synthèse prononcent mal.
2. **La voix de synthèse de Sahla** : pour les réponses libres, qu'on ne peut pas enregistrer à l'avance. On la crée à partir de la même voix (voir plus bas).

`phrases.json` contient toutes les phrases (texte par langue, moment, expression, ton). Le **prompteur** (page web publiée à partir de ce fichier) les affiche une par une pendant la séance, avec l'expression de Sahla à jouer, et permet de cocher ce qui est enregistré.

## Qui enregistre

- **La voix principale de Sahla** : une femme (Sahla est « elle »), voix jeune, chaleureuse et souriante. Idéalement une Mauritanienne qui parle hassaniya, arabe et français : ce sont les trois langues à enregistrer en premier.
- **Pulaar, soninké, wolof** : la même personne si elle les parle couramment, sinon une locutrice native de chaque langue, avec un timbre proche (jeune, chaleureux).
- **Anglais, espagnol, portugais, chinois** : facultatif. La voix de synthèse suffit pour ces langues.

Ordre conseillé : hassaniya, français, arabe, puis pulaar, wolof, soninké, puis le reste si besoin.

## Avant la séance : faire valider les textes

| Langue | État des textes |
|---|---|
| Français, arabe, anglais, espagnol, portugais, chinois | prêts |
| Hassaniya, pulaar, wolof | **propositions à faire valider** par une personne native |
| Soninké | **à écrire** par une personne native, à partir du français |

Règle d'or : la comédienne dit la phrase **comme elle la dirait naturellement**. Si elle change des mots, on note le nouveau texte dans `phrases.json` (l'app l'affiche en sous-titre).

## Jouer Sahla

- **Personnalité** : accueillante comme quelqu'un qui reçoit à la maison, simple, efficace, un peu joueuse mais jamais lourde.
- **Le sourire s'entend** : sourire en parlant, sauf pour la phrase d'urgence (calme, posée, sérieuse).
- **Rythme** : posé, phrases courtes, bien articuler les chiffres (17, prix).
- Chaque phrase du prompteur indique le **ton** et l'**expression** de la mascotte au même moment : jouer la même émotion.

## Matériel et réglages

- **La pièce** : petite, sans écho (tapis, rideaux, vêtements dans un placard), loin de la rue. Éteindre ventilateur et climatisation, téléphone en mode avion.
- **Le micro** : un micro USB à condensateur ou un micro-cravate. En dernier recours, un smartphone posé à 20 cm de la bouche.
- **Distance** : la même pendant toute la séance (environ une main et demie), un filtre anti-pop si possible.
- **Format** : WAV, 48 kHz, 24 bits (16 bits accepté), mono.
- **Niveau** : les pics autour de −6 dB, jamais dans le rouge. Aucun effet (pas de réverbération, pas de compression).
- **Prises** : 1 seconde de silence avant et après chaque phrase. Faire 2 ou 3 prises et garder la meilleure.

## Nommer les fichiers

```
voix/<langue>/<cle>.wav
```

Codes de langue : `fr`, `ar`, `mey` (hassaniya), `ff` (pulaar), `snk` (soninké), `wo` (wolof), `en`, `es`, `pt`, `zh`. La clé est indiquée sur chaque phrase du prompteur. Exemples : `voix/mey/accueil.wav`, `voix/fr/recherche_2.wav`.

Garder les WAV d'origine. Pour l'app, on les convertit en M4A :

```bash
ffmpeg -i voix/mey/accueil.wav -ac 1 -c:a aac -b:a 96k voix/mey/accueil.m4a
```

## La voix de synthèse de Sahla

Pour les réponses libres, on crée une voix de synthèse à partir de la voix principale, avec un service de synthèse vocale (à choisir). Le service fournit son propre texte de lecture : selon l'offre, il faut de quelques minutes à quelques heures d'enregistrement. Le faire avec le même micro, dans la même pièce et avec les mêmes réglages que les phrases ci-dessus, de préférence en hassaniya ou en arabe, et en français.

Limite connue : les services actuels gèrent bien le français, l'arabe, l'anglais, l'espagnol, le portugais et le chinois, mais peu ou pas le hassaniya, le pulaar, le soninké et le wolof. À tester avec la personne native avant de choisir le service : c'est pour ces langues que les phrases enregistrées comptent le plus.

## Droits et consentement

Avant la séance, faire signer un **accord écrit** à chaque personne enregistrée. Il précise :
- l'usage des enregistrements dans l'app Sehelli (et la publicité, si prévu) ;
- **l'autorisation de créer une voix de synthèse** à partir de sa voix ;
- la durée, la rémunération et les conditions d'arrêt.

Ne jamais créer une voix de synthèse sans cet accord. Faire relire le contrat par un juriste.
