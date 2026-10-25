# Vidéo promo Fruit Village — 20 s, portrait 9:16

Usage : vidéo YouTube (non répertoriée ou publique) liée à la fiche Play,
statuts WhatsApp, Reels/Shorts. Enregistrer sur le téléphone (enregistreur
d'écran Android, 1080x1920, 60 i/s si possible), **sons du jeu ON**,
notifications coupées (mode Ne pas déranger), barre d'état masquée au montage.

Préparer avant de filmer : une sauvegarde avec 2 pains de singe proches dans
le panier (ou une build debug et le menu debug « Forcer un Baobab » ; dans ce
cas, aucun compteur FPS ni menu ne doit apparaître à l'image), quelques
fruits moyens pour la chaîne de combos.

Pas de pub à l'écran, pas de nom de jeu concurrent, rien qui n'existe pas dans
le jeu (règle Play : la vidéo doit montrer le vrai gameplay).

| Temps | Plan (image) | Son | Texte à l'écran (FR / EN) |
|---|---|---|---|
| 0,0–0,6 s | **Accroche** : gros plan, un fruit tombe et fusionne immédiatement (éclaboussure de jus) | « pop » de fusion | — |
| 0,6–2,0 s | Deux mangues roulent l'une vers l'autre… fusion en papaye, la mascotte singe saute | note de fusion + « Waaw ! » | **Deux pareils ? Ça fusionne !** / *Match two, watch them merge!* |
| 2,0–6,0 s | **Fusion en chaîne** : un lâcher déclenche 3–4 fusions d'affilée, bannière COMBO x2 → x4, léger zoom caméra | notes qui montent en mélodie | **COMBO x4 !** (le jeu l'affiche déjà, pas de texte ajouté) |
| 6,0–8,0 s | Écran plus large : panier bien rempli, fruits qui ont peur près de la ligne rouge (tension) | battement de cœur | **Garde ton calme…** / *Keep your cool…* |
| 8,0–9,0 s | Lâcher décisif : les deux pains de singe se touchent | silence de 0,3 s | — |
| 9,0–14,0 s | **Moment Baobab** : ralenti, « BAOBAB ! », le baobab pousse derrière le marché, pluie de pièces | roulement de sabar | **Fais pousser le Baobab !** / *Grow the mighty Baobab!* |
| 14,0–16,5 s | Carte « Le savais-tu ? » du pain de singe, puis l'album des fruits qui défile | jingle de découverte | **11 fruits d'Afrique à découvrir** / *11 African fruits to discover* |
| 16,5–20,0 s | **Appel à l'action** : logo Fruit Village sur le décor du marché + badge « Disponible sur Google Play » | accord final + « Dieuredieuf ! » | **Joue gratuitement sur Google Play** / *Play free on Google Play* |

Montage : coupes franches sur les temps forts du son, textes en Baloo 2
ExtraBold blanc contour brun (comme les captures), jamais plus de 6 mots à
l'écran. Badge Google Play : utiliser le badge officiel (play.google.com/intl/fr/badges)
sans le modifier, seulement une fois l'app publiée.

Version 15 s (Reels/Shorts) : retirer 6,0–8,0 s et raccourcir 14,0–16,5 s à 1 s.

## Version générée depuis le jeu

`tools/video/make_promo.sh` rend cette vidéo depuis le vrai jeu (Movie Maker
de Godot pour le son, capture 1080x1920 pour l'image, montage par
`tools/video/edit.py`) → `store/video/fruit_village_promo_{20s,15s}_{fr,en}.mp4`
(non versionnés). Écarts : voix finale « Dafa neex » (« Dieuredieuf » pas
encore enregistrée), carte du pain de singe sans défilement de l'album,
combo réel jusqu'à x8, pas de badge Google Play avant publication.
