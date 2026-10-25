# Checklist de test manuel — Fruit Village 1.0.0 (release)

À dérouler sur **ton téléphone** avec l'AAB de release installé depuis la
piste **Test interne** (version identique à celle des testeurs : signée par
Google, App ID et blocs AdMob réels).

**Avant de commencer — obligatoire** : AdMob → Paramètres → Appareils de test
→ ajoute ton téléphone (ID publicitaire : Paramètres Android → Google →
Annonces). Sinon tu verrais de vraies pubs : **ne clique jamais** sur une pub
de ton propre jeu (risque de suspension du compte AdMob).

Appareil : ______________ Android ___ RAM ___ Go · Date : ________ · Build : 1.0.0 (code ___)

Légende : ✅ OK · ❌ KO (noter le n° + ce qui s'est passé) · ⏭ non testé

## A. Installation et premier lancement

| # | Action | Attendu | Résultat |
|---|---|---|---|
| 1 | Installer depuis le lien de test interne (Play Store) | Nom « Fruit Village », icône Fruit Village nette (pas d'icône Godot) | |
| 2 | 1er lancement, chronomètre en main | Splash Fruit Village immédiat (pas d'écran noir), écran titre **< 3 s** sur entrée de gamme | |
| 3 | 1er lancement, réseau ON | Si tu es en EEE/R.-U./Suisse : formulaire de consentement Google ; sinon rien. Pas de blocage | |
| 4 | Formulaire de consentement : **tout refuser** | Le jeu continue, aucune erreur ; les boutons « ▶ » peuvent manquer (pubs limitées) | |
| 5 | Réglages → « Gérer mon consentement » → **accepter** | Formulaire rouvert, choix enregistré, boutons « ▶ » réapparaissent ensuite | |
| 6 | Écran titre | Nouveau logo Fruit Village, aucun texte « Merge Marché », aucun menu DEBUG | |
| 7 | Appui long à 3 doigts 2 s en partie | **Rien** (le menu debug n'existe pas en release) ; aucun compteur FPS à l'écran | |

## B. Partie

| # | Action | Attendu | Résultat |
|---|---|---|---|
| 8 | Jouer une partie complète jusqu'au game over | Visée au doigt, lâcher, fusions, score qui roule, fruit suivant affiché | |
| 9 | Faire un combo x3 ou plus | Bannière COMBO, notes de fusion, vibration (si activée) | |
| 10 | Remplir jusqu'à la ligne rouge | Ligne qui clignote, fruits qui tremblent, battement de cœur ; game over après 2 s | |
| 11 | Game over → « ▶ Continuer » (si proposé) → regarder la pub **jusqu'au bout** | Partie reprise, 3 fruits du haut retirés ; 1 seule fois par partie | |
| 12 | « ▶ Continuer » → **fermer la pub avant la fin** | Pas de récompense, retour propre à l'écran de fin, son revenu | |
| 13 | Écran de fin → « ▶ Doubler » | Pièces doublées une seule fois | |
| 14 | Power-ups : Secouer, Pilon, Échange, Agrandir | Chacun fonctionne, pièces débitées, annulation du pilon possible | |
| 15 | Rotation de l'écran (rotation auto activée) | Reste en **portrait**, rien ne bouge | |
| 16 | Bouton pause → Menu → Jouer | Nouvelle partie propre, musique OK | |

## C. Méta

| # | Action | Attendu | Résultat |
|---|---|---|---|
| 17 | Missions du jour | 3 missions, progression qui avance pendant la partie, récompense réclamable | |
| 18 | Cadeau du jour (dès le déblocage) | Réclamable une fois ; le lendemain : jour 2 | |
| 19 | Album | Fruits découverts visibles, cartes « Le savais-tu ? » lisibles | |
| 20 | Réglages : couper musique, sons, vibrations séparément | Chaque réglage agit seul et est conservé après redémarrage | |
| 21 | Réglages → lien politique de confidentialité | Ouvre https://fruit-village.netlify.app/ | |

## D. Interruptions (pas de crash, pas de blocage)

| # | Action | Attendu | Résultat |
|---|---|---|---|
| 22 | **Mode avion** puis lancer le jeu à froid | Démarre, partie jouable ; boutons « ▶ » masqués (jamais de bouton qui ne fait rien) | |
| 23 | Mode avion → jouer → réseau rétabli | Les boutons « ▶ » reviennent après une partie, sans redémarrer | |
| 24 | Pendant une pub à récompense : bouton Accueil 10 s, puis revenir | Pub reprise ou fermée ; le jeu ne reste **jamais** figé en pause (au pire 8 s d'attente) | |
| 25 | Pub qui échoue (couper le Wi-Fi juste après avoir touché « ▶ ») | Pas de récompense, jeu repris, pas de blocage | |
| 26 | **Appel entrant** pendant une partie (fais-toi appeler) | Jeu en pause/son coupé pendant l'appel ; au retour, partie intacte (bouton pause ou reprise) | |
| 27 | Partie en cours → balayer l'app hors des récentes → relancer | Pas de crash ; progression (pièces, album, missions) conservée | |
| 28 | Verrouiller l'écran 1 min en pleine partie, déverrouiller | Retour en pause, rien de cassé, musique reprend | |
| 29 | Notification de rappel (si reçue) | Ouvre le jeu ; sinon noter « pas reçue » (normal en 1.0.0, voir rapport M5) | |

## E. Fin de session

| # | Action | Attendu | Résultat |
|---|---|---|---|
| 30 | 15 min de jeu continu | Pas de surchauffe anormale, pas de ralentissement progressif (FPS stable à l'œil) | |
| 31 | Android vitals (Play Console, J+1) | 0 plantage, 0 ANR pour ton appareil | |
| 32 | Taille dans Paramètres → Applications → Fruit Village | Noter la taille installée : _______ Mo | |

**Bloquants (ne pas passer en test fermé) :** un ❌ sur 2, 4, 7, 11, 12, 22, 24, 25, 26, 27 ou tout plantage.
