# Fruit Village sur iOS — TestFlight puis App Store

Pas besoin de Mac : un runner GitHub **macOS 26 / Xcode 26** fait l'export
Godot, la compilation, la signature et l'envoi sur TestFlight
(`.github/workflows/ios.yml` → `tools/ios/build_ios.sh`). Le dépôt est
public : les minutes macOS de GitHub Actions sont gratuites.

**Rien n'est publié sans toi** : le workflow s'arrête à TestFlight. La
soumission à la revue Apple et la mise en vente se font à la main dans App
Store Connect.

Exigences vérifiées le 26/10/2026 :
- builds envoyés depuis le 28/04/2026 : **Xcode 26 / SDK iOS 26** ([Apple](https://developer.apple.com/news/upcoming-requirements/?id=04282026a)) ;
- Google Mobile Ads iOS : iOS 13 minimum ; Godot 4.7 : **iOS 15** minimum (retenu) ;
- ATT + SKAdNetwork pour l'identifiant publicitaire ([Google](https://developers.google.com/admob/ios/privacy/strategies)).

## Ce que fait déjà le projet

| Élément | Où |
|---|---|
| Bundle ID `com.smartiaservices.fruitvillage`, iPhone + iPad, iOS 15+, portrait | preset « iOS Release » (`export_presets.cfg`) |
| iPhone plein écran : décor jusqu'aux bords, interface et panier dans la zone sûre (Dynamic Island, barre d'accueil) ; iPad : cadre 9:16 centré | `scripts/platform/screen_fit.gd` |
| App ID AdMob iOS réel en release, test Google en debug | `addons/_fv_release`, `scripts/ads/ad_ids.gd` |
| ATT (`NSUserTrackingUsageDescription`), chiffrement exempté, plein écran iPad | preset (Info.plist) ; contrôlé par `tools/ios/check_plist.py` |
| SKAdNetwork Google | plugin AdMob |
| Manifeste de confidentialité (`PrivacyInfo.xcprivacy`) | preset, section privacy (cohérent avec §5) |
| `NSPrivacyTracking` **false**, aucun `NSPrivacyTrackingDomains` : à true sans domaine, Apple invalide le binaire (ITMS-91064, build 22) ; des domaines seraient bloqués par iOS sans accord ATT (plus de pubs). Le SDK Google déclare son propre suivi | preset (`privacy/tracking_*`), contrôlé par `tools/ios/check_plist.py` |
| **Firebase iOS (Analytics + push FCM)** avec le SDK **officiel signé par Google** (12.16.0, empreinte épinglée), lié en statique : le SDK du plugin godotx, non signé, était refusé (ITMS-91065). Signature Google, manifestes de confidentialité et droit push vérifiés à chaque build | `tools/ios/firebase_ios.py`, `build_ios.sh` |
| Icône 1024 opaque | `assets/ui/icon_ios_1024.png` (`tools/store/make_icon.py`) |
| Fiche : textes FR/EN, captures iPhone 6,9" et iPad 13" | `store/ios/` |

## Ce que tu dois faire, dans l'ordre

### 1. Compte Apple Developer (individuel)

1. https://developer.apple.com/programs/enroll/ avec ton identifiant Apple
   (validation en 2 étapes obligatoire) → 99 $/an. Validation : de quelques
   heures à 2 jours.
2. Le **nom du vendeur** affiché sous le jeu sera **ton nom personnel**
   (compte individuel). Passer plus tard en compte Organisation (Smart IA
   Services, D-U-N-S) reste possible : Apple permet de migrer le compte.
3. Note ton **Team ID** : developer.apple.com → Account → Membership details
   (10 caractères).
4. **Contrats** : App Store Connect → Business → accepte le contrat
   « Paid Apps » seulement si tu ajoutes des achats intégrés (inutile en 1.0,
   pubs seules) ; renseigne quand même les informations fiscales (W-8BEN :
   tu n'es pas résident américain).

### 2. Identifiant et fiche de l'app

1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers
   → **+** → App IDs → App → description « Fruit Village », Bundle ID
   **explicite** `com.smartiaservices.fruitvillage`. Aucune capacité
   particulière à cocher.
2. App Store Connect → Apps → **+** Nouvelle app : plateforme iOS, nom
   « Fruit Village : Fusion Fruits », langue principale **Français (France)**,
   bundle ID ci-dessus, SKU `fruitvillage-ios`, accès complet.

### 3. Clé API App Store Connect (signature et envoi par la CI)

App Store Connect → Utilisateurs et accès → **Intégrations** → Clés d'API
App Store Connect → **Clés d'équipe** → **+** :
- nom « GitHub Actions Fruit Village », accès **Admin** (nécessaire pour que
  Xcode crée lui-même le certificat de distribution et le profil) ;
- télécharge `AuthKey_XXXXXXXXXX.p8` (**une seule fois possible**) et range-le
  comme la clé d'upload Android (2 copies hors de l'ordinateur) ;
- note le **Key ID** et l'**Issuer ID** (en haut de la page).

### 4. AdMob et Firebase côté iOS

1. **AdMob** → Applications → Ajouter une application → iOS → « Fruit
   Village » (pas encore publiée : oui, ajouter sans fiche). Crée 2 blocs :
   **Récompensé** et **Interstitiel**. Ajoute la section `[ios]` à ton
   `ads_ids.cfg` local (modèle : `ads_ids.example.cfg`).
2. **AdMob → Confidentialité et messages** :
   - message **RGPD** pour l'app iOS (comme pour Android) ;
   - message **explicatif IDFA** pour l'app iOS : c'est lui qui affiche
     l'écran de suivi d'Apple (ATT) après le consentement. Sans lui, pas
     d'identifiant publicitaire sur iOS (pubs moins bien payées) et Apple peut
     refuser l'app, puisque le jeu déclare suivre l'utilisateur.
3. **Firebase** → projet `fruitvillage` → Ajouter une application → iOS →
   bundle ID `com.smartiaservices.fruitvillage` → télécharge
   `GoogleService-Info.plist` (ignoré par git ; il ne sert que de secret CI
   `GOOGLE_SERVICE_INFO_PLIST_B64`).
4. **Push (FCM)** :
   - developer.apple.com → Certificates, IDs & Profiles → Identifiers →
     `com.smartiaservices.fruitvillage` → coche **Push Notifications** →
     Save ;
   - Keys → **+** → nom « FCM Fruit Village » → coche **Apple Push
     Notifications service (APNs)** → télécharge le `.p8` (une seule fois),
     note le **Key ID** ;
   - console Firebase → Paramètres du projet → Cloud Messaging → app iOS →
     **Clé d'authentification APNs** → Importer le `.p8` + Key ID + Team ID ;
   - envoi d'un push : Firebase → Messaging → Nouvelle campagne →
     Notifications → cible l'app iOS et/ou Android.

### 5. Secrets GitHub (dépôt PSDiop95/Fruit-Village)

GitHub → Settings → Secrets and variables → Actions → New repository secret,
ou dans Git Bash à la racine du projet :

```bash
gh secret set APPLE_TEAM_ID --body "TON_TEAM_ID"
```

```bash
gh secret set ASC_KEY_ID --body "TON_KEY_ID"
```

```bash
gh secret set ASC_ISSUER_ID --body "TON_ISSUER_ID"
```

```bash
gh secret set ASC_KEY_P8_B64 --body "$(base64 -w0 ~/chemin/AuthKey_XXXXXXXXXX.p8)"
```

```bash
gh secret set ADS_IDS_CFG < ads_ids.cfg
```

```bash
gh secret set GOOGLE_SERVICE_INFO_PLIST_B64 --body "$(base64 -w0 GoogleService-Info.plist)"
```

Les secrets ne sont jamais visibles dans les journaux, ni accessibles aux
pull requests venant de forks (dépôt public). Le workflow les efface du
runner en fin de job.

### 6. Premier envoi TestFlight

GitHub → Actions → **iOS** → Run workflow → branche `main` → coche
**upload** → Run. Durée ≈ 10 min une fois la machine obtenue. GitHub
prévient que les runners macOS arm64 sont saturés par moments : l'attente
peut durer, et un job « not acquired by Runner » n'est pas un échec du
build. Relance-le (Re-run jobs).
Le job :
1. lance les tests GUT (arrêt au premier échec) ;
2. exporte le projet Xcode en release (App ID et blocs AdMob iOS réels) ;
3. contrôle l'Info.plist et le `.pck` (`check_plist.py`) ;
4. archive avec une signature ad hoc (aucun iPhone enregistré requis) et
   vérifie que chaque framework embarqué est signé ; numéro de build =
   numéro d'exécution du workflow (toujours croissant) ;
5. signe en distribution App Store (certificat et profil créés dans le cloud
   via la clé API) et envoie sur App Store Connect.

Premier envoi réussi le 26/10/2026 : build 11, version 1.0.0.

Apple traite le build (15-30 min, e-mail), puis il apparaît dans
**TestFlight**. Réponds à la question de conformité du chiffrement s'il la
pose : « aucun chiffrement autre que celui d'Apple / HTTPS » (déjà déclaré
par `ITSAppUsesNonExemptEncryption = false`).

### 7. Tests TestFlight

- **Testeurs internes** (jusqu'à 100 membres de ton équipe App Store
  Connect) : disponible tout de suite, sans revue.
- **Testeurs externes** (jusqu'à 10 000, par e-mail ou **lien public** à
  partager sur WhatsApp) : première version soumise à une revue bêta rapide
  (souvent < 24 h).
- Apple n'impose **pas** de durée de test (pas d'équivalent aux 14 jours de
  Google). Recommandé : 1 semaine avec les testeurs Android qui ont un iPhone.
- Dérouler `docs/QA_CHECKLIST.md` sur un iPhone **et** un iPad, en plus :
  écran ATT après le consentement, rien sous l'encoche, bandes noires
  latérales sur iPad, coupure par un appel FaceTime.

### 8. Fiche App Store (version 1.0)

| Champ | Valeur |
|---|---|
| Nom | `store/ios/fr/name.txt` (EN : `store/ios/en/name.txt`) |
| Sous-titre | `store/ios/*/subtitle.txt` |
| Texte promotionnel | `store/ios/*/promotional_text.txt` |
| Description | `store/ios/*/description.txt` |
| Mots-clés | `store/ios/*/keywords.txt` (≤ 100 caractères, déjà ajustés) |
| **Captures iPhone 6,5" (obligatoire)** | `store/ios/screenshots/iphone_6_5/{fr,en}/` (1284×2778) |
| Captures « iPhone avec Dynamic Island (grand écran) » 6,9" | `store/ios/screenshots/iphone_6_9/{fr,en}/` (1320×2868) |
| Captures « iPhone avec Dynamic Island (écran moyen) » 6,3" | `store/ios/screenshots/iphone_6_3/{fr,en}/` (1206×2622) |
| ⚠️ Jamais les captures Google Play | `store/screenshots/` (1080×1920) : refusées par Apple (ratio 9:16) |
| Captures iPad 13" | `store/ios/screenshots/ipad_13/{fr,en}/` (2064×2752) |
| Vidéo d'aperçu (facultatif) | `store/video/fruit_village_promo_20s_*.mp4` : à réencoder en 886×1920 pour l'iPhone si tu l'ajoutes |
| URL d'assistance | https://fruit-village.netlify.app/ |
| URL de confidentialité | https://fruit-village.netlify.app/ |
| Catégorie | Jeux → **Puzzle** (secondaire : Jeux → Casual) |
| Copyright | 2026 Smart IA Services |
| Prix | Gratuit |
| Disponibilité | Tous les pays (ou tous sauf ceux où tu ne veux pas être) |

### 9. Confidentialité de l'app (étiquette App Store)

App Store Connect → Confidentialité de l'app → **Oui, nous collectons des
données**. Cohérent avec le manifeste de confidentialité du build et avec ta
politique en ligne :

| Type de données | Usage | Associé à l'identité ? | Utilisé pour le suivi ? |
|---|---|---|---|
| Localisation → **Localisation approximative** | Publicité tierce, Analyse | Non | **Oui** |
| Identifiants → **Identifiant de l'appareil** (IDFA) | Publicité tierce, Analyse | Non | **Oui** |
| Données d'utilisation → **Interactions avec le produit** | Publicité tierce, Analyse | Non | **Oui** |
| Données d'utilisation → **Données publicitaires** | Publicité tierce | Non | **Oui** |
| Diagnostics → **Données de performances** | Analyse | Non | Non |
| Diagnostics → **Autres données de diagnostic** | Analyse | Non | Non |
| Identifiants → **Identifiant de l'appareil** (jeton push FCM) | Fonctionnalités de l'app | Non | Non |

« Suivi » = oui, à cause de la publicité AdMob avec IDFA : c'est ce qui rend
l'écran ATT obligatoire. Rien d'autre : pas de compte, pas de nom, pas
d'e-mail, pas de contacts, pas de position précise, pas d'achats.

### 10. Classification par âge (questionnaire Apple 2025)

Réponses suggérées, toutes à **Aucun / Non**, sauf :
- **Publicités** : Oui (l'app contient des pubs) ;
- Contenu généré par les utilisateurs, messagerie, navigateur web non
  restreint, jeux d'argent, achats intégrés : Non.
Résultat attendu : **4+**. Vérifie que la classification maximale des pubs
dans AdMob (app iOS) est réglée sur **G** ou **PG**, cohérente avec 4+.

### 11. Soumission à la revue

Une fois le build TestFlight validé : version 1.0 → Build → choisir le build
→ **Ajouter pour vérification** → Soumettre. Notes pour l'examinateur
(à copier) :

> Fruit Village est un jeu de fusion de fruits, sans compte. Les publicités
> (AdMob) sont facultatives (vidéos à récompense) ou affichées entre deux
> parties, jamais avant la 5e partie. Le consentement RGPD (UMP) puis l'écran
> de suivi Apple (ATT) s'affichent au premier lancement selon la région.
> « Réglages → Gérer mon consentement » permet de changer d'avis.

Revue Apple : en général 24-48 h. Publication : **manuelle** (choisis
« Publier manuellement cette version » pour garder la main).

## Points d'attention

- **`UIRequiresFullScreen`** : nécessaire pour un jeu en portrait seul sur
  iPad. Apple l'a déclaré obsolète dans iPadOS 26 (fenêtres
  redimensionnables) ; s'il est refusé à l'envoi, le cadrage de `ScreenFit`
  suit déjà la taille de la fenêtre (bandes recalculées par Godot).
- **Bandes noires** sur iPad (et en haut et en bas sur les iPhone à encoche) :
  Godot 4 ne permet pas de les décorer. Une vraie mise en page iPad
  demanderait de rendre l'interface adaptative (ancres) : à prévoir si
  l'iPad pèse dans les ventes.
- **Notifications** : pas de plugin iOS non plus (même état qu'Android).
- Le build « contrôle » de chaque pull request compile **sans signature** et
  avec les identifiants de test : il ne prouve pas que la signature
  fonctionne. Seul le premier lancement avec upload le prouve.
