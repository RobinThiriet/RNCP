# PoC Guacamole avec authentification SSO SAML via ADFS

## 1. Objectif du PoC

L'objectif de ce PoC est de mettre en place un bastion `Guacamole` accessible via un reverse proxy `Nginx`, avec une authentification centralisee en `SSO SAML` grace a `ADFS`.

Ce PoC permet de valider :

- l'integration de `Guacamole` derriere un reverse proxy
- l'utilisation d'`Active Directory` comme annuaire
- l'authentification `SSO SAML` via `ADFS`
- l'usage de `AD CS` pour generer les certificats necessaires
- la restriction d'acces a `Guacamole` selon des groupes `Active Directory`

## 2. Architecture du PoC

### Composants utilises

#### Serveur Windows Server 2022

Le serveur Windows heberge, pour les besoins du PoC, plusieurs roles sur la meme machine :

- `AD DS` : Active Directory Domain Services
- `AD CS` : Active Directory Certificate Services
- `AD FS` : Active Directory Federation Services

#### Serveur Linux / Bastion

Le serveur Linux heberge :

- `Apache Guacamole`
- `Nginx` en reverse proxy devant `Guacamole`

## 3. Choix d'architecture

Dans ce PoC, plusieurs roles ont ete regroupes sur le meme serveur Windows afin de simplifier la mise en oeuvre :

- controleur de domaine
- autorite de certification
- fournisseur d'identite `ADFS`

Ce choix est acceptable dans le cadre d'un `PoC`, mais il ne constitue pas une architecture cible de production.
En environnement reel, ces roles devraient etre separes pour des raisons de securite, de disponibilite et de cloisonnement.

## 4. Nommage retenu

### Domaine Active Directory

- domaine `AD` : `poc.local`

### Nom du serveur Windows

- serveur : `SRV-POC.poc.local`

### Nom du service ADFS

- `ADFS` : `adfs.poc.local`

### Nom du portail Guacamole

- `Guacamole` : `guacamole.poc.local`

## 5. Role de chaque composant

### Active Directory Domain Services

`AD DS` est utilise pour :

- centraliser les comptes utilisateurs
- centraliser les groupes de securite
- fournir la base d'identite utilisee par `ADFS`

### Active Directory Federation Services

`AD FS` est utilise pour :

- fournir l'authentification `SSO`
- emettre des assertions `SAML`
- authentifier les utilisateurs `AD` avant leur acces a `Guacamole`

### Active Directory Certificate Services

`AD CS` est utilise pour :

- creer une autorite de certification interne
- delivrer un certificat pour `ADFS`
- delivrer un certificat pour `Guacamole` / `Nginx` si necessaire

### Nginx

`Nginx` est utilise comme :

- reverse proxy
- point d'entree `HTTPS` vers `Guacamole`

### Guacamole

`Guacamole` joue le role de :

- bastion d'acces
- portail web d'administration
- point d'acces centralise vers les ressources distantes

## 6. Comptes et groupes mis en place

### Groupe de securite

- `GG_Guacamole_Users`

Ce groupe sert a definir les utilisateurs autorises a acceder a `Guacamole` via `ADFS`.

### Utilisateurs de test

- `Robin` : membre de `GG_Guacamole_Users`
- `Thomas` : non membre de `GG_Guacamole_Users`

Cette distinction permet de tester :

- un acces autorise
- un acces refuse

### Compte de service

- `svc_adfs`

Ce compte de service est utilise pour executer le service `ADFS`.
Il s'agit d'un compte technique dedie, distinct d'un compte administrateur classique.

## 7. Etapes realisees

### Etape 1 - Mise en place d'Active Directory

Installation et configuration de :

- `AD DS`
- domaine : `poc.local`

Creation des objets necessaires :

- `OU` : `Entreprise`
- groupe : `GG_Guacamole_Users`
- utilisateurs de test
- compte de service `ADFS`

### Etape 2 - Mise en place du DNS

Creation des enregistrements `DNS` necessaires afin de dissocier :

- le nom du serveur
- le nom des services

Exemples :

- `adfs.poc.local` -> IP du serveur Windows
- `guacamole.poc.local` -> IP du reverse proxy `Nginx`

Cette approche permet de conserver des noms stables, meme si l'adressage IP change ulterieurement.

### Etape 3 - Mise en place de AD CS

Installation de :

- `AD CS`
- role `Enterprise Root CA`

Cette autorite de certification interne a permis d'emettre les certificats necessaires au PoC.

### Etape 4 - Generation du certificat ADFS

Creation d'un certificat serveur pour :

- `adfs.poc.local`

Ce certificat a ete genere via `AD CS` et stocke dans :

- `Certificats (ordinateur local)`
- `Personnel`
- `Certificats`

Ce certificat est utilise comme certificat `SSL` pour le service `ADFS`.

### Etape 5 - Installation et configuration de ADFS

Installation du role :

- `Active Directory Federation Services`

Configuration du service de federation avec :

- nom du service `FS` : `adfs.poc.local`
- nom complet du service `FS` : `ADFS POC`
- certificat `SSL` : certificat delivre a `adfs.poc.local`
- compte de service : `POC\\svc_adfs`

Une fois le role installe, la bonne configuration a ete validee par l'acces au fichier de metadonnees :

- `https://adfs.poc.local/FederationMetadata/2007-06/FederationMetadata.xml`

Le chargement correct de ce `XML` confirme que le service `ADFS` est operationnel.

### Etape 6 - Reverse proxy Nginx

`Guacamole` est publie derriere un reverse proxy `Nginx` afin de :

- centraliser l'exposition `HTTPS`
- securiser l'acces au portail
- presenter une `URL` propre a l'utilisateur

URL cible :

- `https://guacamole.poc.local/guacamole/`

### Etape 7 - Preparation du SSO SAML avec Guacamole

Le PoC prevoit l'integration de `Guacamole` avec `ADFS` via `SAML`.

Les elements utilises pour cette configuration sont :

#### Cote IdP

- `IdP` : `ADFS`
- `Metadata URL` : `https://adfs.poc.local/FederationMetadata/2007-06/FederationMetadata.xml`

#### Cote SP

- `Service Provider` : `Guacamole`
- `Entity ID` : `https://guacamole.poc.local/guacamole/`
- `Callback / ACS URL` : `https://guacamole.poc.local/guacamole/`

## 8. Logique d'authentification

Le scenario d'authentification prevu est le suivant :

1. l'utilisateur ouvre `https://guacamole.poc.local/guacamole/`
2. `Guacamole` redirige l'utilisateur vers `ADFS`
3. `ADFS` authentifie l'utilisateur a partir d'`Active Directory`
4. `ADFS` renvoie une assertion `SAML`
5. `Guacamole` autorise ou refuse l'acces selon la configuration

## 9. Controle d'acces

Le controle d'acces repose sur les groupes `Active Directory`.

### Cas autorise

- `Robin` appartient au groupe `GG_Guacamole_Users`
- `Robin` doit pouvoir s'authentifier et acceder a `Guacamole`

### Cas refuse

- `Thomas` n'appartient pas au groupe `GG_Guacamole_Users`
- `Thomas` doit etre refuse

Cela permet de demontrer que l'authentification `SSO` peut etre combinee avec une logique d'autorisation par groupe.

## 10. Points techniques importants retenus

### Pourquoi utiliser `adfs.poc.local`

`adfs.poc.local` n'est pas un nouveau serveur, mais le nom `DNS` du service `ADFS`.

Cela permet de distinguer :

- le nom de la machine : `SRV-POC.poc.local`
- le nom du service : `adfs.poc.local`

C'est ce nom de service qui est utilise dans :

- le certificat `SSL`
- la configuration `ADFS`
- les metadonnees de federation
- les echanges `SAML`

### Pourquoi ne pas utiliser `127.0.0.1`

Le nom `adfs.poc.local` doit pointer vers l'IP reelle du serveur, et non vers `127.0.0.1`.

Sinon :

- depuis un autre poste, `127.0.0.1` pointerait vers lui-meme
- `Guacamole` ou un navigateur client ne pourrait pas joindre le vrai service `ADFS`

## 11. Etat d'avancement actuel

### Realise

- `Active Directory` installe
- `DNS` operationnel
- `AD CS` installe
- certificat `adfs.poc.local` genere
- `AD FS` installe et fonctionnel
- metadonnees `AD FS` accessibles en `HTTPS`

### En cours / a finaliser

- configuration `SAML` cote `Guacamole`
- creation de la `Relying Party Trust` dans `ADFS`
- configuration des claims
- test complet de connexion `SSO` avec `Robin`
- test de refus avec `Thomas`

## 12. Limites du PoC

Ce PoC presente plusieurs limites assumees :

- plusieurs roles critiques sont installes sur la meme machine
- l'architecture n'est pas hautement disponible
- la `PKI` est simplifiee
- la securite est adaptee a une maquette et non a une production
- certains parametres `SAML` pourront necessiter des ajustements en fonction du comportement reel de `Guacamole`

## 13. Evolutions possibles

A terme, cette maquette pourrait evoluer vers :

- separation des roles `AD` / `AD CS` / `ADFS`
- ajout d'une authentification multifacteur
- meilleure journalisation et centralisation des logs
- segmentation reseau plus poussee
- haute disponibilite
- integration plus fine des groupes `AD` dans les droits `Guacamole`
- supervision du bastion et des acces

## 14. Conclusion

Ce PoC permet de demontrer la faisabilite d'une integration entre :

- un bastion `Guacamole`
- un reverse proxy `Nginx`
- un annuaire `Active Directory`
- un fournisseur d'identite `ADFS`
- une `PKI` interne `AD CS`

L'objectif est de centraliser les acces d'administration derriere `Guacamole` tout en apportant une authentification `SSO SAML` reposant sur l'infrastructure Microsoft interne.
