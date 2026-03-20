# Guacamole 1.6.0 avec reverse proxy TLS

Cette stack déploie Apache Guacamole en architecture séparée :

- `reverse-proxy` : terminaison TLS et proxy WebSocket
- `guacamole` : application web, non exposée directement
- `guacd` : daemon Guacamole, réseau interne uniquement
- `postgres` : backend persistant pour auth et configuration
- `postgres-backup` : sauvegardes régulières par `pg_dump`

Les images officielles Guacamole et `guacd` sont alignées en `1.6.0`.

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
cp fullchain.pem proxy/certs/fullchain.pem
cp privkey.pem proxy/certs/privkey.pem
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

- URL : `https://<host>/`
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
SAML_ENTITY_ID=https://guacamole.example.com/
SAML_CALLBACK_URL=https://guacamole.example.com/
```

Puis placez le fichier dans :

- `./saml/idp-metadata.xml`

`EXTENSION_PRIORITY=saml, postgresql` favorise le SSO dès l'arrivée sur la page d'authentification.

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
