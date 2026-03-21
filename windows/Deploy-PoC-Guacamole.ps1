#requires -RunAsAdministrator

param(
    [ValidateSet("1","2","3","4")]
    [string]$Phase = "1"
)

$ErrorActionPreference = "Stop"

# =========================
# Variables PoC
# =========================
$Config = @{
    DomainName              = "poc.local"
    NetbiosName             = "POC"
    ServerName              = "SRV-POC"

    AdfsFqdn                = "adfs.poc.local"
    GuacFqdn                = "guacamole.poc.local"

    CACommonName            = "POC-ROOT-CA"
    AdfsDisplayName         = "POC ADFS"

    OUName                  = "Entreprise"
    GuacGroupName           = "GG_Guacamole_Users"

    RobinSam                = "robin"
    RobinUPN                = "robin@poc.local"

    ThomasSam               = "thomas"
    ThomasUPN               = "thomas@poc.local"

    AdfsSvcSam              = "svc_adfs"
    AdfsSvcUPN              = "svc_adfs@poc.local"

    DefaultPasswordPlain    = "P@ssw0rd123!"
    DSRMPasswordPlain       = "P@ssw0rd123!"

    GuacRelyingPartyName    = "Guacamole"
    GuacEntityId            = "https://guacamole.poc.local/guacamole/"
    GuacCallbackUrl         = "https://guacamole.poc.local/guacamole/"

    WorkDir                 = "C:\PoC"
    ExportDir               = "C:\PoC\Export"
    GuacPfxPasswordPlain    = "P@ssw0rd123!"
}

# =========================
# Helpers
# =========================
function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==== $Message ====" -ForegroundColor Cyan
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Register-NextPhase {
    param([string]$NextPhase)

    $scriptPath = $MyInvocation.MyCommand.Path
    if (-not $scriptPath) {
        throw "Impossible de déterminer le chemin du script en cours."
    }

    $cmd = "powershell.exe -ExecutionPolicy Bypass -File `"$scriptPath`" -Phase $NextPhase"
    New-ItemProperty `
        -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
        -Name "DeployPoCGuacamole" `
        -Value $cmd `
        -PropertyType String `
        -Force | Out-Null
}

function To-SecureStringPlain {
    param([string]$Plain)
    return (ConvertTo-SecureString $Plain -AsPlainText -Force)
}

function Get-DomainDN {
    $parts = $Config.DomainName.Split(".")
    return ($parts | ForEach-Object { "DC=$_" }) -join ","
}

function Ensure-DnsRecord {
    param(
        [string]$Name,
        [string]$ZoneName,
        [string]$IPv4Address
    )

    try {
        $existing = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $Name -ErrorAction SilentlyContinue
        if (-not $existing) {
            Add-DnsServerResourceRecordA -Name $Name -ZoneName $ZoneName -IPv4Address $IPv4Address | Out-Null
        }
    }
    catch {
        Write-Warning "Impossible de créer l'enregistrement DNS $Name.$ZoneName automatiquement : $($_.Exception.Message)"
    }
}

function Ensure-HostsEntry {
    param(
        [string]$Hostname,
        [string]$IPAddress
    )

    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    $entry = "$IPAddress`t$Hostname"
    $content = Get-Content $hostsFile -ErrorAction SilentlyContinue
    if ($content -notcontains $entry) {
        Add-Content -Path $hostsFile -Value $entry
    }
}

function Ensure-ADUser {
    param(
        [string]$SamAccountName,
        [string]$UserPrincipalName,
        [string]$Name,
        [string]$Path,
        [securestring]$Password
    )

    $existing = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADUser `
            -Name $Name `
            -SamAccountName $SamAccountName `
            -UserPrincipalName $UserPrincipalName `
            -Path $Path `
            -AccountPassword $Password `
            -Enabled $true `
            -PasswordNeverExpires $true
    }
}

function Ensure-ADGroup {
    param(
        [string]$GroupName,
        [string]$Path
    )

    $existing = Get-ADGroup -Filter "SamAccountName -eq '$GroupName'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADGroup `
            -Name $GroupName `
            -SamAccountName $GroupName `
            -GroupScope Global `
            -GroupCategory Security `
            -Path $Path
    }
}

function Ensure-ADGroupMember {
    param(
        [string]$GroupName,
        [string]$MemberSam
    )

    $group = Get-ADGroup $GroupName
    $member = Get-ADUser $MemberSam
    $isMember = Get-ADGroupMember $group | Where-Object { $_.DistinguishedName -eq $member.DistinguishedName }
    if (-not $isMember) {
        Add-ADGroupMember -Identity $group -Members $member
    }
}

function Request-WebServerCertificate {
    param(
        [string[]]$DnsNames,
        [string]$FriendlyName
    )

    $cert = Get-Certificate `
        -Template "WebServer" `
        -DnsName $DnsNames `
        -CertStoreLocation "Cert:\LocalMachine\My"

    $thumb = $cert.Certificate.Thumbprint
    $realCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumb }
    if ($realCert) {
        $realCert.FriendlyName = $FriendlyName
    }

    return $realCert
}

# =========================
# Préparation dossiers
# =========================
Ensure-Dir -Path $Config.WorkDir
Ensure-Dir -Path $Config.ExportDir

# =========================
# Phase 1
# =========================
if ($Phase -eq "1") {
    Write-Step "Renommage du serveur si nécessaire"
    if ($env:COMPUTERNAME -ne $Config.ServerName) {
        Rename-Computer -NewName $Config.ServerName -Force
    }

    Write-Step "Installation des rôles AD DS + DNS + outils"
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

    Write-Step "Création de la forêt Active Directory"
    $dsrmPwd = To-SecureStringPlain $Config.DSRMPasswordPlain

    Register-NextPhase -NextPhase "2"

    Install-ADDSForest `
        -DomainName $Config.DomainName `
        -DomainNetbiosName $Config.NetbiosName `
        -InstallDNS `
        -SafeModeAdministratorPassword $dsrmPwd `
        -NoRebootOnCompletion:$true `
        -Force

    Write-Step "Redémarrage vers la phase 2"
    Restart-Computer -Force
}

# =========================
# Phase 2
# =========================
if ($Phase -eq "2") {
    Import-Module ActiveDirectory

    Write-Step "Création de l'OU Entreprise"
    $domainDN = Get-DomainDN
    $ouDn = "OU=$($Config.OUName),$domainDN"

    if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$($Config.OUName))" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Config.OUName -Path $domainDN
    }

    Write-Step "Création du groupe GG_Guacamole_Users"
    Ensure-ADGroup -GroupName $Config.GuacGroupName -Path $ouDn

    Write-Step "Création des utilisateurs Robin / Thomas / svc_adfs"
    $defaultPwd = To-SecureStringPlain $Config.DefaultPasswordPlain

    Ensure-ADUser -SamAccountName $Config.RobinSam -UserPrincipalName $Config.RobinUPN -Name "Robin" -Path $ouDn -Password $defaultPwd
    Ensure-ADUser -SamAccountName $Config.ThomasSam -UserPrincipalName $Config.ThomasUPN -Name "Thomas" -Path $ouDn -Password $defaultPwd
    Ensure-ADUser -SamAccountName $Config.AdfsSvcSam -UserPrincipalName $Config.AdfsSvcUPN -Name "svc_adfs" -Path $ouDn -Password $defaultPwd

    Write-Step "Ajout de Robin au groupe GG_Guacamole_Users"
    Ensure-ADGroupMember -GroupName $Config.GuacGroupName -MemberSam $Config.RobinSam

    Write-Step "Installation d'AD CS"
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

    Write-Step "Déploiement de l'Enterprise Root CA"
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCa `
        -CACommonName $Config.CACommonName `
        -KeyLength 2048 `
        -HashAlgorithmName SHA256 `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -Force

    Write-Step "Création des enregistrements DNS utiles"
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike "169.254*" -and $_.PrefixOrigin -ne "WellKnown" } |
        Select-Object -First 1).IPAddress

    if ($ip) {
        try {
            Ensure-DnsRecord -Name "adfs" -ZoneName "poc.local" -IPv4Address $ip
            Ensure-DnsRecord -Name "guacamole" -ZoneName "poc.local" -IPv4Address $ip
        }
        catch {
        }
        Ensure-HostsEntry -Hostname $Config.AdfsFqdn -IPAddress $ip
        Ensure-HostsEntry -Hostname $Config.GuacFqdn -IPAddress $ip
    }

    Write-Step "Demande du certificat AD FS"
    $adfsCert = Request-WebServerCertificate `
        -DnsNames @($Config.AdfsFqdn) `
        -FriendlyName "ADFS Service Communications"

    Write-Step "Demande du certificat Guacamole / Nginx"
    $guacCert = Request-WebServerCertificate `
        -DnsNames @($Config.GuacFqdn) `
        -FriendlyName "Guacamole Reverse Proxy"

    Write-Step "Export du certificat Guacamole en PFX"
    $pfxPwd = To-SecureStringPlain $Config.GuacPfxPasswordPlain
    Export-PfxCertificate `
        -Cert $guacCert `
        -FilePath "$($Config.ExportDir)\guacamole.poc.local.pfx" `
        -Password $pfxPwd | Out-Null

    Export-Certificate `
        -Cert $guacCert `
        -FilePath "$($Config.ExportDir)\guacamole.poc.local.cer" | Out-Null

    Register-NextPhase -NextPhase "3"

    Write-Step "Redémarrage vers la phase 3"
    Restart-Computer -Force
}

# =========================
# Phase 3
# =========================
if ($Phase -eq "3") {
    Import-Module ActiveDirectory

    Write-Step "Installation du rôle AD FS"
    Install-WindowsFeature ADFS-Federation -IncludeManagementTools

    Write-Step "Récupération du certificat AD FS"
    $adfsCert = Get-ChildItem Cert:\LocalMachine\My |
        Where-Object { $_.Subject -match "CN=$($Config.AdfsFqdn)" } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1

    if (-not $adfsCert) {
        throw "Certificat AD FS introuvable pour $($Config.AdfsFqdn)."
    }

    Write-Step "Création de la ferme AD FS"
    $svcPwd = To-SecureStringPlain $Config.DefaultPasswordPlain
    $svcCred = New-Object System.Management.Automation.PSCredential("$($Config.NetbiosName)\$($Config.AdfsSvcSam)", $svcPwd)

    Install-AdfsFarm `
        -CertificateThumbprint $adfsCert.Thumbprint `
        -FederationServiceDisplayName $Config.AdfsDisplayName `
        -FederationServiceName $Config.AdfsFqdn `
        -ServiceAccountCredential $svcCred `
        -OverwriteConfiguration `
        -Verbose

    Register-NextPhase -NextPhase "4"

    Write-Step "Redémarrage vers la phase 4"
    Restart-Computer -Force
}

# =========================
# Phase 4
# =========================
if ($Phase -eq "4") {
    Import-Module ActiveDirectory
    Import-Module ADFS

    Write-Step "Création de la relying party trust Guacamole"
    $rp = Get-AdfsRelyingPartyTrust -Name $Config.GuacRelyingPartyName -ErrorAction SilentlyContinue

    if (-not $rp) {
        Add-AdfsRelyingPartyTrust `
            -Name $Config.GuacRelyingPartyName `
            -Identifier $Config.GuacEntityId `
            -IssuanceAuthorizationRules '=> issue(Type = "http://schemas.microsoft.com/authorization/claims/permit", Value = "true");'
    }

    Write-Step "Ajout du SAML Assertion Consumer endpoint"
    $samlEp = New-AdfsSamlEndpoint `
        -Binding POST `
        -Protocol SAMLAssertionConsumer `
        -Uri $Config.GuacCallbackUrl `
        -IsDefault $true

    Set-AdfsRelyingPartyTrust `
        -TargetName $Config.GuacRelyingPartyName `
        -SamlEndpoint $samlEp `
        -Identifier $Config.GuacEntityId

    Write-Step "Restriction d'accès au groupe GG_Guacamole_Users"
    $groupSid = (Get-ADGroup $Config.GuacGroupName).SID.Value

    $authorizationRules = @"
@RuleName = "Autoriser uniquement le groupe Guacamole"
c:[Type == "http://schemas.microsoft.com/ws/2008/06/identity/claims/groupsid", Value == "$groupSid"]
 => issue(Type = "http://schemas.microsoft.com/authorization/claims/permit", Value = "true");
"@

    Set-AdfsRelyingPartyTrust `
        -TargetName $Config.GuacRelyingPartyName `
        -IssuanceAuthorizationRules $authorizationRules

    Write-Step "Configuration des claims de base"
    $transformRules = @"
@RuleName = "Pass through UPN"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
 => issue(claim = c);

@RuleName = "UPN to NameID"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn"]
 => issue(
    Type = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier",
    Value = c.Value,
    Properties["http://schemas.xmlsoap.org/ws/2005/05/identity/claimproperties/format"] = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
 );

@RuleName = "Pass through Given Name"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname"]
 => issue(claim = c);

@RuleName = "Pass through Surname"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"]
 => issue(claim = c);

@RuleName = "Pass through Email"
c:[Type == "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"]
 => issue(claim = c);
"@

    Set-AdfsRelyingPartyTrust `
        -TargetName $Config.GuacRelyingPartyName `
        -IssuanceTransformRules $transformRules

    Write-Step "Export des informations utiles"
    $metadataUrl = "https://$($Config.AdfsFqdn)/FederationMetadata/2007-06/FederationMetadata.xml"

@"
Déploiement terminé.

Informations utiles :
- Domaine AD              : $($Config.DomainName)
- OU                      : $($Config.OUName)
- Groupe Guacamole        : $($Config.GuacGroupName)
- Robin                   : $($Config.RobinUPN)   / mot de passe : $($Config.DefaultPasswordPlain)
- Thomas                  : $($Config.ThomasUPN)  / mot de passe : $($Config.DefaultPasswordPlain)
- Compte service AD FS    : $($Config.AdfsSvcUPN) / mot de passe : $($Config.DefaultPasswordPlain)

SAML / ADFS :
- Federation Service Name : $($Config.AdfsFqdn)
- Metadata URL            : $metadataUrl
- Relying Party Name      : $($Config.GuacRelyingPartyName)
- Guacamole Entity ID     : $($Config.GuacEntityId)
- Guacamole Callback URL  : $($Config.GuacCallbackUrl)

Certificats exportés :
- PFX Guacamole           : $($Config.ExportDir)\guacamole.poc.local.pfx
- CER Guacamole           : $($Config.ExportDir)\guacamole.poc.local.cer
- Mot de passe PFX        : $($Config.GuacPfxPasswordPlain)
"@ | Set-Content "$($Config.WorkDir)\RESULTAT-POC.txt" -Encoding UTF8

    Get-Content "$($Config.WorkDir)\RESULTAT-POC.txt"
}
