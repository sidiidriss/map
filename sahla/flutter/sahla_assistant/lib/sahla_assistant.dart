/// Sahla, l'assistante IA de la super-app Sehelli.
///
/// - [SahlaMascotte] : la mascotte animée (6 expressions, voir [SahlaPose]).
/// - [SahlaChat] : l'écran de discussion, branché sur le serveur Sahla.
/// - [SahlaBoutonFlottant] / [ouvrirSahla] : intégration en un clic dans l'app.
library;

export 'src/client.dart' show SahlaClient, FournisseurJeton, lireSse;
export 'src/controleur.dart';
export 'src/mascotte/poses.dart' show SahlaPose;
export 'src/mascotte/sahla_mascotte.dart' show SahlaMascotte;
export 'src/modeles.dart';
export 'src/sahla_bouton.dart';
export 'src/sahla_chat.dart' show SahlaChat, SahlaLogotype, TexteSahla;
export 'src/textes.dart' show SahlaTextes;
export 'src/theme.dart';
