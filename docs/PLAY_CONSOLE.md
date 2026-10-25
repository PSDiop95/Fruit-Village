# Play Console : réponses préparées (Fruit Village 1.0.0)

Réponses à recopier dans la Play Console. Elles décrivent **ce que fait le
build 1.0.0** (AdMob + UMP, Google Analytics for Firebase, pas de Crashlytics,
pas de compte, pas d'achat intégré, sauvegarde locale uniquement) et doivent
rester cohérentes avec la politique de confidentialité en ligne.

> Toi seul es responsable des réponses envoyées à Google. Relis chaque ligne
> avec le build réellement envoyé (permissions affichées par
> `tools/build_release.sh`).

URL de politique de confidentialité supposée : **https://fruit-village.netlify.app/**
(valeur de `data/ads.tres`, ouverte par le bouton du jeu). Si tu en utilises
une autre, change-la aux 3 endroits : Play Console, `data/ads.tres`,
`store/*/full_description.txt`.

---

## 1. Fiche de l'application

| Champ | Valeur |
|---|---|
| Nom de l'application | voir `store/fr/title.txt` (FR, langue par défaut) et `store/en/title.txt` |
| Langue par défaut | Français (France) – fr-FR |
| Application ou jeu | **Jeu** |
| Gratuit ou payant | **Gratuit** (définitif : une app gratuite ne peut plus devenir payante) |
| Catégorie | **Jeux > Puzzle** |
| Tags | Fusion / Merge, Puzzle, Casual, Relaxant (choisir parmi la liste proposée, 5 max) |
| E-mail de contact | itsmartiaservices@gmail.com |
| Téléphone | facultatif (+221 76 557 30 90 est déjà public dans la politique) |
| **Site web** | **https://fruit-village.netlify.app/** ← même site que `app-ads.txt` (indispensable, voir §6) |
| Politique de confidentialité | https://fruit-village.netlify.app/ |

Éléments graphiques : `store/graphics/icon_512.png`,
`store/graphics/feature_graphic_1024x500.png`, captures
`store/screenshots/fr/*.png` (fiche FR) et `store/screenshots/en/*.png`
(traduction EN).

---

## 2. Contenu de l'application (Règles → Contenu de l'application)

| Déclaration | Réponse |
|---|---|
| Politique de confidentialité | https://fruit-village.netlify.app/ |
| Accès à l'application | **Toutes les fonctionnalités sont disponibles sans accès spécial** (aucun identifiant) |
| Annonces | **Oui, mon application contient des annonces** |
| Classification du contenu | Questionnaire IARC, §4 |
| Public cible et contenu | §3 |
| Application d'actualités | Non |
| Applications de suivi des contacts / état de santé COVID-19 | Non |
| Sécurité des données | §5 |
| Applications gouvernementales | **Non** |
| Fonctionnalités financières | **Mon application ne propose aucune fonctionnalité financière** |
| Santé | Mon application n'a pas de fonctionnalités de santé |
| Identifiant publicitaire | **Oui** — utilisé pour : Publicité ou marketing, Analyse, Prévention de la fraude, sécurité et conformité. (La permission `com.google.android.gms.permission.AD_ID` est déclarée ; un « Non » ferait rejeter l'AAB qui la contient.) |

---

## 3. Public cible

- Tranches d'âge : cocher **13-15, 16-17, 18 et plus**. Ne **pas** cocher
  « 12 ans et moins » (pas de ciblage enfants ; cohérent avec la politique §8).
- « L'application pourrait-elle involontairement attirer les enfants ? » :
  réponse proposée **Non**, avec la justification « Jeu de réflexion pour
  adolescents et adultes ; aucun personnage sous licence pour enfants, textes
  et mécaniques (score, combos, pubs à récompense) visant 13 ans et plus. »
  ⚠️ Risque : des fruits cartoon à visages peuvent être jugés attirants pour
  les enfants. Si Google le décide, il exigera la conformité « Familles »
  (SDK publicitaires certifiés, contenu des pubs adapté). AdMob en fait partie,
  mais il faudrait alors marquer les requêtes « enfants » et revoir la
  politique. À anticiper plutôt que subir :
  - dans AdMob → Paramètres de l'application → **Classification maximale du
    contenu des annonces : « PG » (ou « G »)** ;
  - pas de vocabulaire « pour enfants » dans la fiche (déjà le cas).

---

## 4. Classification du contenu (questionnaire IARC) — réponses suggérées

Catégorie : **Jeu**. Adresse e-mail : itsmartiaservices@gmail.com.

| Question (résumé) | Réponse | Pourquoi |
|---|---|---|
| Violence (combats, sang, armes, mort de personnages) | Non | Fruits qui fusionnent ; le « coup de pilon » écrase un fruit sans aucun sang ni personnage humain |
| Peur / horreur | Non | Expressions cartoon (« peur » d'un fruit près de la ligne), rien d'effrayant |
| Sexualité, nudité | Non | — |
| Langage grossier | Non | Voix courtes en wolof/français, sans grossièreté |
| Substances contrôlées (alcool, tabac, drogues) | Non | Le bissap est une boisson non alcoolisée |
| Jeux d'argent (réel ou simulé) | Non | Pas de mise, pas de casino, pas de coffre payant ; les pièces s'obtiennent en jouant et ne s'achètent pas |
| Humour grossier | Non | — |
| Les utilisateurs peuvent-ils interagir ou échanger du contenu ? | Non | Aucun chat, aucun profil ; le partage passe par le menu Android (hors jeu) |
| L'application partage-t-elle la position de l'utilisateur ? | Non | Aucune position précise ; seule l'IP (traitée par Google) donne une zone approximative |
| Achats numériques | Non (V1) | Pas d'achats intégrés en 1.0.0 (à repasser quand les IAP V1.1 arriveront) |
| Accès Internet non restreint (navigateur) | Non | Le seul lien externe ouvre la politique de confidentialité |
| Contient des publicités | Oui (déclaré à part) | — |

Résultat attendu : **PEGI 3 / ESRB Everyone / USK 0 / IARC 3+**. Si un
classement plus élevé sort, relis la question concernée avant de valider.

---

## 5. Sécurité des données (Data safety)

### Questions générales

| Question | Réponse |
|---|---|
| L'application collecte-t-elle ou partage-t-elle des types de données requis ? | **Oui** |
| Toutes les données collectées sont-elles chiffrées en transit ? | **Oui** (AdMob et Firebase : TLS/HTTPS) |
| Moyen de demander la suppression des données ? | **Non** — pas de compte, donc pas de suppression de compte. Les données de jeu sont seulement sur l'appareil (désinstaller / « Effacer les données »). *Variante possible : « Oui » via l'e-mail de contact (politique §9) ; reste sur « Non » si tu ne veux pas t'engager à traiter des demandes.* |
| Création de compte | **Mon application ne permet pas de créer un compte** |
| Examen de sécurité indépendant | Non |
| Règles Familles | Non applicable (public 13+) |

### Types de données

Légende des finalités : **Pub** = Publicité ou marketing, **Ana** =
Analyse, **Fraude** = Prévention de la fraude, sécurité et conformité,
**Fonct.** = Fonctionnalités de l'application.

| Catégorie > type | Collectée | Partagée | Traitement éphémère | Obligatoire / facultative | Finalités | Source |
|---|---|---|---|---|---|---|
| Position > **Position approximative** | Oui | Oui | Non | Obligatoire | Pub, Ana, Fraude | AdMob (zone estimée à partir de l'adresse IP) |
| Activité dans l'application > **Interactions avec l'application** | Oui | Oui | Non | Obligatoire | Pub, Ana, Fraude, Fonct. | AdMob (taps, vues de pubs) ; Firebase (événements de jeu : `game_start`, `merge`, `ad_watched`…) |
| Infos et performances de l'application > **Diagnostics** | Oui | Oui | Non | Obligatoire | Pub, Ana, Fraude | AdMob (temps de lancement, blocages, énergie) |
| Appareil ou autres identifiants > **Appareil ou autres identifiants** | Oui | Oui | Non | Obligatoire | Pub, Ana, Fraude | Identifiant publicitaire, App set ID (AdMob), ID d'instance d'app (Firebase) |

À **ne pas** cocher (non collecté par le build 1.0.0) : informations
personnelles (nom, e-mail, téléphone), infos financières, santé, messages,
photos/vidéos, fichiers audio, contacts, agenda, historique de navigation,
**Journaux de plantage** (Crashlytics désactivé ; les plantages vus dans
Android vitals sont collectés par Google Play lui-même, hors formulaire),
position précise, recherches dans l'appli, autres contenus générés.

« Partagée » : AdMob utilise ces données pour ses propres finalités
publicitaires (Google le présente comme « collected and shared »). Firebase
Analytics agit comme prestataire : seul, il serait « collecté » sans
« partagé » ; les mêmes types étant déjà partagés via AdMob, la ligne reste
« Oui ».

### Cohérence avec la politique en ligne

| Politique (section) | Formulaire | État |
|---|---|---|
| §2 « Identifiant publicitaire, adresse IP, modèle d'appareil, langue, interactions avec les pubs » → AdMob | Identifiants, Position approx., Interactions, Diagnostics | ✅ |
| §2 « Événements de jeu anonymes » → Firebase | Interactions | ✅ |
| §2 « **Rapports de plantage** → Google (Firebase / Play Console) » | Journaux de plantage : **non déclaré** | ⚠️ À corriger : Crashlytics n'est pas dans le build 1.0.0. Remplace la ligne par « Rapports de plantage anonymes : Google Play (Android vitals) » (c'est Google Play, pas l'app, qui les collecte), ou active Crashlytics et coche alors « Journaux de plantage » (Collectée, non partagée, Ana). |
| §3 Consentement UMP (EEE, R.-U., Suisse) + « Gérer mon consentement » dans Réglages | — | ✅ (implémenté : `AdsManager.show_privacy_options`) |
| §8 pas destiné aux moins de 13 ans | Public cible 13+ | ✅ |
| §9 suppression : désinstaller / effacer les données ; demandes par e-mail | Suppression : Non | ✅ (variante « Oui » possible, voir plus haut) |
| §10 échanges chiffrés (HTTPS) | Chiffré en transit : Oui | ✅ |

---

## 6. app-ads.txt

Fichier prêt : `store/app-ads.txt` (une ligne Google, ton ID d'éditeur à
remplir). Ton dossier `Downloads/fruit-village-privacy/app-ads.txt` contient
déjà la ligne complète, avec le même éditeur que `ads_ids.cfg` : tu peux
déployer celui-là tel quel.

1. Déposer `app-ads.txt` **à la racine** du site Netlify :
   `https://fruit-village.netlify.app/app-ads.txt` doit afficher la ligne
   (texte brut, pas de page HTML).
2. Dans la fiche Play, champ **Site web** = `https://fruit-village.netlify.app/`
   (exactement ce domaine : AdMob lit `app-ads.txt` sur le site déclaré dans
   la fiche du store).
3. AdMob → Applications → Fruit Village → **Associer à une plate-forme
   d'applications** (Google Play) une fois l'app publiée, puis onglet
   app-ads.txt → « Rechercher les mises à jour ». La vérification peut prendre
   jusqu'à 24 h, et n'aboutit qu'après la mise en ligne publique de la fiche.

---

## 7. Avant le premier envoi : rappels techniques

- Package **définitif** : `com.smartiaservices.fruitvillage` (il ne pourra
  plus jamais changer une fois un AAB téléversé).
- Firebase : ajouter l'app Android `com.smartiaservices.fruitvillage` au
  projet `fruitvillage`, retélécharger `google-services.json` (le build
  release refuse un fichier qui ne déclare pas ce package).
- AdMob : créer le message RGPD (Confidentialité et messages → RGPD) pour
  Fruit Village, sinon aucun formulaire de consentement ne s'affiche en EEE.
- Version : `tools/bump_version.sh` avant chaque nouvel envoi (un version code
  déjà utilisé est refusé).
