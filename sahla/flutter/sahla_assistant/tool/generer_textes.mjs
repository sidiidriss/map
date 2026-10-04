// Régénère lib/src/textes.dart depuis sahla/serveur/public/textes.js (source unique des textes).
// Usage : node tool/generer_textes.mjs   (depuis sahla/flutter/sahla_assistant)
import { writeFileSync } from "node:fs";
import { TEXTES, LANGUES_RTL } from "../../../serveur/public/textes.js";

const q = (s) => `'${s.replace(/\\/g, "\\\\").replace(/'/g, "\\'").replace(/\$/g, "\\$")}'`;

let out = `// Fichier généré par tool/generer_textes.mjs depuis sahla/serveur/public/textes.js : ne pas modifier à la main.
// À faire relire par des locuteurs natifs : hassaniya (mey), pulaar (ff), wolof (wo).
// Soninké (snk) : salutation seulement, le reste en français en attendant une traduction validée.

import 'mascotte/poses.dart';

class SahlaTextes {
  const SahlaTextes({
    required this.nom,
    required this.sousTitre,
    required this.titre,
    required this.intro,
    required this.saisie,
    required this.envoyer,
    required this.nouvelle,
    required this.suggestions,
    required this.poses,
    required this.erreurs,
  });

  final String nom;
  final String sousTitre;
  final String titre;
  final String intro;
  final String saisie;
  final String envoyer;
  final String nouvelle;
  final List<String> suggestions;
  final Map<SahlaPose, String> poses;
  final Map<String, String> erreurs;

  String erreur(String code) => erreurs[code] ?? erreurs['indisponible']!;

  /// Textes pour un code de langue (fr, ar, mey, ff, snk, wo, en, es, pt, zh), français par défaut.
  static SahlaTextes pour(String langue) => sahlaTextes[langue] ?? sahlaTextes['fr']!;

  static bool droiteAGauche(String langue) => const {${[...LANGUES_RTL].map(q).join(", ")}}.contains(langue);
}

const sahlaTextes = <String, SahlaTextes>{
`;
for (const [code, t] of Object.entries(TEXTES)) {
  out += `  ${q(code)}: SahlaTextes(\n`;
  for (const k of ["nom", "sousTitre", "titre", "intro", "saisie", "envoyer", "nouvelle"]) out += `    ${k}: ${q(t[k])},\n`;
  out += `    suggestions: [\n${t.suggestions.map((s) => `      ${q(s)},`).join("\n")}\n    ],\n`;
  out += `    poses: {\n${Object.entries(t.poses).map(([p, v]) => `      SahlaPose.${p}: ${q(v)},`).join("\n")}\n    },\n`;
  out += `    erreurs: {\n${Object.entries(t.erreurs).map(([p, v]) => `      ${q(p)}: ${q(v)},`).join("\n")}\n    },\n`;
  out += `  ),\n`;
}
out += "};\n";
writeFileSync(new URL("../lib/src/textes.dart", import.meta.url), out);
console.log("lib/src/textes.dart régénéré");
