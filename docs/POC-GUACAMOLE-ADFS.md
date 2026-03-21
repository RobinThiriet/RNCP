# POC Guacamole + AD FS

## Objectif

Mettre en place un PoC Guacamole avec :

- déploiement en `docker-compose`
- reverse proxy TLS
- authentification SAML via AD FS
- stockage PostgreSQL
- enregistrement des sessions
- extension TOTP prête à être activée

## Architecture visée

### Côté Linux / Docker

- `reverse-proxy` : publication HTTPS de Guacamole
- `guacamole` : application web
- `guacd` : daemon Guacamole
- `postgres` : base de données Guacamole
- `postgres-backup` : sauvegardes régulières

### Côté Windows

- `AD DS` : domaine Active Directory du PoC
- `AD CS` : autorité de certification interne
- `AD FS` : fournisseur d'identité SAML

## Parametres PoC actuellement retenus

- Domaine AD : `poc.local`
- NetBIOS : `POC`
- Serveur Windows : `SRV-POC.poc.local`
- AD FS : `adfs.poc.local`
- Guacamole : `guacamole.poc.local`
- Groupe AD : `GG_Guacamole_Users`

## SAML prévu

- IdP metadata URL : `https://adfs.poc.local/FederationMetadata/2007-06/FederationMetadata.xml`
- Entity ID Guacamole : `https://guacamole.poc.local/guacamole/`
- Callback URL Guacamole : `https://guacamole.poc.local/guacamole/`

## Ce qui est déjà dans le repo

- Stack Docker Guacamole : [docker-compose.yaml](/root/RNCP-repo/docker-compose.yaml)
- Documentation principale : [README.md](/root/RNCP-repo/README.md)
- Script PowerShell PoC Windows : [windows/Deploy-PoC-Guacamole.ps1](/root/RNCP-repo/windows/Deploy-PoC-Guacamole.ps1)
- Notes Windows : [windows/README.md](/root/RNCP-repo/windows/README.md)
- Documentation detaillee Windows : [docs/windows-adfs-poc.md](/root/RNCP-repo/docs/windows-adfs-poc.md)

## Points a aligner

- Vérifier si Guacamole doit être publié sur `/` ou sur `/guacamole/`
- Vérifier l'export du certificat `guacamole.poc.local` pour `Nginx`
- Définir les vrais certificats à utiliser côté reverse proxy
- Tester le mapping des claims SAML côté Guacamole
- Décider quand activer TOTP

## Ordre de mise en oeuvre

1. Déployer la stack Docker Guacamole
2. Déployer le PoC Windows AD DS / AD CS / AD FS
3. Exporter le certificat Guacamole pour le reverse proxy
4. Configurer SAML dans Guacamole
5. Tester la connexion avec un utilisateur membre de `GG_Guacamole_Users`
6. Activer les recordings sur les connexions Guacamole
7. Activer TOTP si besoin

## Intention du dépôt

Ce dépôt sert à conserver :

- la configuration cible du PoC
- les scripts d'automatisation
- les choix techniques
- les paramètres retenus
- les étapes restantes avant validation
