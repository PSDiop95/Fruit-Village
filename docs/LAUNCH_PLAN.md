# Plan de test et de lancement — Fruit Village

## Règle Google Play à respecter (vérifiée le 24 octobre 2026)

Source : [Play Console Help — App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465).

- Compte développeur **personnel créé après le 13 novembre 2023** : avant
  d'accéder à la production, il faut un **test fermé** avec **au moins 12
  testeurs inscrits (« opted in ») en continu pendant les 14 derniers jours**
  au moment de la demande.
- Un testeur qui se désinscrit puis se réinscrit **remet ses 14 jours à
  zéro** : il faut 14 jours consécutifs.
- Demande : Play Console → Tableau de bord → **« Demander l'accès à la
  production »** (3 sections : test fermé, app, préparation à la production).
  Google examine en **7 jours ou moins** en général, et peut demander de
  prolonger le test si l'engagement des testeurs est jugé insuffisant.
- Les comptes **Organisation** (numéro D-U-N-S) sont exemptés. Si Smart IA
  Services a un D-U-N-S et que tu crées un compte Organisation, cette étape
  saute ; sinon, on la planifie.

Autres règles en vigueur intégrées au build : targetSdk **36** obligatoire
depuis le 31 août 2026 pour les nouvelles apps
([source](https://support.google.com/googleplay/android-developer/answer/11926878)) ;
compatibilité **pages mémoire 16 Ko** pour les apps ciblant Android 15+
([source](https://developer.android.com/guide/practices/page-sizes)).

## Calendrier (J0 = jour où l'AAB passe ton test interne)

Prévois **15 à 20 testeurs** pour garder une marge au-dessus de 12.

| Jour | Étape | Qui | Sortie attendue |
|---|---|---|---|
| J-3 → J-1 | Recrutement WhatsApp (message ci-dessous), collecte des adresses Gmail | Toi | ≥ 15 adresses Gmail |
| J-2 | Clé d'upload, Firebase (nouveau package), message RGPD AdMob, `tools/build_release.sh` | Toi | AAB signé, rapport vert |
| J-1 | Play Console : créer l'app, fiche, contenu de l'app (`docs/PLAY_CONSOLE.md`), envoi en **Test interne** | Toi | Lien de test interne |
| J0 | `docs/QA_CHECKLIST.md` sur ton téléphone | Toi | 0 bloquant |
| J0 | Créer la piste **Test fermé** (liste d'e-mails ou Google Group), même AAB, envoyer le lien d'inscription | Toi | Revue Google du test fermé (souvent < 2 j) |
| J1–J2 | Relancer chaque testeur jusqu'à « inscrit + installé » ; vérifier le compteur dans la Play Console | Toi | **≥ 12 inscrits** → le compteur de 14 jours démarre |
| J2–J15 | Test fermé : jouer chaque jour (au moins 1 partie), retours via le formulaire. Une mise à jour par semaine max (`tools/bump_version.sh`) | Testeurs | Retours, Android vitals propre |
| J9 | Point d'étape : corrections des retours, nouvelle version en test fermé (les testeurs restent inscrits) | Toi + moi | 1.0.1 |
| J16 | **Demande d'accès à la production** (≥ 12 inscrits depuis 14 jours) | Toi | Formulaire envoyé |
| J16–J23 | Examen Google (≤ 7 jours en général). Le test fermé **continue** | Google | Accès production |
| J+0 prod | Production, **déploiement progressif 20 %** | Toi | — |
| J+3 | Si tableau de bord vert → **50 %** | Toi | — |
| J+7 | Si vert → **100 %** | Toi | — |

Arrêt du déploiement (Play Console → Production → « Interrompre le
déploiement ») dès qu'un seuil **rouge** ci-dessous est atteint.

## Tableau de bord des 14 premiers jours

Sources : Play Console (Android vitals, Statistiques, Acquisition), Firebase
Analytics (rétention, événements `game_start`, `game_over`, `ad_offered`,
`ad_watched`/`ad_rewarded`), AdMob (revenus, eCPM, taux de remplissage).

| KPI | Où | Cible | Alerte (orange) | Rouge → action |
|---|---|---|---|---|
| Taux de plantage perçu | Android vitals | < 0,3 % | ≥ 0,5 % | **≥ 1,09 %** (seuil « mauvais comportement » Google) → stopper le déploiement, corriger, 1.0.x |
| Taux d'ANR perçu | Android vitals | < 0,2 % | ≥ 0,3 % | **≥ 0,47 %** (seuil Google) → stopper, analyser les traces (souvent : pub, sauvegarde) |
| Temps de démarrage à froid | Android vitals → Démarrage | < 3 s | 3–5 s | > 5 s → alléger le chargement (textures, modèles) |
| Rétention J1 | Firebase → Rétention | ≥ 35 % | < 30 % | < 22 % (médiane du marché) → revoir les 3 premières minutes : difficulté, panier, objectif visible |
| Rétention J7 | Firebase → Rétention | ≥ 10 % | < 7 % | < 4 % → renforcer missions, cadeau du jour, avancer les Commandes (V1.1) |
| Durée de session | Firebase → Engagement | 3–10 min | < 3 min | < 2 min → parties trop dures/courtes : agrandir le panier, revoir le spawn |
| Parties par joueur actif / jour | `game_start` / utilisateurs actifs | ≥ 3 | < 2 | < 1,5 → relance après game over, objectif « Prochain fruit » |
| % joueurs ayant atteint la Mangue en 3 j | `merge` rang 7 | ≥ 30 % | < 15 % | **< 5 %** (seuil du cahier des charges) → panier trop petit ou spawn trop dur |
| Vue rewarded « Continuer » (`ad_rewarded` / `ad_offered`) | Firebase | ≥ 30 % | < 20 % | < 10 % → offre peu visible ou peu utile (durée d'offre, nombre de fruits retirés) |
| Vue rewarded « Doubler » | Firebase | ≥ 20 % | < 12 % | < 6 % → revoir la valeur des pièces (prix des power-ups) |
| Vue rewarded « Secouer gratuit » | Firebase | ≥ 10 % | < 5 % | < 2 % → bouton peu visible |
| Échecs de pub (`ad_failed` / `ad_shown`) | Firebase | < 5 % | ≥ 10 % | ≥ 20 % → taux de remplissage AdMob, réseau ; envisager la médiation (phase 2) |
| Revenu par joueur actif / jour (ARPDAU) | AdMob ÷ utilisateurs actifs Firebase | 0,02–0,05 $ | < 0,01 $ | < 0,005 $ → placements, fréquence d'interstitiel (règle 3 parties / 3 min), ciblage pays Tier 1 |
| Note moyenne | Play Console → Notes | ≥ 4,3 | < 4,0 | < 3,5 → lire les avis 1–2★, corriger en priorité |
| Conversion fiche → installation | Play Console → Acquisition | ≥ 25 % | < 20 % | < 15 % → icône, 1re capture, description courte (tests A/B de fiche) |
| Désinstallations J1 | Play Console → Statistiques | < 30 % | ≥ 35 % | ≥ 45 % → pubs trop tôt ? (aucun interstitiel avant la 5e partie : vérifier) |

Rythme : vitals **chaque jour** pendant le déploiement progressif ; le reste
chaque lundi. Une seule modification de réglage à la fois (sinon on ne sait
pas ce qui a marché).

## Message de recrutement (WhatsApp, FR)

> 🍍 **Teste mon jeu avant tout le monde !**
>
> Salut ! Je sors **Fruit Village**, un jeu de fusion de fruits d'Afrique
> (bissap, ditakh, madd, mangue… jusqu'au Baobab 🌳). Avant la sortie sur le
> Play Store, Google m'oblige à le faire tester **14 jours** par au moins
> 12 personnes.
>
> Ce que je te demande :
> 1️⃣ M'envoyer l'**adresse Gmail** de ton téléphone Android (pas d'iPhone pour
> l'instant).
> 2️⃣ Cliquer sur le lien que je t'enverrai → « Devenir testeur » → installer
> depuis le Play Store.
> 3️⃣ **Garder le jeu installé 14 jours** et faire au moins une petite partie
> par jour (2-3 min suffisent 🙏). Ne te désinscris pas, sinon le compteur
> repart à zéro pour moi.
> 4️⃣ Me donner ton avis via un petit formulaire (2 min).
>
> C'est gratuit, sans inscription dans le jeu. Il y a quelques pubs (c'est
> comme ça que le jeu sera financé) : merci de **ne pas cliquer dessus pour
> m'aider**, ça peut faire bloquer mon compte 😅
>
> Partant(e) ? Réponds juste avec ton Gmail. Merci 🙏🏾

Relance J+1 (à ceux qui ne sont pas encore inscrits) :

> Petit rappel 🍊 : le lien pour tester Fruit Village est ici 👉 [lien].
> Il faut cliquer « Devenir testeur » PUIS installer. Dis-moi si ça bloque !

## Formulaire de retour (Google Forms, 2 min)

1. Ton téléphone (marque, modèle) — *texte court*
2. As-tu eu un plantage ou un écran figé ? — *Non / Oui, une fois / Oui,
   plusieurs fois* ; si oui, à quel moment ? — *texte*
3. Le jeu démarre-t-il vite ? — *Oui / Moyen / Trop lent*
4. As-tu compris comment jouer sans explication ? — *Oui tout de suite / Après
   quelques essais / Non*
5. Note le plaisir de jeu — *1 à 5 étoiles*
6. Plus gros fruit atteint — *liste : Sidem → Pain de singe, Baobab !*
7. Les pubs te dérangent-elles ? — *Pas du tout / Un peu / Beaucoup* ;
   lesquelles ? — *Continuer / Doubler / Entre deux parties*
8. Ce que tu as préféré — *texte*
9. Ce qui t'a agacé ou que tu changerais — *texte*
10. Rejouerais-tu demain sans qu'on te le demande ? — *Oui / Peut-être / Non*
11. Capture d'écran d'un bug (facultatif) — *envoi de fichier*

Le formulaire n'est pas collecté par le jeu : ne demande pas plus que l'e-mail
Gmail déjà connu, et indique son usage (test du jeu uniquement).
