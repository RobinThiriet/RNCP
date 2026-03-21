# Windows PoC

Ce dossier contient un script PowerShell de lab pour automatiser un PoC Active Directory, AD CS et AD FS autour de Guacamole et du SAML.

- Script : `Deploy-PoC-Guacamole.ps1`
- Exécution : PowerShell en administrateur
- Déroulé : 4 phases avec redémarrages intermédiaires via `RunOnce`
- Domaine : `poc.local`
- Service ADFS : `adfs.poc.local`
- Portail Guacamole : `guacamole.poc.local`
- Groupe d'accès : `GG_Guacamole_Users`

La documentation détaillée associée est disponible dans [docs/windows-adfs-poc.md](/root/RNCP-repo/docs/windows-adfs-poc.md).
