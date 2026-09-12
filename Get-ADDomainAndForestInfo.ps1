Import-Module ActiveDirectory

$DomainInfo = Get-ADDomain
$DomainNETBIOS = $DomainInfo.NetBIOSName
$DomainDNSRoot = $DomainInfo.DNSRoot
$DomainDN = $DomainInfo.DistinguishedName

Write-Host "Domain NetBIOS: $DomainNETBIOS"
Write-Host "Domain DNS Root: $DomainDNSRoot"
Write-Host "Domain DN: $DomainDN"

Write-Host "[All Domains and Domain SIDs]"
(Get-ADForest).Domains | ForEach-Object {
    Get-ADDomain -Server $_ | Select-Object Name, DomainSID
}

$rootDomain = (Get-ADForest).RootDomain
$rootDomainSid = (Get-ADDomain -Server $rootDomain).DomainSID.Value
Write-Host "Root Forest Domain: $rootDomain"
Write-Host "Forest SID: $rootDomainSid"

$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
$hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($rootDomainSid))
$hashString = [System.BitConverter]::ToString($hash).Replace('-', '')
Write-Host "Forest SID (SHA256): $hashString"
