import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { MockBackend, normaliser } from "../src/backend/mock.js";
import { ErreurSehelli } from "../src/backend/types.js";
import { chargerConnaissances, construirePromptSysteme } from "../src/prompt.js";

const backend = new MockBackend();

describe("recherche de lieux (démo)", () => {
  it("trouve un quartier en arabe, en français et en translittération", async () => {
    assert.equal((await backend.rechercherLieu("تفرغ زينة"))[0].id, "nkc-tevragh-zeina");
    assert.equal((await backend.rechercherLieu("Tevragh-Zeïna"))[0].id, "nkc-tevragh-zeina");
    assert.equal((await backend.rechercherLieu("l'aéroport"))[0].id, "nkc-aeroport");
    assert.equal((await backend.rechercherLieu("المطار"))[0].id, "nkc-aeroport");
  });

  it("normalise accents et formes arabes", () => {
    assert.equal(normaliser("Dar Naïm"), "dar naim");
    assert.equal(normaliser("إلى المطارِ"), "الي المطار");
  });
});

describe("estimation de prix (démo)", () => {
  it("donne une fourchette cohérente", async () => {
    const e = await backend.estimerPrix({ service: "course", depart_id: "nkc-ksar", arrivee_id: "nkc-sebkha" }, {});
    assert.equal(e.devise, "MRU");
    assert.ok(e.prix_min < e.prix_max);
    assert.ok(e.distance_km > 0);
  });

  it("utilise la position partagée et refuse quand elle manque", async () => {
    const e = await backend.estimerPrix(
      { service: "livraison", depart_id: "position_actuelle", arrivee_id: "nkc-ksar" },
      { position: { lat: 18.09, lng: -15.98 } },
    );
    assert.equal(e.depart, "Votre position");
    await assert.rejects(
      backend.estimerPrix({ service: "course", depart_id: "position_actuelle", arrivee_id: "nkc-ksar" }, {}),
      (err: unknown) => err instanceof ErreurSehelli && err.code === "position_inconnue",
    );
  });

  it("signale un trajet hors zone", async () => {
    await assert.rejects(
      backend.estimerPrix(
        { service: "course", depart_id: "position_actuelle", arrivee_id: "nkc-ksar" },
        { position: { lat: 20.94, lng: -17.04 } }, // Nouadhibou
      ),
      (err: unknown) => err instanceof ErreurSehelli && err.code === "hors_zone",
    );
  });
});

describe("base de connaissances", () => {
  it("charge les fichiers dans l'ordre et cache les notes de l'équipe", () => {
    const base = chargerConnaissances(new URL("../../connaissances", import.meta.url).pathname);
    assert.equal(base.fichiers[0], "00-sahla.md");
    assert.ok(!base.fichiers.includes("README.md"));
    const prompt = construirePromptSysteme(base);
    assert.ok(!prompt.includes("<!--"));
    assert.ok(prompt.includes("Wassalni"));
    assert.ok(base.aCompleter > 0);
  });
});
