# Clé d'upload et Play App Signing

Fruit Village utilise **Play App Signing** : Google génère et garde la **clé de
signature de l'application** (celle que voient les téléphones). Le projet ne
détient que la **clé d'upload**, qui prouve à Google que c'est bien toi qui
envoies un AAB. Conséquence : perdre la clé d'upload est **réparable** (Google
peut la réinitialiser) ; ce n'est pas la fin de l'app.

## 1. Créer la clé (une seule fois, par toi)

```bash
tools/make_upload_keystore.sh
```

- Crée `~/fruit-village-keys/fruitvillage-upload.jks` (RSA 4096, 30 ans,
  alias `fruitvillage-upload`), **hors du projet**.
- `keytool` te demande le mot de passe : choisis-en un fort (≥ 12 caractères),
  enregistre-le dans ton gestionnaire de mots de passe **avant** de continuer.
- Exporte aussi `upload_certificate.pem` (certificat public) et
  `upload_certificate_fingerprints.txt` (empreintes SHA-1/SHA-256).
- Écrit `export_credentials.cfg` à la racine (ignoré par git) **sans** le mot
  de passe. Pour builder, au choix :
  - décommente `FV_UPLOAD_PASSWORD='…'` dans `export_credentials.cfg`
    (fichier local, jamais commité) ;
  - ou, plus prudent : `export FV_UPLOAD_PASSWORD='…'` dans le terminal juste
    avant `tools/build_release.sh`.

Rien de tout cela n'entre dans git : `.gitignore` exclut `*.jks`,
`*.keystore`, `*.p12`, `*.pem`, `export_credentials.cfg`, `ads_ids.cfg`,
`google-services.json`. Le test `test_release.gd` le vérifie.

## 2. Activer Play App Signing (Play Console)

À la création de l'app, au premier envoi d'un AAB (piste « Test interne ») :
Play Console propose « Laisser Google générer et gérer la clé de signature
de l'application » → **accepter** (option par défaut et recommandée).
Le premier AAB signé avec ta clé d'upload enregistre automatiquement cette
clé comme clé d'upload.

Ensuite : Play Console → Fruit Village → Test et publication → Intégrité de
l'application → Signature d'application : vérifie que l'empreinte SHA-1 du
**certificat de la clé d'importation** = celle de
`upload_certificate_fingerprints.txt`.

> À reporter aussi dans Firebase (Paramètres du projet → ton app Android →
> Ajouter une empreinte) : l'empreinte SHA-1 du **certificat de signature de
> l'application** (celle de Google, même page). Pas indispensable pour
> Analytics, utile si tu ajoutes d'autres services Firebase.

## 3. Sauvegarder (2 copies hors de l'ordinateur)

À sauvegarder ensemble : `fruitvillage-upload.jks`, `upload_certificate.pem`,
`upload_certificate_fingerprints.txt`, et une note avec l'alias
(`fruitvillage-upload`) et le nom du package (`com.smartiaservices.fruitvillage`).

| Copie | Où | Comment |
|---|---|---|
| 1 | Clé USB chiffrée (ou disque externe), rangée chez toi hors du sac de l'ordinateur | Copier le dossier `fruit-village-keys` |
| 2 | Cloud personnel chiffré (Google Drive / Proton Drive), dans une archive chiffrée | Archive 7-Zip AES-256 du dossier, mot de passe d'archive **différent** |

Le **mot de passe** du keystore ne voyage **jamais** avec le fichier :
gestionnaire de mots de passe (Bitwarden, 1Password…) + une copie papier
dans un lieu sûr. Vérifie les sauvegardes une fois : restaure le `.jks` sur un
autre dossier et lance `keytool -list -keystore <copie>.jks` avec le mot de
passe.

## 4. En cas de perte ou de fuite de la clé d'upload

1. **Ne recrée pas l'app** : avec Play App Signing, la clé de l'app est chez
   Google, rien n'est perdu.
2. Génère une nouvelle clé : `tools/make_upload_keystore.sh ~/fruit-village-keys-2`
   (le script refuse d'écraser une clé existante).
3. Play Console → Intégrité de l'application → Signature d'application →
   **Demander la réinitialisation de la clé d'importation** ; joins
   `upload_certificate.pem` de la **nouvelle** clé.
4. Google valide (en général quelques jours) ; en attendant, aucune mise à jour
   ne peut être envoyée.
5. Mets à jour `export_credentials.cfg` et refais les 2 sauvegardes.
6. En cas de **fuite** (clé + mot de passe exposés) : même procédure,
   immédiatement, et change le mot de passe de ton compte Google développeur.

Seul cas sans retour : perdre l'accès au **compte développeur Google** lui-même.
Active la validation en 2 étapes et des moyens de récupération sur ce compte.

## 5. Build signé

```bash
tools/build_release.sh
```

Lit `FV_UPLOAD_KEYSTORE` / `FV_UPLOAD_ALIAS` / `FV_UPLOAD_PASSWORD`
(environnement, sinon `export_credentials.cfg`) et les passe à Godot via
`GODOT_ANDROID_KEYSTORE_RELEASE_*` : rien n'est écrit dans
`export_presets.cfg` (versionné). Godot range ses propres identifiants
d'export dans `.godot/export_credentials.cfg`, lui aussi ignoré par git :
ne saisis pas la clé dans l'éditeur si tu peux l'éviter.
