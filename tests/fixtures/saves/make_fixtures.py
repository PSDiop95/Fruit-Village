"""Génère les sauvegardes de test V2-0 (tests/unit/test_save_recovery.gd).

Usage : python tests/fixtures/saves/make_fixtures.py
Le checksum reproduit SaveCodec.checksum : sha256(SALT + json)[:24].
Données fictives uniquement (aucune donnée joueur réelle).
"""
import hashlib
import json
import os

SALT = "fruit-village/marche/2026"
HERE = os.path.dirname(os.path.abspath(__file__))


def js(d):
    return json.dumps(d, separators=(",", ":"), ensure_ascii=False)


def v2(data, header="FV2", checksum=None):
    body = js(data)
    cs = checksum or hashlib.sha256((SALT + body).encode("utf-8")).hexdigest()[:24]
    return "%s %s\n%s" % (header, cs, body)


SETTINGS = {"music_on": False, "sfx_on": True, "quality": 1, "language": "en"}
CORE = {"best_score": 5230, "best_rank": 7, "games_played": 42, "settings": SETTINGS}
SYSTEMS = {
    "wallet": {"coins": 310, "earned": 900, "spent": 590, "stock": {"shake": 2, "swap": 1}},
    "progression": {"xp": 1450},
    "collection": {"found": [0, 1, 2, 3, 4, 5, 6, 7], "completion_claimed": False},
    "daily": {"last_claim_day": 20400, "streak": 4, "cycle": 4, "last_shield_day": -1000000,
              "last_seen": 1762600000},
    "ads": {"lifetime_games": 42, "games_since_last": 1, "last_shown": -1e12},
}
VALID = {"version": 2, "core": CORE, "systems": SYSTEMS}

files = {}
# V1 (M1–M3) : JSON brut.
files["v1_valid.json"] = js({"version": 1, "best_score": 3100, "best_rank": 6, "games_played": 9,
                             "settings": {"music_on": False, "quality": 1}})
files["v2_valid.sav"] = v2(VALID)
files["corrupt.sav"] = "FV2 0123456789abcdef01234567\n{\"core\": {\"best_score\": 52"
# Solde modifié à la main (checksum non recalculé).
tampered = json.loads(js(VALID))
tampered["systems"]["wallet"]["coins"] = 999999
files["tampered.sav"] = v2(VALID, checksum=None).split("\n")[0] + "\n" + js(tampered)
# Champs/sections manquants (checksum valide).
files["incomplete.sav"] = v2({"version": 2, "core": {"best_score": 800}})
files["missing_sections.sav"] = v2({"version": 2, "core": CORE})
# Version future : en-tête FV3, et FV2 avec "version": 3.
future = json.loads(js(VALID))
future["version"] = 3
future["systems"]["achievements"] = {"unlocked": ["first_baobab"]}
future["cloud"] = {"linked": False}
files["future_header.sav"] = v2(future, header="FV3", checksum="0" * 24)
files["future_version.sav"] = v2(future)
# Grosse progression + section inconnue (V2-x) à préserver.
big = json.loads(js(VALID))
big["core"]["best_score"] = 98765
big["core"]["best_rank"] = 10
big["core"]["games_played"] = 2500
big["core"]["settings"]["future_option"] = "keep-me"
big["core"]["lifetime_baobabs"] = 3
big["systems"]["wallet"] = {"coins": 54000, "earned": 210000, "spent": 156000,
                            "stock": {"shake": 40, "pestle": 12, "swap": 9, "grow": 5}}
big["systems"]["progression"] = {"xp": 250000}
big["systems"]["collection"] = {"found": list(range(11)), "completion_claimed": True}
big["systems"]["achievements"] = {"unlocked": ["first_baobab", "combo_6"], "progress": {"mango": 87}}
files["large_progression.sav"] = v2(big)

for name, text in files.items():
    with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
print("ok", len(files))
