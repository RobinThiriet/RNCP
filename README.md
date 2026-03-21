# Guacamole 1.6.0 avec reverse proxy TLS, SSO SAML ADFS et recordings

Cette stack déploie Apache Guacamole en architecture séparée :

- `reverse-proxy` : terminaison TLS et proxy WebSocket
- `guacamole` : application web, non exposée directement
- `guacd` : daemon Guacamole, réseau interne uniquement
- `postgres` : backend persistant pour auth et configuration
- `postgres-backup` : sauvegardes régulières par `pg_dump`

Les images officielles Guacamole et `guacd` sont alignées en `1.6.0`.

## Sommaire

- [Vue d'ensemble](#vue-densemble)
- [Principe de sécurité](#principe-de-securite)
- [Structure](#structure)
- [Démarrage](#demarrage)
- [Extensions officielles préparées](#extensions-officielles-preparees)
- [SAML](#saml)
- [PoC Windows / ADFS](#poc-windows--adfs)
- [TOTP](#totp)
- [Recording](#recording)
- [Sauvegardes PostgreSQL](#sauvegardes-postgresql)
- [Vérifications utiles](#verifications-utiles)
- [Références officielles](#references-officielles)

## Vue d'ensemble

Le dépôt contient la partie Linux du PoC :

- reverse proxy `Nginx`
- `Apache Guacamole`
- backend `PostgreSQL`
- intégration `SAML` prête pour un fournisseur d'identité `ADFS`
- recordings persistants avec lecture depuis l'historique Guacamole

La documentation détaillée de la partie Windows Server 2022, AD DS, AD CS et ADFS est disponible dans [docs/windows-adfs-poc.md](/root/RNCP-repo/docs/windows-adfs-poc.md).

## Principe de sécurité

- Ne pas exposer `guacamole`, `guacd` ni `postgres` sur Internet
- Faire passer l'accès uniquement par le reverse proxy TLS
- Conserver le support WebSocket côté proxy
- Faire confiance aux en-têtes `X-Forwarded-*` uniquement depuis l'IP interne du proxy Docker

## Structure

- `docker-compose.yaml` : stack principale
- `proxy/conf.d/guacamole.conf` : configuration Nginx TLS et WebSocket
- `proxy/certs/` : certificats TLS à fournir
- `extensions/available/` : JARs officiels téléchargés et conservés localement
- `extensions/enabled/` : JARs effectivement montés dans Guacamole
- `downloads/` : archives officielles téléchargées et leurs checksums
- `recordings/` : stockage des enregistrements de session
- `backups/` : sauvegardes PostgreSQL
- `saml/` : metadata SAML locale si nécessaire
- `scripts/` : scripts d'exploitation
- `windows/` : automatisation PowerShell pour un PoC AD / AD CS / AD FS
- `docs/` : notes de cadrage et trace de l'objectif du PoC

## Démarrage

1. Vérifier les variables dans `.env`
2. Déposer vos certificats TLS :

```bash
cp guacamole.poc.local.crt proxy/certs/guacamole.poc.local.crt
cp guacamole.poc.local.key proxy/certs/guacamole.poc.local.key
```

3. Télécharger les extensions officielles :

```bash
chmod +x scripts/*.sh
./scripts/download-extensions.sh
```

4. Activer les extensions voulues :

```bash
./scripts/enable-extension.sh guacamole-auth-sso-saml-1.6.0.jar
./scripts/enable-extension.sh guacamole-history-recording-storage-1.6.0.jar
```

Pour préparer TOTP sans l'activer tout de suite, laissez simplement son JAR dans `extensions/available/`.

5. Démarrer la stack :

```bash
docker compose up -d
```

Accès :

- URL : `https://guacamole.poc.local/guacamole/`
- compte local initial : `guacadmin` / `guacadmin`

## Extensions officielles préparées

Le script de téléchargement récupère les paquets officiels Apache Guacamole `1.6.0` suivants :

- `guacamole-auth-totp-1.6.0.tar.gz`
- `guacamole-auth-sso-1.6.0.tar.gz`
- `guacamole-history-recording-storage-1.6.0.tar.gz`

Il vérifie aussi les fichiers `.sha256` publiés par Apache avant extraction.

## SAML

Renseignez au minimum dans `.env` :

- `SAML_IDP_METADATA_URL`
- `SAML_ENTITY_ID`
- `SAML_CALLBACK_URL`

Exemple avec metadata locale :

```env
SAML_IDP_METADATA_URL=file:///saml/idp-metadata.xml
SAML_ENTITY_ID=https://guacamole.poc.local/guacamole/
SAML_CALLBACK_URL=https://guacamole.poc.local/guacamole/
```

Puis placez le fichier dans :

- `./saml/idp-metadata.xml`

`EXTENSION_PRIORITY=saml, postgresql` favorise le SSO dès l'arrivée sur la page d'authentification.

Exemple PoC avec `ADFS` :

```env
SAML_IDP_METADATA_URL=https://adfs.poc.local/FederationMetadata/2007-06/FederationMetadata.xml
SAML_ENTITY_ID=https://guacamole.poc.local/guacamole/
SAML_CALLBACK_URL=https://guacamole.poc.local/guacamole/
SAML_GROUP_ATTRIBUTE=groups
```

Selon les claims réellement émis par `ADFS`, l'attribut de groupe pourra nécessiter un ajustement.
Pour le PoC, `SAML_STRICT=false` et `SAML_DEBUG=true` facilitent l'intégration initiale. En cible, repassez `SAML_STRICT=true`.

## PoC Windows / ADFS

Le scénario PoC documenté repose sur les éléments suivants :

- domaine Active Directory : `poc.local`
- serveur Windows : `SRV-POC.poc.local`
- service ADFS : `adfs.poc.local`
- portail Guacamole : `guacamole.poc.local`
- groupe d'autorisation : `GG_Guacamole_Users`

La partie Windows couvre :

- `AD DS`
- `AD CS`
- `AD FS`
- comptes et groupes de test
- logique d'autorisation par groupe pour l'accès Guacamole

Documentation détaillée :

- [docs/windows-adfs-poc.md](/root/RNCP-repo/docs/windows-adfs-poc.md)
- [windows/README.md](/root/RNCP-repo/windows/README.md)
- [windows/Deploy-PoC-Guacamole.ps1](/root/RNCP-repo/windows/Deploy-PoC-Guacamole.ps1)

Configuration ADFS attendue côté relying party :

- identifier / entity ID : `https://guacamole.poc.local/guacamole/`
- reply URL / ACS : `https://guacamole.poc.local/guacamole/`
- restriction d'accès sur le groupe `GG_Guacamole_Users`
- émission d'un `NameID` basé sur l'identité AD exposée par `ADFS`

## TOTP

TOTP est téléchargé et conservé localement, mais n'est pas activé par défaut.

Pour l'activer plus tard :

```bash
./scripts/enable-extension.sh guacamole-auth-totp-1.6.0.jar
docker compose restart guacamole
```

Pour le désactiver :

```bash
./scripts/disable-extension.sh guacamole-auth-totp-1.6.0.jar
docker compose restart guacamole
```

## Recording

L'extension de lecture des enregistrements est prévue pour être activée via :

```bash
./scripts/enable-extension.sh guacamole-history-recording-storage-1.6.0.jar
```

Le stockage des enregistrements est dédié :

- hôte : `./recordings`
- conteneurs : `/recordings`

Pour qu'une connexion soit réellement enregistrée, configurez aussi la connexion Guacamole avec :

- `recording-path` : `${HISTORY_PATH}/${HISTORY_UUID}`
- `create-recording-path` : `true`
- `recording-name` : `recording`

Paramètres recommandés pour le PoC :

- `recording-path` : `/recordings/${HISTORY_UUID}`
- `create-recording-path` : `true`
- `recording-name` : `recording`
- `recording-include-keys` : `true`
- `recording-exclude-mouse` : `false`
- `recording-exclude-output` : `false`

Pour `SSH`, vous pouvez aussi ajouter :

- `typescript-path` : `/recordings/${HISTORY_UUID}`
- `create-typescript-path` : `true`
- `typescript-name` : `typescript`

## Sauvegardes PostgreSQL

Le service `postgres-backup` effectue un `pg_dump -Fc` régulier dans `./backups`.

Variables utiles dans `.env` :

- `BACKUP_INTERVAL_SECONDS=86400`
- `BACKUP_RETENTION_DAYS=14`

## Vérifications utiles

Valider la stack :

```bash
docker compose config
```

Préparer l'initialisation de base si nécessaire :

```bash
docker compose run --rm guac-init
```

Suivre les logs :

```bash
docker compose logs -f reverse-proxy guacamole postgres
```

## Références officielles

- Docker : https://guacamole.apache.org/doc/gug/guacamole-docker.html
- Reverse proxy / SSL termination : https://guacamole.apache.org/doc/gug/reverse-proxy.html
- SAML : https://guacamole.apache.org/doc/gug/saml-auth.html
- TOTP : https://guacamole.apache.org/doc/gug/totp-auth.html
- Recording playback : https://guacamole.apache.org/doc/gug/recording-playback.html
- Release 1.6.0 : https://guacamole.apache.org/releases/1.6.0/
