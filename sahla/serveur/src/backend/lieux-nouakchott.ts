import type { Lieu } from "./types.js";

// Lieux de démonstration à Nouakchott. Coordonnées approximatives : en
// production, la recherche passe par l'API Sehelli (HttpBackend).
export interface LieuDemo extends Lieu {
  alias: string[];
}

export const LIEUX_NOUAKCHOTT: LieuDemo[] = [
  { id: "nkc-aeroport", nom: "Aéroport international Nouakchott–Oumtounsy", ville: "Nouakchott", lat: 18.3101, lng: -15.9697,
    alias: ["aeroport", "aéroport", "airport", "oumtounsy", "المطار", "مطار أم التونسي", "matar", "aeropuerto", "aeroporto", "机场"] },
  { id: "nkc-tevragh-zeina", nom: "Tevragh Zeina", quartier: "Tevragh Zeina", ville: "Nouakchott", lat: 18.1, lng: -15.99,
    alias: ["tevragh zeina", "tevrag zeina", "tavragh zeina", "tefragh zeina", "تفرغ زينة"] },
  { id: "nkc-ksar", nom: "Ksar", quartier: "Ksar", ville: "Nouakchott", lat: 18.105, lng: -15.955,
    alias: ["ksar", "lksar", "lekser", "el ksar", "لكصر", "القصر"] },
  { id: "nkc-capitale", nom: "Marché Capitale", quartier: "Tevragh Zeina", ville: "Nouakchott", lat: 18.0866, lng: -15.9785,
    alias: ["marche capitale", "marché capitale", "grand marche", "grand marché", "marsa", "سوق العاصمة", "مرصة", "capitale"] },
  { id: "nkc-sebkha", nom: "Sebkha", quartier: "Sebkha", ville: "Nouakchott", lat: 18.07, lng: -16.0,
    alias: ["sebkha", "sebkhe", "السبخة"] },
  { id: "nkc-el-mina", nom: "El Mina", quartier: "El Mina", ville: "Nouakchott", lat: 18.045, lng: -15.985,
    alias: ["el mina", "elmina", "mina", "الميناء"] },
  { id: "nkc-arafat", nom: "Arafat", quartier: "Arafat", ville: "Nouakchott", lat: 18.05, lng: -15.955,
    alias: ["arafat", "carrefour", "عرفات"] },
  { id: "nkc-riyad", nom: "Riyad", quartier: "Riyad", ville: "Nouakchott", lat: 18.015, lng: -15.945,
    alias: ["riyad", "riyadh", "الرياض", "pk"] },
  { id: "nkc-dar-naim", nom: "Dar Naïm", quartier: "Dar Naïm", ville: "Nouakchott", lat: 18.115, lng: -15.93,
    alias: ["dar naim", "dar naïm", "darnaim", "دار النعيم"] },
  { id: "nkc-teyarett", nom: "Teyarett", quartier: "Teyarett", ville: "Nouakchott", lat: 18.125, lng: -15.965,
    alias: ["teyarett", "teyaret", "tayaret", "tayarett", "تيارت"] },
  { id: "nkc-toujounine", nom: "Toujounine", quartier: "Toujounine", ville: "Nouakchott", lat: 18.085, lng: -15.915,
    alias: ["toujounine", "tojounin", "toujounin", "توجنين"] },
  { id: "nkc-port-peche", nom: "Plage des pêcheurs (port de pêche artisanale)", quartier: "Sebkha", ville: "Nouakchott", lat: 18.095, lng: -16.03,
    alias: ["plage des pecheurs", "plage des pêcheurs", "port de peche", "marche aux poissons", "marché aux poissons", "شاطئ الصيادين", "سوق السمك", "plage"] },
  { id: "nkc-port-amitie", nom: "Port autonome de Nouakchott (Port de l'Amitié)", quartier: "El Mina", ville: "Nouakchott", lat: 18.03, lng: -16.035,
    alias: ["port", "port de l'amitie", "port de l'amitié", "port autonome", "ميناء الصداقة", "الميناء المستقل"] },
  { id: "nkc-hopital-national", nom: "Centre hospitalier national", quartier: "Ksar", ville: "Nouakchott", lat: 18.087, lng: -15.97,
    alias: ["hopital national", "hôpital national", "chn", "hopital", "hôpital", "المستشفى الوطني", "hospital"] },
  { id: "nkc-carrefour-madrid", nom: "Carrefour Madrid", quartier: "Ksar", ville: "Nouakchott", lat: 18.093, lng: -15.964,
    alias: ["carrefour madrid", "madrid", "ملتقى مدريد"] },
  { id: "nkc-universite", nom: "Université de Nouakchott", quartier: "Dar Naïm", ville: "Nouakchott", lat: 18.123, lng: -15.94,
    alias: ["universite", "université", "fac", "faculte", "جامعة نواكشوط", "الجامعة", "university"] },
];
