<#
    Semperis Community prerequisites checker for on-premises products (ADFR + DSP)

    Initial development by Evgenij Smirnov (evgenijs@semperis.com) in the Summer 2023, refactored in 2024+2025+2026.

    Build date: 020260623.1750

    Change log:
    2026-04-05: added comprehensive logging to the main script
    2026-04-03: First published

#>
[CmdletBinding(DefaultParameterSetName='Interactive')]
Param(
    [Parameter(Mandatory=$true, ParameterSetName='DCTarget')]
    [string]$DomainController,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [PSCredential]$Credential,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [switch]$SkipReport,
    [Parameter(Mandatory=$false, ParameterSetName='LMOnly')]
    [switch]$LocalMachineOnly,
    [Parameter(Mandatory=$false, ParameterSetName='ADOnly')]
    [switch]$LocalForestOnly,
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [switch]$Report,
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [switch]$Status,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [Parameter(Mandatory=$false, ParameterSetName='LMOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='ADOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [string]$ProjectName,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [Parameter(Mandatory=$false, ParameterSetName='LMOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='ADOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [string]$ProjectOperator,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [Parameter(Mandatory=$false, ParameterSetName='LMOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='ADOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [string]$ProjectDescription,
    [Parameter(Mandatory=$false, ParameterSetName='DCTarget')]
    [Parameter(Mandatory=$false, ParameterSetName='LMOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='ADOnly')]
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [Parameter(Mandatory=$false, ParameterSetName='Status')]
    [Parameter(Mandatory=$false, ParameterSetName='Interactive')]
    [ValidateRange(0,3)]
    [int]$LogLevel = 0,
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [ValidateSet('3.8','4.0','4.1','4.2','5.0','5.1','6.0')]
    [string]$ADFRVersion = '6.0',
    [Parameter(Mandatory=$false, ParameterSetName='Report')]
    [ValidateSet('3.6','3.8','4.0','4.0SP1','4.1','4.0SP2','4.2','5.0','5.1','5.2')]
    [string]$DSPVersion = '5.2'
)
$script:version = '020260623.1750'
$script:LogPath = $null
$script:LogLevel = $LogLevel
$script:LogLevelCaption = @('DEBUG','INFO','WARNING','ERROR')[$script:LogLevel]
#region function definitions

function Complete-SMPRSExecution {
    [CmdletBinding()]
    Param()
    if ($null -eq $script:ExecutionID) {
        Write-SMPRSLog -Severity 2 -Message 'Execution completion without previous start!'
        return $false
    } else {
        Write-SMPRSLog -Severity 1 -Message ('Completing execution {0}' -f $script:ExecutionID)
    }
    if ($script:masterData.Executions.Where({$_.ID -eq $script:ExecutionID}).Count -eq 0) {
        Write-SMPRSLog -Severity 2 -Message 'Execution record not found in datastore!'
        $execres = $false
    } else {
        ($script:masterData.Executions.Where({$_.ID -eq $script:ExecutionID})[0]).End = [datetime]::Now
        $execres = Update-SMPRSDataStore
    }
    $script:ExecutionID = $null
    return $execres
}

function ConvertTo-GUID {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $InputValue,
        [Parameter(Mandatory=$false)]
        [switch]$AddBraces,
        [Parameter(Mandatory=$false)]
        [switch]$Uppercase
    )
    if ($InputValue.GetType().Name -eq 'String') {
        if (32 -eq $InputValue.Length) {
            $InputString = $InputValue
            $InputValue = @()
            for ($i = 0; $i -lt 16; $i++) {
                $InputValue += [int]"0x$($InputString.Substring($i * 2, 2))"
            }
        }
    } 
    if (16 -eq $InputValue.Count) {
        $out = ('{0:x2}{1:x2}{2:x2}{3:x2}-{4:x2}{5:x2}-{6:x2}{7:x2}-{8:x2}{9:x2}-{10:x2}{11:x2}{12:x2}{13:x2}{14:x2}{15:x2}' -f $InputValue[3], $InputValue[2], $InputValue[1], $InputValue[0], $InputValue[5], $InputValue[4], $InputValue[7], $InputValue[6], $InputValue[8], $InputValue[9], $InputValue[10], $InputValue[11], $InputValue[12], $InputValue[13], $InputValue[14], $InputValue[15])
        if ($Uppercase) {
            $out = $out.ToUpper()
        } else {
            $out = $out.ToLower()
        }
        if ($AddBraces) {
            $out = "{$($out)}"
        }
    }
    return $out
}

function ConvertTo-SID {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $InputValue
    )
    if (24 -le $InputValue.Count) {
        $Val3 = $InputValue[15]
        $Val3 = $Val3 * 256 + $InputValue[14]
        $Val3 = $Val3 * 256 + $InputValue[13]
        $Val3 = $Val3 * 256 + $InputValue[12]
        $Val4 = $InputValue[19]
        $Val4 = $Val4 * 256 + $InputValue[18]
        $Val4 = $Val4 * 256 + $InputValue[17]
        $Val4 = $Val4 * 256 + $InputValue[16]
        $Val5 = $InputValue[23]
        $Val5 = $Val5 * 256 + $InputValue[22]
        $Val5 = $Val5 * 256 + $InputValue[21]
        $Val5 = $Val5 * 256 + $InputValue[20]
        if (26 -le $InputValue.Count) {
            $Val6 = $InputValue[25]
            $Val6 = $Val6 * 256 + $InputValue[24]
            $out = 'S-{0}-{1}-{2}-{3}-{4}-{5}-{6}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3, $Val4, $Val5, $Val6
        } else {
            $out = 'S-{0}-{1}-{2}-{3}-{4}-{5}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3, $Val4, $Val5
        }
    } elseif (16 -eq $InputValue.Count) {
        $Val3 = $InputValue[15]
        $Val3 = $Val3 * 256 + $InputValue[14]
        $Val3 = $Val3 * 256 + $InputValue[13]
        $Val3 = $Val3 * 256 + $InputValue[12]
        $out = 'S-{0}-{1}-{2}-{3}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3
    } else {
        Write-Warning ('[ConvertTo-SID] Wrong byte count [{0}], should be 16, 24 or 26+' -f $InputValue.Count)
        $out = $null
    }
    return $out
}

function Explore-SMPRSDomain {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ForestGUID,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential = $cred
    )
    Write-SMPRSLog -Severity 1 -Message ('ForestGUID supplied: {0}' -f $ForestGUID)
    if ($null -eq ($ForestGUID -as [guid])) {
        if ($script:masterData.Forests.Count -eq 1) {
            $tgtGUID = $script:masterData.Forests[$script:masterData.Forests.GetEnumerator()[0].Name].ForestGUID
        } elseif (-not [string]::IsNullOrWhiteSpace($script:CurrentForestGUID)) {
            $tgtGUID = $script:CurrentForestGUID
        } else {
            Write-SMPRSLog -Severity 2 -Message ('Cannot identify forest without GUID because there are {0} forests in the dataset!' -f $script:masterData.Forests.Count)
            return $false
        }
    } else {
        $tgtGUID = '{{{0}}}' -f ($ForestGUID -as [guid]).Guid.ToUpper()
        if (-not $script:masterData.Forests.ContainsKey($tgtGUID)) {
            Write-SMPRSLog -Severity 2 -Message ('Forest not found by GUID: {0}' -f $tgtGUID)
            return $false
        }
    }
    Write-SMPRSLog -Severity 1 -Message ('Resolved ForestGUID: {0}' -f $tgtGUID)
    $domainList = @($script:masterData.Forests[$tgtGUID].Domains)
    Write-SMPRSLog -Severity 1 -Message ('Found {0} domains' -f $domainList.Count)

    $domainExplorationSB = {
        Param(
            [string]$domainFQDN,
            [string]$domainNC,
            [PSCredential]$Credential,
            [string[]]$domainControllers
        )
        $stopWatch =  [System.Diagnostics.Stopwatch]::StartNew()
        #region function definitions
        function ConvertTo-GUID {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                $InputValue,
                [Parameter(Mandatory=$false)]
                [switch]$AddBraces,
                [Parameter(Mandatory=$false)]
                [switch]$Uppercase
            )
            if ($InputValue.GetType().Name -eq 'String') {
                if (32 -eq $InputValue.Length) {
                    $InputString = $InputValue
                    $InputValue = @()
                    for ($i = 0; $i -lt 16; $i++) {
                        $InputValue += [int]"0x$($InputString.Substring($i * 2, 2))"
                    }
                }
            } 
            if (16 -eq $InputValue.Count) {
                $out = ('{0:x2}{1:x2}{2:x2}{3:x2}-{4:x2}{5:x2}-{6:x2}{7:x2}-{8:x2}{9:x2}-{10:x2}{11:x2}{12:x2}{13:x2}{14:x2}{15:x2}' -f $InputValue[3], $InputValue[2], $InputValue[1], $InputValue[0], $InputValue[5], $InputValue[4], $InputValue[7], $InputValue[6], $InputValue[8], $InputValue[9], $InputValue[10], $InputValue[11], $InputValue[12], $InputValue[13], $InputValue[14], $InputValue[15])
                if ($Uppercase) {
                    $out = $out.ToUpper()
                } else {
                    $out = $out.ToLower()
                }
                if ($AddBraces) {
                    $out = "{$($out)}"
                }
            }
            return $out
        }
        function ConvertTo-SID {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                $InputValue
            )
            if (24 -le $InputValue.Count) {
                $Val3 = $InputValue[15]
                $Val3 = $Val3 * 256 + $InputValue[14]
                $Val3 = $Val3 * 256 + $InputValue[13]
                $Val3 = $Val3 * 256 + $InputValue[12]
                $Val4 = $InputValue[19]
                $Val4 = $Val4 * 256 + $InputValue[18]
                $Val4 = $Val4 * 256 + $InputValue[17]
                $Val4 = $Val4 * 256 + $InputValue[16]
                $Val5 = $InputValue[23]
                $Val5 = $Val5 * 256 + $InputValue[22]
                $Val5 = $Val5 * 256 + $InputValue[21]
                $Val5 = $Val5 * 256 + $InputValue[20]
                if (26 -le $InputValue.Count) {
                    $Val6 = $InputValue[25]
                    $Val6 = $Val6 * 256 + $InputValue[24]
                    $out = 'S-{0}-{1}-{2}-{3}-{4}-{5}-{6}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3, $Val4, $Val5, $Val6
                } else {
                    $out = 'S-{0}-{1}-{2}-{3}-{4}-{5}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3, $Val4, $Val5
                }
            } elseif (16 -eq $InputValue.Count) {
                $Val3 = $InputValue[15]
                $Val3 = $Val3 * 256 + $InputValue[14]
                $Val3 = $Val3 * 256 + $InputValue[13]
                $Val3 = $Val3 * 256 + $InputValue[12]
                $out = 'S-{0}-{1}-{2}-{3}' -f $InputValue[0], $InputValue[7], $InputValue[8], $Val3
            } else {
                Write-Warning ('[ConvertTo-SID] Wrong byte count [{0}], should be 16, 24 or 26+' -f $InputValue.Count)
                $out = $null
            }
            return $out
        }
        function Test-DCConnection {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                [string]$ComputerName,
                [Parameter(Mandatory=$false)]
                [PSCredential]$Credential,
                [Parameter(Mandatory=$false)]
                [ValidateSet('LDAP','LDAPS')]
                [string[]]$Protocol
            )
            if (-not $PSBoundParameters.ContainsKey('Protocol')) {
                $Protocol = @('LDAP','LDAPS')
            }
            $result = [PSCustomObject]@{
                'LDAP' = $null
                'LDAPS' = $null
            }
            if ($Protocol -contains 'LDAP') {
                $args = @("LDAP://$($ComputerName)/RootDSE")
                if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
                    $args += $Credential.UserName
                    $args += $Credential.GetNetworkCredential().Password
                    $args += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing+[System.DirectoryServices.AuthenticationTypes]::ServerBind)
                }
                try {
                    $dsE = New-Object System.DirectoryServices.DirectoryEntry($args) -EA Stop
                    $dsE.RefreshCache()
                    $result.LDAP = $true
                } catch {
                    $result.LDAP = $false
                }
            }
            if ($Protocol -contains 'LDAPS') {
                $args = @("LDAP://$($ComputerName):636/RootDSE")
                if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
                    $args += $Credential.UserName
                    $args += $Credential.GetNetworkCredential().Password
                    $args += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing+[System.DirectoryServices.AuthenticationTypes]::ServerBind)
                }
                try {
                    $dsE = New-Object System.DirectoryServices.DirectoryEntry($args) -EA Stop
                    $dsE.RefreshCache()
                    $result.LDAPS = $true
                } catch {
                    $result.LDAPS = $false
                }
            }
            return $result
        }
        function Get-RootDSE {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                [string]$ComputerName,
                [Parameter(Mandatory=$false)]
                [ValidateRange(1,120)]
                [int]$Timeout = 3
            )
            $result = [PSCustomObject]@{
                'Argument' = $ComputerName
                'Success' = $true
                'FQDN' = $null
                'HostName' = $null
                'RootDomain' = $null
                'RootNC' = $null
                'FFL' = $null
                'ConfigNC' = $null
                'SchemaNC' = $null
                'Domain' = $null
                'ErrorMessage' = $null
            }
            try {
                Add-Type -AssemblyName System.DirectoryServices.Protocols -EA Stop
            } catch {
                $result.Success = $false
                $result.ErrorMessage = $_.Exception.Message
                return $result
            }
            try {
                $ldapIdentifier = New-Object -TypeName System.DirectoryServices.Protocols.LdapDirectoryIdentifier -ArgumentList $ComputerName,389, $false, $true
                $ldap = New-Object -TypeName System.DirectoryServices.Protocols.LdapConnection -ArgumentList $ldapIdentifier
                $ldap.AuthType = [System.DirectoryServices.Protocols.AuthType]::Anonymous
                $ldap.Timeout = New-TimeSpan -Seconds $Timeout
                $request = New-Object -TypeName System.DirectoryServices.Protocols.SearchRequest
                $request.DistinguishedName = $null
                $request.Filter = '(&(objectClass=*))'
                $request.Scope = [System.DirectoryServices.Protocols.SearchScope]::Base
                $null = $request.Attributes.Add('ldapServiceName')
                $null = $request.Attributes.Add('dnsHostName')
                $null = $request.Attributes.Add('forestFunctionality')
                $null = $request.Attributes.Add('rootDomainNamingContext')
                $null = $request.Attributes.Add('configurationNamingContext')
                $null = $request.Attributes.Add('schemaNamingContext')
                $response = $ldap.SendRequest($request)
                if ($response.ResultCode.value__ -eq 0) {
                    $svcName = $response.Entries[0].Attributes['ldapServiceName'][0]
                    if ($svcName -match '^(?<frd>[a-zA-Z0-9\-\.]+)\:(?<hn>[a-zA-Z0-9\-]+)\$\@(?<dom>[a-zA-Z0-9\-\.]+)$') {
                        $result.RootDomain = $Matches['frd']
                        $result.HostName = $Matches['hn'].ToUpper()
                        $result.Domain = $Matches['dom'].ToLower()
                    } else {
                        $result.Success = $false
                        $result.ErrorMessage = ('LDAP Service name has a wrong format [{0}]' -f $svcName)
                    }
                    $result.FQDN = $response.Entries[0].Attributes['dnsHostName'][0].ToLower()
                    $result.RootNC = $response.Entries[0].Attributes['rootDomainNamingContext'][0]
                    $result.ConfigNC = $response.Entries[0].Attributes['configurationNamingContext'][0]
                    $result.SchemaNC = $response.Entries[0].Attributes['schemaNamingContext'][0]
                    $result.FFL = $response.Entries[0].Attributes['forestFunctionality'][0]
                }
                $ldap.Dispose()
            } catch {
                $result.Success = $false
                $result.ErrorMessage = $_.Exception.Message
            }
            return $result
        }
        function Get-DSObject {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$false)]
                [string]$ObjectDN = "RootDSE",
                [Parameter(Mandatory=$false)]
                [string]$Server,
                [Parameter(Mandatory=$false)]
                [PSCredential]$Credential,
                [Parameter(Mandatory=$false)]
                [switch]$UseLDAPS
            )
            $res = [PSCustomObject]@{
                'Success' = $true
                'ErrorMessage' = $null
                'DSEntry' = $null
            }
            if ($UseLDAPS) { $ldapPort = ':636' } else { $ldapPort = '' }
            if (-not [string]::IsNullOrWhiteSpace($Server)) {
                $pathPrefix = "LDAP://$($Server)$($ldapPort)/"
            } else {
                $pathPrefix = "LDAP://"
            }
            $objArgs = @("$($pathPrefix)$ObjectDN")
            if ($PSBoundParameters.ContainsKey("Credential") -and ($null -ne $Credential)) {
                $cred = $Credential
            } else {
                $cred = $null
            }
            if ($null -ne $cred) {
                $objArgs += $cred.UserName
                $objArgs += $cred.GetNetworkCredential().Password
                $objArgs += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing)
            }
            try {
                $dsE = New-Object System.DirectoryServices.DirectoryEntry($objArgs) -EA Stop
                $dsE.RefreshCache()
                $res.DSEntry = $dsE
            } catch {
                $res.ErrorMessage = $_.Exception.Message
                $res.Success = $false
            }
            return $res
        }
        function Get-DSChildren {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                [string]$ParentDN,
                [Parameter(Mandatory=$false)]
                [string]$LDAPFilter = "(objectClass=*)",
                [Parameter(Mandatory=$false)]
                [switch]$SearchSubtree,
                [Parameter(Mandatory=$false)]
                [string[]]$Properties,
                [Parameter(Mandatory=$false)]
                [switch]$SearchResults,
                [Parameter(Mandatory=$false)]
                [switch]$NamesOnly,
                [Parameter(Mandatory=$false)]
                [string]$Server,
                [Parameter(Mandatory=$false)]
                [PSCredential]$Credential,
                [Parameter(Mandatory=$false)]
                [switch]$UseLDAPS
            )
            $parentParms = @{
                'ObjectDN' = $ParentDN
            }
            if ($PSBoundParameters.ContainsKey("Server")) {
                $parentParms.Add('Server', $Server)
                if ($UseLDAPS) {
                    $parentParms.Add('UseLDAPS', $true)
                }
            }
            if ($PSBoundParameters.ContainsKey("Credential") -and ($null -ne $Credential)) {
                $parentParms.Add('Credential', $Credential)
            }
            $res = @()
            $parent = Get-DSObject @parentParms
            if ($parent.Success) {
                $ds = New-Object System.DirectoryServices.DirectorySearcher
                $ds.SearchRoot = $parent.DSEntry
                $ds.Filter = $LDAPFilter
                if ($SearchSubtree) {
                    $ds.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
                } else {
                    $ds.SearchScope = [System.DirectoryServices.SearchScope]::OneLevel
                }
                $ds.PageSize = 1000
                if ($SearchResults) {
                    foreach ($prop in $Properties) {
                        $null = $ds.PropertiesToLoad.Add($prop)
                    }
                }
                if ($NamesOnly) {
                    $ds.PropertyNamesOnly = $true
                }
                $ds.FindAll().ForEach({
                    if ($NamesOnly) {
                        $item = $_
                    } elseif ($SearchResults -or $NamesOnly) {
                        if ($null -eq $_.Properties['distinguishedName']) {
                            Add-LogEntry -Severity 2 -Message ('Found a search result without distingiushedName while searching for {0} under {1}' -f $LDAPFilter, $ParentDN)
                            $item = $null
                        } else {
                            $item = $_
                        }
                    } else {
                        try {
                            $item = $_.GetDirectoryEntry()
                            if ($null -eq $item.Properties['distinguishedName']) {
                                Add-LogEntry -Severity 2 -Message ('Found a directory entry without distingiushedName while searching for {0} under {1}' -f $LDAPFilter, $ParentDN)
                                $item = $null
                            }
                        } catch {
                            Add-LogEntry -Severity 2 -Message ('Error getting directory entry while searching for {0} under {1}: {2}' -f $LDAPFilter, $ParentDN, $_.Exception.Message)
                            $item = $null
                        }
                    }
                    if ($item) {
                        $res += $item
                    }
                })
            } else {
                Add-LogEntry -Severity 0 -Message ('Parent not found: {0}' -f $ParentDN)
            }
            return $res
        }
        function Get-GPOVersion {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$false)]
                [uint32]$VersionNumber = 0
            )
            $result = [PSCustomObject]@{
                'Machine' = 0
                'User' = 0
            }
            if ($VersionNumber -gt 0) {
                $result.Machine = $VersionNumber -band [uint32]"0x0000FFFF"
                $result.User = ($VersionNumber -band [uint32]"0xFFFF0000") / 65536
            }
            return $result
        }
        function Add-LogEntry {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$false, Position=1)]
                [int]$Severity = 0,
                [Parameter(Mandatory=$true, Position=0)]
                [string]$Message
            )
            $result.Log += [PSCustomObject]@{
                'Timestamp' = [datetime]::Now
                'Severity' = $Severity
                'Message' = $Message
            }
        }
        #endregion
        $result = [PSCustomObject]@{
            'Success' = $true
            'IsExplored' = $true
            'DomainFQDN' = $domainFQDN
            'DomainNC' = $domainNC
            'UserName' = $Credential.UserName
            'Start' = [datetime]::Now
            'ForestGUID' = $null
            'TargetDC' = $null
            'UseLDAPS' = $null
            'DomainGUID' = $null
            'DomainSID' = $null
            'DomainFL' = $null
            'DomainName' = $null
            'FSMOPDCe' = $null
            'FSMORID' = $null
            'FSMOInfra' = $null
            'DAinPU' = $null
            'AUinPreWin2K' = $null
            'MachineAccountQuota' = $null
            'NumUsers' = $null
            'NumUsersActive' = $null
            'NumGroups' = $null
            'NumAdmins' = $null
            'NumComputers' = $null
            'NumOUs' = $null
            'NumPwdLastSetInvalid' = $null
            'NumLocalHostInName' = $null
            'KrbTGTpwdLastSet' = $null
            'Trusts' = @()
            'GPOs' = @()
            'DomainControllers' = @()
            'ElapsedSeconds' = $null
            'ErrorMessage' = $null
            'Log' = @()
        }
        Add-LogEntry -Severity 1 -Message ('Starting domain exploration job for {0}, {1} domain controllers specified' -f $domainFQDN, $domainControllers.Count)
        $tgtDC = $null
        foreach ($dc in $domainControllers) {
            Add-LogEntry -Severity 0 -Message ('Testing connectivity to DC {0}' -f $dc)
            $dcConn = Test-DCConnection -ComputerName $dc -Credential $Credential -Protocol LDAP,LDAPS
            if ($dcConn.LDAPS) {
                $tgtDC = $dc
                Add-LogEntry -Severity 0 -Message 'Found LDAPS!'
                break
            } elseif ($dcConn.LDAP) {
                $tgtDC = $dc
            } else {
                Add-LogEntry -Severity 2 -Message 'LDAP and LDAPS not reachable'
            }
        }
        if ($null -eq $tgtDC) {
            $result.Success = $false
            $result.ErrorMessage = 'Could not find a DC accessible on LDAP or LDAPS with the specified credentials'
            return $result
        }
        $ldapParms = @{
            'Server' = $tgtDC
            'Credential' = $Credential
            'UseLDAPS' = $dcConn.LDAPS
        }
        $result.TargetDC = $tgtDC
        $result.UseLDAPS = $dcConn.LDAPS
        Add-LogEntry -Severity 0 -Message 'Getting RootDSE'
        $rootDSE = Get-RootDSE -ComputerName $tgtDC
        Add-LogEntry -Severity 0 -Message 'Getting domain root object'
        $domRoot = Get-DSObject -ObjectDN $domainNC @ldapParms
        if (-not $domRoot.Success) {
            $result.Success = $false
            $result.ErrorMessage = $domRoot.ErrorMessage
            return $result
        }
        Add-LogEntry -Severity 1 -Message 'Domain root object acquired successfully'
        $result.DomainName = $domRoot.DSEntry.name[0]
        $result.DomainFL = $domRoot.DSEntry.'msDS-Behavior-Version'[0]
        $result.MachineAccountQuota = $domRoot.DSEntry.'ms-DS-MachineAccountQuota'[0]
        $result.DomainGUID = ConvertTo-GUID -InputValue $domRoot.DSEntry.objectGUID[0] -AddBraces -Uppercase
        $result.DomainSID = ConvertTo-SID -InputValue $domroot.DSEntry.objectSid[0]
        if ($domainNC -eq $rootDSE.RootNC) {
            $result.ForestGUID = $result.DomainGUID
        } else {
            $rootDomain = Get-DSObject -ObjectDN $rootDSE.RootNC @ldapParms
            $result.ForestGUID = ConvertTo-GUID -InputValue $rootDomain.DSEntry.objectGUID[0] -AddBraces -Uppercase
        }
        $result.FSMOPDCe = $domRoot.DSEntry.fSMORoleOwner[0]
        Add-LogEntry -Severity 0 -Message ('PDC emulator: {0}' -f $result.FSMOPDCe)
        # KRBTGT
        $krbTgt = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(objectSID={0}-502)' -f $result.DomainSID) -SearchResults -SearchSubtree @ldapParms)
        if ($krbTgt.Count -gt 0) {
            $result.KrbTGTpwdLastSet = $krbTgt[0].Properties['pwdLastSet'][0]
        } else {
            Add-LogEntry -Severity 2 -Message 'Could not acquire KRBTGT object'
        }
        # infrastructure master
        $infraUp = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=infrastructureUpdate)' -SearchSubtree @ldapParms)
        if ($infraUp.Count -gt 0) {
            $result.FSMOInfra = $infraUp[0].Properties['fSMORoleOwner'][0]
            Add-LogEntry -Severity 0 -Message ('Infrastructure master: {0}' -f $result.FSMOInfra)
        } else {
            Add-LogEntry -Severity 2 -Message 'Could not acquire InfrastructureUpdate object'
        }
        # rid master
        $ridMan = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=rIDManager)' -SearchSubtree @ldapParms)
        if ($ridMan.Count -gt 0) {
            $result.FSMORID = $ridMan[0].Properties['fSMORoleOwner'][0]
            Add-LogEntry -Severity 0 -Message ('RID master: {0}' -f $result.FSMORID)
        } else {
            Add-LogEntry -Severity 2 -Message 'Could not acquire RIDManager object'
        }
        # DA in PU
        Add-LogEntry -Severity 0 -Message 'Getting Protected Users group and checking if Domain Admins are nested into it'
        $puGroup = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(objectSID={0}-525)' -f $result.DomainSID) -SearchSubtree -SearchResults @ldapParms)
        $puMembers = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(&(objectSID={1}-512)(objectClass=group)(memberOf:1.2.840.113556.1.4.1941:={0}))' -f $puGroup[0].Properties['distinguishedName'][0], $result.DomainSID) -SearchSubtree -SearchResults @ldapParms)
        $result.DAinPU = ($puMembers.Count -gt 0)
        # AU in PreWin2K
        Add-LogEntry -Severity 0 -Message 'Getting Pre-Win2k group and checking if Authenticated Users are nested into it'
        $preWin2KGroup = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectSID=S-1-5-32-554)' -SearchSubtree -SearchResults @ldapParms)
        $puMembers = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(&(objectSID=S-1-5-11)(memberOf:1.2.840.113556.1.4.1941:={0}))' -f $preWin2KGroup[0].Properties['distinguishedName'][0], $result.DomainSID) -SearchSubtree -SearchResults @ldapParms)
        $result.AUinPreWin2K = ($puMembers.Count -gt 0)
        # object count
        Add-LogEntry -Severity 0 -Message 'Getting object counts'
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(&(objectCategory=person)(objectClass=user))' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumUsers = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Users: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(&(objectCategory=person)(objectClass=user)(adminCount=1))' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumAdmins = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Admins in default groups: {0}' -f $objs.Count)
        $todayMinus90 = (Get-Date).AddDays(-90).ToFileTimeUtc()
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(&(objectCategory=person)(objectClass=user)(lastLogonTimestamp>={0}))' -f $todayMinus90) -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumUsersActive = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Active users: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(&(objectClass=user)(objectCategory=person)(pwdLastSet=-1))' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumPwdLastSetInvalid = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Users with invalid pwdLastSet: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(&(objectClass=computer)(|(cn=localhost)(sAMAccountName=localhost)(servicePrincipalName=host/localhost*)))' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumLocalHostInName = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Computers with localhost in any name: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=group)' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumGroups = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Groups: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=organizationalUnit)' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumOUs = $objs.Count
        Add-LogEntry -Severity 0 -Message ('OUs: {0}' -f $objs.Count)
        $objs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=computer)' -SearchSubtree -SearchResults -NamesOnly @ldapParms)
        $result.NumComputers = $objs.Count
        Add-LogEntry -Severity 0 -Message ('Computers: {0}' -f $objs.Count)
        # GPOs
        $regex = [regex]'(\[(\{[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\})(\{[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\})?\])'
        $gpos = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(objectClass=groupPolicyContainer)' -SearchSubtree @ldapParms)
        Add-LogEntry -Severity 0 -Message ('Group Policy Objects: {0}' -f $gpos.Count)
        foreach ($gpo in $gpos) {
            $gpoVersion = Get-GPOVersion -VersionNumber ([uint32]($gpo.Properties['versionNumber'][0]))
            $gpoObj = [PSCustomObject]@{
                'GUID' = $gpo.Properties['name'][0]
                'Name' = $gpo.Properties['displayName'][0]
                'MachineVersion' = $gpoVersion.Machine
                'UserVersion' = $gpoVersion.User
                'MachineCSEs' = $regex.Matches($gpo.Properties['gPCMachineExtensionNames'][0]).Groups.Where({$_.Name -eq '2'}).Count
                'UserCSEs' = $regex.Matches($gpo.Properties['gPCUserExtensionNames'][0]).Groups.Where({$_.Name -eq '2'}).Count
                'FolderPath' = $gpo.properties['gPCFileSysPath'][0]
                'LowASCII' = (([int[]][char[]]$gpo.Properties['displayName'][0]).Where({$_ -lt 32}).Count -gt 0)
                'EmptyName' = ($gpo.Properties['displayName'][0].Length -eq 0)
            }
            $result.GPOs += $gpoObj
        }
        # trusts
        $trusts = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(&(objectClass=trustedDomain)(!(trustAttributes:1.2.840.113556.1.4.803:=32)))' -SearchSubtree @ldapParms)
        Add-LogEntry -Severity 0 -Message ('Trusts: {0}' -f $trusts.Count)
        foreach ($trust in $trusts) {
            $result.Trusts += [PSCustomObject]@{
                'TrustPartner' = $trust.Properties['trustPartner'][0]
                'TrustType' = $trust.Properties['trustType'][0]
                'TrustAttributes' = $trust.Properties['trustAttributes'][0]
                'TrustDirection' = $trust.Properties['trustDirection'][0]
            }
        }
        # DC objects
        $dcs = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter '(|(primaryGroupID=516)(primaryGroupID=521))' -SearchSubtree @ldapParms)
        Add-LogEntry -Severity 0 -Message ('Domain Controllers: {0}' -f $dcs.Count)
        foreach ($dc in $dcs) {
            $dcObj = [PSCustomObject]@{
                'DN' = $dc.distinguishedName[0]
                'IsRO' = ($dc.primaryGroupID[0] -eq 521)
                'ManagedBy' = $dc.managedBy[0]
                'EncryptionTypes' = $dc.'msDS-SupportedEncryptionTypes'[0]
                'FQDN' = $dc.dNSHostName[0]
                'KrbTGTAccount' = $null
                'KrbTGTpwdLastSet' = $null
            }
            if ($dcObj.IsRO) {
                $dcObj.KrbTGTAccount = $dc.'msDS-KrbTgtLink'[0]
                $dcKrbTgt = @(Get-DSChildren -ParentDN $domainNC -LDAPFilter ('(distinguishedName={0})' -f $dcObj.KrbTGTAccount) -SearchSubtree -SearchResults @ldapParms)
                if ($dcKrbTgt.Count -gt 0) {
                    $dcObj.KrbTGTpwdLastSet = $dcKrbTgt[0].Properties['pwdLastSet'][0]
                }
            }

            $result.DomainControllers += $dcObj
        }

        $stopWatch.Stop()
        $result.ElapsedSeconds = $stopWatch.Elapsed.TotalSeconds
        return $result
    }

    #region Creating runspace pool
    Write-SMPRSLog -Severity 0 -Message ('Creating runspace pool with {0} threads' -f (1 + [System.Environment]::ProcessorCount))
    $pool = [RunspaceFactory]::CreateRunspacePool(1,  (1 + [System.Environment]::ProcessorCount))
    $pool.ApartmentState = [System.Threading.ApartmentState]::MTA
    $pool.Open()
    $runspaces = @()
    $results = @()
    #endregion 

    $start = Get-Date
    Write-SMPRSLog -Severity 1 -Message 'Creating runspaces for domains'
    Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status 'Starting domain exploration' -PercentComplete 0
    $nDom = 0
    $nEx = 0
    foreach ($domain in $domainList) {
        $nDom ++
        Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status ('Submitting job for domain {0}/{1}: {2}' -f $nDom, $domainList.Count, $domain.DomainFQDN) -PercentComplete ($nDom * 100 / $domainList.Count)
        $dcs = $script:masterData.Forests[$tgtGUID].DomainControllers.Where({$_.Domain -eq $domain.DomainFQDN}).FQDN
        Write-SMPRSLog -Severity 1 -Message ('Submitting job for domain {0}/{1}: {2} with {3} DCs' -f $nDom, $domainList.Count, $domain.DomainFQDN, $dcs.Count)
        try {
            $runspace = [PowerShell]::Create()
            $null = $runspace.AddScript($domainExplorationSB)
            $null = $runspace.AddArgument($domain.DomainFQDN)
            $null = $runspace.AddArgument($domain.DomainNC)
            $null = $runspace.AddArgument($Credential)
            $null = $runspace.AddArgument($dcs)
            $runspace.RunspacePool = $pool
            $runspaces += [PSCustomObject]@{ 
                'Pipe' = $runspace
                'Status' = $runspace.BeginInvoke()
                'Finished' = $false
            }
            Write-SMPRSLog -Severity 0 -Message 'Runspace created and invoked successfully'
        } catch {
            Write-SMPRSLog -Severity 2 -Message $_.Exception.Message
            $nEx ++
        }
    }
    Write-SMPRSLog -Severity 0 -Message ('All runspaces submitted with {0} exceptions' -f $nEx)
    Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status 'Done submitting jobs' -Completed
    $rsCount = $runspaces.Count
    $rsCompleted = 0
    $rsTimedOut = 0
    Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status 'Receiving job results' -PercentComplete 0
    $nLoop = 0
    do {
        $nLoop ++
        Write-SMPRSLog -Severity 0 -Message ('Enter results collection loop {0}' -f $nLoop)
        $rsRunning = 0
        foreach ($runspace in $runspaces) {
            if ($runspace.Finished) { continue }
            if ($runspace.Status.IsCompleted) {
                Write-SMPRSLog -Severity 0 -Message 'Found a new finished runspace'
                $results += $runspace.Pipe.EndInvoke($runspace.Status)
                $runspace.Pipe.Dispose()
                $rsCompleted++
                $runspace.Finished = $true
            } else {
                $rsRunning++
            }
        }
        Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status ('Receiving job results: {0} running, {1} finished' -f $rsRunning, $rsCompleted) -PercentComplete ($rsCompleted * 100 / $nDom)
        Write-SMPRSLog -Severity 0 -Message ('Receiving job results: {0} running, {1} finished' -f $rsRunning, $rsCompleted)
        if ($rsRunning -gt 0) {
            Write-SMPRSLog -Severity 0 -Message ('{0} running jobs left, will sleep for 5 seconds' -f $rsRunning)
            Start-Sleep -Milliseconds 5000
        }
    } until ($rsRunning -eq 0)
    Write-SMPRSLog -Severity 0 -Message ('All results received or have timed out, result count: {0}' -f $results.Count)
    Write-Progress -Id 0 -Activity ('Exploring domains in forest {0}' -f $tgtGUID) -Status 'Done receiving job results' -Completed
    $res = $true
    foreach ($result in $results) {
        Write-SMPRSLog -Severity 0 -Message ('Result for {0} successful: {1} log entries: {2}' -f $result.DomainFQDN, $result.Success, $result.Log.Count)
        if ($result.Log.Count -gt 0) {
            Write-SMPRSLog -Severity 1 -Message ('=== Job log for domain {0}: {1} entries' -f $result.DomainFQDN, $result.Log.Count)
            foreach ($logEntry in $result.Log) {
                Write-SMPRSLog -Message $logEntry.Message -Severity $logEntry.Severity -TimeStamp $logEntry.TimeStamp
            }
            Write-SMPRSLog -Severity 1 -Message ('=== END job log for domain {0}' -f $result.FQDN)
        }
        if (-not $result.Success) {
            foreach ($msg in $result.ErrorMessage) {
                Write-SMPRSLog -Severity 2 -Message ('[{0}]: {1}' -f $result.DomainFQDN, $msg)
            }
            continue
        }
        $domPDC = $script:masterData.Forests[$tgtGUID].DomainControllers.Where({$_.NTDSA -eq $result.FSMOPDCe}).Name
        if ($null -ne $domPDC) { $result.FSMOPDCe = $domPDC }
        $domRID = $script:masterData.Forests[$tgtGUID].DomainControllers.Where({$_.NTDSA -eq $result.FSMORID}).Name
        if ($null -ne $domRID) { $result.FSMORID = $domRID }
        $domInfra = $script:masterData.Forests[$tgtGUID].DomainControllers.Where({$_.NTDSA -eq $result.FSMOInfra}).Name
        if ($null -ne $domInfra) { $result.FSMOInfra = $domInfra }
        $domNBT = $script:masterData.Forests[$tgtGUID].Domains.Where({$_.DomainNC -eq $result.DomainNC}).DomainName
        if ($null -ne $domNBT) { $result.DomainName = $domNBT }
        $result.IsExplored = $true
        Write-SMPRSLog -Severity 0 -Message 'Writing domain to datastore'
        $res = $res -and (Update-SMPRSDataStore -DataArea Domain -Data $result)
    }
    Write-SMPRSLog -Severity 1 -Message ('Overall result of domain exploration: {0}' -f $res)
    return $res
}

function Explore-SMPRSDomainController {
    [CmdletBinding(DefaultParameterSetName='Forest')]
    Param(
        [Parameter(Mandatory=$false, ParameterSetName='Forest')]
        [string]$ForestGUID,
        [Parameter(Mandatory=$true, ParameterSetName='List')]
        [string[]]$Targets,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$false)]
        [int]$Timeout = 120,
        [Parameter(Mandatory=$false)]
        [int]$PoolSize = (1 + [System.Environment]::ProcessorCount),
        [Parameter(Mandatory=$false)]
        [switch]$ForceWMI,
        [Parameter(Mandatory=$false)]
        [int]$WinRMPort = 5985,
        [Parameter(Mandatory=$false)]
        [int]$WinRMSecurePort = 5986
    )
    #region ScriptBlock for runspace (outer)
    $scriptBlock = {
        Param(
            [string]$tgtName,
            [string]$Protocol,
            [int]$Port,
            [PSCredential]$Credential
        )
        $stopWatch =  [System.Diagnostics.Stopwatch]::StartNew()
        $result = [PSCustomObject]@{
            'NamePassed' = $tgtName
            'Protocol' = $Protocol
            'UserName' = $null
            'ElapsedSeconds' = 0
            'Data' = $null
            'ErrorMessage' = $null
        }
        if ($null -ne $Credential) {
            $result.UserName = $Credential.UserName
        }
        #region ScriptBlock for exploration (inner)
        $explorationSB = {
            Param(
                [string]$ComputerName,
                [PSCredential]$Credential
            )
            trap { 
                $resData.Errors += ('TRAP on line {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            #region function definitions
            # $reg is used from global scope
            function Test-RegistryKey {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key
                )
                try {
                    return (0 -eq ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue)
                } catch {
                    $resData.Errors += ('Error in Test-RegistryKey {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
            }

            function Get-RegistrySubkeys {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key
                )
                try {
                    $regSubkeys = $reg.EnumKey($HKEY_LOCAL_MACHINE, $Key)
                } catch {
                    $resData.Errors += ('Error in Get-RegistrySubkeys {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
                return $regSubkeys.sNames.Where({$_})
            }

            function Get-RegistryValueNames {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key
                )
                if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $false}
                try {
                    $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
                    return $regValues.sNames
                } catch {
                    $resData.Errors += ('Error in Get-RegistryValueNames {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
            }

            function Test-RegistryValue {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key,
                    [Parameter(Mandatory=$true)]
                    [string]$Value
                )
                if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $false}
                try {
                    $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
                    if ($null -eq $regValues.sNames) {
                        return $false
                    } else {
                        $vi = $regValues.sNames.ToLower().IndexOf($Value.ToLower())
                        return ($vi -ge 0)
                    }
                } catch {
                    $resData.Errors += ('Error in Test-RegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
            }

            function Get-RegistryValue {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key,
                    [Parameter(Mandatory=$true)]
                    [string]$Value
                )
                if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $null}
                try {
                    $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
                    if ($null -eq $regValues.sNames) {
                        return $null
                    } else {
                        $vi = $regValues.sNames.ToLower().IndexOf($Value.ToLower())
                        if ($vi -lt 0) {
                            return $null
                        } else {
                            $regType = $regValues.Types[$vi]
                        }
                    }
                } catch {
                    $resData.Errors += ('Error in Get-RegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
                switch ($regType) {
                    1 {
                        $result = $reg.GetStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
                    }
                    2 {
                        $result = $reg.GetExpandedStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
                    }
                    3 {
                        $result = $reg.GetBinaryValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
                    }
                    4 {
                        $result = $reg.GetDWORDValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
                    }
                    7 {
                        $result = $reg.GetMultiStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
                    }
                    11 {
                        $result = $reg.GetQWORDValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
                    }
                    default {
                        $result = $null
                    }
                }
                return $result
            }

            function Get-SysUserRegistryValue {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Key,
                    [Parameter(Mandatory=$true)]
                    [string]$Value
                )
                $Key = ('S-1-5-18\{0}' -f $Key)
                if (0 -ne ($reg.CheckAccess($HKEY_USERS, $Key, 9)).ReturnValue) { return $null}
                try {
                    $regValues = $reg.EnumValues($HKEY_USERS, $Key)
                    $vi = $regValues.sNames.IndexOf($Value)
                    if ($vi -lt 0) {
                        return $null
                    } else {
                        $regType = $regValues.Types[$vi]
                    }
                } catch {
                    $resData.Errors += ('Error in Get-SysUserRegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    return $null
                }
                switch ($regType) {
                    1 {
                        $result = $reg.GetStringValue($HKEY_USERS, $Key, $Value).sValue
                    }
                    2 {
                        $result = $reg.GetExpandedStringValue($HKEY_USERS, $Key, $Value).sValue
                    }
                    3 {
                        $result = $reg.GetBinaryValue($HKEY_USERS, $Key, $Value).uValue
                    }
                    4 {
                        $result = $reg.GetDWORDValue($HKEY_USERS, $Key, $Value).uValue
                    }
                    7 {
                        $result = $reg.GetMultiStringValue($HKEY_USERS, $Key, $Value).sValue
                    }
                    11 {
                        $result = $reg.GetQWORDValue($HKEY_USERS, $Key, $Value).uValue
                    }
                    default {
                        $result = $null
                    }
                }
                return $result
            }

            function Get-FolderEnumeration {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Path,
                    [Parameter(Mandatory=$false)]
                    [object]$Enumeration
                )
                if ($null -eq $Enumeration) {
                    $Enumeration = [PSCustomObject]@{
                        'Files' = @()
                        'Folders' = @()
                        'FileSize' = 0
                    }
                }
                if ($wmiParms.ContainsKey('ComputerName')) {
                    $startPath = $Path -replace "\\","\\"
                    $qFiles = ('ASSOCIATORS OF {{Win32_Directory.Name="{0}"}} WHERE ResultClass = CIM_DataFile' -f $startPath)
                    $qFolders = ('ASSOCIATORS OF {{Win32_Directory.Name="{0}"}} WHERE AssocClass = Win32_SubDirectory ResultRole = PartComponent' -f $startPath)
                    try {
                        $subFiles = Get-WmiObject -Query $qFiles -EA Stop @wmiParms
                    } catch {
                        $resData.Errors += ('Error in Get-FolderEnumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                        $subFiles = $null
                    }
                    foreach ($zFile in $subFiles) {
                        $Enumeration.Files += $zFile.Name
                        try {
                            $fileObj = Get-WmiObject -Class CIM_DataFile -Filter ('Name="{0}"' -f ($zFile.Name -replace '\\','\\')) -EA Stop @wmiParms
                            $Enumeration.FileSize += $fileObj.FileSize
                        } catch {
                            $resData.Errors += ('Error in Get-FolderEnumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                        }
        
                    }
                    try {
                        $subFolders = Get-WmiObject -Query $qFolders -EA Stop @wmiParms
                    } catch {
                        $resData.Errors += ('Error in Get-FolderEnumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                        $subFolders = $null
                    }
                    foreach ($zFolder in $subFolders) {
                        $Enumeration.Folders += $zFolder.Name
                        $Enumeration = Get-FolderEnumeration -Path $zFolder.Name -Enumeration $Enumeration
                    }
                } else {
                    if (Test-Path -Path $Path -PathType Container) {
                        try {
                            $Enumeration.Folders = (Get-ChildItem -Path $Path -Directory -Recurse -EA Stop).FullName
                            $files = Get-ChildItem -Path $Path -File -Recurse -EA Stop
                            $Enumeration.Files = $files.FullName
                            $Enumeration.FileSize = ($files | Measure-Object -Sum -Property Length).Sum
                        } catch {
                            $resData.Errors += ('Error in Get-FolderEnumeration PS {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                        }
                    }
                }
                return $Enumeration
            }
            
            function Get-FileProperties {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$true)]
                    [string]$Path
                )
                if ($wmiParms.ContainsKey('ComputerName')) {
                    try {
                        $fileObj = Get-WmiObject -Class CIM_DataFile -Filter ('Name="{0}"' -f ($Path -replace '\\','\\')) -EA Stop @wmiParms
                    } catch {
                        $resData.Errors += ('Error in Get-FileProperties WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                        return $null
                    }
                } else {
                    $fileObj = $null
                    if (Test-Path -Path $Path -PathType Leaf) {
                        $fi = Get-Item -Path $Path -Force
                        $fileObj = [PSCustomObject]@{
                            'FileName' = $fi.BaseName 
                            'FileSize' = $fi.Length
                        }
                    }
                }
                return $fileObj
            }

            function Get-PendingReboot {
                $chkValue = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Updates' -Value 'UpdateExeVolatile'
                if (($null -ne $chkValue) -and ($chkValue -ne 0)) { return $true }
                if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations') { return $true }
                if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting') { return $true }
                $svcSubkeys = Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending'
                if ($svcSubkeys.Where({$_ -match '[0-9A-Fa-f]{8}[-]?(?:[0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}'}).Count -gt 0) { return $true }
                if (Test-RegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending') { return $true }
                if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts') { return $true }
                if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain') { return $true }
                if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet') { return $true }
                $oldCN = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Value 'ComputerName'
                $newCN = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Value 'ComputerName'
                if ($oldCN -ne $newCN) { return $true }
                return $false
            }
            
            function Add-LogEntry {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$false, Position=1)]
                    [int]$Severity = 0,
                    [Parameter(Mandatory=$true, Position=0)]
                    [string]$Message
                )
                if ($null -ne $resData.FQDN) { 
                    $machine = $resData.FQDN 
                } elseif (-not [string]::IsNullOrWhiteSpace($ComputerName)) {
                    $machine = $ComputerName
                } else {
                    $machine = [System.Environment]::MachineName
                }
                $resData.Log += [PSCustomObject]@{
                    'Timestamp' = [datetime]::Now
                    'Severity' = $Severity
                    'Message' = ('[{0}] {1}' -f $machine, $Message)
                }
            }
            #endregion function definitions
            #region initialization
            if ($PSVersionTable.PSVersion.Major -gt 5) {
                Add-LogEntry 'PowerShell 7.x detected, adding System.Security.Cryptography explicitly'
                Add-Type -AssemblyName System.Security.Cryptography
            }
            $resData = [PSCustomObject]@{
                'Success' = $true
                'IsExplored' = $true
                'ElapsedSeconds' = $null
                'ProtocolUsed' = $null
                'MachineName' = $null
                'DomainRole' = $null
                'Domain' = $null
                'FQDN' = $null
                'ForestGUID' = $null
                'Manufacturer' = $null
                'Model' = $null
                'HVDynamicMemory' = $null
                'NumCPU' = $null
                'MemoryMB' = $null
                'OSBuild' = $null
                'OSEdition' = $null
                'OSLanguage' = $null
                'SysLocale' = $null
                'SysLocaleName' = $null
                'ServerCore' = $null
                'ServerCoreFeature' = $null
                'TimeZoneOffset' = $null
                'TimeZoneDST' = $null
                'DotNetVersion' = $null
                'DotNetStrongCrypto' = $null
                'DotNetDefaultTLS' = $null
                'NTDSPath' = $null
                'NTDSLogsPath' = $null
                'NTDSLogsCount' = 0
                'NTDSSize' = 0
                'SYSVOLPath' = $null
                'SYSVOLNumFiles' = 0
                'SYSVOLSize' = 0
                'SYSVOLReplicationState' = $null
                'SYSVOLMigrationState' = $null
                'SystemDrive' = $null
                'WindowsPath' = $null
                'RebootPending' = $null
                'ClientAuthTrustMode' = $null
                'NumSystemKeys' = $null
                'SChannelTLS12Server' = $null
                'SChannelTLS12Client' = $null
                'SChannelTLS13Server' = $null
                'SChannelTLS13Client' = $null
                'CipherSuites' = $null
                'FIPSCryptoEnabled' = $null
                'LSAProtected' = $null
                'AuditSubcats' = $null
                'UserInit' = $null
                'ProxyServer' = $null
                'ProxyOverride' = $null
                'SMB1Dependency' = $null
                'RestrictNTLM' = $null
                'PinnedRPCPortNTDS' = $null
                'PinnedRPCPortNetlogon' = $null
                'FieldEngineering' = $null
                'BackupExclusions' = $null
                'DSAHeuristics' = $null
                'NTPLocalProvider' = $null
                'NTPLocalSource' = $null
                'NTPPolicyProvider' = $null
                'NTPPolicySource' = $null
                'ReplicationState' = @()
                'WrongRoots' = @()
                'Networks' = @()
                'Routes' = @()
                'DiskDrives' = @()
                'Firewall' = @()
                'DFSNameSpaces' = @()
                'Features' = @()
                'Antimalware' = @()
                'Errors' = @()
                'Log' = @()
            }
            # known overzealous antimalware
            $avsvc = @{
                'CSFalconService' = 'AVCrowdStrike'
                'cyserver' = 'AVPaloAltoTraps'
                'SentinelAgent' = 'SentinelONE'
            }
            # known interesting features
            $features2check = @(
                'CertificateServices'
                'DHCPServer'
                'WINSRuntime'
            )
            # WMI initialization
            Add-LogEntry -Severity 1 -Message 'Starting Domain Controller exploration'
            Add-LogEntry 'Initializing WMI'
            $wmiParms = @{}
            $wmiReg = $false
            if (-not [string]::IsNullOrWhiteSpace($ComputerName)) {
                $wmiParms = @{
                    'ComputerName' = $ComputerName
                    'Credential' = $Credential
                }
            }
            if ($wmiParms.ContainsKey('ComputerName')) { $cName = $wmiParms['ComputerName'] } else { $cName = '.' }
            if ($wmiParms.ContainsKey('Credential')) { $wCred = $wmiParms['Credential']; $wUser = $wCred.UserName } else { $wCred = $null; $wUser = 'NULL' }
            Add-LogEntry ('Final WMI parameters: Computername={0} Credential={1}' -f $cName, $wUser)
            $HKEY_LOCAL_MACHINE = 2147483650
            $HKEY_USERS = 2147483651
            $mScopePath = ('\\{0}\ROOT\DEFAULT:StdRegProv' -f $cName)
            $mscope = New-Object System.Management.ManagementScope($mScopePath)
            if ($null -ne $wCred) {
                $mscope.Options.Username = $wCred.UserName
                $mscope.Options.Password = $wCred.GetNetworkCredential().Password
            }
            try {
                $mscope.Connect()
                Add-LogEntry 'Management scope connected'
                $reg = New-Object System.Management.ManagementClass($mscope,$mScopePath,$null)
                Add-LogEntry 'Reg object initialized'
                $wmiReg = $true
            } catch {
                Add-LogEntry -Severity 3 -Message ('Error in WMI registry context initialization {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in WMI registry context initialization {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Success = $false
                return $resData
            }
            #endregion
               
            # basic machine data
            Add-LogEntry 'Collecting base data'
            try {
                $wmiCS = Get-WMIObject -Class Win32_ComputerSystem @wmiParms
                $wmiOS = Get-WMIObject -Class Win32_OperatingSystem @wmiParms
                Add-LogEntry 'WMI objects for ComputerSystem and OperatingSystem retrieved'
            } catch {
                $resData.Success = $false
                $resData.Errors += ('Error in basic data WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                return $resData
            }
            # record and evaluate the DomainRole
            $resdata.DomainRole = $wmiCS.DomainRole
            Add-LogEntry ('Domain role: {0}' -f $wmiCS.DomainRole)
            if ($wmiCS.DomainRole -lt 4) {
                $resData.Success = $false
                Add-LogEntry -Severity 3 -Message ('The machine is not a DC and will not be explored (DomainRole={0})' -f $wmiCS.DomainRole)
                $resData.Errors += ('The machine is not a DC and will not be explored (DomainRole={0})' -f $wmiCS.DomainRole)
                return $resData
            }
            # record basic hardware and OS data
            $resData.Domain = $wmiCS.Domain
            $resData.MachineName = $wmiCS.Name
            $resData.FQDN = ('{0}.{1}' -f $wmiCS.Name, $wmiCS.Domain)
            $resData.Manufacturer = $wmiCS.Manufacturer
            $resData.Model = $wmiCS.Model
            $resData.TimeZoneOffset = $wmiCS.CurrentTimeZone
            $resData.TimeZoneDST = $wmiCS.DaylightInEffect
            $resData.NumCPU = $wmiCS.NumberOfLogicalProcessors
            $resData.MemoryMB = [math]::Floor($wmiCS.TotalPhysicalMemory / 1MB) -as [int]
            $resData.OSBuild = $wmiOS.BuildNumber
            $resData.OSLanguage = $wmiOS.OSLanguage
            $resData.SystemDrive = $wmiOS.SystemDrive
            $resData.WindowsPath = $wmiOS.WindowsDirectory
            $resData.RebootPending = Get-PendingReboot
            Add-LogEntry ('Reboot pending: {0}' -f $resData.RebootPending)
            $resData.OSEdition = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'EditionID'
            $resData.SysLocale = Get-SysUserRegistryValue -Key 'Control Panel\International' -Value 'Locale'
            $resData.SysLocaleName = Get-SysUserRegistryValue -Key 'Control Panel\International' -Value 'LocaleName'
            $resData.DotNetVersion = Get-RegistryValue -Key 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Value 'Release'
            $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'InstallationType'
            if ($zVal -eq 'Server Core') {
                $resData.ServerCore = $true
            } else {
                $resData.ServerCore = $false
            }
            try {
                $shellFeat = Get-WmiObject Win32_OptionalFeature -Filter 'Name="Server-Shell"' -EA Stop @wmiParms
                $resData.ServerCoreFeature = ($null -eq $shellFeat)
            } catch {
                Add-LogEntry -Severity 2 -Message ('Error determining Shell feature presence: {0}' -f $_.Exception.Message)
            }
            if (($wmiCS.Manufacturer -like 'Microsoft Corporation') -and ($wmiCS.Model -like 'Virtual Machine')) {
                Add-LogEntry -Severity 1 -Message 'Hyper-V VM detected, checking for dynamic memory...'
                $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Value 'VirtualMachineDynamicMemoryBalancingEnabled'
                $resData.HVDynamicMemory = ($zVal -eq 1)
            }
            # DSA Heuristics
            $resData.DSAHeuristics = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'DSA Heuristics'
            Add-LogEntry ('DSA Heuristics: {0}' -f $resData.DSAHeuristics)
            # NTDS
            $resData.NTDSPath = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'DSA Database file'
            Add-LogEntry ('NTDS Path: {0}' -f $resData.NTDSPath)
            $ntdsFile = Get-FileProperties -Path $resData.NTDSPath
            $resData.NTDSSize = $ntdsFile.FileSize
            Add-LogEntry ('NTDS Size: {0}' -f $resData.NTDSSize)
            $resData.NTDSLogsPath = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'Database log files path'
            Add-LogEntry ('NTDS Logs Path: {0}' -f $resData.NTDSLogsPath)
            $ntdsLogs = Get-FolderEnumeration -Path $resData.NTDSLogsPath -Enumeration $ntdsLogs
            $resData.NTDSLogsCount = $ntdsLogs.Files.Count
            $sysKeys = Get-FolderEnumeration -Path 'C:\ProgramData\Microsoft\Crypto\Keys' -Enumeration $sysKeys
            $resData.NumSystemKeys = $sysKeys.Files.Count
            Add-LogEntry ('System RSA Keys: {0}' -f $resData.NumSystemKeys)
            # SYSVOL
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\LanmanServer\Shares' -Value 'SYSVOL'
            if ($null -ne $zVal) {
                $resData.SYSVOLPath = Split-Path -Path ($zVal.Where({$_.Split('=')[0] -eq 'Path'})[0].Split('=')[1])
            }
            Add-LogEntry ('SYSVOL Path: {0}' -f $resData.SYSVOLPath)
            $svPath = Join-Path -Path $resData.SYSVOLPath -ChildPath 'domain'
            $svFolders = Get-FolderEnumeration -Path $svPath -Enumeration $svFolders
            $resData.SYSVOLNumFiles = $svFolders.Files.Count
            $resData.SYSVOLSize = $svFolders.FileSize
            # SYSVOL Migration State
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\DFSR\Parameters\SysVols\Migrating Sysvols' -Value 'Local State'
            if ($null -ne $zVal) {
                $resData.SYSVOLMigrationState = $zVal
            } else {
                $resData.SYSVOLMigrationState = -1
            }
            Add-LogEntry ('SYSVOL Migration State: {0}' -f $resData.SYSVOLMigrationState)
            # Wrong roots
            Add-LogEntry 'Looking for wrong root certs'
            $RootKeys = @{
                'System' = 'SOFTWARE\Microsoft\SystemCertificates\ROOT\Certificates'
                'Policy' = 'SOFTWARE\Policies\Microsoft\SystemCertificates\Root\Certificates'
            }
            $wrongRoots = @()
            foreach ($rk in $RootKeys.GetEnumerator()) {
                $subkeys = Get-RegistrySubkeys -Key $rk.Value
                foreach ($cert in $subkeys) {
                    $certKey = '{0}\{1}' -f $rk.Value, $cert
                    $blob = Get-RegistryValue -Key $certKey -Value 'Blob'
                    $blob = $blob -as [byte[]]
                    if ($null -ne $blob) {
                        if ($PSVersionTable.PSVersion.Major -le 5) {
                            $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                            $x509Cert.Import($blob)
                        } else {
                            $tempFile = Join-Path -Path $env:TEMP -ChildPath 'cert.tmp'
                            if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile }
                            [IO.File]::WriteAllBytes($tempFile, $blob)
                            $x509Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromCertFile($tempFile)
                            if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile }
                        }
                        if ($x509Cert.Issuer -ne $x509Cert.Subject) {
                            $wrongRoots += ('{0}:[{1}]' -f $rk.Key, $x509Cert.Subject)
                            Add-LogEntry ('Found wrong root cert: {0} [{1}]' -f $rk.Key, $x509Cert.Subject)
                        }
                    }
                }
            }
            $resData.WrongRoots = $wrongRoots
            # client auth trust mode
            Add-LogEntry 'Crypto settings'
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Value 'ClientAuthTrustMode'
            if ($zVal -is [uint32]) {
                $resData.ClientAuthTrustMode = $zVal
            } else {
                $resData.ClientAuthTrustMode = -1
            }
            # crypto
            $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Value 'SchUseStrongCrypto'
            if ($zVal -is [uint32]) {
                $resData.DotNetStrongCrypto = $zVal
            } else {
                $resData.DotNetStrongCrypto = -1
            }
            $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Value 'SystemDefaultTlsVersions'
            if ($zVal -is [uint32]) {
                $resData.DotNetDefaultTLS = $zVal
            } else {
                $resData.DotNetDefaultTLS = -1
            }
            $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Value 'Enabled'
            $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Value 'DisabledByDefault'
            if ($eVal -eq 1) {
                $zVal = 1
            } elseif ($dVal -eq 1) {
                $zVal = 0
            } else {
                $zVal = -1
            }
            $resData.SChannelTLS12Server = $zVal
            $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Value 'Enabled'
            $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Value 'DisabledByDefault'
            if ($eVal -eq 1) {
                $zVal = 1
            } elseif ($dVal -eq 1) {
                $zVal = 0
            } else {
                $zVal = -1
            }
            $resData.SChannelTLS12Client = $zVal
            $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Value 'Enabled'
            $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Value 'DisabledByDefault'
            if ($eVal -eq 1) {
                $zVal = 1
            } elseif ($dVal -eq 1) {
                $zVal = 0
            } else {
                $zVal = -1
            }
            $resData.SChannelTLS13Server = $zVal
            $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -Value 'Enabled'
            $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -Value 'DisabledByDefault'
            if ($eVal -eq 1) {
                $zVal = 1
            } elseif ($dVal -eq 1) {
                $zVal = 0
            } else {
                $zVal = -1
            }
            $resData.SChannelTLS13Client = $zVal
            $resData.CipherSuites = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -Value 'Functions'
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy' -Value 'Enabled'
            if ($zVal -eq 0) {
                $resData.FIPSCryptoEnabled = 0
            } elseif ($zVal -eq 1) {
                $resData.FIPSCryptoEnabled = 1
            } else {
                $resData.FIPSCryptoEnabled = -1
            }
            # pinned RPC ports
            $isPinned = Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'TCP/IP Port'
            if ($isPinned) {
                $resData.PinnedRPCPortNTDS = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'TCP/IP Port'
                Add-LogEntry ('RPC port pinned for NTDS to {0}' -f $resData.PinnedRPCPortNTDS)
            }
            $isPinned = Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Value 'DCTcpipPort'
            if ($isPinned) {
                $resData.PinnedRPCPortNetlogon = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Value 'DCTcpipPort'
                Add-LogEntry ('RPC port pinned for Netlogon to {0}' -f $resData.PinnedRPCPortNetlogon)
            }
            # drives
            Add-LogEntry 'Enumerating disks'
            try {
                $allDisks = Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3' -EA Stop @wmiParms
            } catch {
                $allDisks = null
                Add-LogEntry -Severity 3 -Message ('Error in Disk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in Disk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            foreach ($disk in $allDisks) {
                $resData.DiskDrives += [PSCustomObject]@{
                    'DeviceID' = $disk.DeviceID
                    'Size' = $disk.Size
                    'FreeSpace' = $disk.FreeSpace
                }
            }
            # networks
            Add-LogEntry 'Enumerating networks'
            try {
                $ipConfigs = @(Get-WMIObject  Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -EA Stop @wmiParms)
            } catch {
                $ipConfigs = $null
                Add-LogEntry -Severity 3 -Message ('Error in Networkk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in Network Adapter enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            foreach ($ipc in $ipConfigs) {
                $network = [PSCustomObject]@{
                    'MACAddress' = $ipc.MACAddress
                    'SettingID' = $ipc.SettingID
                    'Alias' = $ipc.ServiceName
                    'Description' = $ipc.Description
                    'DHCPEnabled' = $ipc.DHCPEnabled
                    'NetworkProfile' = $null
                    'DNSServers' = @($ipc | Select-Object -ExpandProperty DNSServerSearchOrder | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
                    'IPConfigs' = @()
                }
                $ipAddrs = @($ipc | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
                $ipMasks = @($ipc | Select-Object -ExpandProperty IPSubnet | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
                $ipGW = @($ipc | Select-Object -ExpandProperty DefaultIPGateway | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
                for ($i = 0; $i -lt $ipAddrs.Count; $i++) {
                    $network.IPConfigs += [PSCustomObject]@{
                        'IPAddress' = $ipAddrs[$i]
                        'SubnetMask' = $ipMasks[$i]
                        'Gateway' = $ipGW[0]
                    }
                }
                try {
                    $netProf = Get-WmiObject -Class MSFT_NetConnectionProfile -Namespace 'root/StandardCimv2' -Filter ('InstanceID="{0}"' -f $ipc.SettingID) -EA Stop @wmiParms
                    $network.Alias = $netProf.InterfaceAlias
                    $network.NetworkProfile = $netProf.NetworkCategory
                } catch {
                    $netProf = $null
                    Add-LogEntry -Severity 3 -Message ('Error in NetConnectionProfile WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    $resData.Errors += ('Error in NetConnectionProfile WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                }
                $resData.Networks += $network
            }
            # system proxy
            Add-LogEntry 'Detecting system proxy'
            $resData.ProxyServer = Get-SysUserRegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -Value 'ProxyServer'
            $resData.ProxyOverride = Get-SysUserRegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -Value 'ProxyOverride'
            # userinit
            Add-LogEntry 'Detecting USERINIT'
            $resData.UserInit = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Value 'UserInit'
            # DFS namespaces
            Add-LogEntry 'Enumerating DFS namespaces'
            $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\Standalone')
            foreach ($ns in $zNS) {
                $resData.DFSNameSpaces += [PSCustomObject]@{
                    'Type' = 'Standalone'
                    'Name' = $ns
                }
            }
            $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\Domain')
            foreach ($ns in $zNS) {
                $resData.DFSNameSpaces += [PSCustomObject]@{
                    'Type' = 'Domain2000'
                    'Name' = $ns
                }
            }
            $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\DomainV2')
            foreach ($ns in $zNS) {
                $resData.DFSNameSpaces += [PSCustomObject]@{
                    'Type' = 'Domain2008'
                    'Name' = $ns
                }
            }
            # SYSVOL replication
            Add-LogEntry 'Investigating SYSVOL replication'
            try {
                $dfsFolders = @(Get-WmiObject -Namespace 'root\MicrosoftDFS' -Class 'DFSRReplicatedFolderInfo' -EA Stop @wmiParms | Where-Object ReplicatedFolderName -eq "SYSVOL Share")
                if ($dfsFolders.Count -eq 0) {
                    $resData.SYSVOLReplicationState = 666
                } else {
                    $resData.SYSVOLReplicationState = $dfsFolders[0].State
                }
            } catch {
                $resData.SYSVOLReplicationState = -1
                Add-LogEntry -Severity 3 -Message ('Error in SYSVOL Replication WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in SYSVOL Replication WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            # LSA Protection
            Add-LogEntry 'Investigating LSA protection'
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa' -Value 'RunAsPPL'
            if ($null -eq $zVal) {
                $zVal = -1
            }
            $resData.LSAProtected = $zVal
            # Audit subcat override
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa' -Value 'SCENoApplyLegacyAuditPolicy'
            if ($null -eq $zVal) {
                $zVal = -1
            }
            $resData.AuditSubcats = $zVal
            # NTLM restrictions
            Add-LogEntry 'Investigating NTLM restrictions'
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Value 'restrictntlmindomain'
            # 0 = all allowed, 1 = domain accts to domain servers, 3 = domain accounts, 5 = domain servers, 7 = all disabled
            if ($null -eq $zVal) {
                $zVal = -1
            }
            $resData.RestrictNTLM = $zVal
            # Antimalware
            Add-LogEntry 'Investigating known antimalware'
            foreach ($svc in $avsvc.Keys) {
                $zSvc = Get-WmiObject -Class Win32_Service -Filter ('Name="{0}"' -f $svc) @wmiParms
                if ($null -ne $zSvc) {
                    $resData.Antimalware += ('{0} ({1}/{2})' -f $avsvc[$svc], $zSvc.StartMode, $zSvc.State)
                }
            }
            # LANMANSERVER depends on Srv
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\LanManServer' -Value 'DependOnService'
            $resData.SMB1Dependency = ($zVal -contains 'Srv')
            # Optional Features
            try {
                $zFeat = Get-WmiObject -Class Win32_OptionalFeature -Filter 'InstallState=1' -EA Stop @wmiParms | Select-Object -ExpandProperty Name
                foreach ($feat in $features2check) {
                    if ($zFeat -contains $feat) {
                        $resData.Features += $feat
                    }
                }
            } catch {
                $resData.Errors += ('Error in Optional Features WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            # Field Engineering Level
            Add-LogEntry 'Investigating Field Engineering level'
            $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics' -Value '15 Field Engineering'
            # 5 = debug, someone watching the LDAP queries
            if ($null -eq $zVal) {
                $zVal = -1
            }
            $resData.FieldEngineering = $zVal
            # Persistent routes
            Add-LogEntry 'Investigating persistent routes'
            try {
                $zRoutes = Get-WmiObject -Class Win32_IP4PersistedRouteTable -Filter "Destination <> '0.0.0.0'" -EA Stop @wmiParms
                foreach($route in $zRoutes) {
                    $resData.Routes += [PSCustomObject]@{
                        'Destination' = $route.Destination
                        'SubnetMask' = $route.Mask
                        'Metric' = $route.Metric1
                        'Gateway' = $route.NextHop
                    }
                }
            } catch {
                $resData.Errors += ('Error in Persistent Routes WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            # firewall config
            Add-LogEntry 'Investigating Windows firewall configuration'
            foreach ($fwProf in @('DomainProfile','PrivateProfile','PublicProfile')) {
                Add-LogEntry ('Profile: {0}' -f $fwProf)
                $regPath = 'SOFTWARE\Policies\Microsoft\WindowsFirewall\{0}' -f $fwProf
                $fwSetting = [PSCustomObject]@{
                    'Profile' = $fwProf
                    'Policy' = Test-RegistryKey -Key $regPath
                    'Enabled' = $null
                    'InboundMode' = $null
                    'OutboundMode' = $null
                    'MergeLocal' = $null
                }
                if ($fwSetting.Policy) {
                    $zVal = Get-RegistryValue -Key $regPath -Value 'AllowLocalPolicyMerge'
                    $fwSetting.MergeLocal = (0 -ne $zVal)
                } else {
                    $regPath = 'SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\{0}' -f $fwProf
                }
                $zVal = Get-RegistryValue -Key $regPath -Value 'EnableFirewall'
                $fwSetting.Enabled = (0 -ne $zVal)
                $zVal = Get-RegistryValue -Key $regPath -Value 'DefaultInboundAction'
                if ($zVal -ne $null) {
                    $fwSetting.InboundMode = $zVal
                } else {
                    $fwSetting.InboundMode = -1
                }
                $zVal = Get-RegistryValue -Key $regPath -Value 'DefaultOutboundAction'
                if ($zVal -ne $null) {
                    $fwSetting.OutboundMode = $zVal
                } else {
                    $fwSetting.OutboundMode = -1
                }
            
                $resData.Firewall += $fwSetting
            }
            # NTP
            $resData.NTPLocalProvider = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Value 'Type'
            $resData.NTPLocalSource = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Value 'NtpServer'
            if (Test-RegistryKey -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters') {
                $resData.NTPPolicyProvider = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters' -Value 'Type'
                $resData.NTPPolicySource = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters' -Value 'NtpServer'
            }
            # replication state
            Add-LogEntry 'Checking AD replication state'
            $ctxArgs = @(
                [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer
            )
            if (-not [string]::IsNullOrWhiteSpace($ComputerName)) {
                $ctxArgs += $ComputerName
                if ($null -ne $Credential) {
                    $ctxArgs += $Credential.UserName
                    $ctxArgs += $Credential.GetNetworkCredential().Password
                }
            } else {
                $ctxArgs += [Environment]::MachineName
            }
            try {
                $ctxConn = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($ctxArgs)
                $dc = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($ctxConn)
            } catch {
                $dc = $null
                Add-LogEntry -Severity 3 -Message ('Error in GetDomainControllers {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in GetDomainControllers {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            if ($null -ne $dc) {
                try {
                    $rns = $dc.GetAllReplicationNeighbors()
                } catch {
                    $rns = $null
                    Add-LogEntry -Severity 3 -Message ('Error in GetAllReplicationNeighbors {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                    $resData.Errors += ('Error in GetAllReplicationNeighbors {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                }
                foreach ($rn in $rns) {
                    $out = [PSCustomObject]@{
                        'Partition' = $rn.PartitionName
                        'FromServer' = $rn.SourceServer
                        'ToServer' = $dc.Name
                        'Result' = $rn.LastSyncResult
                        'LastAttempt' = $rn.LastAttemptedSync
                        'LastSync' = $rn.LastSuccessfulSync
                        'Message' = $null
                        'FailureCount' = $rn.ConsecutiveFailureCount
                    }
                    if ($out.Result -ne 0) {
                        $out.Message = $rn.LastSyncMessage
                    }
                    $resData.ReplicationState += $out
                }
            }
            # backup exclusions
            Add-LogEntry -Message 'Checking for backup exclusions'
            if (Test-RegistryKey -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup') {
                Add-LogEntry -Message 'FilesNotToBackup key found'
                $values = @(Get-RegistryValueNames -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup')
                Add-LogEntry -Message ('Found {0} values' -f $values.Count)
                if ($values.Count -gt 0) {
                    $resData.BackupExclusions = @{}
                }
                foreach ($value in $values) {
                    $lines = Get-RegistryValue -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup' -Value $value
                    $resData.BackupExclusions.Add($value, $lines)
                }
            }
            
            # sayonara
            Add-LogEntry -Severity 1 -Message ('Finished Domain Controller exploration')
            return $resData
        }
        #endregion ScriptBlock for exploration (inner)
        $psParm = @{
            'ComputerName' = $tgtName
            'Port' = $Port 
            'Authentication' = 'Kerberos'
            'ScriptBlock' = $explorationSB
            'ErrorAction' = 'Stop'
        }
        if ($nuill -ne $Credential) {
            $psParm.Add('Credential', $Credential)    
        }
        if ($Protocol -eq 'WMI') {
            # remote WMI investigation
            try {
                $result.Data = $explorationSB.Invoke($tgtName, $Credential)
            } catch {
                $result.ErrorMessage = ('Error exploring {0} by WMI: {1}' -f $tgtName, $_.Exception.Message)
            }
        } elseif ($Protocol -eq 'WINRMS') {
            # PSRemoting investigation with SSL
            try {
                $result.Data = Invoke-Command -UseSSL @psParm
            } catch {
                $result.ErrorMessage = ('Error exploring {0} by WinRM/SSL: {1}' -f $tgtName, $_.Exception.Message)
            }
        } else {
            # PSRemoting investigation
            try {
                $result.Data = Invoke-Command @psParm
            } catch {
                $result.ErrorMessage = ('Error exploring {0} by WinRM: {1}' -f $tgtName, $_.Exception.Message)
            }
        }
        $stopWatch.Stop()
        $result.ElapsedSeconds = $stopWatch.Elapsed.TotalSeconds
        return $result
    }
    #endregion ScriptBlock for runspace (outer)
    #region Creating runspace pool
    #2do run connectivity check first and then resize pool so that WinRM is always executed in parallel
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $PoolSize)
    $pool.ApartmentState = [System.Threading.ApartmentState]::MTA
    $pool.Open()
    $runspaces = @()
    $results = @()
    #endregion

    Write-SMPRSLog -Severity 1 -Message 'Runspace pool created, adding exploration threads'
    #region establishing targets
    if ($PSCmdlet.ParameterSetName -eq 'Forest') {
        Write-SMPRSLog -Severity 1 -Message ('Enumerating DCs for forest [{0}]' -f $ForestGUID)
        if ($null -eq ($ForestGUID -as [guid])) {
            if ($script:masterData.Forests.Count -ne 1) {
                Write-SMPRSLog -Severity 2 -Message ('Cannot identify forest without GUID because there are {0} forests in the dataset!' -f $script:masterData.Forests.Count)
                return $false
            } else {
                $tgtGUID = $script:masterData.Forests[$script:masterData.Forests.GetEnumerator()[0].Name].ForestGUID
            }
        } else {
            $tgtGUID = '{{{0}}}' -f ($ForestGUID -as [guid]).Guid.ToUpper()
            if (-not $script:masterData.Forests.ContainsKey($tgtGUID)) {
                Write-SMPRSLog -Severity 2 -Message ('Forest not found by GUID: {0}' -f $tgtGUID)
                return $false
            }
        }
        $Targets = $script:masterData.Forests[$tgtGUID].DomainControllers.FQDN
    } else {
        Write-SMPRSLog -Severity 1 -Message ('Enumerating DCs from list: {0}' -f ($Targets -join ', '))
        $Targets = ($Targets | Select-Object -Unique)
    }
    Write-SMPRSLog -Severity 1 -Message ('Starting Domain Controller exploration for {0} targets and {1} runspace pool size' -f $Targets.Count, $PoolSize)
    Write-SMPRSLog -Severity 1 -Message ('WMI forced: {0}' -f $ForceWMI)
    
    if ($Targets.Count -eq 0) {
        Write-SMPRSLog -Severity 2 -Message 'No targets identified'
        return $false
    }
    #endregion

    #region Creating runspaces
    $res = $true
    $tgtCount = 0
    foreach ($tgt in $Targets) {
        Write-SMPRSLog -Severity 1 -Message ('Testing connectivity to DC {0}' -f $tgt)
        $tgtCount++
        Write-Progress -Id 0 -Activity 'Exploring DCs: Creating jobs' -Status ('{1}/{2} Checking connectivity to {0}' -f $tgt, $tgtCount, $Targets.Count) -PercentComplete ($tgtCount * 100 / $Targets.Count)
        if ($ForceWMI) {
            $dcConn = Test-DCConnection -ComputerName $tgt -Credential $Credential -Protocol WMI
        } else {
            $dcConn = Test-DCConnection -ComputerName $tgt -Credential $Credential -Protocol WMI,WinRM,WinRMS -WinRMPort $WinRMPort -WinRMSecurePort $WinRMSecurePort -PreferInsecureWinRM
        }
        if ($dcConn.WinRMS -and (($dcConn.PSVersion -as [int]) -ge 5)) {
            $proto = 'WinRMS'
            $tgtName = $dcConn.FQDN
            $port = $WinRMSecurePort
        } elseif ($dcConn.WinRM -and (($dcConn.PSVersion -as [int]) -ge 5)) {
            $proto = 'WinRM'
            $tgtName = $dcConn.FQDN
            $port = $WinRMPort
        } elseif ($dcConn.WMI) {
            $proto = 'WMI'
            $tgtName = $tgt
            $port = 0
        } else {
            Write-SMPRSLog -Severity 2 -Message ('No protocol accessible for {0}' -f $tgt)
            continue
        }
        
        if ($dcConn.WMI -and $ForceWMI) {
            $proto = 'WMI'
            $tgtName = $tgt
            $port = 0
        }
        Write-SMPRSLog -Severity 1 -Message ('Target name: {0} on protocol {1}' -f $tgtName, $proto)
        
    
        Write-Progress -Id 0 -Activity 'Exploring DCs: Creating jobs' -Status ('{1}/{2} Adding {0} on protocol {3}' -f $tgtName, $tgtCount, $Targets.Count, $proto) -PercentComplete ($tgtCount * 100 / $Targets.Count)
        $runspace = [PowerShell]::Create()
        $null = $runspace.AddScript($scriptBlock)
        $null = $runspace.AddArgument($tgtName)
        $null = $runspace.AddArgument($proto)
        $null = $runspace.AddArgument($port)
        if ($null -ne $Credential) {
            $null = $runspace.AddArgument($Credential)
        }
        $runspace.RunspacePool = $pool
        $runspaces += [PSCustomObject]@{ 
            'Pipe' = $runspace
            'Status' = $runspace.BeginInvoke()
            'RunUntil' = [datetime]::Now.AddSeconds($Timeout)
            'Finished' = $false
        }
    }
    Write-Progress -Id 0 -Activity 'Exploring DCs: Jobs are running' -PercentComplete 100 -Completed
    #endregion

    #region Get results and clean up runspaces
    $rsCount = $runspaces.Count
    if ($rsCount -gt 0) {
        Write-Progress -Id 0 -Activity 'Receiving exploration results back from DCs' -Status ('0/{0} completed' -f $rsCount) -PercentComplete 0
        $rsCompleted = 0
        $rsTimedOut = 0
        Write-SMPRSLog -Severity 1 -Message 'Waiting for 3 seconds'
        Start-Sleep -Seconds 3
        Write-SMPRSLog -Severity 1 -Message 'Getting the runspaces back'
        do {
            $rsRunning = 0
            $rsCounter = 0
            foreach ($runspace in $runspaces ) {
                $rsCounter++
                Write-SMPRSLog -Severity 0 -Message ('Runspace {0}/{1}' -f $rsCounter,  $rsCount)
                if ($runspace.Finished) { 
                    Write-SMPRSLog -Severity 0 -Message ('Runspace {0} is finished' -f $rsCounter)
                    continue 
                }
                if ($runspace.Status.IsCompleted) {
                    Write-SMPRSLog -Severity 0 -Message ('Runspace {0}: Receiving results...' -f $rsCounter)
                    $rsResult = $runspace.Pipe.EndInvoke($runspace.Status)
                    if (-not [string]::IsNullOrWhiteSpace($rsResult.ErrorMessage)) {
                        $errmsg = (' Error: {0}' -f $rsResult.ErrorMessage)
                    } else {
                        $errmsg = $null
                    }
                    Write-SMPRSLog -Severity 0 -Message ('Runspace {0}: Elapsed seconds: {1}{2}' -f $rsCounter, $rsResult.ElapsedSeconds, $errmsg)
                    $results += $rsResult
                    $runspace.Pipe.Dispose()
                    $rsCompleted++
                    $runspace.Finished = $true
                } elseif ($runspace.RunUntil -lt [datetime]::Now) {
                    $runspace.Pipe.Dispose()
                    $rsTimedout++
                    $runspace.Finished = $true
                } else {
                    $rsRunning++
                }
            }
            Write-Progress -Id 0 -Activity 'Receiving exploration results back from DCs' -Status ('{1}/{0} completed: {2} finished, {3} timed out' -f $rsCount, ($rsCompleted + $rsTimedOut), $rsCompleted, $rsTimedOut) -PercentComplete (($rsCompleted + $rsTimedOut) * 100/$rsCount)
            Write-SMPRSLog -Message ('Receiving exploration results back from DCs: {1}/{0} completed: {2} finished, {3} timed out' -f $rsCount, ($rsCompleted + $rsTimedOut), $rsCompleted, $rsTimedOut)
            if ($rsRunning -gt 0) { Start-Sleep -Milliseconds 500 }
        } until ($rsRunning -eq 0)
        Write-Progress -Id 0 -Activity 'Receiving results' -PercentComplete 100 -Completed
        Write-SMPRSLog -Severity 1 -Message 'All runspaces have finished or timed out'
    } else {
        Write-SMPRSLog -Severity 2 -Message 'No runspaces have been created'
    }
    #endregion

    #region close pool
    $pool.Close()
    $pool.Dispose()
    #endregion

    #region write results to database
    if ($rsCount -gt 0) {
        Write-SMPRSLog -Severity 1 -Message '===== BEGIN DC EXPLORATION LOGS ====='
        if ([string]::IsNullOrWhiteSpace($ForestGUID) -and (-not [string]::IsNullOrWhiteSpace($script:CurrentForestGUID))) {
            $ForestGUID = $script:CurrentForestGUID
        }
        foreach ($result in $results) {
            if ($result.Data.Log.Count -gt 0) {
                foreach ($logEntry in $result.Data.Log) {
                    Write-SMPRSLog -Message $logEntry.Message -Severity $logEntry.Severity -TimeStamp $logEntry.TimeStamp
                }
            }
            if ($result.Data.PSObject.Properties.Name.Contains('Log')) { $result.Data.PSObject.Properties.Remove('Log') }
            if (-not $result.Data.Success) { continue }
            $result.Data.PSobject.Properties.Remove('PSComputerName')
            $result.Data.PSobject.Properties.Remove('PSShowComputerName')
            $result.Data.PSobject.Properties.Remove('RunspaceID')
            $result.Data.ElapsedSeconds = $result.ElapsedSeconds
            $result.Data.ProtocolUsed = $result.Protocol
            $result.Data.IsExplored = $true
            if ([string]::IsNullOrWhiteSpace($result.Data.ForestGUID) -and ($null -ne ($ForestGUID -as [guid]))) {
                $result.Data.ForestGUID = $ForestGUID
            }
            $updateRes = Update-SMPRSDataStore -DataArea DomainController -Data $result.Data
            if ($updateRes) {
                Write-SMPRSLog -Severity 1 -Message 'MasterData update successful'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'MasterData update failed'
                $res = $false
            }
        }
        Write-SMPRSLog -Severity 1 -Message '===== END DC EXPLORATION LOGS ====='
    }
    #endregion
    return $res
}

function Explore-SMPRSForest {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential        ,
        [Parameter(Mandatory=$false)]
        [switch]$PassThru
    )
    Write-SMPRSLog -Severity 1 -Message ('Starting forest exploration at: {0}' -f $ComputerName)
    $rootDSE = Get-RootDSE -ComputerName $ComputerName
    Write-SMPRSLog -Severity 0 -Message ('RootDSE success: {0}' -f $rootDSE.Success)
    $ValidDNSRecordClasses = (0..21) + (24..25) + (28..30) + (33..35) + (39..43) + (46..52)
    $result = [PSCustomObject]@{
        'Parameters' = [PSCustomObject]@{
            'ComputerName' = $ComputerName
            'Credential' = if ($null -ne $Credential) { $Credential.UserName } else { $null }
        }
        'Success' = $rootDSE.Success
        'ExplorationDate' = [datetime]::Now
        'ExplorationFrom' = [System.Environment]::MachineName
        'ExplorationBy' = [System.Environment]::UserName
        'TargetFQDN' = $rootDSE.FQDN
        'TargetDomain' = $rootDSE.Domain
        'TargetHostName' = $rootDSE.HostName
        'ForestRootDomain' = $rootdse.RootDomain
        'ForestRootNC' = $rootDSE.RootNC
        'ForestFL' = $rootDSE.FFL
        'ForestSID' = $null
        'ForestSIDHash' = $null
        'ForestGUID' = $null
        'FSMOSchema' = $null
        'FSMONaming' = $null
        'ConfigNC' = $rootDSE.ConfigNC
        'SchemaNC' = $rootDSE.SchemaNC
        'Heuristics' = $null
        'TombstoneLifetime' = $null
        'DeletedLifetime' = $null
        'FeatureRecycleBin' = $null
        'FeaturePIM' = $null
        'Feature32K' = $null
        'SchemaVersion' = $null
        'SchemaExchange' = $null
        'SchemaSkype' = $null
        'SchemaLapsLegacy' = $null
        'SchemaLapsWindows' = $null
        'SchemaClassActive' = $null
        'SchemaClassDefunct' = $null
        'SchemaAttributeActive' = $null
        'SchemaAttributeDefunct' = $null
        'SchemaOIDOverlap' = @()
        'ExchangeForestConfiguration' = $null
        'QueryPolicies' = @()
        'AdminSettings' = @()
        'Sites' = @()
        'Domains' = @()
        'Partitions' = @()
        'DomainControllers' = @()
        'ReplicationLinks' = @()
        'ErrorMessage' = $rootDSE.ErrorMessage
    }
    if (-not $rootDSE.Success) { return $result }
    Write-SMPRSLog -Severity 0 -Message 'RootDSE test successful, checking DC connectivity'
    $dcConn = Test-DCConnection -ComputerName $ComputerName -Credential $Credential -Protocol LDAP,LDAPS
    if (-not ($dcConn.LDAP -or $dcConn.LDAPS))  { 
        $result.Success = $false
        $result.ErrorMessage = ('Neither LDAP nor LDAPS to {0} were successful' -f $ComputerName)
        Write-SMPRSLog -Severity 2 -Message ('Neither LDAP nor LDAPS to {0} were successful' -f $ComputerName)
        return $result 
    } else {
        $useLDAPS = $dcConn.LDAPS
        Write-SMPRSLog -Severity 0 -Message ('Will use LDAPS: {0}' -f $useLDAPS)
    }
    if ($dcConn.DNS -and (-not [string]::IsNullOrWhiteSpace(($dcConn.FQDN)))) {
        $ldapTarget = $dcConn.FQDN
    } else {
        $ldapTarget = $ComputerName
    }
    Write-SMPRSLog -Severity 0 -Message ('LDAP target: {0}' -f $ldapTarget)
    $ldapParms = @{
        'Server' = $ldapTarget
        'Credential' = $Credential
        'UseLDAPS' = $useLDAPS 
    }
    #2do revisit this to connect to a root DC in order to enumerate the root domain (referral chasing seems to work but better not take any chances)
    $rootDomain = Get-DSObject -ObjectDN $result.ForestRootNC @ldapParms
    if (-not $rootDomain.Success) {
        $result.Success = $false
        $result.ErrorMessage = $rootDomain.ErrorMessage
        Write-SMPRSLog -Severity 2 -Message $rootDomain.ErrorMessage
        return $result
    }
    $rdDSE = $rootDomain.DSEntry
    $result.ForestSID = ConvertTo-SID ($rdDSE.Properties['objectSID'][0])
    Write-SMPRSLog -Severity 0 -Message ('Forest SID: {0}' -f $result.ForestSID)
    $result.ForestGUID = ConvertTo-GUID ($rdDSE.Properties['objectGUID'][0]) -AddBraces -Uppercase
    Write-SMPRSLog -Severity 0 -Message ('Forest GUID: {0}' -f $result.ForestGUID)
    $result.ForestSIDHash = Get-SMPRSSIDHash -SID $result.ForestSID
    Write-SMPRSLog -Severity 0 -Message ('Forest SID hashed: {0}' -f $result.ForestSIDHash)

    $script:CurrentForestGUID = $result.ForestGUID

    $schemaDSE = Get-DSObject -ObjectDN $result.SchemaNC @ldapParms
    if ($schemaDSE.Success) {
        $result.SchemaVersion = $schemaDSE.DSEntry.Properties['objectVersion'][0]
        Write-SMPRSLog -Severity 0 -Message ('Schema version: {0}' -f $result.SchemaVersion)
        $result.FSMOSchema = $schemaDSE.DSEntry.Properties['fSMORoleOwner'][0]
        Write-SMPRSLog -Severity 0 -Message ('Schema master: {0}' -f $result.FSMOSchema)
        $schClasses = @(Get-DSChildren -ParentDN $result.SchemaNC -LDAPFilter '(&(objectClass=classSchema)(!(isDefunct=TRUE)))' -NamesOnly @ldapParms)
        $schClassesDef = @(Get-DSChildren -ParentDN $result.SchemaNC -LDAPFilter '(&(objectClass=classSchema)(isDefunct=TRUE))' -NamesOnly @ldapParms)
        $result.SchemaClassActive = $schClasses.Count
        $result.SchemaClassDefunct = $schClassesDef.Count
        $schAttr = @(Get-DSChildren -ParentDN $result.SchemaNC -LDAPFilter '(&(objectClass=attributeSchema)(!(isDefunct=TRUE)))' -SearchResults -Properties @('name','attributeID','rangeUpper') @ldapParms)
        $schAttrDef = @(Get-DSChildren -ParentDN $result.SchemaNC -LDAPFilter '(&(objectClass=attributeSchema)(isDefunct=TRUE))' -SearchResults -Properties @('name','attributeID') @ldapParms)
        $result.SchemaAttributeActive = $schAttr.Count
        $result.SchemaAttributeDefunct = $schAttrDef.Count
        Write-SMPRSLog -Severity 0 -Message ('Schema classes: {0}/{1} attributes: {2}/{3}' -f $schClasses.Count, $schClassesDef.Count, $schAttr.Count, $schAttrDef.Count)
        $oids = @{}
        foreach ($attr in ($schAttr + $schAttrDef)) {
            if ($oids.ContainsKey($attr.properties['attributeID'][0])) {
                $result.SchemaOIDOverlap += ('{0}: {1} - {2}' -f $attr.properties['attributeID'][0], $oids[$attr.properties['attributeID'][0]], $attr.properties['name'][0])
            } else {
                $oids.Add($attr.properties['attributeID'][0],$attr.properties['name'][0])
            }
            if (-not $result.SchemaLapsWindows -and ($attr.properties['name'][0] -eq 'ms-LAPS-Password')) {
                $result.SchemaLapsWindows = $true
            }
            if (-not $result.SchemaLapsLegacy -and ($attr.properties['name'][0] -eq 'ms-Mcs-AdmPwd')) {
                $result.SchemaLapsLegacy = $true
            }
            if ($attr.properties['name'][0] -eq 'ms-Exch-Schema-Version-Pt') {
                $result.SchemaExchange = $attr.properties['rangeUpper'][0]
            }
            if ($attr.properties['name'][0] -eq 'ms-RTC-SIP-Schemaversion') {
                $result.SchemaSkype = $attr.properties['rangeUpper'][0]
            }
        }
        Write-SMPRSLog -Severity 0 -Message ('Schema OID overlaps: {0}' -f $result.SchemaOIDOverlap.Count)
        if ($result.SchemaLapsWindows -ne $true) { $result.SchemaLapsWindows = $false }
        if ($result.SchemaLapsLegacy -ne $true) { $result.SchemaLapsLegacy = $false }
        if ($result.SchemaExchange -eq $null) { $result.SchemaExchange = -1 }
        if ($result.SchemaSkype -eq $null) { $result.SchemaSkype = -1 }
    }

    # partitions, naming master and optional features
    $partsDN = ('CN=Partitions,{0}' -f $result.ConfigNC)
    $partsDSE = Get-DSObject -ObjectDN $partsDN @ldapParms
    if ($partsDSE.Success) {
        Write-SMPRSLog -Severity 0 -Message ('Partitions container found: {0}' -f $partsDN)
        $result.FSMONaming = $partsDSE.DSEntry.Properties['fSMORoleOwner'][0]
        Write-SMPRSLog -Severity 0 -Message ('Naming master: {0}' -f $result.FSMONaming)
        $enabledFeatures = $partsDSE.DSEntry.Properties['msDS-EnabledFeature']
        Write-SMPRSLog -Severity 0 -Message ('{0} enabled features' -f $enabledFeatures.Count)
        foreach ($feature in $enabledFeatures) {
            $feDSE = Get-DSObject -ObjectDN $feature @ldapParms
            Write-SMPRSLog -Severity 0 -Message ('Checking enabled feature {0}' -f $feature)
            if ($feDSE.Success) {
                $fguid = ConvertTo-GUID -InputValue $feDSE.DSEntry.Properties['msDS-OptionalFeatureGUID'][0]
                if ($fguid -eq '766ddcd8-acd0-445e-f3b9-a7f9b6744f2a') {
                    $result.FeatureRecycleBin = $true
                } elseif ($fguid -eq 'ec43e873-cce8-4640-b4ab-07ffe4ab5bcd') {
                    $result.FeaturePIM = $true
                } elseif ($fguid -eq '52982ac6-1e73-754f-ae24-73ae2775aab8') {
                    $result.Feature32K = $true
                }
            } else {
                Write-SMPRSLog -Severity 2 -Message ('Could not open enabled feature {0}' -f $feature)
            }
        }
        if ($null -eq $result.FeatureRecycleBin) { $result.FeatureRecycleBin = $false }
        Write-SMPRSLog -Severity 0 -Message ('Recycle Bin enabled: {0}' -f $result.FeatureRecycleBin)
        if ($null -eq $result.FeaturePIM) { $result.FeaturePIM = $false }
        Write-SMPRSLog -Severity 0 -Message ('PIM enabled: {0}' -f $result.FeaturePIM)
        if ($null -eq $result.Feature32K) { $result.Feature32K = $false }
        Write-SMPRSLog -Severity 0 -Message ('32K pages enabled: {0}' -f $result.Feature32K)
        $partsList = @(Get-DSChildren -ParentDN $partsDN -LDAPFilter '(objectClass=crossRef)' @ldapParms)
        Write-SMPRSLog -Severity 0 -Message ('Read {0} partitions' -f $partsList.Count)
        foreach ($part in $partsList) {
            Write-SMPRSLog -Severity 0 -Message ('Analyzing partition {0}' -f $part.nCName[0])
            $isDomain = (($part.systemFlags[0] -band 2) -gt 0)
            $isGCR = (($part.systemFlags[0] -band 4) -eq 0)
            $curPart = [PSCustomObject]@{
                'IsDomain' = $isDomain
                'IsGCReplicated' = $isGCR
                'Name' = $part.nCName[0]
                'DomainName' = if($isDomain) { $part.nETBIOSName[0] } else { $null }
                'DomainFQDN' = if($isDomain) { $part.dnsRoot[0] } else { $null }
                'DNSRecordClasses' = @()
                'BadDNSRecords' = @()
            }
            if ($isDomain) {
                Write-SMPRSLog -Severity 0 -Message 'Partition is a domain'
                $domFromGC = Get-DSObject -ObjectDN $part.nCName[0] -UseGC @ldapParms
                $result.Domains += [PSCustomObject]@{
                    'IsExplored' = $false
                    'DomainName' = $part.nETBIOSName[0]
                    'DomainFQDN' = $part.dnsRoot[0]
                    'DomainNC' = $part.nCName[0]
                    'DomainFL' = $part.'msDS-Behavior-Version'[0]
                    'DomainGUID' = (ConvertTo-GUID -InputValue ($domFromGC.DSEntry.Properties['objectGUID'][0]) -Uppercase -AddBraces)
                    'ForestGUID' = $result.ForestGUID
                    'GPOs' = @()
                }
            } else {
                Write-SMPRSLog -Severity 0 -Message 'Partition is not a domain'
                $dnsRecords = @(Get-DSChildren -ParentDN $curPart.Name -LDAPFilter '(&(objectClass=dnsNode)(dnsRecord=*))' -SearchSubtree -SearchResults -Properties @('dnsRecord','distinguishedName') @ldapParms)
                Write-SMPRSLog -Severity 0 -Message ('Found {0} DNS records' -f $dnsRecords.Count)
                $rcs =  New-Object System.Collections.Generic.HashSet[int]
                foreach ($recObj in $dnsRecords) {
                    foreach ($rec in $recObj.Properties['dnsRecord']) {
                        $rClass = $rec[3]*256 + $rec[2]
                        if ($rClass -notin $ValidDNSRecordClasses) {
                            Write-SMPRSLog -Severity 2 -Message ('Invalid DNS record type for {0}: {1}' -f $recObj.Properties['distinguishedName'][0], $rClass)
                            $curPart.BadDNSRecords += [PSCustomObject]@{
                                'Name' = ($recObj.Properties['distinguishedName'][0] -split '\,CN\=')[0]
                                'RTYPE' = $rClass
                            }
                        }
                        $null = $rcs.Add($rClass)
                    }
                }
                $curPart.DNSRecordClasses = [array]$rcs
            }
            $result.Partitions += $curPart
        }
    } else {
        Write-SMPRSLog -Severity 2 -Message ('Partitions container NOT found: {0}' -f $partsDN)
    }
    # exchange forest config
    Write-SMPRSLog -Severity 0 -Message 'Looking for Exchange config containers'
    $exchConfig = @(Get-DSChildren -ParentDN $result.ConfigNC -LDAPFilter '(objectClass=msExchOrganizationContainer)' -SearchSubtree @ldapParms)
    Write-SMPRSLog -Severity 0 -Message ('Found {0} Exchange config containers' -f $exchConfig.Count)
    $result.ExchangeForestConfiguration = -1
    if ($exchConfig.Count -gt 0) {
        foreach ($exOrgCnt in $exchConfig) {
            if ($result.ExchangeForestConfiguration -lt ($exOrgCnt.objectVersion[0] -as [int])) { $result.ExchangeForestConfiguration = ($exOrgCnt.objectVersion[0] -as [int]) }
        }
    }

    # dsHeuristics, admin settings, tombstone and rbin lifetime
    Write-SMPRSLog -Severity 0 -Message 'Analyzing NTDS Service configuration'
    $ntdsSvc = @(Get-DSChildren -ParentDN $result.ConfigNC -LDAPFilter '(objectClass=nTDSService)' -SearchSubtree -Properties @('dsHeuristics','TombstoneLifetime','msDS-DeletedObjectLifetime','msDS-Other-Settings') @ldapParms)
    if ($ntdsSvc.Count -gt 0) {
        $result.Heuristics = $ntdsSvc[0].dsHeuristics[0]
        Write-SMPRSLog -Severity 0 -Message ('dsHeuristics: {0}' -f $result.Heuristics)
        $result.TombstoneLifetime = $ntdsSvc[0].tombstoneLifetime[0]
        Write-SMPRSLog -Severity 0 -Message ('Tombstone Lifetime: {0}' -f $result.TombstoneLifetime)
        if ($result.FeatureRecycleBin) {
            if ($null -eq $ntdsSvc[0].'msDS-DeletedObjectLifetime'[0]) { 
                $result.DeletedLifetime = -1 
            } else {
                $result.DeletedLifetime = $ntdsSvc[0].'msDS-DeletedObjectLifetime'[0]
                Write-SMPRSLog -Severity 0 -Message ('Deleted Object Lifetime: {0}' -f $result.DeletedLifetime)
            }
        }
        foreach ($setting in $ntdsSvc[0].'msDS-Other-Settings') {
            $result.AdminSettings += [PSCustomObject]@{
                'Name' = ($setting -split '\=')[0]
                'Value' = ($setting -split '\=')[1]
            }
        }
    } else {
        Write-SMPRSLog -Severity 2 -Message ('NTDS Service not found under {0}' -f $result.ConfigNC)
    }

    # query policies
    Write-SMPRSLog -Severity 0 -Message 'Analyzing query policies'
    $qPols = @(Get-DSChildren -ParentDN $result.ConfigNC -LDAPFilter '(objectClass=queryPolicy)' -SearchSubtree @ldapParms)
    foreach ($qpol in $qPols) {
        $qPolObj = [PSCustomObject]@{
            'Name' = $qpol.name[0]
            'DN' = $qpol.distinguishedName[0]
            'AdminLimits' = @()
            'IPDenyList' = @()
        }
        foreach ($setting in $qpol.lDAPAdminLimits) {
            $qPolObj.AdminLimits += [PSCustomObject]@{
                'Name' = ($setting -split '\=')[0]
                'Value' = ($setting -split '\=')[1]
            }
        }
        foreach ($entry in $qpol.lDAPIPDenyList) {
            $qPolObj.IPDenyList += [System.Text.Encoding]::ASCII.GetString($entry)
        }
        $result.QueryPolicies += $qPolObj
    }

    # sites and dcs
    Write-SMPRSLog -Severity 0 -Message 'Analyzing sites and DC NTDS objects'
    $sitesCont = @(Get-DSChildren -ParentDN $result.ConfigNC -LDAPFilter '(objectClass=sitesContainer)' @ldapParms)
    if ($sitesCont.Count -eq 1) {
        $sitesContDN = $sitesCont[0].distinguishedName[0]
        $subnetsCont = @(Get-DSChildren -ParentDN $sitesContDN -LDAPFilter '(objectClass=subnetContainer)' @ldapParms)
        if ($subnetsCont.Count -eq 1) {
            $subnetsContDN = $subnetsCont[0].distinguishedName[0]
        } else {
            $subnetsContDN = $null
        }
        $sitesList = @(Get-DSChildren -ParentDN $sitesContDN -LDAPFilter '(objectClass=site)' @ldapParms)
        Write-SMPRSLog -Severity 0 -Message ('Found {0} sites' -f $sitesList.Count)
        foreach ($site in $sitesList) {
            Write-SMPRSLog -Severity 0 -Message ('Analyzing site {0}' -f $site.name[0])
            $siteNTDS = @(Get-DSChildren -ParentDN $site.distinguishedName[0] -LDAPFilter '(objectClass=nTDSSiteSettings)' @ldapParms)
            if ($siteNTDS.Count -gt 0) {
                $uniGMC = (($siteNTDS[0].options[0] -band 32) -gt 0)
            } else {
                $uniGMC = $null
            }
            if ($null -ne $subnetsContDN) {
                $snCount = @(Get-DSChildren -ParentDN $subnetsContDN -LDAPFilter ('(&(objectClass=subnet)(siteObject={0}))' -f $site.distinguishedName[0]) @ldapParms).Count
            } else {
                $snCount = $null
            }
            if ($siteNTDS.queryPolicyObject.Count -gt 0) {
                $qPol = $siteNTDS.queryPolicyObject[0]   
            } else {
                $qPol = $null
            }
            $result.Sites += [PSCustomObject]@{
                'Name' = $site.name[0]
                'LinkedGPO' = @($site.gpLink[0] -split "\]\[").Where({-not [string]::IsNullOrWhiteSpace($_)}).Count
                'DN' = $site.distinguishedName[0]
                'UniGroupMC' = $uniGMC
                'SubnetCount' = $snCount
                'QueryPolicy' = $qPol
            }
            Write-SMPRSLog -Severity 0 -Message 'Listing servers in site'
            $srvColl = @(Get-DSChildren -ParentDN $site.distinguishedName[0] -LDAPFilter '(objectClass=server)' -SearchSubtree @ldapParms)
            Write-SMPRSLog -Severity 0 -Message ('Found {0} servers' -f $srvColl.Count)
            foreach ($srv in $srvColl) {
                Write-SMPRSLog -Severity 0 -Message ('Recording server {0}' -f $srv.Name[0])
                $dc = [PSCustomObject]@{
                    'IsExplored' = $false
                    'ForestGUID' = $result.ForestGUID
                    'Name' = $srv.name[0]
                    'Site' = $site.name[0]
                    'Domain' = $null
                    'Version' = $null
                    'IsGC' = $null
                    'IsRODC' = $null
                    'OSBuild' = $null
                    'FSMORoles' = @()
                    'FQDN' = $srv.dnsHostName[0]
                    'DN' = $srv.serverReference[0]
                    'NTDSA' = $null
                    'QueryPolicy' = $null
                    'ReplicationEpoch' = $null
                    'HostedNCs' = @()
                }
                Write-SMPRSLog -Severity 0 -Message 'Getting the server NTDS-DSA'
                $srvNTDS = @(Get-DSChildren -ParentDN $srv.distinguishedName[0] -LDAPFilter '(objectClass=nTDSDSA)' @ldapParms)
                if ($srvNTDS.Count -gt 0) {
                    $dc.NTDSA = $srvNTDS[0].distinguishedName[0]
                    if ($srvNTDS.queryPolicyObject.Count -gt 0) {
                        $qPol = $srvNTDS.queryPolicyObject[0]   
                    } else {
                        $qPol = $null
                    }
                    $dc.QueryPolicy = $qPol
                    $dc.HostedNCs = $srvNTDS[0].hasMasterNCs
                    $dc.Version = $srvNTDS[0].'msDS-Behavior-Version'[0]
                    $dc.ReplicationEpoch = $srvNTDS[0].'msDS-ReplicationEpoch'[0]
                    $dc.IsGC = (($srvNTDS[0].options[0] -band 1) -gt 0)
                    $dc.IsRODC = ((($srvNTDS[0].options[0] -band 4) -gt 0) -and (($srvNTDS[0].options[0] -band 32) -gt 0))
                    $dcDomain = $result.Domains.Where({$_.DomainNC -eq $srvNTDS[0].'msDS-HasDomainNCs'[0]})
                    if ($dcDomain.Count -gt 0) {
                        $dc.Domain = $dcDomain[0].DomainFQDN
                    }
                    if ($result.FSMONaming -eq $srvNTDS[0].distinguishedName[0]) {
                        $result.FSMONaming = $srv.dnsHostName[0]
                        $dc.FSMORoles += 'Naming'
                    }
                    if ($result.FSMOSchema -eq $srvNTDS[0].distinguishedName[0]) {
                        $result.FSMOSchema = $srv.dnsHostName[0]
                        $dc.FSMORoles += 'Schema'
                    }
                    $ntdsConns = @(Get-DSChildren -ParentDN  $srvNTDS[0].distinguishedName[0] -LDAPFilter '(objectClass=nTDSConnection)' @ldapParms)
                    if ($ntdsConns.Count -gt 0) {
                        foreach ($ntdsConn in $ntdsConns) {
                            $ntdsConnItem = [PSCustomObject]@{
                                'ToDC' = $srvNTDS[0].distinguishedName[0]
                                'FromDC' = $ntdsConn.fromServer[0]
                                'Options' = $ntdsConn.options[0]
                            }
                            $result.ReplicationLinks += $ntdsConnItem
                        }
                    }
                }
                Write-SMPRSLog -Severity 0 -Message 'Adding DC record to result'
                $result.DomainControllers += $dc
            }
        }
    }
    Write-SMPRSLog -Severity 1 -Message 'Updating forest data'
    $updateRes = Update-SMPRSDataStore -DataArea Forest -Data $result
    if ($updateRes) {
        Write-SMPRSLog -Severity 1 -Message 'MasterData update for Forest successful'
    } else {
        Write-SMPRSLog -Severity 2 -Message 'MasterData update for Forest failed'
    }
    foreach ($dom in $result.Domains) {
        if ($script:masterData.Domains.ContainsKey($dom.DomainGUID)) {
            Write-SMPRSLog -Severity 0 -Message ('Domain record for GUID {0} already in database!' -f $dom.DomainGUID)
        } else {
            Write-SMPRSLog -Severity 0 -Message ('Adding domain record for GUID {0}' -f $dom.DomainGUID)
            $updateRes = Update-SMPRSDataStore -DataArea Domain -Data $dom
            if ($updateRes) {
                Write-SMPRSLog -Severity 1 -Message 'MasterData update for Domain successful'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'MasterData update for Domain failed'
            }
        }
    }
    foreach ($dc in $result.DomainControllers) {
        if ($script:masterData.Domains.ContainsKey($dc.FQDN)) {
            Write-SMPRSLog -Severity 0 -Message ('DC record for {0} already in database!' -f $dc.FQDN)
        } else {
            Write-SMPRSLog -Severity 0 -Message ('Adding DC record for {0}' -f $dc.FQDN)
            $updateRes = Update-SMPRSDataStore -DataArea DomainController -Data $dc
            if ($updateRes) {
                Write-SMPRSLog -Severity 1 -Message 'MasterData update for DC successful'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'MasterData update for DC failed'
            }
        }
    }
    if ($PassThru) {
        return $result
    }
}

function Explore-SMPRSLocalMachine {
    [CmdletBinding()]
    Param()
    if (-not (Test-Elevation)) {
        Write-SMPRSLog -Severity 2 -Message 'Local Machine exploration requires elevation!'
        return $false
    }
    Write-SMPRSLog -Severity 1 'Enumerating basic WMI information'
    try {
        $wmiCS = Get-WMIObject -Class Win32_ComputerSystem
        $wmiOS = Get-WMIObject -Class Win32_OperatingSystem
    } catch {
        Write-SMPRSLog -Severity 3 -Message ('Error in basic data WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        return $false
    }
    if ($wmiCS.DomainRole -le 1) {
        Write-SMPRSLog -Severity 1 -Message 'This machine is a workstation so will not be explored'
        return $true
    } elseif ($wmiCS.DomainRole -ge 4) {
        #dev shortcut: DCs will not be explored as local machines
        Write-SMPRSLog -Severity 1 -Message 'This machine is a domain controller, will not explore'
        return $false

        # 2do revisit and maybe remove the DC specific parts altogether
        Write-SMPRSLog -Severity 1 -Message 'This machine is a domain controller, checking if the forest it belongs to has already been explored...'
        $ownForests = $script:masterData.Forests.Values.Where({($_.Domains.DomainFQDN -eq $wmiCS.Domain) -and ($_.DomainControllers.Name -eq [Environment]::MachineName)})
        if ($ownForests.Count -eq 0) {
             Write-SMPRSLog -Severity 2 -Message 'No forests have been discovered yet that contain this machine''s domain and name'
             return $false
        }
    }
    #region function definitions
    # $reg is used from global scope
    function Test-RegistryKey {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key
        )
        try {
            return (0 -eq ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue)
        } catch {
            $resData.Errors += ('Error in Test-RegistryKey {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
    }

    function Get-RegistrySubkeys {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key
        )
        try {
            $regSubkeys = $reg.EnumKey($HKEY_LOCAL_MACHINE, $Key)
        } catch {
            $resData.Errors += ('Error in Get-RegistrySubkeys {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
        return $regSubkeys.sNames.Where({$_})
    }

    function Get-RegistryValueNames {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key
        )
        if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $false}
        try {
            $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
            return $regValues.sNames
        } catch {
            $resData.Errors += ('Error in Get-RegistryValueNames {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
    }

    function Test-RegistryValue {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
        if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $false}
        try {
            $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
            if ($null -eq $regValues.sNames) {
                return $false
            } else {
                $vi = $regValues.sNames.ToLower().IndexOf($Value.ToLower())
                return ($vi -ge 0)
            }
        } catch {
            $resData.Errors += ('Error in Test-RegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
    }

    function Get-RegistryValue {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
        if (0 -ne ($reg.CheckAccess($HKEY_LOCAL_MACHINE, $Key, 9)).ReturnValue) { return $null}
        try {
            $regValues = $reg.EnumValues($HKEY_LOCAL_MACHINE, $Key)
            if ($null -eq $regValues.sNames) {
                return $null
            } else {
                $vi = $regValues.sNames.ToLower().IndexOf($Value.ToLower())
                if ($vi -lt 0) {
                    return $null
                } else {
                    $regType = $regValues.Types[$vi]
                }
            }
        } catch {
            $resData.Errors += ('Error in Get-RegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
        switch ($regType) {
            1 {
                $result = $reg.GetStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
            }
            2 {
                $result = $reg.GetExpandedStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
            }
            3 {
                $result = $reg.GetBinaryValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
            }
            4 {
                $result = $reg.GetDWORDValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
            }
            7 {
                $result = $reg.GetMultiStringValue($HKEY_LOCAL_MACHINE, $Key, $Value).sValue
            }
            11 {
                $result = $reg.GetQWORDValue($HKEY_LOCAL_MACHINE, $Key, $Value).uValue
            }
            default {
                $result = $null
            }
        }
        return $result
    }

    function Get-SysUserRegistryValue {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Key,
            [Parameter(Mandatory=$true)]
            [string]$Value
        )
        $Key = ('S-1-5-18\{0}' -f $Key)
        if (0 -ne ($reg.CheckAccess($HKEY_USERS, $Key, 9)).ReturnValue) { return $null}
        try {
            $regValues = $reg.EnumValues($HKEY_USERS, $Key)
            $vi = $regValues.sNames.IndexOf($Value)
            if ($vi -lt 0) {
                return $null
            } else {
                $regType = $regValues.Types[$vi]
            }
        } catch {
            $resData.Errors += ('Error in Get-SysUserRegistryValue {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            return $null
        }
        switch ($regType) {
            1 {
                $result = $reg.GetStringValue($HKEY_USERS, $Key, $Value).sValue
            }
            2 {
                $result = $reg.GetExpandedStringValue($HKEY_USERS, $Key, $Value).sValue
            }
            3 {
                $result = $reg.GetBinaryValue($HKEY_USERS, $Key, $Value).uValue
            }
            4 {
                $result = $reg.GetDWORDValue($HKEY_USERS, $Key, $Value).uValue
            }
            7 {
                $result = $reg.GetMultiStringValue($HKEY_USERS, $Key, $Value).sValue
            }
            11 {
                $result = $reg.GetQWORDValue($HKEY_USERS, $Key, $Value).uValue
            }
            default {
                $result = $null
            }
        }
        return $result
    }

    function Get-FolderEnumeration {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Path,
            [Parameter(Mandatory=$false)]
            [object]$Enumeration
        )
        if ($null -eq $Enumeration) {
            $Enumeration = [PSCustomObject]@{
                'Files' = @()
                'Folders' = @()
                'FileSize' = 0
            }
        }
        if (Test-Path -Path $Path -PathType Container) {
            try {
                $Enumeration.Folders = (Get-ChildItem -Path $Path -Directory -Recurse -EA Stop).FullName
                $files = Get-ChildItem -Path $Path -File -Recurse -EA Stop
                $Enumeration.Files = $files.FullName
                $Enumeration.FileSize = ($files | Measure-Object -Sum -Property Length).Sum
            } catch {
                $resData.Errors += ('Error in Get-FolderEnumeration PS {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
        }
        return $Enumeration
    }
            
    function Get-FileProperties {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory=$true)]
            [string]$Path
        )
        $fileObj = $null
        if (Test-Path -Path $Path -PathType Leaf) {
            $fi = Get-Item -Path $Path -Force
            $fileObj = [PSCustomObject]@{
                'FileName' = $fi.BaseName 
                'FileSize' = $fi.Length
            }
        }
        return $fileObj
    }

    function Get-PendingReboot {
        $chkValue = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Updates' -Value 'UpdateExeVolatile'
        if (($null -ne $chkValue) -and ($chkValue -ne 0)) { return $true }
        if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations') { return $true }
        if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting') { return $true }
        $svcSubkeys = Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending'
        if ($svcSubkeys.Where({$_ -match '[0-9A-Fa-f]{8}[-]?(?:[0-9A-Fa-f]{4}[-]?){3}[0-9A-Fa-f]{12}'}).Count -gt 0) { return $true }
        if (Test-RegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending') { return $true }
        if (Test-RegistryKey -Key 'SOFTWARE\Microsoft\ServerManager\CurrentRebootAttempts') { return $true }
        if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain') { return $true }
        if (Test-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet') { return $true }
        $oldCN = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Value 'ComputerName'
        $newCN = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Value 'ComputerName'
        if ($oldCN -ne $newCN) { return $true }
        return $false
    }
    #endregion
    #region constants
    $res = $true
    $nStages = 15
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Preparing the environment' -PercentComplete 0
    if ($PSVersionTable.PSVersion.Major -gt 5) {
        Write-SMPRSLog -Severity 0 -Message 'PowerShell 7, loading System.Security.Cryptography assembly explicitly...'
        Add-Type -AssemblyName System.Security.Cryptography
    }
    # known overzealous antimalware
    $avsvc = @{
        'CSFalconService' = 'AVCrowdStrike'
        'cyserver' = 'AVPaloAltoTraps'
        'SentinelAgent' = 'SentinelONE'
    }
    Write-SMPRSLog -Severity 1 -Message ('{0} overzealous antimalware items: {1}' -f $avsvc.Count, ($avsvc.Values -join ', '))
    #supported browsers
    $SupportedBrowsers = @('Google Chrome','Microsoft Edge')
    Write-SMPRSLog -Severity 1 -Message ('{0} supported browsers: {1}' -f $SupportedBrowsers.Count, ($SupportedBrowsers.Values -join ', '))
    # known interesting features (for Domain Controllers)
    $features2check = @(
        'CertificateServices'
        'DHCPServer'
        'WINSRuntime'
    )
    Write-SMPRSLog -Severity 1 -Message ('{0} feature of interest items: {1}' -f $features2check.Count, ($features2check -join ', '))
    #endregion
    # WMI init
    $HKEY_LOCAL_MACHINE = 2147483650
    $HKEY_USERS = 2147483651
    $mScopePath = '\\.\ROOT\DEFAULT:StdRegProv'
    $mscope = New-Object System.Management.ManagementScope($mScopePath)
    try {
        $mscope.Connect()
        $reg = New-Object System.Management.ManagementClass($mscope,$mScopePath,$null)
    } catch {
        Write-SMPRSLog -Severity 3 -Message ('Error in WMI registry context initialization {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        return $false
    }
    $resDataDef = @{
        'Success' = $true
        'ElapsedSeconds' = $null
        'MachineName' = [Environment]::MachineName
        'DomainRole' = $null
        'Domain' = $null
        'FQDN' = $null
        'Manufacturer' = $null
        'Model' = $null
        'NumCPU' = $null
        'MemoryMB' = $null
        'HVDynamicMemory' = $null
        'OSBuild' = $null
        'OSEdition' = $null
        'OSLanguage' = $null
        'SysLocale' = $null
        'SysLocaleName' = $null
        'UserLanguage' = $null
        'ServerCore' = $null
        'ServerCoreFeature' = $null
        'TimeZoneOffset' = $null
        'TimeZoneDST' = $null
        'DotNetVersion' = $null
        'DotNetStrongCrypto' = $null
        'DotNetDefaultTLS' = $null
        'SystemDrive' = $null
        'WindowsPath' = $null
        'RebootPending' = $null
        'ClientAuthTrustMode' = $null
        'SChannelTLS12Server' = $null
        'SChannelTLS12Client' = $null
        'SChannelTLS13Server' = $null
        'SChannelTLS13Client' = $null
        'CipherSuites' = $null
        'FIPSCryptoEnabled' = $null
        'ProxyServer' = $null
        'ProxyOverride' = $null
        'RestrictNTLM' = $null
        'NTPLocalProvider' = $null
        'NTPLocalSource' = $null
        'NTPPolicyProvider' = $null
        'NTPPolicySource' = $null
        'SQLInstance' = $null
        'ImageHealth' = $null
        'WrongRoots' = @()
        'Networks' = @()
        'Routes' = @()
        'DiskDrives' = @()
        'Firewall' = @()
        'Antimalware' = @()
        'Errors' = @()
        'Log' = @()
    }
    if ($wmiCS.DomainRole -ge 4) {
        $dataArea = 'DomainController'
        $resDataDef += @{
            'ForestGUID' = $null
            'NTDSPath' = $null
            'NTDSLogsPath' = $null
            'NTDSLogsCount' = 0
            'NTDSSize' = 0
            'SYSVOLPath' = $null
            'SYSVOLNumFiles' = 0
            'SYSVOLSize' = 0
            'SYSVOLReplicationState' = $null
            'NumSystemKeys' = $null
            'LSAProtected' = $null
            'AuditSubcats' = $null
            'UserInit' = $null
            'SMB1Dependency' = $null
            'BackupExclusions' = $null
            'DSAHeuristics' = $null
            'ReplicationState' = @()
            'DFSNameSpaces' = @()
        }
    } else {
        $dataArea = 'LocalMachine'
        $resDataDef += @{
            'LocalUserNames' = @()
            'Browsers' = @()
        }
    }
    Write-SMPRSLog -Severity 1 -Message ('Data Area: {0}' -f $dataArea)
    $resData = [PSCustomObject]$resDataDef
    $resdata.DomainRole = $wmiCS.DomainRole
    Write-SMPRSLog -Severity 1 -Message ('Domain role: {0}' -f $wmiCS.DomainRole)
    if ($wmiCS.PartOfDomain) {
        $resData.Domain = $wmiCS.Domain
        $resData.FQDN = ('{0}.{1}' -f $wmiCS.Name, $wmiCS.Domain)
    } else {
        $resData.Domain = $wmiCS.Workgroup
    }
    # record basic hardware and OS data
    $stage = 1
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording basic data' -PercentComplete ($stage * 100 / $nStages)

    $resData.Manufacturer = $wmiCS.Manufacturer
    $resData.Model = $wmiCS.Model
    $resData.TimeZoneOffset = $wmiCS.CurrentTimeZone
    $resData.TimeZoneDST = $wmiCS.DaylightInEffect
    $resData.NumCPU = $wmiCS.NumberOfLogicalProcessors
    $resData.MemoryMB = [math]::Floor($wmiCS.TotalPhysicalMemory / 1MB) -as [int]
    $resData.OSBuild = $wmiOS.BuildNumber
    $resData.OSLanguage = $wmiOS.OSLanguage
    $resData.SystemDrive = $wmiOS.SystemDrive
    $resData.WindowsPath = $wmiOS.WindowsDirectory
    $resData.UserLanguage = (Get-UICulture).LCID
    $resData.RebootPending = Get-PendingReboot
    Write-SMPRSLog ('Reboot pending: {0}' -f $resData.RebootPending)
    $resData.OSEdition = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'EditionID'
    $resData.SysLocale = Get-SysUserRegistryValue -Key 'Control Panel\International' -Value 'Locale'
    $resData.SysLocaleName = Get-SysUserRegistryValue -Key 'Control Panel\International' -Value 'LocaleName'
    
    $stage = 2
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording .NET version data' -PercentComplete ($stage * 100 / $nStages)

    $resData.DotNetVersion = Get-RegistryValue -Key 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Value 'Release'
    $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Value 'InstallationType'
    if ($zVal -eq 'Server Core') {
        $resData.ServerCore = $true
    } else {
        $resData.ServerCore = $false
    }
    try {
        $shellFeat = Get-WmiObject Win32_OptionalFeature -Filter 'Name="Server-Shell"' -EA Stop
        $resData.ServerCoreFeature = ($null -eq $shellFeat)
    } catch {
        Write-SMPRSLog -Severity 2 -Message ('Error determining Shell feature presence: {0}' -f $_.Exception.Message)
    }
    if (($wmiCS.Manufacturer -like 'Microsoft Corporation') -and ($wmiCS.Model -like 'Virtual Machine')) {
        Write-SMPRSLog -Severity 1 -Message 'Hyper-V VM detected, checking for dynamic memory...'
        $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' -Value 'VirtualMachineDynamicMemoryBalancingEnabled'
        $resData.HVDynamicMemory = ($zVal -eq 1)
    }
    #DC specific checks
    Write-SMPRSLog -Severity 1 -Message 'Performing DC-specific checks'
    if ($wmics.DomainRole -ge 4) {
        # forestGUID
        $rootDSE = Get-RootDSE -ComputerName $resdata.FQDN
        $rootDomain = Get-DSObject -ObjectDN $rootDSE.RootNC
        $resData.ForestGUID = ConvertTo-GUID ($rootDomain.DSEntry.Properties['objectGUID'][0]) -AddBraces -Uppercase
        Write-SMPRSLog ('Forest GUID: {0}' -f $resData.ForestGUID)
        # DSA Heuristics
        $resData.DSAHeuristics = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'DSA Heuristics'
        Write-SMPRSLog ('DSA Heuristics: {0}' -f $resData.DSAHeuristics)
        # NTDS
        $resData.NTDSPath = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'DSA Database file'
        Write-SMPRSLog ('NTDS Path: {0}' -f $resData.NTDSPath)
        $ntdsFile = Get-FileProperties -Path $resData.NTDSPath
        $resData.NTDSSize = $ntdsFile.FileSize
        Write-SMPRSLog ('NTDS Size: {0}' -f $resData.NTDSSize)
        $resData.NTDSLogsPath = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Value 'Database log files path'
        Write-SMPRSLog ('NTDS Logs Path: {0}' -f $resData.NTDSLogsPath)
        $ntdsLogs = Get-FolderEnumeration -Path $resData.NTDSLogsPath -Enumeration $ntdsLogs
        $resData.NTDSLogsCount = $ntdsLogs.Files.Count
        $sysKeys = Get-FolderEnumeration -Path 'C:\ProgramData\Microsoft\Crypto\Keys' -Enumeration $sysKeys
        $resData.NumSystemKeys = $sysKeys.Files.Count
        Write-SMPRSLog ('System RSA Keys: {0}' -f $resData.NumSystemKeys)
        # SYSVOL
        $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\LanmanServer\Shares' -Value 'SYSVOL'
        if ($null -ne $zVal) {
            $resData.SYSVOLPath = Split-Path -Path ($zVal.Where({$_.Split('=')[0] -eq 'Path'})[0].Split('=')[1])
        }
        Write-SMPRSLog ('SYSVOL Path: {0}' -f $resData.SYSVOLPath)
        $svPath = Join-Path -Path $resData.SYSVOLPath -ChildPath 'domain'
        $svFolders = Get-FolderEnumeration -Path $svPath -Enumeration $svFolders
        $resData.SYSVOLNumFiles = $svFolders.Files.Count
        $resData.SYSVOLSize = $svFolders.FileSize
        # userinit
        Write-SMPRSLog 'Detecting USERINIT'
        $resData.UserInit = Get-RegistryValue -Key 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Value 'UserInit'
        # DFS namespaces
        Write-SMPRSLog 'Enumerating DFS namespaces'
        $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\Standalone')
        Write-SMPRSLog ('{0} standalone namespaces' -f $zNS.Count)
        foreach ($ns in $zNS) {
            $resData.DFSNameSpaces += [PSCustomObject]@{
                'Type' = 'Standalone'
                'Name' = $ns
            }
        }
        $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\Domain')
        Write-SMPRSLog ('{0} domain legacy namespaces' -f $zNS.Count)
        foreach ($ns in $zNS) {
            $resData.DFSNameSpaces += [PSCustomObject]@{
                'Type' = 'Domain2000'
                'Name' = $ns
            }
        }
        $zNS = @(Get-RegistrySubkeys -Key 'SOFTWARE\Microsoft\DFS\Roots\DomainV2')
        Write-SMPRSLog ('{0} domain modern namespaces' -f $zNS.Count)
        foreach ($ns in $zNS) {
            $resData.DFSNameSpaces += [PSCustomObject]@{
                'Type' = 'Domain2008'
                'Name' = $ns
            }
        }
        # SYSVOL replication
        Write-SMPRSLog 'Investigating SYSVOL replication'
        try {
            $dfsFolders = @(Get-WmiObject -Namespace 'root\MicrosoftDFS' -Class 'DFSRReplicatedFolderInfo' -EA Stop | Where-Object ReplicatedFolderName -eq "SYSVOL Share")
            if ($dfsFolders.Count -eq 0) {
                $resData.SYSVOLReplicationState = 666
            } else {
                $resData.SYSVOLReplicationState = $dfsFolders[0].State
            }
        } catch {
            $resData.SYSVOLReplicationState = -1
            Write-SMPRSLog -Severity 3 -Message ('Error in SYSVOL Replication WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            $resData.Errors += ('Error in SYSVOL Replication WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        }
        Write-SMPRSLog ('SYSVOL replication state: {0}' -f $resData.SYSVOLReplicationState)
        # LSA Protection
        Write-SMPRSLog 'Investigating LSA protection'
        $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa' -Value 'RunAsPPL'
        if ($null -eq $zVal) {
            $zVal = -1
        }
        $resData.LSAProtected = $zVal
        # Audit subcat override
        Write-SMPRSLog 'Recording audit subcategory override'
        $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa' -Value 'SCENoApplyLegacyAuditPolicy'
        if ($null -eq $zVal) {
            $zVal = -1
        }
        $resData.AuditSubcats = $zVal
        # LANMANSERVER depends on Srv
        Write-SMPRSLog 'Recording dependency of LANMANSERVER on SMB1'
        $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\LanManServer' -Value 'DependOnService'
        $resData.SMB1Dependency = ($zVal -contains 'Srv')
        # Optional Features
        Write-SMPRSLog 'Recording optional features of interest'
        try {
            $zFeat = Get-WmiObject -Class Win32_OptionalFeature -Filter 'InstallState=1' -EA Stop | Select-Object -ExpandProperty Name
            foreach ($feat in $features2check) {
                if ($zFeat -contains $feat) {
                    $resData.Features += $feat
                }
            }
        } catch {
            $resData.Errors += ('Error in Optional Features WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        }
        # replication state
        Write-SMPRSLog 'Checking AD replication state'
        $ctxArgs = @(
            [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::DirectoryServer
            [Environment]::MachineName
        )
    
        try {
            $ctxConn = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($ctxArgs)
            $dc = [System.DirectoryServices.ActiveDirectory.DomainController]::GetDomainController($ctxConn)
        } catch {
            $dc = $null
            Write-SMPRSLog -Severity 3 -Message ('Error in GetDomainControllers {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            $resData.Errors += ('Error in GetDomainControllers {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        }
        if ($null -ne $dc) {
            try {
                $rns = $dc.GetAllReplicationNeighbors()
            } catch {
                $rns = $null
                Write-SMPRSLog -Severity 3 -Message ('Error in GetAllReplicationNeighbors {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
                $resData.Errors += ('Error in GetAllReplicationNeighbors {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            }
            Write-SMPRSLog ('Replication Neighbors: {0}' -f $rns.Count)
            foreach ($rn in $rns) {
                $out = [PSCustomObject]@{
                    'Partition' = $rn.PartitionName
                    'FromServer' = $rn.SourceServer
                    'ToServer' = $dc.Name
                    'Result' = $rn.LastSyncResult
                    'LastAttempt' = $rn.LastAttemptedSync
                    'LastSync' = $rn.LastSuccessfulSync
                    'Message' = $null
                    'FailureCount' = $rn.ConsecutiveFailureCount
                }
                if ($out.Result -ne 0) {
                    $out.Message = $rn.LastSyncMessage
                }
                $resData.ReplicationState += $out
            }
        }
        # backup exclusions
        Write-SMPRSLog -Message 'Checking for backup exclusions'
        if (Test-RegistryKey -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup') {
            Write-SMPRSLog -Message 'FilesNotToBackup key found'
            $values = @(Get-RegistryValueNames -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup')
            Write-SMPRSLog -Message ('Found {0} values' -f $values.Count)
            if ($values.Count -gt 0) {
                $resData.BackupExclusions = @{}
            }
            foreach ($value in $values) {
                $lines = Get-RegistryValue -Key 'System\CurrentControlSet\Control\BackupRestore\FilesNotToBackup' -Value $value
                $resData.BackupExclusions.Add($value, $lines)
            }
        }
    } else {
        # non-dc specific checks
        $stage = 3
        Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording supported browsers' -PercentComplete ($stage * 100 / $nStages)

        Write-SMPRSLog -Severity 1 -Message 'Performing member-specific checks'
        Write-SMPRSLog 'Recording local user names'
        $resData.LocalUserNames = (Get-LocalUser | where {(($_.SID.Value -split "\-")[-1] -as [int]) -ge 1000}).Name

        Write-SMPRSLog 'Recording supported browsers'
        foreach ($regPath in @('SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall','SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall')) {
            $appSubkeys = Get-RegistrySubkeys -Key $regPath
            foreach ($subkey in $appSubkeys) {
                $appRegPath = ('{0}\{1}' -f $regPath, $subKey)
                Write-SMPRSLog -Severity 0 -Message ('Checking for supported browsers in {0}' -f $appRegPath)
                if (Test-RegistryValue -Key $appRegPath -Value 'DisplayName') {
                    $appName = Get-RegistryValue -Key $appRegPath -Value 'DisplayName'
                    Write-SMPRSLog -Severity 0 -Message ('Found application: {0}' -f $appName)
                    if ($appName -in $SupportedBrowsers) {
                        $appVersion = Get-RegistryValue -Key $appRegPath -Value 'DisplayVersion'
                        Write-SMPRSLog -Severity 1 -Message ('Found supported browser: {0} version {1}' -f $appName, $appVersion)
                        $resData.Browsers += [PSCustomObject]@{
                            'Name' = $appName
                            'Version' = $appVersion
                        }
                    }
                }
            }
        }
    }
    # image health
    $stage = 4
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Checking integrity of the Windows image... this will take a while' -PercentComplete ($stage * 100 / $nStages)

    try {
        $oldPP = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        $imageHealth = Repair-WindowsImage -ScanHealth -Online -EA Stop
        $ProgressPreference = $oldPP
        Write-SMPRSLog -Severity 0 -Message ('Image health: {0} ({1})' -f $imageHealth.ImageHealthState.value__, $imageHealth.ImageHealthState)
        $resData.ImageHealth = $imageHealth.ImageHealthState.value__
    } catch {
        Write-SMPRSLog -Severity 3 -Message $_.Exception.Message
        $resData.ImageHealth = -1
    }

    # Wrong roots
    $stage = 6
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording possible issues with cert-based auth' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Looking for wrong root certs'    
    $RootKeys = @{
        'System' = 'SOFTWARE\Microsoft\SystemCertificates\ROOT\Certificates'
        'Policy' = 'SOFTWARE\Policies\Microsoft\SystemCertificates\Root\Certificates'
    }
    $wrongRoots = @()
    foreach ($rk in $RootKeys.GetEnumerator()) {
        $subkeys = Get-RegistrySubkeys -Key $rk.Value
        foreach ($cert in $subkeys) {
            $certKey = '{0}\{1}' -f $rk.Value, $cert
            $blob = Get-RegistryValue -Key $certKey -Value 'Blob'
            $blob = $blob -as [byte[]]
            if ($null -ne $blob) {
                if ($PSVersionTable.PSVersion.Major -le 5) {
                    $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                    $x509Cert.Import($blob)
                } else {
                    $tempFile = Join-Path -Path $env:TEMP -ChildPath 'cert.tmp'
                    if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile }
                    [IO.File]::WriteAllBytes($tempFile, $blob)
                    $x509Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromCertFile($tempFile)
                    if (Test-Path -Path $tempFile) { Remove-Item -Path $tempFile }
                }
                if ($x509Cert.Issuer -ne $x509Cert.Subject) {
                    $wrongRoots += ('{0}:[{1}]' -f $rk.Key, $x509Cert.Subject)
                    Write-SMPRSLog ('Found wrong root cert: {0} [{1}]' -f $rk.Key, $x509Cert.Subject)
                }
            }
        }
    }
    $resData.WrongRoots = $wrongRoots
    # client auth trust mode
    Write-SMPRSLog 'Crypto settings'
    $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL' -Value 'ClientAuthTrustMode'
    if ($zVal -is [uint32]) {
        $resData.ClientAuthTrustMode = $zVal
    } else {
        $resData.ClientAuthTrustMode = -1
    }
    # crypto
    $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Value 'SchUseStrongCrypto'
    if ($zVal -is [uint32]) {
        $resData.DotNetStrongCrypto = $zVal
    } else {
        $resData.DotNetStrongCrypto = -1
    }
    $zVal = Get-RegistryValue -Key 'SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Value 'SystemDefaultTlsVersions'
    if ($zVal -is [uint32]) {
        $resData.DotNetDefaultTLS = $zVal
    } else {
        $resData.DotNetDefaultTLS = -1
    }
    $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Value 'Enabled'
    $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Value 'DisabledByDefault'
    if ($eVal -eq 1) {
        $zVal = 1
    } elseif ($dVal -eq 1) {
        $zVal = 0
    } else {
        $zVal = -1
    }
    
    $stage = 7
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording system cryptography' -PercentComplete ($stage * 100 / $nStages)
    
    $resData.SChannelTLS12Server = $zVal
    $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Value 'Enabled'
    $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Value 'DisabledByDefault'
    if ($eVal -eq 1) {
        $zVal = 1
    } elseif ($dVal -eq 1) {
        $zVal = 0
    } else {
        $zVal = -1
    }
    $resData.SChannelTLS12Client = $zVal
    $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Value 'Enabled'
    $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server' -Value 'DisabledByDefault'
    if ($eVal -eq 1) {
        $zVal = 1
    } elseif ($dVal -eq 1) {
        $zVal = 0
    } else {
        $zVal = -1
    }
    $resData.SChannelTLS13Server = $zVal
    $eVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -Value 'Enabled'
    $dVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client' -Value 'DisabledByDefault'
    if ($eVal -eq 1) {
        $zVal = 1
    } elseif ($dVal -eq 1) {
        $zVal = 0
    } else {
        $zVal = -1
    }
    $resData.SChannelTLS13Client = $zVal
    $resData.CipherSuites = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002' -Value 'Functions'
    $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy' -Value 'Enabled'
    if ($zVal -eq 0) {
        $resData.FIPSCryptoEnabled = 0
    } elseif ($zVal -eq 1) {
        $resData.FIPSCryptoEnabled = 1
    } else {
        $resData.FIPSCryptoEnabled = -1
    }
    # drives
    Write-SMPRSLog 'Enumerating disks'
    try {
        $allDisks = Get-WmiObject -Class Win32_LogicalDisk -Filter 'DriveType=3' -EA Stop
    } catch {
        $allDisks = null
        Write-SMPRSLog -Severity 3 -Message ('Error in Disk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        $resData.Errors += ('Error in Disk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    }
    foreach ($disk in $allDisks) {
        $resData.DiskDrives += [PSCustomObject]@{
            'DeviceID' = $disk.DeviceID
            'Size' = $disk.Size
            'FreeSpace' = $disk.FreeSpace
        }
    }
    # networks
    $stage = 8
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Enumerating networks' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog -Severity 1 -Message 'Enumerating networks'
    try {
        $ipConfigs = @(Get-WMIObject  Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -EA Stop)
    } catch {
        $ipConfigs = $null
        Write-SMPRSLog -Severity 3 -Message ('Error in Networkk Enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        $resData.Errors += ('Error in Network Adapter enumeration WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    }
    foreach ($ipc in $ipConfigs) {
        $network = [PSCustomObject]@{
            'MACAddress' = $ipc.MACAddress
            'SettingID' = $ipc.SettingID
            'Alias' = $ipc.ServiceName
            'Description' = $ipc.Description
            'DHCPEnabled' = $ipc.DHCPEnabled
            'NetworkProfile' = $null
            'DNSServers' = @($ipc | Select-Object -ExpandProperty DNSServerSearchOrder | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
            'IPConfigs' = @()
        }
        $ipAddrs = @($ipc | Select-Object -ExpandProperty IPAddress | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
        $ipMasks = @($ipc | Select-Object -ExpandProperty IPSubnet | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
        $ipGW = @($ipc | Select-Object -ExpandProperty DefaultIPGateway | Where-Object {$_ -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'})
        for ($i = 0; $i -lt $ipAddrs.Count; $i++) {
            $network.IPConfigs += [PSCustomObject]@{
                'IPAddress' = $ipAddrs[$i]
                'SubnetMask' = $ipMasks[$i]
                'Gateway' = $ipGW[0]
            }
        }
            
        try {
            $netProf = Get-WmiObject -Class MSFT_NetConnectionProfile -Namespace 'root/StandardCimv2' -Filter ('InstanceID="{0}"' -f $ipc.SettingID) -EA Stop
            $network.Alias = $netProf.InterfaceAlias
            $network.NetworkProfile = $netProf.NetworkCategory
        } catch {
            $netProf = $null
            Write-SMPRSLog -Severity 3 -Message ('Error in NetConnectionProfile WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
            $resData.Errors += ('Error in NetConnectionProfile WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
        }

        $resData.Networks += $network
    }
    # system proxy
    $stage = 9
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Detecting system proxy configuration' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Detecting system proxy'
    $resData.ProxyServer = Get-SysUserRegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -Value 'ProxyServer'
    $resData.ProxyOverride = Get-SysUserRegistryValue -Key 'SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -Value 'ProxyOverride'
    
    # NTLM restrictions
    $stage = 10
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording various possible issues' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Investigating NTLM restrictions'
    $zVal = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Value 'restrictntlmindomain'
    # 0 = all allowed, 1 = domain accts to domain servers, 3 = domain accounts, 5 = domain servers, 7 = all disabled
    if ($null -eq $zVal) {
        $zVal = -1
    }
    $resData.RestrictNTLM = $zVal
    # Antimalware
    Write-SMPRSLog 'Investigating known antimalware'
    foreach ($svc in $avsvc.Keys) {
        $zSvc = Get-WmiObject -Class Win32_Service -Filter ('Name="{0}"' -f $svc)
        if ($null -ne $zSvc) {
            $resData.Antimalware += ('{0} ({1}/{2})' -f $avsvc[$svc], $zSvc.StartMode, $zSvc.State)
        }
    }
    
    # Persistent routes
    $stage = 11
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording persistent routes' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Investigating persistent routes'
    try {
        $zRoutes = Get-WmiObject -Class Win32_IP4PersistedRouteTable -Filter "Destination <> '0.0.0.0'" -EA Stop
        foreach($route in $zRoutes) {
            $resData.Routes += [PSCustomObject]@{
                'Destination' = $route.Destination
                'SubnetMask' = $route.Mask
                'Metric' = $route.Metric1
                'Gateway' = $route.NextHop
            }
        }
    } catch {
        $resData.Errors += ('Error in Persistent Routes WMI {0}: {1}' -f $_.Exception.InvocationInfo.ScriptLineNumber, $_.Exception.Message)
    }
    # firewall config
    $stage = 12
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording firewall configuration' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Investigating Windows firewall configuration'
    foreach ($fwProf in @('DomainProfile','PrivateProfile','PublicProfile')) {
        Write-SMPRSLog ('Profile: {0}' -f $fwProf)
        $regPath = 'SOFTWARE\Policies\Microsoft\WindowsFirewall\{0}' -f $fwProf
        $fwSetting = [PSCustomObject]@{
            'Profile' = $fwProf
            'Policy' = Test-RegistryKey -Key $regPath
            'Enabled' = $null
            'InboundMode' = $null
            'OutboundMode' = $null
            'MergeLocal' = $null
        }
        if ($fwSetting.Policy) {
            $zVal = Get-RegistryValue -Key $regPath -Value 'AllowLocalPolicyMerge'
            $fwSetting.MergeLocal = (0 -ne $zVal)
        } else {
            $regPath = 'SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\{0}' -f $fwProf
        }
        $zVal = Get-RegistryValue -Key $regPath -Value 'EnableFirewall'
        $fwSetting.Enabled = (0 -ne $zVal)
        $zVal = Get-RegistryValue -Key $regPath -Value 'DefaultInboundAction'
        if ($zVal -ne $null) {
            $fwSetting.InboundMode = $zVal
        } else {
            $fwSetting.InboundMode = -1
        }
        $zVal = Get-RegistryValue -Key $regPath -Value 'DefaultOutboundAction'
        if ($zVal -ne $null) {
            $fwSetting.OutboundMode = $zVal
        } else {
            $fwSetting.OutboundMode = -1
        }
            
        $resData.Firewall += $fwSetting
    }
    # SMRPS SQL
    $stage = 13
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Checking for SMPRS SQL instance' -PercentComplete ($stage * 100 / $nStages)
    Write-SMPRSLog 'Investigating SMPRS SQL instance'
    $zSvc = Get-WmiObject -Class Win32_Service -Filter 'Name="MSSQL$SMPRS"'
    if ($null -ne $zSvc) {
        Write-SMPRSLog ('Found service MSSQL$SMPRS, status: {0}, image: {1}' -f $zSvc.State, $zSvc.PathName)
        $sqlInst = [PSCustomObject]@{
            'ConfigOK' = $true
            'State' = $zSvc.State
            'PathName' = $zSvc.PathName
            'StartMode' = $zSvc.StartMode
            'MajorVersion' = $null
            'Version' = $null
            'Language' = $null
        }
        if ($zSvc.PathName -match '\"(?<exe>.*\\sqlservr\.exe)\".*\-sSMPRS') {
            $sqlEXE = Get-Item -Path $Matches['exe'] -EA SilentlyContinue
            if ($null -ne $sqlEXE) {
                $sqlInst.MajorVersion = $sqlEXE.VersionInfo.FileMajorPart
                $sqlInst.Version = $sqlEXE.VersionInfo.FileVersion
                $sqlInst.Language = $sqlEXE.VersionInfo.Language
            }
        } else {
            $sqlInst.ConfigOK = $false
        }
        $resData.SQLInstance = $sqlInst
    }
    # NTP
    $stage = 14
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Recording NTP configuration' -PercentComplete ($stage * 100 / $nStages)

    Write-SMPRSLog 'Recording NTP client configuration'
    $resData.NTPLocalProvider = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Value 'Type'
    $resData.NTPLocalSource = Get-RegistryValue -Key 'SYSTEM\CurrentControlSet\Services\W32Time\Parameters' -Value 'NtpServer'
    if (Test-RegistryKey -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters') {
        $resData.NTPPolicyProvider = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters' -Value 'Type'
        $resData.NTPPolicySource = Get-RegistryValue -Key 'SOFTWARE\Policies\Microsoft\W32Time\Parameters' -Value 'NtpServer'
    }

    $stage = 15
    Write-Progress -Id 0 -Activity 'Exploring the local machine' -Status 'Persisting local machine data in datastore' -PercentComplete ($stage * 100 / $nStages)

    $updateRes = Update-SMPRSDataStore -DataArea $dataArea -Data $resData
    if ($updateRes) {
        Write-SMPRSLog -Severity 1 -Message 'MasterData update successful'
    } else {
        Write-SMPRSLog -Severity 2 -Message 'MasterData update failed'
        $res = $false
    }
    Write-Progress -id 0 -Activity 'Done' -Completed
    return $res
}

function Flip-RowColor {
    if ($Script:RowColor -ne '#FFFFFF') {
        $Script:RowColor = '#FFFFFF'
    } else {
        $Script:RowColor = '#D4FBF9'
    }
}

function Get-ComplianceHTML {
    Param(
        [PSObject]$ComplianceItem,
        [switch]$NoFlipRowColor,
        [switch]$ResetRowColor,
        [switch]$GreyRow
        )
    $styles = @(
        'iconok'
        'iconinfo'
        'iconwarn'
        'iconerror'
    )
    if ($ResetRowColor) {
        $Script:RowColor = '#FFFFFF'
    }
    if ($GreyRow) {
        $rowC = '#EEEEEE'
    } else {
        $rowC = $Script:RowColor
    }
    
    $thADFR = $null
    $thDSP = $null
    $outADFR = '&nbsp;'
    $outDSP = '&nbsp;'
    if ($ComplianceItem.Score) {
        if ($ComplianceItem.Legend.Count -gt 0) {
            $popupMsg = @()
            foreach ($li in $ComplianceItem.Legend) {
                $popupMsg += $cc.Legend[$li]
            }
            $thtml = (' title="{0}"' -f ($popupMsg -join [Environment]::NewLine))
            if ($ComplianceItem.ADFR -gt 0) {
                $thADFR = $thtml
            }
            if ($ComplianceItem.DSP -gt 0) {
                $thDSP = $thtml
            }
        }
        if ($null -ne $ComplianceItem.ADFR) {
            $outADFR = ('<span class="{0}"{1}>&nbsp;</span>' -f $styles[$ComplianceItem.ADFR], $thADFR)
        }
        if ($null -ne $ComplianceItem.DSP) {
            $outDSP = ('<span class="{0}"{1}>&nbsp;</span>' -f $styles[$ComplianceItem.DSP], $thDSP)
        }
    }
    if ($null -ne $ComplianceItem.OutputValue) {
        $oVal = $ComplianceItem.OutputValue
    } else {
        $oVal = $ComplianceItem.Value
    }
    if (-not [string]::IsNullOrWhiteSpace($ComplianceItem.Description)) {
        $oDesc = $ComplianceItem.Description
    } else {
        $oDesc = 'Overall readiness'
        if (($null -eq $oVal) -and (($ComplianceItem.ADFR + $ComplianceItem.DSP) -gt 0)) {
            $oVal = 'The less-than-optimal overall readiness score can be due to an underlying object.'
        }
    }
    $res = [PSCustomObject]@{
        'ADFR' = $outADFR
        'DSP' = $outDSP
        'Description' = $oDesc
        'Value' = $ComplianceItem.Value
        'Label' = $ComplianceItem.Label
        'TableRow' = ('<tr style="background-color: {0};"><td><b>{1}</b></td><td class="cnt">{2}</td><td class="cnt">{3}</td><td>{4}</td></tr>{5}' -f $rowC, $oDesc, $outADFR, $outDSP, $oVal, [Environment]::NewLine)
    }
    if (-not $NoFlip) {
        Flip-RowColor
    }
    return $res
}


function Export-SMPRSReport {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('3.8','4.0','4.1','4.2','5.0','5.1','6.0')]
        [string]$ADFRVersion = '6.0',
        [Parameter(Mandatory=$false)]
        [ValidateSet('3.6','3.8','4.0','4.0SP1','4.1','4.0SP2','4.2','5.0','5.1','5.2')]
        [string]$DSPVersion = '5.2',
        [Parameter(Mandatory=$false)]
        [ValidateSet('HTML','JSON')]
        [string[]]$OutputFormat = @('HTML','JSON')
    )
    Write-SMPRSLog -Severity 1 -Message ('Creating report for ADFR {0} and DSP {1}' -f $ADFRVersion, $DSPVersion)
    $res = $true
    $titleString = ('Semperis environment readiness report, created on {0}' -f (Get-Date -Format 'yyyy-MM-dd'))
    $cc = Get-SMPRSCompliance -ADFRVersion $ADFRVersion -DSPVersion $DSPVersion
    Write-SMPRSLog -Message 'Compliance calculation complete'
    if ($OutputFormat -contains 'JSON') {
        $outFileJSON = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath ('SMPRS.ReadinessReport.{0}.json' -f (Get-Date -Format 'yyyyMMdd.HHmm'))
        try {
            $cc | ConvertTo-Json -Depth 12 -EA Stop | Set-Content -Path $outFileJSON -Force -EA Stop
            Write-SMPRSLog -Severity 1 -Message ('JSON File saved: {0}' -f $outFileJSON)
        } catch {
            Write-SMPRSLog -Severity 3 -Message ('JSON Report failed: {0}' -f $_.Exception.Message)
            $res = $false
        }
    }
    if ($OutputFormat -contains 'HTML') {
        $html = $script:HTMLTemplate
        $outFileHTML = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath ('SMPRS.ReadinessReport.{0}.html' -f (Get-Date -Format 'yyyyMMdd.HHmm'))
        $forestCIs = @(
            'ForestRootNC'
            'ConfigNC'
            'SchemaNC'
            'FSMOSchema'
            'FSMONaming'
            'ForestFL'
            'ADSchema'
            'EXSchemaRU'
            'EXSchemaOV'
            'SkypeSchema'
            'LAPSSchemaLegacy'
            'LAPSSchemaWindows'
            'TombstoneLifetime'
            'RecycleBin'
            'DeletedLifetime'
            'BackupLifetime'
            'FeaturePIM'
            'Feature32K'
            'SlowReplication'
            'SchemaClassActive'
            'SchemaClassDefunct'
            'SchemaAttributeActive'
            'SchemaAttributeDefunct'
            'OIDOverlap'
            'DSHeuristics'
        )
        $domainCIs = @(
            'DomainFL'
            'FSMOPDCe'
            'FSMORID'
            'FSMOInfra'
            'MachineAccountQuota'
            'AUinPreWin2K'
            'DAinPU'
            'KRBTGTPwdLastSet'
            'LocalHostInName'
            'PwdLastSetInvalid'
            'NumUsers'
            'NumAdmins'
            'NumUsersActive'
            'NumComputers'
            'NumGroups'
            'NumOUs'
            'NumGPOs'
            'GPOBadName'
            'GPOEmptyName'
        )
        $dcCIs = @(
            'PersistentRoutes'
            'Firewall'
            'ProxyServer'
            'ProxyOverride'
            'RODC'
            'ADReplState'
            'DCVersion'
            'OSBuild'
            'OSEdition'
            'ServerCore'
            'MakeAndModel'
            'NumCPU'
            'MemoryMB'
            'OSLanguage'
            'SystemLocale'
            'TimeZone'
            'NTPConfig'
            'RebootPending'
            'DiskDrives'
            'SystemDrive'
            'WindowsPath'
            'NTDSPath'
            'NTDSSize'
            'NTDSLogsPath'
            'NTDSLogsCount'
            'SYSVOLPath'
            'SYSVOLCount'
            'SYSVOLSize'
            'LocalBackupCopy'
            'LocalFreeSpace'
            'SYSVOLMigState'
            'SYSVOLReplState'
            'BEXMissing'
            'BEXExcess'
            'DotNetVersion'
            'DotNetStrongCrypto'
            'DotNetDefaultTLS'
            'TLS12Server'
            'TLS12Client'
            'TLS13Server'
            'TLS13Client'
            'FIPSCrypto'
            'CipherSuites'
            'WrongRoots'
            'AuthTrustMode'
            'PinnedRPCPortNTDS'
            'PinnedRPCPortNetlogon'
            'MachineKeys'
            'UserInit'
            'SMB1'
            'Antivirus'
            'OptRoles'
            'RestrictNTLM'
            'DFSN'
            'AuditSubcats'
            'LSAProtected'
            'DCEncTypes'
            'ReplEpoch'
            'FieldEngineering'
            'DSAHeuristics'
        )
        $lmCIs = @(
            'PersistentRoutes'
            'DNSSettings'
            'DomainMember'
            'Firewall'
            'ProxyServer'
            'ProxyOverride'
            'OSBuild'
            'OSEdition'
            'ServerCore'
            'ImageHealth'
            'MakeAndModel'
            'Browsers'
            'SQLInstance'
            'NumCPU'
            'MemoryMB'
            'OSLanguage'
            'SystemLocale'
            'UILanguage'
            'TimeZone'
            'NTPConfig'
            'RebootPending'
            'DiskDrives'
            'SystemDrive'
            'WindowsPath'
            'LocalFreeSpace'
            'DotNetVersion'
            'DotNetStrongCrypto'
            'DotNetDefaultTLS'
            'TLS12Server'
            'TLS12Client'
            'TLS13Server'
            'TLS13Client'
            'FIPSCrypto'
            'CipherSuites'
            'WrongRoots'
            'AuthTrustMode'
            'LocalUserDomainName'
            'Antivirus'
            'RestrictNTLM'
        )
        $blockMenu = '<div class="menu" id="menuOVERVIEW"><a href="#OVERVIEW">Overview</a></div><hr />'
        $blockLM = ''
        $blockAD = ''
        $blockLegend = ''
        $blockComments = ''
        $listMenuID = ''
        $blockB2T = '<div style="margin: 10px; text-align: right;"><a href="#OVERVIEW"><span class="back2top" title="back to top">&nbsp;</span></a></div>'
        #region overview
        $blockOverview = '<h1 id="OVERVIEW" class="firstheader">OVERVIEW</h1><p>Thank you for running the Semperis environment readiness assessment. This report helps your Semperis Solutions Architect to:</p>'
        $blockOverview += '<ul><li>create the requisite license files</li><li>provide estimates for the infrastructure footprint</li><li>identify environmental issues that could prevent Semperis products from working properly</li></ul>'
        $blockOverview += '<p>&nbsp;</p>'
        $blockOverview += ([Environment]::NewLine)
        $blockOverview += ('<table style="border-top: 1px solid black;"><tr><td><b>Report created:</b></td><td>{0}</td></tr>' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
        $blockOverview += ([Environment]::NewLine)
        $blockOverview += ('<tr><td><b>ADFR Version:</b></td><td>{0}</td></tr>' -f $ADFRVersion)
        $blockOverview += ([Environment]::NewLine)
        $blockOverview += ('<tr><td><b>DSP Version:</b></td><td>{0}</td></tr>' -f $DSPVersion)
        $blockOverview += ([Environment]::NewLine)
        if (-not [string]::IsNullOrWhiteSpace($cc.Project.Name)) {
            $blockOverview += ('<tr><td><b>Report for:</b></td><td>{0}</td></tr>' -f $cc.Project.Name)
            $blockOverview += ([Environment]::NewLine)
        }
        if (-not [string]::IsNullOrWhiteSpace($cc.Project.Operator)) {
            $blockOverview += ('<tr><td><b>Report by:</b></td><td>{0}</td></tr>' -f $cc.Project.Operator)
            $blockOverview += ([Environment]::NewLine)
        }
        if (-not [string]::IsNullOrWhiteSpace($cc.Project.Description)) {
            $blockOverview += ('<tr><td><b>Description:</b></td><td>{0}</td></tr>' -f ($cc.Project.Description -replace [Environment]::NewLine, '<br/>'))
            $blockOverview += ([Environment]::NewLine)
        }
        if ($cc.LocalMachines.Count -gt 0) {
            $blockOverview += ('<tr><td><b>Local machines:</b></td><td>{0}</td></tr>' -f $cc.LocalMachines.Count)
            $blockOverview += ([Environment]::NewLine)
        }
        if ($cc.Forests.Count -gt 0) {
            $blockOverview += ('<tr><td><b>AD forests:</b></td><td>{0}</td></tr>' -f $cc.Forests.Count)
            $blockOverview += ([Environment]::NewLine)
            $ndom = 0
            foreach ($forest in $cc.Forests) { $ndom += $forest.Domains.Count }
            $blockOverview += ('<tr><td><b>AD domains:</b></td><td>{0}</td></tr>' -f $ndom)
            $blockOverview += ([Environment]::NewLine)
            $ndom = 0
            foreach ($forest in $cc.Forests) { $ndom += $forest.DomainControllers.Count }
            $blockOverview += ('<tr><td><b>Domain Controllers:</b></td><td>{0}</td></tr>' -f $ndom)
            $blockOverview += ([Environment]::NewLine)
        }
        $blockOverview += '</table>' 
        #endregion
        #region local machines
        #endregion
        #region AD forests
        if ($cc.Forests.Count -gt 0) {
            $blockAD = '<h1 id="ADFORESTS_HEAD">ACTIVE DIRECTORY</h1>'
            $blockAD += ([Environment]::NewLine)
            $blockAD += '<p>Compliance status is presented as "cumulative worst" - a problem with a particular domain controllers causes the compliance level of its domain to decrease, and a problem in a domain affects the compliance level of the entire forest.</p>'
        }
        $isFirstForest = $true
        foreach ($forest in $cc.Forests) {
            $blockB2F = ('<div style="margin: 10px; text-align: right;"><a href="#ADF_{0}_HEAD"><span class="back2forest" title="back to forest {0}">&nbsp;</span></a></div>' -f $forest.ForestRootName)
            $blockMenu += ('<div class="menu" id="menuADF_{0}"><a href="#ADF_{0}_HEAD">{0}</a>&nbsp;<span id="menuADF_{0}_bodycol" onclick="collapseForestMenu(''menuADF_{0}_body'')"><a href="#">[-]</a></span><span id="menuADF_{0}_bodyexp" onclick="expandForestMenu(''menuADF_{0}_body'')" style="display:none;"><a href="#">[+]</a></span></div>' -f $forest.ForestRootName)
            $blockMenu += ([Environment]::NewLine)
            $blockMenu += ('<div id="menuADF_{0}_body">' -f $forest.ForestRootName)
            $blockMenu += ([Environment]::NewLine)
        
            if ($isFirstForest) {
                $classSelector = ' class="firstheader2"'
                $isFirstForest = $false
                $insB2T = '<p>&nbsp;</p>'
            } else {
                $classSelector = ''
                $insB2T = $blockB2T
            }
            $blockAD += ('<h2 id="ADF_{0}_HEAD"{2}>Forest: {0} [{1}]</h2>' -f $forest.ForestRootName, $forest.ForestRootDomain, $classSelector)
            $blockAD += ([Environment]::NewLine)
            $blockAD += $insB2T
            $blockAD += ([Environment]::NewLine)
            $blockAD += '<table><tr><th>Parameter</th><th class="cnt">ADFR</th><th class="cnt">DSP</th><th>Value</th></tr>'
            $blockAD += ([Environment]::NewLine)
            $blockAD += ('<tr style="background-color: #EEEEEE;"><td><b>Forest Root Domain</b></td><td>&nbsp;</td><td>&nbsp;</td><td><span id="ADF_{0}_FRD" class="copy" onclick="copyToClipboard(''ADF_{0}_FRD'',''{1}'')">&nbsp;</span>&nbsp;{1}</td></tr>' -f $forest.ForestRootName, $forest.ForestRootDomain)
            $blockAD += ([Environment]::NewLine)
            $blockAD += ('<tr style="background-color: #EEEEEE;"><td><b>Forest Root SID (hashed)</b></td><td>&nbsp;</td><td>&nbsp;</td><td><span id="ADF_{0}_SID" class="copy" onclick="copyToClipboard(''ADF_{0}_SID'',''{1}'')">&nbsp;</span>&nbsp;{1}</td></tr>' -f $forest.ForestRootName, $forest.ForestSIDHash)
            $blockAD += ([Environment]::NewLine)
            $chtml = Get-ComplianceHTML -ComplianceItem $forest.Compliance -ResetRowColor -GreyRow
            $blockAD += $chtml.TableRow
            $blockAD += ('<tr style="background-color: {0};"><td><b>Forest GUID</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, $forest.ForestGUID)
            $blockAD += ([Environment]::NewLine)
            Flip-RowColor
        
            foreach ($fci in $forestCIs) {
                if ($null -eq $fci) { continue }
                if ($forest.ComplianceItems.ContainsKey($fci)) {
                    $chtml = Get-ComplianceHTML -ComplianceItem $forest.ComplianceItems[$fci]
                    $blockAD += $chtml.TableRow
                } else {
                    Write-SMPRSLog -Severity 2 -Message ('Forest Compliance Item missing: {0}' -f $fci)
                }
            }
            $blockAD += '</table>'
        
            if (-not [string]::IsNullOrWhiteSpace($forest.ComplianceItems['DSHeuristics'].Value)) {
                $blockAD += ('<h4 id="ADF_{0}_HEURISTICS" style="margin-top:20px;">dsHeuristics for forest {0} demystified</h4>' -f $forest.ForestRootName)
                $blockAD += ([Environment]::NewLine)
                $blockAD += '<p>Click on the names of the individual settings to open Microsoft documentation about their meaning and behavior</p>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += '<table><tr><th>Pos.</th><th>Name</th><th class="cnt">Value</th><th class="cnt">Valid</th><th class="cnt">Default</th><th>Behavior</th></tr>'
                $script:RowColor = '#FFFFFF'
                $dsHeur = Resolve-DsHeuristics -Heuristics $forest.ComplianceItems['DSHeuristics'].Value
                foreach ($line in $dsHeur) {
                    $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td nowrap="nowrap"><a href="{2}" target="_blank">{3}</a></td><td class="cnt">{4}</td><td class="cnt">{5}</td><td class="cnt">{6}</td><td>{7}</td></tr>' -f $script:RowColor, $line.Position, $line.URI, $line.Name, $line.Character, $line.IsValid, $line.IsDefault, $line.Behavior)
                    $blockAD += ([Environment]::NewLine)
                    Flip-RowColor
                }
                $blockAD += '</table>'
            }
            #region domains and partitions
            $blockMenu += ('<div class="submenu"><a href="#ADF_{0}_DOMPARTS">Domains</a></div>' -f $forest.ForestRootName)
            $blockMenu += ([Environment]::NewLine)
            $blockAD += ([Environment]::NewLine)
            $blockAD += ('<h3 id="ADF_{0}_DOMPARTS">DOMAINS AND PARTITIONS</h3>' -f $forest.ForestRootName)
            $blockAD += ([Environment]::NewLine)
            $blockAD += '<table><tr><th>NC</th><th>Name</th><th>DFL</th><th>Objects</th><th>DIT Size</th><th>SYSVOL Size</th><th class="cnt">ADFR</th><th class="cnt">DSP</th></tr>'
            $blockAD += ([Environment]::NewLine)
            $script:RowColor = '#FFFFFF'
            foreach ($part in $forest.Partitions.Where({$_.IsDomain})) {
                $dom = $forest.Domains.Where({$_.DomainNC -eq $part.Name})[0]
                if ($dom.IsExplored) {
                    $chtml = Get-ComplianceHTML -ComplianceItem $dom.Compliance
                    $dflString = ('{0} ({1})' -f $dom.ComplianceItems['DomainFL'].Label, $dom.ComplianceItems['DomainFL'].Value)
                    $nObjects = $dom.ComplianceItems['NumUsers'].Value + $dom.ComplianceItems['NumGroups'].Value + $dom.ComplianceItems['NumComputers'].Value
                    $ditSize = [int64]0
                    $volSize = [int64]0
                    foreach ($domDC in $forest.DomainControllers.Where({$_.Domain -eq $dom.DomainFQDN})) {
                        if ($domDC.IsExplored) {
                            $ditSize = [math]::Max([int64]$ditSize, [int64]($domDC.ComplianceItems['NTDSSize'].Data))
                            $volSize = [math]::Max($volSize, [int64]($domDC.ComplianceItems['SYSVOLSize'].Data))
                        }
                    }
                    $ditSize = $ditSize / 1GB
                    $volSize = $volSize / 1GB
                    $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td><a href="#ADF_{8}_DOM_{3}">{2}<br />{3}</a></td><td>{4}</td><td class="cnt">{5}</td><td>{9:0.##} GB</td><td>{10:0.##} GB</td><td class="cnt">{6}</td><td class="cnt">{7}</td></tr>' -f $script:RowColor, $part.Name, $dom.DomainFQDN, $dom.DomainName.ToUpper(), $dflString, $nObjects, $chtml.ADFR, $chtml.DSP, $forest.ForestRootName, $ditSize, $volSize)
                } else {
                    $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td><a href="#ADF_{5}_DOM_{3}">{2}<br />{3}</a></td><td>{4}</td><td class="cnt" colspan="5">- domain not explored -</td></tr>' -f $script:RowColor, $part.Name, $dom.DomainFQDN, $dom.DomainName.ToUpper(), $dflString, $forest.ForestRootName)
                }
                Flip-RowColor
                $blockAD += ([Environment]::NewLine)
            }
            foreach ($part in $forest.Partitions.Where({-not $_.IsDomain})) {
                $chtml = Get-ComplianceHTML -ComplianceItem $part.Compliance
                $blockAD += ('<tr style="background-color:#EEEEEE"><td>{0}</td><td>- non-domain -</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td class="cnt">{1}</td><td class="cnt">{2}</td></tr>' -f $part.Name, $chtml.ADFR, $chtml.DSP)
                $blockAD += ([Environment]::NewLine)
                if ($part.ComplianceItems.ContainsKey('BadDNSRecords')) {
                    $blockAD += '<tr style="background-color:#EEEEEE"><td colspan="8"><b>DNS Records of unsupported types:</b><br />'
                    foreach ($rec in $part.ComplianceItems['BadDNSRecords'].Data) {
                        $blockAD += ('{0} <br />' -f $rec)
                    }
                    $blockAD += '</td></tr>'
                    $blockAD += ([Environment]::NewLine)
                }
            }
            $blockAD += '<table>'
            $blockAD += ([Environment]::NewLine)
            $blockAD += $blockB2F
            foreach ($dom in $forest.Domains) {
                if (-not $dom.IsExplored) { continue }
                $blockMenu += ('<div class="submenu">&nbsp;<a href="#ADF_{0}_DOM_{1}">{1}</a></div>' -f $forest.ForestRootName, $dom.DomainName.ToUpper())
                $blockMenu += ([Environment]::NewLine)
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<h4 id="ADF_{0}_DOM_{1}">Domain: {1}</h4>' -f $forest.ForestRootName, $dom.DomainName.ToUpper())
                $script:RowColor = '#FFFFFF'
                $blockAD += ([Environment]::NewLine)
                $blockAD += '<table><tr><th>Parameter</th><th>ADFR</th><th>DSP</th><th>Value</th></tr>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<tr style="background-color: #EEEEEE;"><td><b>Domain NETBIOS name</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{0}</td></tr>' -f $dom.DomainName.ToUpper())
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<tr style="background-color: #EEEEEE;"><td><b>Domain FQDN</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{0}</td></tr>' -f $dom.DomainFQDN.ToLower())
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<tr style="background-color: #EEEEEE;"><td><b>Domain NC</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{0}</td></tr>' -f $dom.DomainNC)
                $blockAD += ([Environment]::NewLine)
                $chtml = Get-ComplianceHTML -ComplianceItem $dom.Compliance -GreyRow
                $blockAD += $chtml.TableRow
                $blockAD += ('<tr style="background-color: {0};"><td><b>Domain GUID</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, $dom.DomainGUID)
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
            
                foreach ($dci in $domainCIs) {
                    if ($null -eq $dci) { continue }
                    if ($dom.ComplianceItems.ContainsKey($dci)) {
                        $chtml = Get-ComplianceHTML -ComplianceItem $dom.ComplianceItems[$dci]
                        $blockAD += $chtml.TableRow
                    } else {
                        Write-SMPRSLog -Severity 2 -Message ('Domain Compliance Item missing: {0}' -f $dci)
                    }
                }
                if ($dom.Trusts.Count -gt 0) {
                    $trustBlock = @()
                    foreach ($trust in $dom.Trusts) {
                        $trustBlock += $trust.OutputValue
                    }
                    $blockAD += ('<tr style="background-color: {0};"><td><b>Trust(s) to/from this domain</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, ($trustBlock -join '<br />'))
                    $blockAD += ([Environment]::NewLine)
                    Flip-RowColor
                }
                $blockAD += '</table>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<p style="font-size: .8em;">Exploration of this domain took {0} seconds.</p>' -f $dom.ExploreDuration)
                $blockAD += ([Environment]::NewLine)
                $blockAD += $blockB2F
                $blockAD += ([Environment]::NewLine)
            }
        
            #endregion
            #region trusts
            if ($forest.Trusts.Count -gt 0) {
                $blockMenu += ('<div class="submenu"><a href="#ADF_{0}_TRUSTS">Trusts</a></div>' -f $forest.ForestRootName)
                $blockMenu += ([Environment]::NewLine)
                $blockAD += ('<h3 id="ADF_{0}_TRUSTS">TRUSTS</h3>' -f $forest.ForestRootName)
                $script:RowColor = '#FFFFFF'
                $blockAD += ([Environment]::NewLine)
                $blockAD += '<table><tr><th>Own Trust Partner</th><th>Foreign Trust Partner</th><th>Valid</th><th>Direction</th><th>Type</th><th>Parameters</th><th>Raw Values</th></tr>'
                $blockAD += ([Environment]::NewLine)
                foreach ($trust in $forest.Trusts) {
                    $typeBlock = @($trust.TrustTypeResolved)
                    if ($trust.TrustAttributesResolved.ForestTransitive) {
                        $typeBlock += 'Forest'
                        if ($trust.TrustAttributesResolved.PIMTrust) {
                            $typeBlock += 'PIM'
                        }
                    }
                    $parmBlock = @()
                    if (-not $trust.TrustAttributesResolved.ForestTransitive) {
                        if ($trust.TrustAttributesResolved.NonTransitive) {
                            $parmBlock += 'Non-transitive'
                        } else {
                            $parmBlock += 'Transitive'
                        }
                    }
                    if ($trust.TrustAttributesResolved.UplevelOnly) {
                        $parmBlock += 'Uplevel-only'
                    }
                    if ($trust.TrustAttributesResolved.Quarantined) {
                        $parmBlock += 'Quarantined'
                    }
                    if ($trust.TrustAttributesResolved.CrossOrganization) {
                        $parmBlock += 'Cross-Organization'
                    }
                    if ($trust.TrustAttributesResolved.TreatAsExternal) {
                        $parmBlock += 'Treat as external'
                    }
                    if ($trust.TrustAttributesResolved.UsesRC4) {
                        $parmBlock += 'RC4'
                    }
                    if ($trust.TrustAttributesResolved.NoDelegation) {
                        $parmBlock += 'No Delegation'
                    }
                    if ($trust.TrustAttributesResolved.MustDelegate) {
                        $parmBlock += 'Must delegate'
                    }
                    $rawBlock = ('trustDirection: {0}<br />trustType: {1}<br />trustAttributes: {2}' -f $trust.TrustDirection, $trust.TrustType, $trust.TrustAttributes)
                    $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td>{2}</td><td>{6}</td><td>{3}</td><td>{4}</td><td>{5}</td><td>{7}</td></tr>' -f $script:RowColor, $trust.LocalTrustPartner, $trust.RemoteTrustPartner, $trust.TrustDirectionResolved, ($typeBlock -join ', '), ($parmBlock -join ', '), $trust.TrustAttributesResolved.IsValid, $rawBlock)
                    $blockAD += ([Environment]::NewLine)
                    Flip-RowColor
                }
                $blockAD += '</table>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += $blockB2F
                $blockAD += ([Environment]::NewLine)
            }
            #endregion
            #region sites
            $blockMenu += ('<div class="submenu"><a href="#ADF_{0}_SITES">Sites</a></div>' -f $forest.ForestRootName)
            $blockMenu += ([Environment]::NewLine)
            $blockAD += ('<h3 id="ADF_{0}_SITES">SITES</h3>' -f $forest.ForestRootName)
            $script:RowColor = '#FFFFFF'
            $blockAD += ([Environment]::NewLine)
            $blockAD += '<table><tr><th>Name</th><th>GPOs</th><th>Subnets</th><th>UGMC</th><th>Query Policy</th></tr>'
            $blockAD += ([Environment]::NewLine)
            foreach ($site in $forest.sites) {
                $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td class="cnt">{2}</td><td class="cnt">{3}</td><td class="cnt">{4}</td><td>{5}</td></tr>' -f $script:RowColor, $site.Name, $site.LinkedGPO, $site.SubnetCount, $site.UniGroupMC, $site.QueryPolicy)
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
            }
            $blockAD += '</table>'
            $blockAD += ([Environment]::NewLine)
            $blockAD += $blockB2F
            $blockAD += ([Environment]::NewLine)
            #endregion
            #region gpos
            if ($forest.GroupPolicies.Count -gt 0) {
                $blockMenu += ('<div class="submenu"><a href="#ADF_{0}_GPOS">Group Policies</a></div>' -f $forest.ForestRootName)
                $blockMenu += ([Environment]::NewLine)
                $script:RowColor = '#FFFFFF'
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<h3 id="ADF_{0}_GPOS">GROUP POLICIES ({1})</h3>' -f $forest.ForestRootName, $forest.GroupPolicies.Count)
                $blockAD += ([Environment]::NewLine)
                $blockAD += '<table><tr><th>Name</th><th>Domain</th><th>GUID</th><th class="cnt">Machine<br />Version</th><th class="cnt">User<br />Version</th><th class="cnt">Machine<br />CSE</th><th class="cnt">User<br />CSE</th><th class="cnt">Empty<br />Name</th><th class="cnt">Bad<br />Name</th></tr>'
                $blockAD += ([Environment]::NewLine)
                foreach ($gpo in $forest.GroupPolicies) {
                    if ($gpo.EmptyName) {
                        $enstr = '<span class="iconwarn">&nbsp;</span>'
                    } else {
                        $enstr = '&nbsp;'
                    }
                    if ($gpo.LowASCII) {
                        $bnstr = '<span class="iconwarn">&nbsp;</span>'
                    } else {
                        $bnstr = '&nbsp;'
                    }
                    $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td nowrap="nowrap">{2}</td><td>{3}</td><td class="cnt">{4}</td><td class="cnt">{5}</td><td class="cnt">{6}</td><td class="cnt">{7}</td><td class="cnt">{8}</td><td class="cnt">{9}</td></tr>' -f $script:RowColor, $gpo.Name, $gpo.Domain, $gpo.GUID, $gpo.MachineVersion, $gpo.UserVersion, $gpo.MachineCSEs, $gpo.UserCSEs, $enstr, $bnstr)
                    $blockAD += ([Environment]::NewLine)
                    Flip-RowColor
                }
                $blockAD += '</table>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += $blockB2F
                $blockAD += ([Environment]::NewLine)
            }
            #endregion
            #region dcs
            $blockMenu += ('<div class="submenu"><a href="#ADF_{0}_DCS">Domain Controllers</a></div>' -f $forest.ForestRootName)
            $blockMenu += ([Environment]::NewLine)
            $blockAD += ([Environment]::NewLine)
            $blockAD += ('<h3 id="ADF_{0}_DCS">DOMAIN CONTROLLERS ({1})</h3>' -f $forest.ForestRootName, $forest.DomainControllers.Count)
            if ($forest.DomainControllers.Count -eq 0) {
                $blockAD += '<p>No Domain Controllers have been identified for this forest. We recommend you perform the exploration on at least one DC where Semperis ADFR and/or DSP agents will be installed.</p>'
                $blockAD += ([Environment]::NewLine)
            } else {
                $blockAD += '<table><tr><th>Name</th><th>Domain</th><th>Site</th><th>GC</th><th>RODC</th><th>Version</th><th>Core</th><th>FSMO</th><th>DIT Size</th><th>SYSVOL Size</th><th>ADFR</th><th>DSP</th></tr>'
                $blockAD += ([Environment]::NewLine)
                $script:RowColor = '#FFFFFF'
                $fsmoMap = @{}
                foreach ($dc in ($forest.DomainControllers | Sort-Object -Property Name)) {
                    if ($dc.IsExplored) {
                        $chtml = Get-ComplianceHTML -ComplianceItem $dc.Compliance
                        if ($dc.ComplianceItems['RODC'].Value) { $isRODC = 'RODC' } else { $isRODC = '&nbsp;' }
                        if ($dc.ComplianceItems['ServerCore'].Value) { $isCore = 'Core' } else { $isCore = '&nbsp;' }
                        $dcFSMO = @()
                        if ($forest.ComplianceItems['FSMONaming'].Value -eq $dc.FQDN) { $dcFSMO += 'Naming' }
                        if ($forest.ComplianceItems['FSMOSchema'].Value -eq $dc.FQDN) { $dcFSMO += 'Schema' }
                        $dcDomain = $forest.Domains.Where({$_.DomainFQDN -eq $dc.Domain})[0]
                        if ($dcDomain.IsExplored) {
                            if ($dcDomain.ComplianceItems['FSMOPDCe'].Value -eq $dc.Name) { $dcFSMO += 'PDCe' }
                            if ($dcDomain.ComplianceItems['FSMORID'].Value -eq $dc.Name) { $dcFSMO += 'RID' }
                            if ($dcDomain.ComplianceItems['FSMOInfra'].Value -eq $dc.Name) { $dcFSMO += 'Infra' }
                        } else {
                            $dcFSMO += '- domain N/E -'
                        }
                        $null = $fsmoMap.Add($dc.FQDN, $dcFSMO)
                        $ditSize = $dc.ComplianceItems['NTDSSize'].Data / 1GB
                        $volSize = $dc.ComplianceItems['SYSVOLSize'].Data / 1GB
                        $blockAD += ('<tr style="background-color: {0};"><td><a href="#ADF_{11}_DC_{1}">{1}</a></td><td nowrap="nowrap">{2}</td><td>{3}</td><td class="cnt">{4}</td><td class="cnt">{5}</td><td class="cnt">{6}</td><td class="cnt">{7}</td><td>{8}</td><td>{12:0.##} GB</td><td>{13:0.##} GB</td><td class="cnt">{9}</td><td class="cnt">{10}</td></tr>' -f $script:RowColor, $dc.Name, $dc.Domain, $dc.Site, $dc.IsGC, $isRODC, $dc.ComplianceItems['OSBuild'].Label, $IsCore, ($dcFSMO -join '<br />'), $chtml.ADFR, $chtml.DSP, $forest.ForestRootName, $ditSize, $volSize)
                    } else {
                        $cx = $dc.Compliance
                        if ($cx.ADFR -eq 0) { $cx.ADFR = 1 }
                        if ($cx.DSP -eq 0) { $cx.DSP = 1 }
                        $chtml = Get-ComplianceHTML -ComplianceItem $cx
                        $blockAD += ('<tr style="background-color: {0};"><td><a href="#ADF_{11}_DC_{1}">{1}</a></td><td nowrap="nowrap">{2}</td><td>{3}</td><td class="cnt">{4}</td><td class="cnt">{5}</td><td class="cnt">{6}</td><td class="cnt">{7}</td><td>{8}</td><td class="cnt" colspan="2">- not explored -</td><td class="cnt">{9}</td><td class="cnt">{10}</td></tr>' -f $script:RowColor, $dc.Name, $dc.Domain, $dc.Site, $dc.IsGC, $isRODC, $dc.ComplianceItems['OSBuild'].Label, $IsCore, ($dcFSMO -join '<br />'), $chtml.ADFR, $chtml.DSP, $forest.ForestRootName)
                        Flip-RowColor
                    }
                    $blockAD += ([Environment]::NewLine)
                }
                $blockAD += '</table>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += $blockB2F
                $blockAD += ([Environment]::NewLine)
            }


            foreach ($dc in ($forest.DomainControllers | Sort-Object -Property Name)) {
                if (-not $dc.IsExplored) { continue }
                $blockMenu += ('<div class="submenu">&nbsp;<a href="#ADF_{0}_DC_{1}">{1}</a></div>' -f $forest.ForestRootName, $dc.Name)
                $blockMenu += ([Environment]::NewLine)
                $blockAD += ('<h4 id="ADF_{0}_DC_{1}">Domain Controller: {1}</h4>' -f $forest.ForestRootName, $dc.Name)
                $blockAD += ([Environment]::NewLine)
                $script:RowColor = '#FFFFFF'
                $blockAD += '<table><tr><th>Parameter</th><th>ADFR</th><th>DSP</th><th>Value</th></tr>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<tr style="background-color: {0};"><td><b>FQDN</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, $dc.FQDN)
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
                $blockAD += ('<tr style="background-color: {0};"><td><b>Domain</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, $dc.Domain)
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
                $blockAD += ('<tr style="background-color: {0};"><td><b>Site</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, $dc.Site)
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
                $blockAD += ('<tr style="background-color: {0};"><td><b>FSMO roles</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{1}</td></tr>' -f $script:RowColor, ($fsmoMap[$dc.FQDN] -join ' | '))
                $blockAD += ([Environment]::NewLine)
                Flip-RowColor
                foreach ($nw in $dc.Networks) {
                    $nwBlock = ('<table style="border-bottom:none;"><tr><td>MAC Address</td><td>{0}</td></tr><tr><td>Adapter</td><td>{1}</td></tr><tr><td>Profile</td><td>{2}</td></tr>' -f $nw.MACAddress, $nw.Description, (Get-SMPRSVersionData -Entity NetworkProfile -Version $nw.NetworkProfile))
                    if ($nw.DHCPEnabled) {
                        $nwBlock += '<tr><td>&nbsp;</td><td>DHCP</td></tr>'
                    }
                    foreach ($nwip in $nw.IPConfigs) {
                        $nwBlock += ('<tr><td>Address</td><td>{0} / {1}</td></tr><tr><td>Gateway</td><td>{2}</td></tr>' -f $nwip.IPAddress, $nwip.SubnetMask, $nwip.Gateway)
                    }
                    $nwBlock += ('<tr><td>DNS Servers</td><td>{0}</td></tr>' -f ($nw.DNSServers -join '<br />'))
                    $nwBlock += '</table>'
                    $blockAD += ('<tr style="background-color: {0};"><td><b>Network {1}</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{2}</td></tr>' -f $script:RowColor, $nw.Alias, $nwBlock)
                    $blockAD += ([Environment]::NewLine)
                    Flip-RowColor
                }
            
                foreach ($dci in $dcCIs) {
                    if ($null -eq $dci) { continue }
                    if ($dc.ComplianceItems.ContainsKey($dci)) {
                        $chtml = Get-ComplianceHTML -ComplianceItem $dc.ComplianceItems[$dci]
                        $blockAD += $chtml.TableRow
                    } else {
                        Write-SMPRSLog -Severity 2 -Message ('Domain Controller Compliance Item missing: {0}' -f $dci)
                    }
                }
                $blockAD += '</table>'
                $blockAD += ([Environment]::NewLine)
                $blockAD += ('<p style="font-size: .8em;">Exploration of this Domain Controller using {1} took {0} seconds.</p>' -f $dc.ExploreDuration, $dc.ProtocolUsed)
                $blockAD += ([Environment]::NewLine)
                $blockAD += $blockB2F
                $blockAD += ([Environment]::NewLine)
                if ($dc.ComplianceItems['DSAHeuristics'].Value) {
                    $blockAD += ('<h4 id="ADF_{0}_DC_{1}_HEURISTICS" style="margin-top:20px;">dsHeuristics for DC {1} demystified</h4>' -f  $forest.ForestRootName, $dc.Name)
                    $blockAD += ([Environment]::NewLine)
                    $blockAD += '<table><tr><th>Pos.</th><th>Name</th><th class="cnt">Value</th><th class="cnt">Valid</th><th class="cnt">Default</th><th>Behavior</th></tr>'
                    $script:RowColor = '#FFFFFF'
                    $dsaHeur = Resolve-DsaHeuristics -Heuristics $dc.ComplianceItems['DSAHeuristics'].Label
                    foreach ($line in $dsaHeur) {
                        $blockAD += ('<tr style="background-color: {0};"><td>{1}</td><td nowrap="nowrap"><a href="{2}" target="_blank">{3}</a></td><td class="cnt">{4}</td><td class="cnt">{5}</td><td class="cnt">{6}</td><td>{7}</td></tr>' -f $script:RowColor, $line.Position, $line.URI, $line.Name, $line.Character, $line.IsValid, $line.IsDefault, $line.Behavior)
                        $blockAD += ([Environment]::NewLine)
                        Flip-RowColor
                    }
                    $blockAD += '</table>'
                }
            }
            #endregion
            $blockMenu += '</div><hr />'
            $blockMenu += ([Environment]::NewLine)
        }
        #endregion
        #region local machines
        if ($cc.LocalMachines.Count -gt 0) {
            $blockMenu += '<div class="menu" id="menuLM"><a href="#LOCAL_MACHINES">Local Machines</a></div>'
            $blockMenu += ([Environment]::NewLine)
            $blockLM = ('<h1 id="LOCAL_MACHINES">Local Machines ({0})</h1>' -f $cc.LocalMachines.Count)

            foreach ($lm in $cc.LocalMachines) {
                $blockMenu += ('<div class="submenu">&nbsp;<a href="#LM_{0}">{0}</a></div>' -f $lm.MachineName)
                $blockMenu += ([Environment]::NewLine)
                $blockLM += ('<h2 id="LM_{0}">Local Machine: {0}</h2>' -f $lm.MachineName)
                $blockLM += '<table><tr><th>Parameter</th><th>ADFR</th><th>DSP</th><th>Value</th></tr>'
                $blockLM += ([Environment]::NewLine)
                $chtml = Get-ComplianceHTML -ComplianceItem $lm.Compliance -GreyRow -ResetRowColor -NoFlipRowColor
                $blockLM += $chtml.TableRow

                foreach ($nw in $lm.ComplianceItems['Networks'].Data) {
                    $nwBlock = ('<table style="border-bottom:none;"><tr><td>MAC Address</td><td>{0}</td></tr><tr><td>Adapter</td><td>{1}</td></tr><tr><td>Profile</td><td>{2}</td></tr>' -f $nw.MACAddress, $nw.Description, (Get-SMPRSVersionData -Entity NetworkProfile -Version $nw.NetworkProfile))
                    if ($nw.DHCPEnabled) {
                        $nwBlock += '<tr><td>&nbsp;</td><td>DHCP</td></tr>'
                    }
                    foreach ($nwip in $nw.IPConfigs) {
                        $nwBlock += ('<tr><td>Address</td><td>{0} / {1}</td></tr><tr><td>Gateway</td><td>{2}</td></tr>' -f $nwip.IPAddress, $nwip.SubnetMask, $nwip.Gateway)
                    }
                    $nwBlock += ('<tr><td>DNS Servers</td><td>{0}</td></tr>' -f ($nw.DNSServers -join '<br />'))
                    $nwBlock += '</table>'
                    $blockLM += ('<tr style="background-color: {0};"><td><b>Network {1}</b></td><td>&nbsp;</td><td>&nbsp;</td><td>{2}</td></tr>' -f $script:RowColor, $nw.Alias, $nwBlock)
                    $blockLM += ([Environment]::NewLine)
                    Flip-RowColor
                }

                
                foreach ($lmci in $lmCIs) {
                    if ($null -eq $lmci) { continue }
                    if ($lm.ComplianceItems.ContainsKey($lmci)) {
                        $chtml = Get-ComplianceHTML -ComplianceItem $lm.ComplianceItems[$lmci]
                        $blockLM += $chtml.TableRow
                    } else {
                        Write-SMPRSLog -Severity 2 -Message ('Local Machine Compliance Item missing: {0}' -f $lmci)
                    }
                }

                $blockLM += '</table>'
                $blockLM += ([Environment]::NewLine)
            }

            $blockMenu += '<hr />'
            $blockMenu += ([Environment]::NewLine)
        }
        #endregion
        #region legend
        if ($cc.Legend.Count -gt 0) {
            $blockMenu += '<div class="menu" id="menuLegend"><a href="#LEGEND">Legend</a></div>'
            $blockMenu += ([Environment]::NewLine)
            $blockLegend = '<h1 id="LEGEND">LEGEND</h1>'
            $blockLegend += ([Environment]::NewLine)
            $blockLegend += '<p><b>The following noteworthy items and/or problems have been identified in the environment:</b></p>'
            $blockLegend += ([Environment]::NewLine)
            foreach ($legitem in $cc.Legend.GetEnumerator()) {
                $blockLegend += ('<p id="LEGEND_{0}">{1}</p>' -f $legitem.Name, $legitem.Value)
                $blockLegend += ([Environment]::NewLine)
            }
            $blockLegend += $blockB2T
        }
        #endregion
        #region comments
        foreach ($exec in $script:masterData.Executions) {
            $blockComments += ('Execution {0} on {1} as {2} in mode [{3}]: {4} - {5}' -f $exec.ID, $exec.From, $exec.By, $exec.Mode, $exec.Start, $exec.End)
            $blockComments += [Environment]::NewLine
        }
        #endregion
        $html = ($html -replace '###TITLE###', $titleString)
        $html = ($html -replace '###LOGOTEXT###', 'ENVIRONMENT READINESS REPORT')
        $html = ($html -replace '###COMMENTS###', $blockComments)
        $html = ($html -replace '###MENUBLOCK###', $blockMenu)
        $html = ($html -replace '###OVERVIEWBLOCK###', $blockOverview)
        $html = ($html -replace '###LOCALMACHINESBLOCK###', $blockLM)
        $html = ($html -replace '###ADFORESTSBLOCK###', $blockAD)
        $html = ($html -replace '###LEGENDBLOCK###', $blockLegend)
        $html = ($html -replace '###MENUIDLIST###', $listMenuID)
        $html = ($html -replace '###SCRIPTVERSION###', $script:version)
        try {
            $html | Set-Content -Path $outFileHTML -Encoding UTF8 -Force -EA Stop
            Write-SMPRSLog -Severity 1 -Message ('HTML File saved: {0}' -f $outFileHTML)
        } catch {
            Write-SMPRSLog -Severity 3 -Message ('HTML Report failed: {0}' -f $_.Exception.Message)
            $res = $false
        }
    }
    return $res
}

function Get-SMPRSCompliance {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('3.8','4.0','4.1','4.2','5.0','5.1','6.0')]
        [string]$ADFRVersion = '6.0',
        [Parameter(Mandatory=$false)]
        [ValidateSet('3.6','3.8','4.0','4.0SP1','4.1','4.0SP2','4.2','5.0','5.1','5.2')]
        [string]$DSPVersion = '5.2'
    )
    Write-SMPRSLog -Severity 1 -Message ('Getting compliance for ADFR {0} and DSP {1}' -f $ADFRVersion, $DSPVersion)
    $result = [PSCustomObject]@{
        'GeneratedOn' = [datetime]::Now
        'Project' = $Script:masterData.Project
        'TargetVersion' = [PSCustomObject]@{
            'ADFR' = $ADFRVersion
            'DSP' = $DSPVersion
        }
        'LocalMachines' = @()
        'Forests' = @()
        'Legend' = @{}
    }
    $fCounter = 0
    $domCounter = 0
    $dcCounter = 0
    $lmCounter = 0
    $ValidDNSRecordClasses = (0..21) + (24..25) + (28..30) + (33..35) + (39..43) + (46..52)
    $dnsTypeNames = @{
        0 = 'Reserved'
        1 = 'A'
        2 = 'NS'
        3 = 'MD'
        4 = 'MF'
        5 = 'CNAME'
        6 = 'SOA'
        7 = 'MB'
        8 = 'MG'
        9 = 'MR'
        10 = 'NULL'
        11 = 'WKS'
        12 = 'PTR'
        13 = 'HINFO'
        14 = 'MINFO'
        15 = 'MX'
        16 = 'TXT'
        17 = 'RP'
        18 = 'AFSDB'
        19 = 'X25'
        20 = 'ISDN'
        21 = 'RT'
        22 = 'NSAP'
        23 = 'NSAP-PTR'
        24 = 'SIG'
        25 = 'KEY'
        26 = 'PX'
        27 = 'GPOS'
        28 = 'AAAA'
        29 = 'LOC'
        30 = 'NXT'
        31 = 'EID'
        32 = 'NIMLOC'
        33 = 'SRV'
        34 = 'ATMA'
        35 = 'NAPTR'
        36 = 'KX'
        37 = 'CERT'
        38 = 'A6'
        39 = 'DNAME'
        40 = 'SINK'
        41 = 'OPT'
        42 = 'APL'
        43 = 'DS'
        44 = 'SSHFP'
        45 = 'IPSECKEY'
        46 = 'RRSIG'
        47 = 'NSEC'
        48 = 'DNSKEY'
        49 = 'DHCID'
        50 = 'NSEC3'
        51 = 'NSEC3PARAM'
        52 = 'TLSA'
        53 = 'SMIMEA'
        55 = 'HIP'
        56 = 'NINFO'
        57 = 'RKEY'
        58 = 'TALINK'
        59 = 'CDS'
        60 = 'CDNSKEY'
        61 = 'OPENPGPKEY'
        62 = 'CSYNC'
        63 = 'ZONEMD'
        64 = 'SVCB'
        65 = 'HTTPS'
        66 = 'DSYNC'
        67 = 'HHIT'
        68 = 'BRID'
        99 = 'SPF'
        100 = 'UINFO'
        101 = 'UID'
        102 = 'GID'
        103 = 'UNSPEC'
        104 = 'NID'
        105 = 'L32'
        106 = 'L64'
        107 = 'LP'
        108 = 'EUI48'
        109 = 'EUI64'
        128 = 'NXNAME'
        249 = 'TKEY'
        250 = 'TSIG'
        251 = 'IXFR'
        252 = 'AXFR'
        253 = 'MAILB'
        254 = 'MAILA'
        255 = '*'
        256 = 'URI'
        257 = 'CAA'
        258 = 'AVC'
        259 = 'DOA'
        260 = 'AMTRELAY'
        261 = 'RESINFO'
        262 = 'WALLET'
        263 = 'CLA'
        264 = 'IPN'
        32768 = 'TA'
        32769 = 'DLV'
        65535 = 'Reserved'
    }
    $trustTypes = @('0','NT4','AD','MIT','DCE','EntraID')
    $trustDirections = @('Disabled','Inbound','Outbound','Bi-Directional')
    $avsvc = @{
        'CSFalconService' = 'CrowdStrike Falcon'
        'cyserver' = 'Palo Alto Traps'
        'SentinelAgent' = 'SentinelONE'
    }
    $badLocales = @('0000041F','0000042C') # tr-TR = 0000041F, az-Latin-AZ = 0000042C
    $dfsrMigStates = @('UNKNOWN','PREPARED','REDIRECTED','ELIMINATED','UNKNOWN','UNKNOWN','REDIRECTING','UNKNOWN','UNKNOWN','UNKNOWN')
    $allDomains = @()
    $allNBTDomains = @()
    $allDNSServers = @()
    $allDCIPs = @()
    $cTpl = @{
        'Description' = $null
        'Score' = $true
        'Display' = $true
        'Value' = $null
        'Label' = $null
        'OutputValue' = $null
        'ADFR' = 0
        'DSP' = 0
        'Legend' = @()
        'Data' = $null
    }
    Write-SMPRSLog -Severity 1 -Message 'Base structures initialized, starting compliance checks'
    foreach ($forest in $Script:masterData.Forests.GetEnumerator()) {
        $fCounter++
        $fCompliance = [PSCustomObject]@{
            'Index' = $fCounter
            'ForestGUID' = $forest.Name
            'ForestRootDomain' = $forest.Value.ForestRootDomain
            'ForestRootName' = $forest.Value.Domains.Where({$_.DomainFQDN -eq $forest.Value.ForestRootDomain})[0].DomainName
            'ForestSIDHash' = $forest.Value.ForestSIDHash
            'Compliance' = [PSCustomObject]$cTpl
            'ComplianceItems' = @{}
            'Domains' = @()
            'DomainControllers' = @()
            'Partitions' = @()
            'Sites' = @()
            'GroupPolicies' = @()
            'QueryPolicies' = @()
            'Trusts' = @()
        }
        Write-SMPRSLog -Severity 1 -Message ('Forest #{0}: {1} {2}' -f $fCounter, $forest.Name, $forest.Value.ForestRootDomain)
        #region base forest compliance and non-scored items
        # Root NC
        Write-SMPRSLog -Message ('Forest #{0}: Root NC' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Forest root NC'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.ForestRootNC
        $fCompliance.ComplianceItems.Add('ForestRootNC', $ci)

        # Config NC
        Write-SMPRSLog -Message ('Forest #{0}: Config NC' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Configuration NC'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.ConfigNC
        $fCompliance.ComplianceItems.Add('ConfigNC', $ci)

        # Schema NC
        Write-SMPRSLog -Message ('Forest #{0}: Schema NC' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema NC'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaNC
        $fCompliance.ComplianceItems.Add('SchemaNC', $ci)

        # Naming Master
        Write-SMPRSLog -Message ('Forest #{0}: Naming Master' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'FSMO: Naming Master'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.FSMONaming
        $fCompliance.ComplianceItems.Add('FSMONaming', $ci)

        # Schema Master
        Write-SMPRSLog -Message ('Forest #{0}: Schema Master' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'FSMO: Schema Master'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.FSMOSchema
        $fCompliance.ComplianceItems.Add('FSMOSchema', $ci)

        # Schema version
        Write-SMPRSLog -Message ('Forest #{0}: Schema Version' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'AD schema version'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaVersion
        $ci.Label = Get-SMPRSVersionData -Entity ADSchema -Version $ci.Value -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $fCompliance.ComplianceItems.Add('ADSchema', $ci)

        # Schema exchange
        Write-SMPRSLog -Message ('Forest #{0}: Exchange Schema' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Exchange schema version (schema)'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaExchange
        $ci.Label = Get-SMPRSVersionData -Entity EXSchemaRU -Version $ci.Value -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $fCompliance.ComplianceItems.Add('EXSchemaRU', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Exchange schema version (forest)'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.ExchangeForestConfiguration
        $ci.Label = Get-SMPRSVersionData -Entity EXSchemaOV -Version $ci.Value -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $fCompliance.ComplianceItems.Add('EXSchemaOV', $ci)

        # Schema skype
        Write-SMPRSLog -Message ('Forest #{0}: Skype Schema' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Skype for Business version (schema)'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaSkype
        $ci.Label = Get-SMPRSVersionData -Entity SkypeSchema -Version $ci.Value -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $fCompliance.ComplianceItems.Add('SkypeSchema', $ci)

        # Schema LAPS
        Write-SMPRSLog -Message ('Forest #{0}: Legacy LAPS Schema' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Legacy LAPS'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaLapsLegacy
        if ($ci.Value) {
            $ci.Label = 'Enabled'
        } else {
            $ci.Label = 'Disabled'
        }
        $ci.OutputValue = $ci.Label
        $fCompliance.ComplianceItems.Add('LAPSSchemaLegacy', $ci)
        Write-SMPRSLog -Message ('Forest #{0}: Windows LAPS Schema' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Windows LAPS'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaLapsWindows
        if ($ci.Value) {
            $ci.Label = 'Enabled'
        } else {
            $ci.Label = 'Disabled'
        }
        $ci.OutputValue = $ci.Label
        $fCompliance.ComplianceItems.Add('LAPSSchemaWindows', $ci)

        # schema object counts
        Write-SMPRSLog -Message ('Forest #{0}: Schema object counts' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema: active classes'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaClassActive
        $fCompliance.ComplianceItems.Add('SchemaClassActive', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema: defunct classes'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaClassDefunct
        $fCompliance.ComplianceItems.Add('SchemaClassDefunct', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema: active attributes'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaAttributeActive
        $fCompliance.ComplianceItems.Add('SchemaAttributeActive', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema: defunct attributes'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaAttributeDefunct
        $fCompliance.ComplianceItems.Add('SchemaAttributeDefunct', $ci)

        # Tombstone Lifetime
        Write-SMPRSLog -Message ('Forest #{0}: Tombstone Lifetime' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Tombstone Lifetime'
        $ci.Score = $false
        $ci.Display = $true
        if ($null -eq $forest.Value.TombstoneLifetime) {
            $tstlt = 180
            $tstmsg = 'by default (not set in AD)'
        } elseif ($forest.Value.TombstoneLifetime -lt 2) {
            $tstlt = 60
            $tstmsg = 'by default (value is set in AD is too low)'
        } else {
            $tstlt = $forest.Value.TombstoneLifetime
            $tstmsg = 'as set in AD'
        }
        $ci.Value = $tstlt
        $ci.OutputValue = ('{0} days {1}' -f $tstlt, $tstmsg)
        $fCompliance.ComplianceItems.Add('TombstoneLifetime', $ci)
        $effBackupLifetime = $tstlt

        # Recycle Bin
        Write-SMPRSLog -Message ('Forest #{0}: Recycle Bin' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'AD Recycle Bin feature'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $forest.Value.FeatureRecycleBin
        if ($ci.Value) {
            $ci.Label = 'Enabled'
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('RecycleBinOn'))) { $result.Legend.Add('RecycleBinOn','Restore of deleted objects with Recycle Bin enabled will take longer. Password changes made immediately before deletion may not be restored.') }
            $ci.Legend += 'RecycleBinOn'
        } else {
            $ci.Label = 'Disabled'
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('RecycleBinOff'))) { $result.Legend.Add('RecycleBinOff','Immediate restore of deleted objects with Recycle Bin disabled (i.e. from tombstones) may not restore group memberships or other linked attributes.') }
            $ci.Legend += 'RecycleBinOff'
        }
        $fCompliance.ComplianceItems.Add('RecycleBin', $ci)
        $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)
        if ($forest.Value.FeatureRecycleBin) {
            # Deleted Lifetime
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'Deleted Items Lifetime'
            $ci.Score = $false
            $ci.Display = $true
            $ci.Value = $forest.Value.DeletedLifetime
            $ci.OutputValue = ('{0} days' -f $forest.Value.DeletedLifetime)
            $fCompliance.ComplianceItems.Add('DeletedLifetime', $ci)
            if ($forest.Value.DeletedLifetime -gt 1) {
                $effBackupLifetime = $forest.Value.DeletedLifetime
            }
        } 

        # Backup Lifetime
        Write-SMPRSLog -Message ('Forest #{0}: Effective Backup Lifetime' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Effective Backup Lifetime'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $effBackupLifetime
        $ci.OutputValue = ('{0} days' -f $effBackupLifetime)
        if ($effBackupLifetime -lt 14) {
            $ci.ADFR = 2
            if (-not ($result.Legend.ContainsKey('ShortBackupLife'))) { $result.Legend.Add('ShortBackupLife','Short effective backup life affects ADFR backups as well.') }
            $ci.Legend += 'ShortBackupLife'
        }
        $fCompliance.ComplianceItems.Add('BackupLifetime', $ci)
        $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)

        # FFL
        Write-SMPRSLog -Message ('Forest #{0}: Functional Level' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Forest Functional Level'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $forest.Value.ForestFL
        $ci.Label = Get-SMPRSVersionData -Entity FFL -Version $ci.Value -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $trueFL = $forest.Value.ForestFL -as [int]
        if ($null -ne $trueFL) {
            if (2 -gt $trueFL) {
                $ci.DSP = 3
                $ci.ADFR = 3
                if (-not ($result.Legend.ContainsKey('FFL2003'))) { $result.Legend.Add('FFL2003','FFL below 2003 is not supported by Semperis products.') }
                $ci.Legend += 'FFL2003'
            } elseif ((7 -lt $trueFL) -and (($ADFRVersion -lt '5') -or ($DSPVersion -lt '5'))) {
                $ci.DSP = 3
                $ci.ADFR = 3
                if (-not ($result.Legend.ContainsKey('FFL2016'))) { $result.Legend.Add('FFL2016','FFL above 2016 is not supported by Semperis products.') }
                $ci.Legend += 'FFL2016'
            }
        } else {
            Write-SMPRSLog -Severity 2 -Message ('Forest #{0}: FFL [{1}] could not be converted to integer!' -f $fCounter, $forest.Value.ForestFL)
            $ci.DSP = 1
            $ci.ADFR = 1
            if (-not ($result.Legend.ContainsKey('FFLNotCastable'))) { $result.Legend.Add('FFLNotCastable','FFL could not be converted to integer.') }
            $ci.Legend += 'FFLNotCastable'
        }
        $fCompliance.ComplianceItems.Add('ForestFL', $ci)
        $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)

        # PIM feature
        Write-SMPRSLog -Message ('Forest #{0}: PIM Feature' -f $fCounter)
        if (7 -le $forest.Value.ForestFL) {
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'PIM Feature'
            $ci.Score = $true
            $ci.Display = $true
            $ci.Value = $forest.Value.FeaturePIM
            if ($ci.Value) {
                $ci.Label = 'Enabled'
                $ci.DSP = 2
                if (-not ($result.Legend.ContainsKey('FeaturePIM'))) { $result.Legend.Add('FeaturePIM','DSP is not able to track the expiration of TTL for linked attribuites and, if reverted, may create permanent linkings.') }
                $ci.Legend += 'FeaturePIM'
            } else {
                $ci.Label = 'Disabled'
            }
            $fCompliance.ComplianceItems.Add('FeaturePIM', $ci)
            $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
            $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)
        }

        # 32K Page feature
        if (10 -le $forest.Value.ForestFL) {
            Write-SMPRSLog -Message ('Forest #{0}: 32K Feature' -f $fCounter)
            $ci = [PSCustomObject]$cTpl
            $ci.Description = '32K Pages Feature'
            $ci.Score = $true
            $ci.Display = $true
            $ci.Value = $forest.Value.Feature32K
            if ($ci.Value) {
                $ci.Label = 'Enabled'
                $ci.ADFR = 1
                if (-not ($result.Legend.ContainsKey('Feature32K'))) { $result.Legend.Add('Feature32K','32K memory pages may have an effect on ADFR performance.') }
                $ci.Legend += 'Feature32K'
            } else {
                $ci.Label = 'Disabled'
            }
            $fCompliance.ComplianceItems.Add('Feature32K', $ci)
            $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
            $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)
        }

        # SchemaOIDOverlap
        Write-SMPRSLog -Message ('Forest #{0}: Schema OID overlap' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schema: OID overlaps'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $forest.Value.SchemaOIDOverlap.Count
        if ($ci.Value -gt 0) {
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('OIDOverlap'))) { $result.Legend.Add('OIDOverlap','Multiple attributes with identical OID, usually only one of them being active, result in DSP malfunction.') }
            $ci.Legend += 'OIDOverlap'
            $ci.Label = ('{0} OID overlaps found' -f $forest.Value.SchemaOIDOverlap.Count)
            $ci.Data = $forest.Value.SchemaOIDOverlap
        } else {
            $ci.Label = 'No OID overlaps found'
        }
        $fCompliance.ComplianceItems.Add('OIDOverlap', $ci)
        $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)

        # Heuristics
        Write-SMPRSLog -Message ('Forest #{0}: dsHeuristics' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'DS Heuristics'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $forest.Value.Heuristics
        if ($null -ne $ci.Value) {
            $ci.DSP = 1
            $ci.Label = 'DS Heuristics configured'
            $ci.Data = Resolve-DsHeuristics -Heuristics $forest.Value.Heuristics
        } else {
            $ci.Label = 'DS Heuristics not configured (default behavior)'
        }
        $fCompliance.ComplianceItems.Add('DSHeuristics', $ci)
        $fCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $fCompliance.Compliance.ADFR)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)
        #endregion
        #region domains within the forest
        Write-SMPRSLog -Message ('Forest #{0}: Domains' -f $fCounter)
        foreach ($dom in $forest.Value.Domains) {
            $domains = $script:masterData.Domains.GetEnumerator().Where({($_.Value.ForestGUID -eq $forest.Name) -and ($_.Value.DomainFQDN -eq $dom.DomainFQDN)})
            if ($domains.Count -ne 1) {
                Write-SMPRSLog -Severity 2 -Message ('Domain data not found or ambiguous for {0}: record count={1}' -f $dom.DomainFQDN, $domains.Count)
                continue
            }
            $domCounter++
            $domain = $domains[0].Value
            foreach ($gpo in $domain.GPOs) {
                $fCompliance.GroupPolicies += [PSCustomObject]@{
                    'GUID' = $gpo.GUID
                    'Domain' = $domain.DomainFQDN
                    'Name' = $gpo.Name
                    'MachineVersion' = $gpo.MachineVersion
                    'UserVersion' = $gpo.UserVersion
                    'MachineCSEs' = $gpo.MachineCSEs
                    'UserCSEs' = $gpo.UserCSEs
                    'FolderPath' = $gpo.FolderPath
                    'LowASCII' = $gpo.LowASCII
                    'EmptyName' = $gpo.EmptyName
                }
            }
            $domCompliance = [PSCustomObject]@{
                'Index' = $domCounter
                'IsExplored' = $false
                'DomainGUID' = $domains[0].Name
                'DomainFQDN' = $domain.DomainFQDN
                'DomainName' = $domain.DomainName
                'DomainNC' = $domain.DomainNC
                'ExploreDuration' = $domain.ElapsedSeconds
                'Compliance' = [PSCustomObject]$cTpl
                'ComplianceItems' = @{}
                'GroupPolicies' = @()
                'Trusts' = @()
            }
            $allDomains += $domain.DomainFQDN
            $allNBTDomains += $domain.DomainName
            #region base domain compliance items
            # Domain NC
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'Domain NC'
            $ci.Score = $false
            $ci.Display = $true
            $ci.Value = $domain.DomainNC
            $domCompliance.ComplianceItems.Add('DomainNC', $ci)

            # Domain FL
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'Domain Functional Level'
            $ci.Score = $false
            $ci.Display = $true
            $ci.Value = $domain.DomainFL
            $ci.Label = Get-SMPRSVersionData -Entity DFL -Version $domain.DomainFL -DoNotIncludeOriginal
            $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
            $domCompliance.ComplianceItems.Add('DomainFL', $ci)

            if ($domain.IsExplored) {
                Write-SMPRSLog -Severity 1 -Message ('Domain {0} has been explored, processing additional items' -f $domain.DomainFQDN)
                $domCompliance.IsExplored = $true
                # PDCe
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'FSMO: PDC Emulator'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.FSMOPDCe
                $domCompliance.ComplianceItems.Add('FSMOPDCe', $ci)

                # RID Master
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'FSMO: RID Master'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.FSMORID
                $domCompliance.ComplianceItems.Add('FSMORID', $ci)

                # Infrastructure Master
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'FSMO: Infrastructure Master'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.FSMOInfra
                $domCompliance.ComplianceItems.Add('FSMOInfra', $ci)
            
                # Machine Account Quota
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Machine Account Quota'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.MachineAccountQuota
                $domCompliance.ComplianceItems.Add('MachineAccountQuota', $ci)

                # KRBTGT password rotation
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'KRBTGT password last set'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = [datetime]::FromFileTimeUtc($domain.KrbTGTpwdLastSet)
                $ci.OutputValue = (Get-Date $ci.Value -Format 'yyyy-MM-dd HH:mm')
                $domCompliance.ComplianceItems.Add('KRBTGTPwdLastSet', $ci)

                # DA in PU
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'DA protected'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $domain.DAinPU
                if ($ci.Value) {
                    $ci.Label = 'Domain Admins nested in Protected Users'
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('DAinPU'))) { $result.Legend.Add('DAinPU','Under rare conditions, nesting Domain Admins in Protected Users has been known to disrupt forest onboarding in ADFR.') }
                    $ci.Legend += 'DAinPU'
                } else {
                    $ci.Label = 'Domain Admins not nested in Protected Users'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('DAinPU', $ci)

                # AU in PreWin2k
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Authenticated Users legacy permissions'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $domain.AUinPreWin2K
                if ($ci.Value) {
                    $ci.Label = 'Authenticated Users nested in Pre-Windows2000 compatible access'
                } else {
                    $ci.Label = 'Authenticated Users removed from Pre-Windows2000 compatible access'
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('AUinPreWin2K'))) { $result.Legend.Add('AUinPreWin2K','If Authenticated Users have been removed from the Pre-Windows 2000 Compatible Access group, the machine identity of DSP MS cannot read DNS information from application partitions. It does not affect change tracking in those partitions but it affects some security indicators.') }
                    $ci.Legend += 'AUinPreWin2K'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('AUinPreWin2K', $ci)

                # Object count
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of user accounts'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumUsers
                $domCompliance.ComplianceItems.Add('NumUsers', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of active user accounts'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumUsersActive
                $domCompliance.ComplianceItems.Add('NumUsersActive', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of groups'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumGroups
                $domCompliance.ComplianceItems.Add('NumGroups', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of admin users'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumAdmins
                $domCompliance.ComplianceItems.Add('NumAdmins', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of computer accounts'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumComputers
                $domCompliance.ComplianceItems.Add('NumComputers', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of OUs'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.NumOUs
                $domCompliance.ComplianceItems.Add('NumOUs', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of GPOs'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $domain.GPOs.Count
                $domCompliance.ComplianceItems.Add('NumGPOs', $ci)

                # Invalid pwdLastSet
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Users with invalid values of pwdLastSet'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($domain.NumPwdLastSetInvalid -gt 0)
                if (-not $ci.Value) {
                    $ci.Label = 'No users with invalid pwdLastSet values found.'
                } else {
                    $ci.Label = ('{0} users with invalid pwdLastSet values found.' -f $domain.NumPwdLastSetInvalid)
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('PwdLastSetInvalid)'))) { $result.Legend.Add('PwdLastSetInvalid)','Invalid values in pwdLastSet will affect DSP synchronization.') }
                    $ci.Legend += 'PwdLastSetInvalid)'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('PwdLastSetInvalid', $ci)

                # Localhost in name
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Users with localhost in name or SPN'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($domain.NumLocalHostInName -gt 0)
                if (-not $ci.Value) {
                    $ci.Label = 'No users with localhost in name or SPN found.'
                } else {
                    $ci.Label = ('{0} users with localhost in name or SPN found.' -f $domain.NumLocalHostInName)
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('LocalHostInName)'))) { $result.Legend.Add('LocalHostInName)','Users with localhost in sAMAccountName or servicePrincipalName will affect DSP synchronization.') }
                    $ci.Legend += 'LocalHostInName)'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('LocalHostInName', $ci)
            
                # GPOs with bad names
                $numEmptyNames = $domain.GPOs.Where({$_.EmptyName}).Count
                $numBadNames = $domain.GPOs.Where({$_.LowAscII}).Count
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Group Policy Objects with empty names'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($numEmptyNames -gt 0)
                if (-not $ci.Value) {
                    $ci.Label = 'No GPOs with empty name found.'
                } else {
                    $ci.Label = ('{0} GPOs with empty name found.' -f $numEmptyNames)
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('GPOEmptyName)'))) { $result.Legend.Add('GPOEmptyName)','GPOs with empty names will cause confusion when tracking GPO changes in DSP.') }
                    $ci.Legend += 'GPOEmptyName)'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('GPOEmptyName', $ci)
            
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Group Policy Objects with low ASCII characters in names'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($numBadNames -gt 0)
                if (-not $ci.Value) {
                    $ci.Label = 'No GPOs with ASCII characters <32 in names found.'
                } else {
                    $ci.Label = ('{0} GPOs with ASCII characters <32 in names found.' -f $numBadNames)
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('GPOBadName)'))) { $result.Legend.Add('GPOBadName)','GPOs with low ASCII characters in display names will not be backed up successfully by DSP.') }
                    $ci.Legend += 'GPOBadName)'
                }
                $ci.OutputValue = $ci.Label
                $domCompliance.ComplianceItems.Add('GPOBadName', $ci)

                foreach ($trust in $domain.Trusts) {
                    $to = [PSCustomObject]@{
                        'LocalTrustPartner' = $domain.DomainFQDN
                        'RemoteTrustPartner' = $trust.TrustPartner
                        'TrustDirection' = $trust.TrustDirection
                        'TrustDirectionResolved' = $trustDirections[$trust.TrustDirection]
                        'TrustType' = $trust.TrustType
                        'TrustTypeResolved' = $trustTypes[$trust.TrustType]
                        'TrustAttributes' = $trust.TrustAttributes
                        'TrustAttributesResolved' = (Resolve-TrustAttributes -Value $trust.TrustAttributes)
                        'OutputValue' = $null
                    }
                    if ($to.TrustAttributesResolved.ForestTransitive) {
                        $ft = ' [Forest]'
                    } else {
                        $ft = ''
                    }
                    if ($to.TrustAttributesResolved.PIMTrust) {
                        $pim = ' [PIM]'
                    } else {
                        $pim = ''
                    }
                    $to.OutputValue = ('[{0}]{1}{4} [{2}] {3}' -f $to.TrustTypeResolved, $ft, $to.TrustDirectionResolved, $trust.TrustPartner, $pim)
                    $domCompliance.Trusts += $to
                    $fCompliance.Trusts += $to
                }
            }

            foreach ($ci in $domCompliance.ComplianceItems.GetEnumerator()) {
                if ($ci.Value.Score) {
                    $domCompliance.Compliance.ADFR = [math]::Max($ci.Value.ADFR, $domCompliance.Compliance.ADFR)
                    $domCompliance.Compliance.DSP = [math]::Max($ci.Value.DSP, $domCompliance.Compliance.DSP)
                }
            }
            
            #endregion
            $fCompliance.Domains += $domCompliance
            $fCompliance.Compliance.ADFR = [math]::Max($domCompliance.Compliance.ADFR, $fCompliance.Compliance.ADFR)
            $fCompliance.Compliance.DSP = [math]::Max($domCompliance.Compliance.DSP, $fCompliance.Compliance.DSP)
        }
        #endregion
        #region query policies and admin settings
        Write-SMPRSLog -Message ('Forest #{0}: Query Policies' -f $fCounter)
        $fCompliance.QueryPolicies = $forest.Value.QueryPolicies
        #endregion
        #region sites
        Write-SMPRSLog -Message ('Forest #{0}: Sites' -f $fCounter)
        $fCompliance.Sites = $forest.Value.Sites
        #endregion
        #region replication links
        Write-SMPRSLog -Message ('Forest #{0}: Replication Links' -f $fCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Schedule-based replication links'
        $ci.Score = $true
        $ci.Display = $true
        $schBasedLinks = @()
        foreach ($repLink in $forest.Value.ReplicationLinks) {
            if ($repLink.Options -ge 64) { 
                # RODC
                continue 
            }
            $fromSite = $forest.Value.DomainControllers.Where({$_.NTDSA -eq $repLink.FromDC})[0].Site
            $toSite = $forest.Value.DomainControllers.Where({$_.NTDSA -eq $repLink.ToDC})[0].Site
            if (($fromSite -ne $toSite) -and (($repLink.Options -band 8) -eq 0)) {
                $schBasedLinks += [PSCustomObject]@{
                    'FromDC' = $forest.Value.DomainControllers.Where({$_.NTDSA -eq $repLink.FromDC})[0].Name
                    'ToDC' = $forest.Value.DomainControllers.Where({$_.NTDSA -eq $repLink.ToDC})[0].Name
                    'AutoGenerated' = (($repLink.Options -band 1) -gt 0)
                    'OverrideNotify' = (($repLink.Options -band 4) -gt 0)
                    'UseNotify' = (($repLink.Options -band 8) -gt 0)
                }
            }
        }
        $ci.Value = $schBasedLinks.Count
        if ($ci.Value -gt 0) {
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('SlowReplication'))) { $result.Legend.Add('SlowReplication','Schedule-based cross-site replication is detrimental to the reaction speed of DSP change rollback and scripted actions.') }
            $ci.Legend += 'SlowReplication'
            $ci.Label = ('{0} Schedule-based replication links found' -f $ci.Value)
        } else {
            $ci.Label = 'No schedule-based replication links found'
        }
        $ci.OutputValue = $ci.Label
        $ci.Data = $schBasedLinks
        $fCompliance.ComplianceItems.Add('SlowReplication', $ci)
        $fCompliance.Compliance.DSP = [math]::Max($ci.DSP, $fCompliance.Compliance.DSP)
        #endregion
        #region domain controllers within the forest
        Write-SMPRSLog -Message ('Forest #{0}: Domain Controllers' -f $fCounter)
        $dcCounter = 0
        foreach ($dcM in $script:masterdata.DomainControllers.GetEnumerator().Where({$_.Value.ForestGUID -eq $forest.Name})) {
            $dcCounter++
            Write-SMPRSLog -Message ('Forest #{0} DC #{1} [{2}]: Starting compliance eval' -f $fCounter, $dcCounter, $dcM.Name)
            # $dcM = result of machine investigation
            # $dcF = object in the forest replication topology
            # $dcD = computer object in the domain
            try {
                $dcF = $script:masterdata.Forests[$forest.Name].DomainControllers.Where({$_.FQDN -eq $dcM.Name})[0]
                $dcDs = $script:masterdata.Domains.GetEnumerator().Where({$_.Value.ForestGUID -eq $forest.Name}).Value.DomainControllers.Where({$_.FQDN -eq $dcM.Name})
            } catch {
                Write-SMPRSLog -Severity 2 -Message $_.Exception.Message
            }
            Write-SMPRSLog -Message ('Forest #{0} DC #{1} dcF: {2}' -f $fCounter, $dcCounter, ($dcF | ConvertTo-Json -Compress))
            if ($dcDs.Count -gt 0) {
                $dcD = $dcDs[0]
            } else {
                $dcD = $null
            }
            Write-SMPRSLog -Message ('Forest #{0} DC #{1}: data structures initialized' -f $fCounter, $dcCounter)
            $dcCompliance = [PSCustomObject]@{
                'Name' = $dcF.Name
                'FQDN' = $dcF.FQDN
                'IsExplored' = $false
                'ExploreDuration' = $null
                'ProtocolUsed' = $null
                'Site' = $dcF.Site
                'Domain' = $dcF.Domain
                'DN' = $dcF.DN
                'IsGC' = $dcF.IsGC
                'NTDSA' = $dcF.NTDSA
                'Networks' = $null
                'Routes' = $null
                'Compliance' = [PSCustomObject]$cTpl
                'ComplianceItems' = @{}
            }

            if ($dcM.Value.IsExplored) {
                $dcCompliance.IsExplored = $true
                $dcCompliance.ExploreDuration = $dcM.Value.ElapsedSeconds
                $dcCompliance.ProtocolUsed = $dcM.Value.ProtocolUsed
                $dcCompliance.Networks = $dcM.Value.Networks
                $dcCompliance.Routes = $dcM.Value.Routes

                # Hardware
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Make and Model'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Data = [PSCustomObject]@{'Model' = $dcM.Value.Model; 'Manufacturer' = $dcM.Value.Manufacturer}
                $ci.Value = $dcM.Value.Model
                $ci.Label = $dcM.Value.Manufacturer
                if ($dcM.Value.HVDynamicMemory) {
                    $ci.ADFR = 1
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('HVDM'))) { $result.Legend.Add('HVDM','Hyper-V Dynamic Memory may not reflect the memory limit set for the VM.') }
                    $ci.Legend += 'HVDM'
                }
                $ci.OutputValue = ('{0} ({1})' -f $ci.Value, $ci.Label)
                $dcCompliance.ComplianceItems.Add('MakeAndModel', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Number of CPUs'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.NumCPU
                if ($dcM.Value.NumCPU -lt 2) {
                    $ci.ADFR = 3
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('DCCPU'))) { $result.Legend.Add('DCCPU','A minimum of 2 CPUs is required on DCs.') }
                    $ci.Legend += 'DCCPU'
                }
                $dcCompliance.ComplianceItems.Add('NumCPU', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Memory MB'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.MemoryMB
                if ($dcM.Value.MemoryMB -lt 2047) {
                    $ci.ADFR = 3
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('DCMEM2GB'))) { $result.Legend.Add('DCMEM2GB','A minimum of 2 GB RAM is required on DCs.') }
                    $ci.Legend += 'DCMEM2GB'
                } elseif ($dcM.Value.MemoryMB -lt 4095) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('DCMEM4GB'))) { $result.Legend.Add('DCMEM4GB','A minimum of 4 GB RAM is recommended on DCs.') }
                    $ci.Legend += 'DCMEM4GB'
                }
                if ($dcM.Value.HVDynamicMemory) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    $ci.Legend += 'HVDM'
                }
                $dcCompliance.ComplianceItems.Add('MemoryMB', $ci)
            
                # OS Version
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Operating System Version'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.OSBuild -as [int]
                if ($null -eq $ci.Value) {
                    $ci.Value = $dcM.Value.OSBuild
                    $ci.Label = 'Could not be converted'
                } else {
                    $ci.Label = Get-SMPRSVersionData -Entity Build -Version $ci.Value -DoNotIncludeOriginal
                    if ($ci.Value -lt 9600) {
                        $ci.ADFR = 3
                        $ci.DSP = 3
                        if (-not ($result.Legend.ContainsKey('OLDSERVER'))) { $result.Legend.Add('OLDSERVER','No server version older than 2012R2 is supported by either Semperis or Microsoft.') }
                        $ci.Legend += 'OLDSERVER'
                    } elseif ($ci.Value -eq 9600) {
                        $ci.ADFR = 2
                        $ci.DSP = 2
                        if (-not ($result.Legend.ContainsKey('OUTOFSUPPORT'))) { $result.Legend.Add('OUTOFSUPPORT','Server 2012R2 is not supported by Microsoft anymore.') }
                        $ci.Legend += 'OUTOFSUPPORT'
                        if ($DSPVersion -ge '4') {
                            if (-not ($result.Legend.ContainsKey('DSP2012'))) { $result.Legend.Add('DSP2012','Server 2012R2 is not supported by DSP 4.0 and above. It is also not supported by Microsoft anymore.') }
                            $ci.Legend += 'DSP2012'
                        }
                    } elseif ($ci.Value -gt 20348) {
                        if ($ADFRVersion -lt '5') {
                            $ci.ADFR = 3
                        }
                        if ($DSPVersion -lt '5') {
                            $ci.DSP = 3
                        }
                        if (($ci.ADFR + $ci.DSP) -gt 0) {
                            if (-not ($result.Legend.ContainsKey('FUTURESERVER'))) { $result.Legend.Add('FUTURESERVER','Server versions newer than 2025 are not supported by Semperis.') }
                            $ci.Legend += 'FUTURESERVER'
                        }
                    }
                }
                $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
                $dcCompliance.ComplianceItems.Add('OSBuild', $ci)

                # OS Edition
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'OS Edition'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.OSEdition
                $dcCompliance.ComplianceItems.Add('OSEdition', $ci)

                # System drive and path
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System Drive'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.SystemDrive
                $dcCompliance.ComplianceItems.Add('SystemDrive', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Windows Path'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.WindowsPath
                $dcCompliance.ComplianceItems.Add('WindowsPath', $ci)

                # Server Core >> we will prefer the feature list since the registry can be easily changed
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Server Core'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $false
                $coreMismatch = $false
                if ($dcM.Value.ServerCoreFeature) {
                    $ci.Value = $true
                    $ci.ADFR = 1
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('COREDSP'))) { $result.Legend.Add('COREDSP','If you decide to put the DSP agent on Server Core, additional preparations for backing up GPO are necessary.') }
                    $ci.Legend += 'COREDSP'
                    if (-not $dcM.Value.ServerCore) {
                        $ci.ADFR = 2
                        $coreMismatch = $true
                    }
                } elseif ($dcM.Value.ServerCore) {
                    $coreMismatch = $true
                }
                if ($coreMismatch) {
                    if (-not ($result.Legend.ContainsKey('COREMISMATCH'))) { $result.Legend.Add('COREMISMATCH','The server core flag in the registry does not match the feature set of the installed image. ADFR may not be willing to restore this DC.') }
                    $ci.Legend += 'COREMISMATCH'           
                }
                if ($ci.Value) {
                    $ci.OutputValue = 'Core'
                } else {
                    $ci.OutputValue = 'Desktop'
                }
                if ($coreMismatch) {
                    $ci.OutputValue = ('{0} (mismatched)' -f $ci.OutputValue)
                }
                $dcCompliance.ComplianceItems.Add('ServerCore', $ci)
            
                # OS Language
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'OS Language'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.OSLanguage
                $ci.Label = Get-SMPRSVersionData -Entity OSLanguage -Version $dcM.Value.OSLanguage -DoNotIncludeOriginal
                $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
                $dcCompliance.ComplianceItems.Add('OSLanguage', $ci)

                # System locale
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Default input locale'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.SysLocale
                $ci.Label = ('{0} ({1})' -f $dcM.Value.SysLocaleName, $dcM.Value.SysLocale.TrimStart('0'))
                if ($badLocales -contains $dcM.Value.SysLocale) {
                    $ci.ADFR = 3
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('DCLOCALE'))) { $result.Legend.Add('DCLOCALE','If DC (system user) locale is set to one of the known problematic locales (TR or AZ) it will cause problems on ADFR recovery.') }
                    $ci.Legend += 'DCLOCALE'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('SystemLocale', $ci)

                # Timezone
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Time Zone'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.TimeZoneOffset
                if ($dcM.Value.TimeZoneDST) {
                    $lbl = '{0}, on Daylight Saving Time'
                } else {
                    $lbl = '{0}, on Standard Time'
                }
                if ($ci.Value -eq 0) {
                    $ci.Label = ($lbl -f 'GMT')
                } elseif ($ci.Value -gt 0) {
                    $ci.Label = ($lbl -f ('GMT+{0}' -f $ci.Value))
                } else {
                    $ci.Label = ($lbl -f ('GMT{0}' -f $ci.Value))
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('TimeZone', $ci)

                # .NET Version
                $ci = [PSCustomObject]$cTpl
                $ci.Description = '.NET Framework version'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.DotNetVersion
                $ci.Label = Get-SMPRSVersionData -Entity DotNet -Version $dcM.Value.DotNetVersion -DoNotIncludeOriginal
                if (($ADFRVersion -lt '6.0') -and ($dcM.Value.DotNetVersion -lt '394802')) {
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('OLDDOTNETADFR'))) { $result.Legend.Add('OLDDOTNETADFR',('The minimum .NET Framework supported by ADFR {0} is 4.6.2.' -f $ADFRVersion)) }
                    $ci.Legend += 'OLDDOTNETADFR' 
                } elseif (($ADFRVersion -eq '6.0') -and ($dcM.Value.DotNetVersion -lt '461808')) {
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('OLDDOTNETADFR'))) { $result.Legend.Add('OLDDOTNETADFR',('The minimum .NET Framework supported by ADFR {0} is 4.7.2.' -f $ADFRVersion)) }
                    $ci.Legend += 'OLDDOTNETADFR' 
                }
                if (($DSPVersion -le '3.6') -and ($dcM.Value.DotNetVersion -lt '379893')) {
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.5.2.' -f $DSPVersion)) }
                    $ci.Legend += 'OLDDOTNETDSP' 
                } elseif (($DSPVersion -lt '4.0') -and ($dcM.Value.DotNetVersion -lt '394802')) {
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.6.2.' -f $DSPVersion)) }
                    $ci.Legend += 'OLDDOTNETDSP' 
                } elseif (($DSPVersion -ge '4.0') -and ($dcM.Value.DotNetVersion -lt '461808')) {
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.7.2.' -f $DSPVersion)) }
                    $ci.Legend += 'OLDDOTNETDSP' 
                }
                $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
                $dcCompliance.ComplianceItems.Add('DotNetVersion', $ci)

                # .NET Crypto
                $ci = [PSCustomObject]$cTpl
                $ci.Description = '.NET Strong Crypto'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.DotNetStrongCrypto -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.DotNetStrongCrypto
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('DOTNETCRYPTO'))) { $result.Legend.Add('DOTNETCRYPTO','If strong cryptography is disabled in .NET, it will affect agent communication of Semperis products.') }
                    $ci.Legend += 'DOTNETCRYPTO'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('DotNetStrongCrypto', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = '.NET Use Default TLS'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.DotNetDefaultTLS -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.DotNetDefaultTLS
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('DOTNETCRYPTO'))) { $result.Legend.Add('DOTNETCRYPTO','If strong cryptography is disabled in .NET, it will affect agent communication of Semperis products.') }
                    $ci.Legend += 'DOTNETCRYPTO'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('DotNetDefaultTLS', $ci)

                # System Crypto
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System Cryptography: TLS 1.2 Server'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.SChannelTLS12Server -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.SChannelTLS12Server
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('TLS12'))) { $result.Legend.Add('TLS12','TLS 1.2 is the mainstream TLS dialect spoken by all supported OS versions. The only situation where it can be disabled is when all components support TLS 1.3 and it is active.') }
                    $ci.Legend += 'TLS12'
                } elseif ($dcM.Value.SChannelTLS13Server -eq 0) {
                    $ci.ADFR = 3
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                    $ci.Legend += 'NoModernTLS'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('TLS12Server', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System Cryptography: TLS 1.2 Client'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.SChannelTLS12Client -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.SChannelTLS12Client
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('TLS12'))) { $result.Legend.Add('TLS12','TLS 1.2 is the mainstream TLS dialect spoken by all supported OS versions. The only situation where it can be disabled is when all components support TLS 1.3 and it is active.') }
                    $ci.Legend += 'TLS12'
                } elseif ($dcM.Value.SChannelTLS13Client -eq 0) {
                    $ci.ADFR = 3
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                    $ci.Legend += 'NoModernTLS'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('TLS12Client', $ci)
            
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System Cryptography: TLS 1.3 Server'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.SChannelTLS13Server -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.SChannelTLS13Server
                if (($dcM.Value.OSBuild -as [int]) -ge 20348) { # server 2022+
                    if (($dcM.Value.SChannelTLS13Server -eq 0) -and ($dcM.Value.SChannelTLS12Server -eq 0)) {
                        $ci.ADFR = 3
                        $ci.DSP = 3
                        if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                        $ci.Legend += 'NoModernTLS'
                    }
                } else {
                    if ($dcM.Value.SChannelTLS13Server -eq 1) {
                        $ci.ADFR = 2
                        $ci.DSP = 2
                        if (-not ($result.Legend.ContainsKey('TLS13Legacy'))) { $result.Legend.Add('TLS13Legacy','Enabling TLS 1.3 on OS < Server 2022 is an unsafe configuration.') }
                        $ci.Legend += 'TLS13Legacy'
                    } elseif ($dcM.Value.SChannelTLS12Server -eq 0) {
                        $ci.ADFR = 3
                        $ci.DSP = 3
                        if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                        $ci.Legend += 'NoModernTLS'
                    }
                }
                $ci.OutputValue = $ci.Label   
                $dcCompliance.ComplianceItems.Add('TLS13Server', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System Cryptography: TLS 1.3 Client'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.SChannelTLS13Client -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.SChannelTLS13Client
                if (($dcM.Value.OSBuild -as [int]) -ge 20348) { # server 2022+
                    if (($dcM.Value.SChannelTLS13Client -eq 0) -and ($dcM.Value.SChannelTLS12Client -eq 0)) {
                        $ci.ADFR = 3
                        $ci.DSP = 3
                        if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                        $ci.Legend += 'NoModernTLS'
                    }
                } else {
                    if ($dcM.Value.SChannelTLS13Client -eq 1) {
                        $ci.ADFR = 2
                        $ci.DSP = 2
                        if (-not ($result.Legend.ContainsKey('TLS13Legacy'))) { $result.Legend.Add('TLS13Legacy','Enabling TLS 1.3 on OS < Server 2022 is an unsafe configuration.') }
                        $ci.Legend += 'TLS13Legacy'
                    } elseif ($dcM.Value.SChannelTLS12Client -eq 0) {
                        $ci.ADFR = 3
                        $ci.DSP = 3
                        if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                        $ci.Legend += 'NoModernTLS'
                    }
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('TLS13Client', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'FIPS Crypto'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.FIPSCryptoEnabled -ne 0)
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.FIPSCryptoEnabled
                if (-not $ci.Value) {
                    $ci.ADFR = 1
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('FIPSCrypto'))) { $result.Legend.Add('FIPSCrypto','FIPS hardened cryptography in conjunction with other settings may affect agent communication of Semperis products.') }
                    $ci.Legend += 'FIPSCrypto'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('FIPSCrypto', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Cipher suites explicitly configured'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = (-not [string]::IsNullOrWhiteSpace($dcM.Value.CipherSuites))
                if ($ci.Value) {
                    $ci.Label = $dcM.Value.CipherSuites
                } else {
                    $ci.Label = '(OS default)'
                }
                if ($ci.Value) {
                    $ci.ADFR = 1
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('CipherSuites'))) { $result.Legend.Add('CipherSuites','If cipher suites are managed on the DCs, please make sure that compatible settings are found on Semperis machines as well.') }
                    $ci.Legend += 'CipherSuites'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('CipherSuites', $ci)

                # Pinned RPC ports
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Pinned RPC port for NTDS'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $null
                if ($null -ne $dcM.Value.PinnedRPCPortNTDS) {
                    $ci.Value = $dcM.Value.PinnedRPCPortNTDS
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('PinnedRPCPortNTDS'))) { $result.Legend.Add('PinnedRPCPortNTDS','Pinned RPC ports must be taken into account when planning firewall rules for ADFR forest registration.') }
                    $ci.Legend += 'PinnedRPCPortNTDS' 
                }
                $dcCompliance.ComplianceItems.Add('PinnedRPCPortNTDS', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Pinned RPC port for Netlogon'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $null
                if ($null -ne $dcM.Value.PinnedRPCPortNetlogon) {
                    $ci.Value = $dcM.Value.PinnedRPCPortNetlogon
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('PinnedRPCPortNetlogon'))) { $result.Legend.Add('PinnedRPCPortNetlogon','Pinned RPC ports must be taken into account when planning firewall rules for ADFR forest registration.') }
                    $ci.Legend += 'PinnedRPCPortNetlogon' 
                }
                $dcCompliance.ComplianceItems.Add('PinnedRPCPortNetlogon', $ci)

                # Reboot pending
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Reboot Pending'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.RebootPending
                if ($ci.Value) {
                    $ci.ADFR = 1
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('DCRebootPending'))) { $result.Legend.Add('DCRebootPending','A pending reboot of DCs can prevent successful agent deployment.') }
                    $ci.Legend += 'DCRebootPending' 
                }
                $dcCompliance.ComplianceItems.Add('RebootPending', $ci)

                # Certs and ClientAuthTrustMode
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Client Auth Trust Mode'
                $ci.Score = $true
                $ci.Display = $true
                if ($dcM.Value.ClientAuthTrustMode -lt 0) {
                    $ci.Value = 'not set'
                } else {
                    $ci.Value = $dcM.Value.ClientAuthTrustMode
                }
                if ($ci.Value -eq 2) {
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('AuthTrustMode2'))) { $result.Legend.Add('AuthTrustMode2','If ClientAuthTrustMode is set to 2, root certificate misplacement will be ignored by Windows.') }
                    $ci.Legend += 'AuthTrustMode2' 
                } elseif ($dcM.Value.WrongRoots.Count -gt 0) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('ClientAuthDisrupted'))) { $result.Legend.Add('ClientAuthDisrupted','If ClientAuthTrustMode is not set to 2, root certificate misplacement will disrupt ADFR agent communications.') }
                    $ci.Legend += 'ClientAuthDisrupted'
                }
                $dcCompliance.ComplianceItems.Add('AuthTrustMode', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Root certificate misplacement'
                $ci.Score = $true
                $ci.Display = $true
                if ($dcM.Value.WrongRoots.Count -gt 0) {
                    $ci.Value = $true
                    $ci.Label = ('Found {0} non-root certificates in the Trusted Roots store' -f $dcM.Value.WrongRoots.Count)
                    $ci.Data = $dcM.Value.WrongRoots
                    $wrFormatted = @()
                    foreach ($wr in $dcM.Value.WrongRoots) {
                        $wrFormatted += ('<b>{0}:</b>&nbsp;{1}' -f ($wr -split '\:',2)[0], ($wr -split '\:',2)[1])
                    }
                    $ci.OutputValue = $wrFormatted -join '<br />'
                } else {
                    $ci.Value = $false
                    $ci.Label = 'Trusted Roots store only contains certificates signed by themselves'
                    $ci.OutputValue = $ci.Label
                }
                if ($ci.Value) {
                    if ($dcM.Value.ClientAuthTrustMode -eq 2) {
                        $ci.ADFR = 1
                        if (-not ($result.Legend.ContainsKey('AuthTrustMode2'))) { $result.Legend.Add('AuthTrustMode2','If ClientAuthTrustMode is set to 2, root certificate misplacement will be ignored by Windows.') }
                        $ci.Legend += 'AuthTrustMode2'
                    } else {
                        $ci.ADFR = 2
                        if (-not ($result.Legend.ContainsKey('ClientAuthDisrupted'))) { $result.Legend.Add('ClientAuthDisrupted','If ClientAuthTrustMode is not set to 2, root certificate misplacement will disrupt ADFR agent communications.') }
                        $ci.Legend += 'ClientAuthDisrupted'
                    }
                }
                $dcCompliance.ComplianceItems.Add('WrongRoots', $ci)

                # Number of SysKeys - 1000 seems to be a good threshold
                # C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Files in RSA\MachineKeys'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.NumSystemKeys
                if ($ci.Value -gt 1000) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('LotsOfMachineKeys'))) { $result.Legend.Add('LotsOfMachineKeys','A huge number of RSA keys in system profile may cause the disk to fill up and will cause ADFR backups to take a long time.') }
                    $ci.Legend += 'LotsOfMachineKeys' 
                }
                $dcCompliance.ComplianceItems.Add('MachineKeys', $ci)

                # NTDS Path and Size
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTDS Database path'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.NTDSPath
                $dcCompliance.ComplianceItems.Add('NTDSPath', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTDS Database size'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = Get-SMPRSFileSize -SizeBytes $dcM.Value.NTDSSize
                $ci.Data = $dcM.Value.NTDSSize
                $dcCompliance.ComplianceItems.Add('NTDSSize', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTDS Logs path'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.NTDSLogsPath
                $dcCompliance.ComplianceItems.Add('NTDSLogsPath', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTDS Logs count'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.NTDSLogsCount
                $dcCompliance.ComplianceItems.Add('NTDSLogsCount', $ci)

                # SYSVOL Path and Size
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'SYSVOL path'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.SYSVOLPath
                $dcCompliance.ComplianceItems.Add('SYSVOLPath', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'SYSVOL size'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = Get-SMPRSFileSize -SizeBytes $dcM.Value.SYSVOLSize
                $ci.Data = $dcM.Value.SYSVOLSize
                $dcCompliance.ComplianceItems.Add('SYSVOLSize', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'SYSVOL File count'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $dcM.Value.SYSVOLNumFiles
                $dcCompliance.ComplianceItems.Add('SYSVOLCount', $ci)

                # SYSVOL migration state
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'SYSVOL Migration State'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.SYSVOLMigrationState
                $ci.Label = $dfsrMigStates[$ci.Value] 
                if ($ci.Value -notin @(2,3)) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('DFSRMigWrongState'))) { $result.Legend.Add('DFSRMigWrongState','FRS to DFSR migration has not started or is underway. This will cause problems with both backup and recovery.') }
                    $ci.Legend += 'DFSRMigWrongState'
                } elseif ($ci.Value -ne 3) {
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('DFSRMigNotCompleted'))) { $result.Legend.Add('DFSRMigNotCompleted','FRS to DFSR migration is not completed on this DC. Please complete the migration as soon as possible.') }
                    $ci.Legend += 'DFSRMigNotCompleted'
                }
                $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
                $dcCompliance.ComplianceItems.Add('SYSVOLMigState', $ci)

                # Backup size projection
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Local backup copy estimate'
                $ci.Score = $false
                $ci.Display = $true
                $lbSize = .5GB + $dcM.Value.SYSVOLSize + $dcM.Value.NTDSSize
                $ci.Data = $lbSize
                $ci.Value = Get-SMPRSFileSize -SizeBytes $lbSize
                $dcCompliance.ComplianceItems.Add('LocalBackupCopy', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Free space requirement'
                $ci.Score = $false
                $ci.Display = $true
                $fsr = (1GB + $lbSize) * 1.5
                $ci.Data = $fsr
                $ci.Value = Get-SMPRSFileSize -SizeBytes $fsr
                $dcCompliance.ComplianceItems.Add('LocalFreeSpace', $ci)

                # Disk topology and free space
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Hard Drives'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Data = $dcM.Value.DiskDrives
                $ci.Value = ($dcM.Value.DiskDrives.DeviceID -join ' ')
                $mFS = 0
                $mFD = $null
                foreach ($drv in $dcM.Value.DiskDrives) {
                    if ($drv.FreeSpace -gt $mFS) {
                        $mFS = $drv.FreeSpace
                        $mFD = $drv.DeviceID
                    }
                }
                $ci.Label = ('Max free space ({0}) is on drive {1}' -f (Get-SMPRSFileSize -SizeBytes $mFS), $mFD)
                if ($mFS -le $fsr) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('LocalFreeSpaceTooLow'))) { $result.Legend.Add('LocalFreeSpaceTooLow','ADFR needs a certain amount of free disk space to create a backup.') }
                    $ci.Legend += 'LocalFreeSpaceTooLow'
                }
                $ci.OutputValue = ('{0}<br />{1}' -f $ci.Value, $ci.Label)
                $dcCompliance.ComplianceItems.Add('DiskDrives', $ci)

                # LSA Protected mode (warning up to and including DSP 4.0)
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'LSA running as PPL'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.LSAProtected
                $ci.Label = Get-SMPRSOnOff -Value $dcM.Value.LSAProtected
                if ($ci.Value -gt 0) {
                    if ($DSPVersion -lt '4.1') {
                        $ci.DSP = 2
                    } else {
                        $ci.DSP = 1
                    }
                    if (-not ($result.Legend.ContainsKey('LSAProtected'))) { $result.Legend.Add('LSAProtected','Up to Version 4.1, DSP agent could not undo changes to password and sidHistory if LSA on its DC was running in protected mode (PPL).') }
                    $ci.Legend += 'LSAProtected'
                }
                $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
                $dcCompliance.ComplianceItems.Add('LSAProtected', $ci)

                # Audit subcategories policy
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Audit subcategories'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = Get-SMPRSOnOff -Value $dcM.Value.AuditSubcats
                if ($dcM.Value.AuditSubcats -ne 1) {
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('AuditSubcats'))) { $result.Legend.Add('AuditSubcats','DSP requires that audit events be logged using subcategories. Although this is the default behavior of modern OS versions, we recommend you enable this policy.') }
                    $ci.Legend += 'LSAProtected'
                }
                $dcCompliance.ComplianceItems.Add('AuditSubcats', $ci)

                # UserInit
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'UserInit has default value'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Label = $dcM.Value.UserInit
                $ci.Value = ($dcM.Value.UserInit -eq 'C:\Windows\system32\userinit.exe,')
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('UserInit'))) { $result.Legend.Add('UserInit','If UserInit has been altered to start a different shell, this can affect the DCs recovered by ADFR if the required executable is not present.') }
                    $ci.Legend += 'UserInit'
                    $ci.OutputValue = ('No, {0}' -f $dcM.Value.UserInit)
                } else {
                    $ci.OutputValue = ('Yes, {0}' -f $dcM.Value.UserInit)
                }
                $dcCompliance.ComplianceItems.Add('UserInit', $ci)

                # Proxy Server
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'System-level proxy server'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = (-not [string]::IsNullOrWhiteSpace($dcM.Value.ProxyServer))
                $ci.Label = $dcM.Value.ProxyServer
                if ($ci.Value) {
                    $ci.OutputValue = $ci.Label
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('ProxyServer'))) { $result.Legend.Add('ProxyServer','A proxy server set at system level can affect agent communication of Semperis products.') }
                    $ci.Legend += 'ProxyServer'
                } else {
                    $ci.OutputValue = 'not set'
                }
                $dcCompliance.ComplianceItems.Add('ProxyServer', $ci)

                if (-not [string]::IsNullOrWhiteSpace($dcM.Value.ProxyServer)) {
                    $ci = [PSCustomObject]$cTpl
                    $ci.Description = 'System-level proxy override'
                    $ci.Score = $false
                    $ci.Display = $true
                    $ci.Value = (-not [string]::IsNullOrWhiteSpace($dcM.Value.ProxyOverride))
                    $ci.Label = $dcM.Value.ProxyOverride
                    $dcCompliance.ComplianceItems.Add('ProxyOverride', $ci)
                }

                # SMB1 dependency
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'LANMANSERVER depends on SMB1'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.SMB1Dependency
                if ($ci.Value) {
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('SMB1'))) { $result.Legend.Add('SMB1','If LANMANSERVER depends on SMBv1, the legacy feature must be installed on recovery target machines prior to ADFR restore.') }
                    $ci.Legend += 'SMB1'
                    $ci.OutputValue = 'Yes'
                } else {
                    $ci.OutputValue = 'No'
                }
                $dcCompliance.ComplianceItems.Add('SMB1', $ci)

                # Field Engineering
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Field Engineering tracing is enabled'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.FieldEngineering -ge 5)
                if ($ci.Value) {
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('FELDAP'))) { $result.Legend.Add('FELDAP','Field Engineering setting on level 5 or above means that someone is monitoring LDAP queries. This can lead to false alarms caused by DSP Intelligence, Purple Knight or ForestDruid.') }
                    $ci.Legend += 'FELDAP'
                    $ci.OutputValue = ('Yes ({0})' -f $dcM.Value.FieldEngineering)
                } else {
                    $ci.OutputValue = ('No ({0})' -f $dcM.Value.FieldEngineering)
                }
                $dcCompliance.ComplianceItems.Add('FieldEngineering', $ci)

                # NTLM restrictions
                # 0 = all allowed, 1 = domain accts to domain servers, 3 = domain accounts, 5 = domain servers, 7 = all disabled
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTLM restrictions applied'
                $ci.Score = $true
                $ci.Display = $true
                switch ($dcM.Value.RestrictNTLM)  {
                    -1 { $ci.Label = 'not configured (all allowed)' }
                    0 { $ci.Label = 'all allowed' }
                    1 { $ci.Label = 'domain accounts to domain members' }
                    3 { $ci.Label = 'domain accounts' }
                    5 { $ci.Label = 'domain members' }
                    7 { $ci.Label = 'all restricted' }
                }
                $ci.Value = ($dcM.Value.RestrictNTLM -ge 1)
                if ($ci.Value) {
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('DSPNTLM'))) { $result.Legend.Add('DSPNTLM','DSP requires NTLM to perform certain functions. These will not be available if NTLM is restricted.') }
                    $ci.Legend += 'DSPNTLM'
                }
                $dcCompliance.ComplianceItems.Add('RestrictNTLM', $ci)

                # DSA Heuristics
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'DSA Heuristics'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Value = $null
                if ([string]::IsNullOrWhiteSpace($dcM.Value.DSAHeuristics)) {
                    $ci.Label = 'All DSA behaviors are at defaults'
                    $ci.Value = $false
                } else {
                    $ci.Data = Resolve-DsaHeuristics -Heuristics $dcM.Value.DSAHeuristics
                    $ci.Label = $dcM.Value.DSAHeuristics
                    $ci.Value = $true
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('DSAHeuristics', $ci)

                # NTP Config
                if ([string]::IsNullOrWhiteSpace($dcM.Value.NTPPolicyProvider)) {
                    $ntpProv = $dcM.Value.NTPLocalProvider
                    $ntpSrc = $dcM.Value.NTPLocalSource
                    $ntpFrom = 'Local'
                } else {
                    $ntpProv = $dcM.Value.NTPPolicyProvider
                    $ntpSrc = $dcM.Value.NTPPolicySource
                    $ntpFrom = 'Policy'
                }
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'NTP Configuration'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ((-not [string]::IsNullOrWhiteSpace($ntpSrc)) -or ($ntpProv -eq 'NT5DS'))
                if ($ntpProv -eq 'NT5DS') { $ntpSrc = $null }
                $ci.Label = ('{0}: {1} {2}' -f $ntpFrom, $ntpProv, $ntpSrc)
                if ($ci.Value) {
                    if (($ntpProv -ne 'NT5DS') -and ($dcM.Value.DomainRole -ne 5)) {
                        $ci.DSP = 2
                        $ci.ADFR = 2
                        if (-not ($result.Legend.ContainsKey('NTPonDC'))) { $result.Legend.Add('NTPonDC','DCs not running the PDC Emulator FSMO role should be configured to use NT5DS time.') }
                        $ci.Legend += 'NTPonDC'
                    }
                } else {
                    $ci.DSP = 2
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('NoTimeSource'))) { $result.Legend.Add('NoTimeSource','No time source is configured on a DC. This is a dangerous configuration.') }
                    $ci.Legend += 'NoTimeSource'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('NTPConfig', $ci)

                # Backup Exclusions
                #2do add default exclusions for DHCP, WINS and ADCS, if any
                $defaultBEX = @(
                    '%TEMP%\* /s'
                    '\System Volume Information\*.{7cc467ef-6865-4831-853f-2a4817fd1bca}DB'
                    '\System Volume Information\*.{7cc467ef-6865-4831-853f-2a4817fd1bca}ALT'
                    '\System Volume Information\*{3808876B-C176-4e48-B7AE-04046E6CC752} /s'
                    '\System Volume Information\Heat\*.* /s'
                    '\Pagefile.sys'
                    '%SystemRoot%\system32\LogFiles\WMI\RtBackup\*.*'
                    ('{0}\System32\MSDtc\MSDTC.LOG' -f $dcM.Value.WindowsPath)
                    ('{0}\System32\MSDtc\trace\dtctrace.log' -f $dcM.Value.WindowsPath)
                    '%UserProfile%\index.dat /s'
                    '%SystemRoot%\netlogon.chg'
                    ('{0}\domain\DfsrPrivate\* /s' -f $dcM.Value.SYSVOLPath)
                    ('{0}\domain\DfsrPrivate\ConflictAndDeleted\* /s' -f $dcM.Value.SYSVOLPath)
                    ('{0}\staging areas\{1}\* /s' -f $dcM.Value.SYSVOLPath, $dcM.Value.Domain)
                    '\System Volume Information\DFSR\* /s'
                    '\System Volume Information\MountPointManagerRemoteDatabase'
                    '%windir%\softwaredistribution\*.* /s'
                    '%SystemRoot%\system32\dns\backup\dns.log'
                    ('{0}\system32\dns\dns.log' -f $dcM.Value.WindowsPath)
                    '\hiberfil.sys'
                    '%ProgramData%\Microsoft\Windows\WER\* /s'
                    '%systemroot%\Minidump\* /s'
                    '%systemroot%\memory.dmp'
                    ('{0}' -f $dcM.Value.NTDSPath)
                    ('{0}\edb*.log' -f $dcM.Value.NTDSLogsPath)
                )
                if ($dcM.Value.OSBuild -eq '14393') {
                    $defaultBEX += @(
                        ('{0}\System32\Bits.log' -f $dcM.Value.WindowsPath)
                        ('{0}\System32\Bits.bak' -f $dcM.Value.WindowsPath)
                        ('{0}\ProgramData\Microsoft\Network\Downloader\*' -f $dcM.Value.SystemDrive)
                    )
                } else {
                    $defaultBEX += @(
                        '%ProgramData%\Microsoft\Network\Downloader\* /s'
                    )
                }
                $bexExcess = @()
                $bexMissing = @()
                $bexCurrent = @()
                foreach ($bexGroup in $dcM.Value.BackupExclusions.Values) {
                    foreach ($bex in $bexGroup) {
                        $bexCurrent += $bex
                        if ($bex -notin $defaultBEX) {
                            $bexExcess += $bex
                        }
                    }
                }
                foreach ($bex in $defaultBEX) {
                    if ($bex -notin $bexCurrent) {
                        $bexMissing += $bex
                    }
                }
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Missing Backup Exclusions'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($bexMissing.Count -gt 0)
                if ($ci.Value) {
                    $ci.Label = ('{0} missing backup exclusions' -f $bexMissing.Count)
                    $ci.Data = $bexMissing
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('BEXMissing'))) { $result.Legend.Add('BEXMissing','If default backup exclusions have been removed, ADFR backups may take longer and increase in size.') }
                    $ci.Legend += 'BEXMissing'
                } else {
                    $ci.Label = 'All default backup exclusions are in place'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('BEXMissing', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Additional Backup Exclusions'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($bexExcess.Count -gt 0)
                if ($ci.Value) {
                    $ci.Label = ('{0} additional backup exclusions' -f $bexExcess.Count)
                    $ci.Data = $bexExcess
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('BEXExcess'))) { $result.Legend.Add('BEXExcess','If non-default backup exclusions have been added, ADFR backups may not contain all required information for the recovery.') }
                    $ci.Legend += 'BEXExcess'
                } else {
                    $ci.Label = 'No custom backup exclusions have been added'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('BEXExcess', $ci)

                # Replication State
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'SYSVOL replication OK'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.SYSVOLReplicationState -eq 4)
                $state = switch ($dcM.Value.SYSVOLReplicationState) {
                    0 { 'Uninitialized' }
                    1 { 'Initialized' }
                    2 { 'Initial Sync' }
                    3 { 'Auto Recovery' }
                    4 { 'Normal' }
                    5 { 'In Error' }
                    default { 'Undefined' }
                }
                $ci.Label = ('{0}={1}' -f $dcM.Value.SYSVOLReplicationState, $state)
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('SYSVOLReplADFR'))) { $result.Legend.Add('SYSVOLReplADFR','Abnormal SYSVOL replication state will prevent ADFR backups from completing successfully.') }
                    $ci.Legend += 'SYSVOLReplADFR'
                    if (-not ($result.Legend.ContainsKey('SYSVOLReplDSP'))) { $result.Legend.Add('SYSVOLReplDSP','Abnormal SYSVOL replication state may cause GPO backups in DSP to contain invalid or outdated information.') }
                    $ci.Legend += 'SYSVOLReplDSP'
                }
                $ci.OutputValue = ('{1} ({0})' -f $dcM.Value.SYSVOLReplicationState, $state)
                $dcCompliance.ComplianceItems.Add('SYSVOLReplState', $ci)

                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'AD replication OK'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.ReplicationState.Where({$_.Result -ne 0}).Count -eq 0)
                $ci.Data = $dcM.Value.ReplicationState
                $ci.Label = ('{0} replication connections, {1} in abnormal state' -f $dcM.Value.ReplicationState.Count, $dcM.Value.ReplicationState.Where({$_.Result -ne 0}).Count)
                if (-not $ci.Value) {
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('ADReplADFR'))) { $result.Legend.Add('ADReplADFR','Abnormal AD replication state may prevent ADFR backups from completing successfully.') }
                    $ci.Legend += 'ADReplADFR'
                    if (-not ($result.Legend.ContainsKey('ADReplDSP'))) { $result.Legend.Add('ADReplDSP','Abnormal AD replication state will cause problems with initial synchronization and change tracking and may also prevent some security indicators from functioning correctly.') }
                    $ci.Legend += 'ADReplDSP'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('ADReplState', $ci)

                # Networks
                foreach ($nic in $dcM.Value.Networks) {
                    $allDNSServers += $nic.DNSServers.Where({$_ -notlike '127.0*'})
                    $allDCIPs += @($nic.IPConfigs.IPAddress)
                }

                # Persistent routes
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Persistent Routes'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.Routes.Count
                $ci.Data = $dcM.Value.Routes
                if ($ci.Value -gt 0) {
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('PersistentRoutes'))) { $result.Legend.Add('PersistentRoutes','Persistent routes must be accounted for when performing a forest recovery. They are usually there for a reason.') }
                    $ci.Legend += 'PersistentRoutes'
                }

                $dcCompliance.ComplianceItems.Add('PersistentRoutes', $ci)

                # Firewall settings
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Restrictive Firewall Settings'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Data = $dcM.Value.Firewall
                $lvl = 0
                $profs = $dcM.Value.Firewall.Where({$_.Profile -eq 'DomainProfile'})
                if ($profs.Count -gt 0) {
                    $prof = $profs[0]
                    if ($prof.Enabled -and (-not $prof.MergeLocal) -and (($prof.InboundMode -ne 0) -or ($prof.OutboundMode -ne 0))) {
                        $lvl = 2
                        $mode = @()
                        if ($prof.InboundMode -ne 0) { $mode += 'In' }
                        if ($prof.OutboundMode -ne 0) { $mode += 'Out' }
                        if ($prof.Policy) {
                            $msg = ('Traffic blocked without local exceptions for: {0}' -f ($mode -join ', '))
                        }
                    }
                } else {
                    $lvl = 1
                    $msg = 'Settings for the domain profile not recorded'
                }
                if ($lvl -lt 2) {
                    $profs = $dcM.Value.Firewall.Where({$_.Profile -eq 'PrivateProfile'})
                    if ($profs.Count -gt 0) {
                        $prof = $profs[0]
                        if ($prof.Enabled -and (-not $prof.MergeLocal) -and (($prof.InboundMode -ne 0) -or ($prof.OutboundMode -ne 0))) {
                            $lvl = 2
                            if (-not ($result.Legend.ContainsKey('FirewallPrivate'))) { $result.Legend.Add('FirewallPrivate','Although Domain Mode is open for Semperis communications, Private Mode is restricted. If this DC switches to Private Mode after a reboot, agent communications will be blocked.') }
                            $ci.Legend += 'FirewallPrivate'
                        }
                    }
                }

                $ci.Value = ($lvl -gt 0)
                if ($ci.Value) {
                    $ci.Label = $msg
                    $ci.OutputValue = $ci.Label
                    $ci.ADFR = $lvl
                    $ci.DSP = $lvl
                    if (-not ($result.Legend.ContainsKey('Firewall'))) { $result.Legend.Add('Firewall','If Windows Firewall is active and blocks traffic but does not accept local exclusions, firewall policies have to be modified to allow Semperis agent communication.') }
                    $ci.Legend += 'Firewall'
                } else {
                    $ci.OutputValue = 'none'
                }
                $dcCompliance.ComplianceItems.Add('Firewall', $ci)

                # DFS Namespaces
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'DFS Namespaces beside SYSVOL'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcM.Value.DFSNameSpaces.Count
                if ($ci.Value -gt 0) {
                    $ci.Data = $dcM.Value.DFSNameSpaces
                    $ci.Label = ('{0} additional DFS Namespaces hosted on this DC' -f $dcM.Value.DFSNameSpaces.Count)
                    $ci.ADFR = 2
                    if (-not ($result.Legend.ContainsKey('DFSN'))) { $result.Legend.Add('DFSN','DFS Namespaces are not recovered completely by ADFR, the DFSRoots folder has to be created manually.') }
                    $ci.Legend += 'DFSN'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('DFSN', $ci)

                # Additional Features
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Additional Windows Roles'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.Features.Count -gt 0)
                if ($ci.Value) {
                    $ci.Label = $dcM.Value.Features -join ', '
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('OptRoles'))) { $result.Legend.Add('OptRoles','DHCP, WINS and CA roles will be recovered by ADFR with known limitations if the backup set contains this DC.') }
                    $ci.Legend += 'OptRoles'
                } else {
                    $ci.Label = 'none'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('OptRoles', $ci)

                # Antimalware
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Known overzealous antimalware'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dcM.Value.Antimalware.Count -gt 0)
                if ($ci.Value) {
                    $avNames = @()
                    foreach ($av in $dcM.Value.Antimalware) {
                        if ($avsvc.ContainsKey($av)) {
                            $avname = $avsvc[$av]
                        } else {
                            $avname = 'UNKNOWN'
                        }
                        $avNames += ('{0} [{1}]' -f $avname, $av)
                    }
                    $ci.Label = $avNames -join ', '
                    $ci.ADFR = 2
                    $ci.DSP = 2
                    if (-not ($result.Legend.ContainsKey('AVSVC'))) { $result.Legend.Add('AVSVC','Antivirus products have been known to prevent ADFR and DSP from functioning correctly. Please make sure the required exclusions are in place.') }
                    $ci.Legend += 'AVSVC'
                    $ci.OutputValue = $ci.Label
                } else {
                    $ci.OutputValue = 'none'
                }
                $dcCompliance.ComplianceItems.Add('Antivirus', $ci)

            }

            if ($null -ne $dcD) {
                # RODC
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Read-Only Domain Controller'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = $dcD.IsRO
                if ($dcD.IsRO) {
                    $ci.Label = 'RODC'
                    $ci.ADFR = 1
                    $ci.DSP = 1
                    if (-not ($result.Legend.ContainsKey('RODCDSP'))) { $result.Legend.Add('RODCDSP','If IRP is used, Audit agents must be deployed on RODCs.') }
                    if (-not ($result.Legend.ContainsKey('RODCADFR'))) { $result.Legend.Add('RODCADFR','RODCs can be repromoted on forest recovery but their configuration will be lost.') }
                    $ci.Legend += 'RODCDSP'
                    $ci.Legend += 'RODCADFR'
                } else {
                    $ci.Label = 'RWDC'
                }
                $ci.OutputValue = $ci.Label
                $dcCompliance.ComplianceItems.Add('RODC', $ci)
            
                if ($dcD.IsRO) {
                    # RODC-ManagedBy
                    $ci = [PSCustomObject]$cTpl
                    $ci.Description = 'RODC Manager'
                    $ci.Score = $true
                    $ci.Display = $true
                    $ci.Value = ($null -ne $dcD.ManagedBy)
                    if ($ci.Value) {
                        $ci.Label = $dcD.ManagedBy
                        $ci.ADFR = 1
                        if (-not ($result.Legend.ContainsKey('RODCManagedBy'))) { $result.Legend.Add('RODCManagedBy','The managedBy account must be re-added to the RODC after restoration.') }
                        $ci.Legend += 'RODCManagedBy'
                    }
                    $dcCompliance.ComplianceItems.Add('RODCManagedBy', $ci)

                    # RODC-KrbTgt
                    $ci = [PSCustomObject]$cTpl
                    $ci.Description = 'RODC KrbTgt'
                    $ci.Score = $true
                    $ci.Display = $true
                    $ci.Data = $dcD.KrbTGTpwdLastSet
                    $ci.Value = Get-Date $dcD.KrbTGTpwdLastSet -Format 'yyyy-MM-dd HH:mm:ss'
                    $ci.Label = $dcD.KrbTGTAccount
                    $ci.ADFR = 1
                    if (-not ($result.Legend.ContainsKey('RODCKRBTGT'))) { $result.Legend.Add('RODCKRBTGT','The KRBTGT account will be created fresh on repromotion. If this account is found after forest recovery, it must be deleted.') }
                    $ci.Legend += 'RODCKRBTGT'
                    $dcCompliance.ComplianceItems.Add('RODCKRBTGT', $ci)
                }

                # EncTypes
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Encryption Types'
                $ci.Score = $false
                $ci.Display = $true
                $ci.Data = $dcD.EncryptionTypes
                $ci.Value = ('0x{0:x2}' -f $dcD.EncryptionTypes)
                $ci.Label = ((Resolve-EncTypes -Value $dcD.EncryptionTypes) -join ', ')
                $ci.OutputValue = ('{0} : {1}' -f $ci.Value, $ci.Label)
                $dcCompliance.ComplianceItems.Add('DCEncTypes', $ci)
            }
            
            # DC Version
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'DC behavior version'
            $ci.Score = $true
            $ci.Display = $true
            if ($null -eq $dcF.Version) {
                $ci.Value = 'N/A'
                $ci.Label = 'Version not recorded from forest exploration'
                $ci.ADFR = 1
                $ci.DSP = 1
                if (-not ($result.Legend.ContainsKey('DCDATAMISSING'))) { 
                    $result.Legend.Add('DCDATAMISSING','DC replication object data missing from forest exploration')
                    $ci.Legend += 'DCDATAMISSING'
                }
            } else {
                $ci.Value = $dcF.Version
                $ci.Label = Get-SMPRSVersionData -Entity DCVersion -Version $dcF.Version -DoNotIncludeOriginal
                if ($dcF.Version -gt 7) {
                    if ($ADFRVersion -lt '5') {
                        $ci.ADFR = 3
                    }
                    if ($DSPVersion -lt '5') {
                        $ci.DSP = 3
                    }
                    if (($ci.DSP + $ci.ADFR) -gt 0) {
                        if (-not ($result.Legend.ContainsKey('DC2022'))) { $result.Legend.Add('DC2022','Server versions higher than 2022 are not supported by Semperis product version older than 5.x.') }
                        $ci.Legend += 'DC2022'
                    }
                }
            }
            $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
            $dcCompliance.ComplianceItems.Add('DCVersion', $ci)
            
            # ReplEpoch
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'Replication Epoch'
            $ci.Score = $true
            $ci.Display = $true
            $ci.Value = $dcF.ReplicationEpoch
            if ($null -ne $dcF.ReplicationEpoch) {
                Write-SMPRSLog -Severity 0 -Message ('Replication epoch set to {0}' -f $dcF.ReplicationEpoch)
                $ci.Label = ('set to {0}' -f $ci.Value)
                $ci.ADFR = 2
                $ci.DSP = 1
                if (-not ($result.Legend.ContainsKey('ReplEpochSet'))) { $result.Legend.Add('ReplEpochSet','Replication epoch set to a value is an indicator of domain rename or previous ADFR restoration.') }
                $ci.Legend += 'ReplEpochSet'
            } else {
                $ci.Label = 'not set (default)'
            }
            $ci.OutputValue = $ci.Label
            $dcCompliance.ComplianceItems.Add('ReplEpoch', $ci)
            Write-SMPRSLog -Message ('Forest #{0} DC #{1} [{2}]: Concluded compliance eval, updating eval scores' -f $fCounter, $dcCounter, $dcM.Name)
            foreach ($ci in $dcCompliance.ComplianceItems.GetEnumerator()) {
                if ($ci.Value.Score) {
                    $dcCompliance.Compliance.ADFR = [math]::Max($ci.Value.ADFR, $dcCompliance.Compliance.ADFR)
                    $dcCompliance.Compliance.DSP = [math]::Max($ci.Value.DSP, $dcCompliance.Compliance.DSP)
                }
            }
            Write-SMPRSLog -Message ('Forest #{0} DC #{1} [{2}]: Adding eval to compliance dataset, ADFR={3}, DSP={4}' -f $fCounter, $dcCounter, $dcM.Name, $dcCompliance.Compliance.ADFR, $dcCompliance.Compliance.DSP)
            $fCompliance.DomainControllers += $dcCompliance
            Write-SMPRSLog -Message ('Forest #{0} DC #{1} [{2}]: Updating forest compliance' -f $fCounter, $dcCounter, $dcM.Name)
            $fCompliance.Compliance.ADFR = [math]::Max($dcCompliance.Compliance.ADFR, $fCompliance.Compliance.ADFR)
            $fCompliance.Compliance.DSP = [math]::Max($dcCompliance.Compliance.DSP, $fCompliance.Compliance.DSP)
            if ($null -ne $dcM.Value.Domain) {
                Write-SMPRSLog -Message ('Forest #{0} DC #{1} [{2}]: Updating domain compliance' -f $fCounter, $dcCounter, $dcM.Name)
                $fCompliance.Domains.Where({$_.DomainFQDN -eq $dcM.Value.Domain})[0].Compliance.ADFR = [math]::Max($dcCompliance.Compliance.ADFR, $fCompliance.Domains.Where({$_.DomainFQDN -eq $dcM.Value.Domain})[0].Compliance.ADFR)
                $fCompliance.Domains.Where({$_.DomainFQDN -eq $dcM.Value.Domain})[0].Compliance.DSP = [math]::Max($dcCompliance.Compliance.DSP, $fCompliance.Domains.Where({$_.DomainFQDN -eq $dcM.Value.Domain})[0].Compliance.DSP)
            } else {
                Write-SMPRSLog -Severity 2 -Message 'Cannot update domain compliance because domain is missing in data'
            }
        }
        Write-SMPRSLog -Message ('Forest #{0}: Finished Domain Controllers compliance' -f $fCounter)
        #endregion
        #region partitions
        Write-SMPRSLog -Message ('Forest #{0}: Partitions' -f $fCounter)
        foreach ($part in $forest.Value.Partitions) {
            $partCompliance = [PSCustomObject]@{
                'Name' = $part.Name
                'IsDomain' = $part.IsDomain
                'IsGCReplicated' = $part.IsGCReplicated
                'HeldOnDCs' = $forest.Value.DomainControllers.Where({$part.Name -in $_.HostedNCs}).Name
                'Compliance' = [PSCustomObject]$cTpl
                'ComplianceItems' = @{}
            }
            # DNS record classes compliance
            if (-not $part.IsDomain) {
                $dnsNOK = @()
                foreach ($class in $part.DNSRecordClasses) {
                    if ($class -notin $ValidDNSRecordClasses) {
                        $dnsNOK += $class
                    }
                }
                $ci = [PSCustomObject]$cTpl
                $ci.Description = 'Unsupported DNS record types'
                $ci.Score = $true
                $ci.Display = $true
                $ci.Value = ($dnsNOK.Count -gt 0)
                if ($ci.Value) {
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('DNSRecordTypes'))) { $result.Legend.Add('DNSRecordTypes','DNS record classes not supported by Microsoft will result in DSP malfunction. See https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dnsp/39b03b89-2264-4063-8198-d62f62a6441a') }
                    $ci.Legend += 'DNSRecordTypes'
                    $ci.Label = ('{0} unsupported DNS record classes found: {1}' -f $dnsNOK.Count, ($dnsNOK -join ', '))
                    $ci.Data = $dnsNOK
                } else {
                    $ci.Label = 'No unsupported record types found'
                }
                $partCompliance.ComplianceItems.Add('DNSRecordTypes', $ci)
                $partCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $partCompliance.Compliance.ADFR)
                $partCompliance.Compliance.DSP = [math]::Max($ci.DSP, $partCompliance.Compliance.DSP)
                
                if ($part.BadDNSRecords.Count -gt 0) {
                    $ci = [PSCustomObject]$cTpl
                    $ci.Description = 'DNS records of unsupported types'
                    $ci.Score = $true
                    $ci.Display = $true
                    $ci.Value = $part.BadDNSRecords.Count
                    $ci.DSP = 3
                    if (-not ($result.Legend.ContainsKey('DNSRecordTypes'))) { $result.Legend.Add('DNSRecordTypes','DNS record classes not supported by Microsoft will result in DSP malfunction. See https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-dnsp/39b03b89-2264-4063-8198-d62f62a6441a') }
                    $ci.Legend += 'DNSRecordTypes'
                    $ci.Label = ('{0} DNS records of unsupported classes found' -f $part.BadDNSRecords.Count -gt 0)
                    $ci.Data = @()
                    foreach ($rec in $part.BadDNSRecords) {
                        if ($dnsTypeNames.ContainsKey($rec.RTYPE)) {
                            $typeName = $dnsTypeNames[$rec.RTYPE]
                        } else {
                            $typeName = 'Non-IANA'
                        }
                        $ci.Data += ('{0} [{1}] {2}' -f $typeName, $rec.RTYPE, $rec.Name)
                    }
                    $partCompliance.ComplianceItems.Add('BadDNSRecords', $ci)
                    $partCompliance.Compliance.ADFR = [math]::Max($ci.ADFR, $partCompliance.Compliance.ADFR)
                    $partCompliance.Compliance.DSP = [math]::Max($ci.DSP, $partCompliance.Compliance.DSP)
                }
            }
            $fCompliance.Partitions += $partCompliance
            $fCompliance.Compliance.ADFR = [math]::Max($partCompliance.Compliance.ADFR, $fCompliance.Compliance.ADFR)
            $fCompliance.Compliance.DSP = [math]::Max($partCompliance.Compliance.DSP, $fCompliance.Compliance.DSP)
        }
        #endregion
        Write-SMPRSLog -Severity 1 -Message ('Forest #{0}: Overall Compliance' -f $fCounter)
        $result.Forests += $fCompliance
    }

    $allDNSServers = $allDNSServers | Select-Object -Unique

    Write-SMPRSLog -Severity 1 -Message 'Local machine compliance'
    foreach ($lm in $Script:masterData.LocalMachines.GetEnumerator()) {
        $lmCounter++
        Write-SMPRSLog -Severity 1 -Message ('Local machine #{0}: {1}' -f $lmCounter, $lm.Name)
        $lmCompliance = [PSCustomObject]@{
            'Index' = $lmCounter
            'MachineName' = $lm.Name
            'Compliance' = [PSCustomObject]$cTpl
            'ComplianceItems' = @{}
        }
        # Domain Membership
        Write-SMPRSLog -Message ('Local machine #{0}: Domain membership' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Domain Membership'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.DomainRole -eq 3)
        if ($ci.Value) {
            $ci.Label = $lm.Value.Domain
            $knownDomain = ($allDomains -contains $lm.Value.Domain)
            if ($knownDomain) {
                $ci.ADFR = 2
                if (-not ($result.Legend.ContainsKey('ADFRMEMBER'))) { $result.Legend.Add('ADFRMEMBER','ADFR MS being a member of a domain it will protect is not supported.') }
                $ci.Legend += 'ADFRMEMBER'
            } else {
                $ci.ADFR = 1
                if (-not ($result.Legend.ContainsKey('ADFRMEMBER'))) { $result.Legend.Add('ADFRMEMBER','ADFR MS being a member of a domain it will protect is not supported.') }
                $ci.Legend += 'ADFRMEMBER'
                $ci.DSP = 2
                if (-not ($result.Legend.ContainsKey('DSPWRONGAD'))) { $result.Legend.Add('DSPWRONGAD','DSP MS cannot be a member in a domain that is not part of the forest it will protect.') }
                $ci.Legend += 'DSPWRONGAD'
            }
        } else {
            $ci.Label = '(standalone server)'
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('DSPAD'))) { $result.Legend.Add('DSPAD','DSP MS cannot be a standalone server.') }
            $ci.Legend += 'DSPAD'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('DomainMember', $ci)

        # Hardware
        Write-SMPRSLog -Message ('Local machine #{0}: Hardware' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Make and Model'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Data = [PSCustomObject]@{'Model' = $lm.Value.Model; 'Manufacturer' = $lm.Value.Manufacturer}
        $ci.Value = $lm.Value.Model
        $ci.Label = $lm.Value.Manufacturer
        if ($lm.Value.HVDynamicMemory) {
            $ci.ADFR = 1
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('HVDM'))) { $result.Legend.Add('HVDM','Hyper-V Dynamic Memory may not reflect the memory limit set for the VM.') }
            $ci.Legend += 'HVDM'
        }
        $ci.OutputValue = ('{0} ({1})' -f $ci.Value, $ci.Label)
        $lmCompliance.ComplianceItems.Add('MakeAndModel', $ci)

        Write-SMPRSLog -Message ('Local machine #{0}: CPU' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Number of CPUs'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.NumCPU
        if ($lm.Value.NumCPU -lt 2) {
            $ci.ADFR = 3
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('MSCPU2'))) { $result.Legend.Add('MSCPU2','A minimum of 2 CPU cores is required on ADFR MS for single-forest deployments.') }
            $ci.Legend += 'MSCPU2'
        } elseif ($lm.Value.NumCPU -lt 4) {
            $ci.ADFR = 2
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('MSCPU4'))) { $result.Legend.Add('MSCPU4','A minimum of 4 CPU cores is required on ADFR MS for multi-forest deployments and on DSP MS for test deployments.') }
            $ci.Legend += 'MSCPU4'
        } elseif ($lm.Value.NumCPU -lt 8) {
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('MSCPU8'))) { $result.Legend.Add('MSCPU8','A minimum of 8 CPU cores is recommended for production DSP MS.') }
            $ci.Legend += 'MSCPU8'
        }
        $lmCompliance.ComplianceItems.Add('NumCPU', $ci)

        Write-SMPRSLog -Message ('Local machine #{0}: RAM' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Memory MB'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.MemoryMB
        if ($lm.Value.MemoryMB -lt 4095) {
            $ci.ADFR = 3
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('MSMEM4GB'))) { $result.Legend.Add('MSMEM4GB','A minimum of 4 GB RAM is required on all Semperis MS.') }
            $ci.Legend += 'MSMEM4GB'
        } elseif ($lm.Value.MemoryMB -lt 8191) {
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('MSMEM8GB'))) { $result.Legend.Add('MSMEM8GB','A minimum of 8 GB RAM is recommended on production DSP MS.') }
            $ci.Legend += 'MSMEM8GB'
        }
        if ($lm.Value.HVDynamicMemory) {
            $ci.ADFR = 2
            $ci.DSP = 2
            $ci.Legend += 'HVDM'
        }
        $lmCompliance.ComplianceItems.Add('MemoryMB', $ci)
            
        # OS Version
        Write-SMPRSLog -Message ('Local machine #{0}: OS' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Operating System Version'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.OSBuild -as [int]
        if ($null -eq $ci.Value) {
            $ci.Value = $lm.Value.OSBuild
            $ci.Label = 'Could not be converted'
        } else {
            $ci.Label = Get-SMPRSVersionData -Entity Build -Version $ci.Value -DoNotIncludeOriginal
            if ($ci.Value -lt 14393) {
                $ci.ADFR = 3
                $ci.DSP = 3
                if (-not ($result.Legend.ContainsKey('OLDMS'))) { $result.Legend.Add('OLDMS','No server version older than 2016 is supported for any Semperis roles.') }
                $ci.Legend += 'OLDMS'
            } elseif ($ci.Value -gt 20348) {
                if ($ADFRVersion -lt '5') {
                    $ci.ADFR = 3
                }
                if ($DSPVersion -lt '5') {
                    $ci.DSP = 3
                }
                if (($ci.ADFR + $ci.DSP) -gt 0) {
                    if (-not ($result.Legend.ContainsKey('FUTURESERVER'))) { $result.Legend.Add('FUTURESERVER','Server versions newer than 2022 are not supported by Semperis for versions older than 5.x.') }
                    $ci.Legend += 'FUTURESERVER'
                }
            }
        }
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $lmCompliance.ComplianceItems.Add('OSBuild', $ci)

        # OS Edition
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'OS Edition'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.OSEdition
        $lmCompliance.ComplianceItems.Add('OSEdition', $ci)

        # System drive and path
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System Drive'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.SystemDrive
        $lmCompliance.ComplianceItems.Add('SystemDrive', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Windows Path'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.WindowsPath
        $lmCompliance.ComplianceItems.Add('WindowsPath', $ci)

        # Server Core
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Server Core'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $false
        $coreMismatch = $false
        if ($lm.Value.ServerCoreFeature) {
            $ci.Value = $true
            $ci.ADFR = 3
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('COREMS'))) { $result.Legend.Add('COREMS','No Semperis MS can be installed on Server Core.') }
            $ci.Legend += 'COREMS'
            if (-not $lm.Value.ServerCore) {
                $coreMismatch = $true
            }
        } elseif ($lm.Value.ServerCore) {
            $coreMismatch = $true
        }
        if ($coreMismatch) {
            if (-not ($result.Legend.ContainsKey('COREMISMATCH'))) { $result.Legend.Add('COREMISMATCH','The server core flag in the registry does not match the feature set of the installed image. ADFR may not be willing to restore this DC.') }
            $ci.Legend += 'COREMISMATCH'           
        }
        if ($ci.Value) {
            $ci.OutputValue = 'Core'
        } else {
            $ci.OutputValue = 'Desktop'
        }
        if ($coreMismatch) {
            $ci.OutputValue = ('{0} (mismatched)' -f $ci.OutputValue)
        }
        $lmCompliance.ComplianceItems.Add('ServerCore', $ci)
            
        # OS Language
        Write-SMPRSLog -Message ('Local machine #{0}: OS Language' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'OS Language'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.OSLanguage
        $ci.Label = Get-SMPRSVersionData -Entity OSLanguage -Version $lm.Value.OSLanguage -DoNotIncludeOriginal
        if ($ci.Value -ne 1033) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('MSOSLang'))) { $result.Legend.Add('MSOSLang','Semperis MS can only be installed on en-US Windows.') }
            $ci.Legend += 'MSOSLang'
        }
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $lmCompliance.ComplianceItems.Add('OSLanguage', $ci)

        # User Language
        Write-SMPRSLog -Message ('Local machine #{0}: User Language' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'User Language'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.UserLanguage
        $ci.Label = Get-SMPRSVersionData -Entity OSLanguage -Version $lm.Value.UserLanguage -DoNotIncludeOriginal
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        if ($ci.Value -ne 1033) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('MSUILang'))) { $result.Legend.Add('MSUILang','Semperis MS can only be installed from a en-US user session.') }
            $ci.Legend += 'MSUILang'
        }
        $lmCompliance.ComplianceItems.Add('UILanguage', $ci)

        # System Locale
        Write-SMPRSLog -Message ('Local machine #{0}: Default input language' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Default input language'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.SysLocale
        $ci.Label = ('{0} ({1})' -f $lm.Value.SysLocaleName, $lm.Value.SysLocale.TrimStart('0'))
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('SystemLocale', $ci)

        # Timezone
        Write-SMPRSLog -Message ('Local machine #{0}: Timezone' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Time Zone'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.TimeZoneOffset
        if ($lm.Value.TimeZoneDST) {
            $lbl = '{0}, on Daylight Saving Time'
        } else {
            $lbl = '{0}, on Standard Time'
        }
        if ($ci.Value -eq 0) {
            $ci.Label = ($lbl -f 'GMT')
        } elseif ($ci.Value -gt 0) {
            $ci.Label = ($lbl -f ('GMT+{0}' -f $ci.Value))
        } else {
            $ci.Label = ($lbl -f ('GMT{0}' -f $ci.Value))
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('TimeZone', $ci)

        # .NET Version
        Write-SMPRSLog -Message ('Local machine #{0}: .NET Framework' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = '.NET Framework version'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.DotNetVersion
        $ci.Label = Get-SMPRSVersionData -Entity DotNet -Version $lm.Value.DotNetVersion -DoNotIncludeOriginal      
        if (($ADFRVersion -lt '6.0') -and ($lm.Value.DotNetVersion -lt '394802')) {
            $ci.ADFR = 3
            if (-not ($result.Legend.ContainsKey('OLDDOTNETADFR'))) { $result.Legend.Add('OLDDOTNETADFR',('The minimum .NET Framework supported by ADFR {0} is 4.6.2.' -f $ADFRVersion)) }
            $ci.Legend += 'OLDDOTNETADFR' 
        } elseif (($ADFRVersion -eq '6.0') -and ($lm.Value.DotNetVersion -lt '461808')) {
            $ci.ADFR = 3
            if (-not ($result.Legend.ContainsKey('OLDDOTNETADFR'))) { $result.Legend.Add('OLDDOTNETADFR',('The minimum .NET Framework supported by ADFR {0} is 4.7.2.' -f $ADFRVersion)) }
            $ci.Legend += 'OLDDOTNETADFR' 
        }
        if (($DSPVersion -le '3.6') -and ($lm.Value.DotNetVersion -lt '379893')) {
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.5.2.' -f $DSPVersion)) }
            $ci.Legend += 'OLDDOTNETDSP' 
        } elseif (($DSPVersion -lt '4.0') -and ($lm.Value.DotNetVersion -lt '394802')) {
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.6.2.' -f $DSPVersion)) }
            $ci.Legend += 'OLDDOTNETDSP' 
        } elseif (($DSPVersion -ge '4.0') -and ($lm.Value.DotNetVersion -lt '461808')) {
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('OLDDOTNETDSP'))) { $result.Legend.Add('OLDDOTNETDSP',('The minimum .NET Framework supported by DSP {0} is 4.7.2.' -f $DSPVersion)) }
            $ci.Legend += 'OLDDOTNETDSP' 
        }
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $lmCompliance.ComplianceItems.Add('DotNetVersion', $ci)

        # .NET Crypto
        $ci = [PSCustomObject]$cTpl
        $ci.Description = '.NET Strong Crypto'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.DotNetStrongCrypto -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.DotNetStrongCrypto
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('DOTNETCRYPTO'))) { $result.Legend.Add('DOTNETCRYPTO','If strong cryptography is disabled in .NET, it will affect agent communication of Semperis products.') }
            $ci.Legend += 'DOTNETCRYPTO'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('DotNetStrongCrypto', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = '.NET Default TLS'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.DotNetDefaultTLS -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.DotNetDefaultTLS
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('DOTNETCRYPTO'))) { $result.Legend.Add('DOTNETCRYPTO','If strong cryptography is disabled in .NET, it will affect agent communication of Semperis products.') }
            $ci.Legend += 'DOTNETCRYPTO'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('DotNetDefaultTLS', $ci)

        # System Crypto
        Write-SMPRSLog -Message ('Local machine #{0}: System Crypto' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System Cryptography: TLS 1.2 Server'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.SChannelTLS12Server -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.SChannelTLS12Server
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('TLS12'))) { $result.Legend.Add('TLS12','TLS 1.2 is the mainstream TLS dialect spoken by all supported OS versions. The only situation where it can be disabled is when all components support TLS 1.3 and it is active.') }
            $ci.Legend += 'TLS12'
        } elseif ($lm.Value.SChannelTLS13Server -eq 0) {
            $ci.ADFR = 3
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
            $ci.Legend += 'NoModernTLS'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('TLS12Server', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System Cryptography: TLS 1.2 Client'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.SChannelTLS12Client -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.SChannelTLS12Client
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('TLS12'))) { $result.Legend.Add('TLS12','TLS 1.2 is the mainstream TLS dialect spoken by all supported OS versions. The only situation where it can be disabled is when all components support TLS 1.3 and it is active.') }
            $ci.Legend += 'TLS12'
        } elseif ($lm.Value.SChannelTLS13Client -eq 0) {
            $ci.ADFR = 3
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
            $ci.Legend += 'NoModernTLS'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('TLS12Client', $ci)
            
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System Cryptography: TLS 1.3 Server'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.SChannelTLS13Server -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.SChannelTLS13Server
        if (($lm.Value.OSBuild -as [int]) -ge 20348) { # server 2022+
            if (($lm.Value.SChannelTLS13Server -eq 0) -and ($lm.Value.SChannelTLS12Server -eq 0)) {
                $ci.ADFR = 3
                $ci.DSP = 3
                if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                $ci.Legend += 'NoModernTLS'
            }
        } else {
            if ($lm.Value.SChannelTLS13Server -eq 1) {
                $ci.ADFR = 2
                $ci.DSP = 2
                if (-not ($result.Legend.ContainsKey('TLS13Legacy'))) { $result.Legend.Add('TLS13Legacy','Enabling TLS 1.3 on OS < Server 2022 is an unsafe configuration.') }
                $ci.Legend += 'TLS13Legacy'
            } elseif ($lm.Value.SChannelTLS12Server -eq 0) {
                $ci.ADFR = 3
                $ci.DSP = 3
                if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                $ci.Legend += 'NoModernTLS'
            }
        }
        $ci.OutputValue = $ci.Label   
        $lmCompliance.ComplianceItems.Add('TLS13Server', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System Cryptography: TLS 1.3 Client'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.SChannelTLS13Client -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.SChannelTLS13Client
        if (($lm.Value.OSBuild -as [int]) -ge 20348) { # server 2022+
            if (($lm.Value.SChannelTLS13Client -eq 0) -and ($lm.Value.SChannelTLS12Client -eq 0)) {
                $ci.ADFR = 3
                $ci.DSP = 3
                if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                $ci.Legend += 'NoModernTLS'
            }
        } else {
            if ($lm.Value.SChannelTLS13Client -eq 1) {
                $ci.ADFR = 2
                $ci.DSP = 2
                if (-not ($result.Legend.ContainsKey('TLS13Legacy'))) { $result.Legend.Add('TLS13Legacy','Enabling TLS 1.3 on OS < Server 2022 is an unsafe configuration.') }
                $ci.Legend += 'TLS13Legacy'
            } elseif ($lm.Value.SChannelTLS12Client -eq 0) {
                $ci.ADFR = 3
                $ci.DSP = 3
                if (-not ($result.Legend.ContainsKey('NoModernTLS'))) { $result.Legend.Add('NoModernTLS','Both TLS 1.2 and TLS 1.3 are disabled. Semperis agents cannot be deployed.') }
                $ci.Legend += 'NoModernTLS'
            }
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('TLS13Client', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'FIPS Crypto'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.FIPSCryptoEnabled -ne 0)
        $ci.Label = Get-SMPRSOnOff -Value $lm.Value.FIPSCryptoEnabled
        if (-not $ci.Value) {
            $ci.ADFR = 1
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('FIPSCrypto'))) { $result.Legend.Add('FIPSCrypto','FIPS hardened cryptography in conjunction with other settings may affect agent communication of Semperis products.') }
            $ci.Legend += 'FIPSCrypto'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('FIPSCrypto', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Cipher suites explicitly configured'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = (-not [string]::IsNullOrWhiteSpace($lm.Value.CipherSuites))
        if ($ci.Value) {
            $ci.Label = $lm.Value.CipherSuites
        } else {
            $ci.Label = '(OS default)'
        }
        if ($ci.Value) {
            $ci.ADFR = 1
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('CipherSuites'))) { $result.Legend.Add('CipherSuites','If cipher suites are managed on the DCs, please make sure that compatible settings are found on Semperis machines as well.') }
            $ci.Legend += 'CipherSuites'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('CipherSuites', $ci)

        # Reboot pending
        Write-SMPRSLog -Message ('Local machine #{0}: Reboot pending' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Reboot Pending'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.RebootPending
        if ($ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('MSRebootPending'))) { $result.Legend.Add('MSRebootPending','A pending reboot will prevent successful Management Server installation.') }
            $ci.Legend += 'MSRebootPending' 
        }
        $lmCompliance.ComplianceItems.Add('RebootPending', $ci)

        # SQL Instance
        Write-SMPRSLog -Message ('Local machine #{0}: SMPRS SQL Instance' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'SMPRS SQL Instance'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($null -ne $lm.Value.SQLInstance)
        if ($ci.Value) {
            $ci.Data = $lm.Value.SQLInstance
            $ci.OutputValue = ('Config OK: {0}<br />Status: {1}<br />Start mode: {2}<br />Version: {3}<br />Language: {4}' -f $lm.Value.SQLInstance.ConfigOK, $lm.Value.SQLInstance.State, $lm.Value.SQLInstance.StartMode, $lm.Value.SQLInstance.Version, $lm.Value.SQLInstance.Language)
            if ($lm.Value.SQLInstance.ConfigOK) {
                $ci.ADFR = 1
                if (-not ($result.Legend.ContainsKey('SQLPRESENT'))) { $result.Legend.Add('SQLPRESENT','A SQL instance named SMPRS is present on this local machine. Depending on version and configuration, it may or may not be suitable for ADFR.') }
                $ci.Legend += 'SQLPRESENT'
                if ($lm.Value.SQLInstance.MajorVersion -gt '2022') {
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('SQLFUTURE'))) { $result.Legend.Add('SQLFUTURE','No ADFR version supports SQL newer than 2022.') }
                    $ci.Legend += 'SQLFUTURE'
                } elseif ($lm.Value.SQLInstance.MajorVersion -lt '2017') {
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('SQLPAST'))) { $result.Legend.Add('SQLPAST','No ADFR version since 3.8 supports SQL older than 2017.') }
                    $ci.Legend += 'SQLPAST'
                } elseif (($ADFRVersion -lt '4') -and ($lm.Value.SQLInstance.MajorVersion -eq '2022')){
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('SQLOLD3X'))) { $result.Legend.Add('SQLOLD3X','ADFR version 3.x only supports SQL 2017 and 2019.') }
                    $ci.Legend += 'SQLOLD3X'
                } elseif (($ADFRVersion -eq '4.0') -and ($lm.Value.SQLInstance.MajorVersion -ne '2019')){
                    $ci.ADFR = 3
                    if (-not ($result.Legend.ContainsKey('SQLOLD40'))) { $result.Legend.Add('SQLOLD40','ADFR version 4.0 only supports SQL 2019.') }
                    $ci.Legend += 'SQLOLD40'
                } 
            } else {
                $ci.ADFR = 2
                if (-not ($result.Legend.ContainsKey('SQLBAD'))) { $result.Legend.Add('SQLBAD','A SQL instance named SMPRS is present on this local machine but it is not configured correctly. Review the SQL configuration before installing ADFR.') }
                $ci.Legend += 'SQLBAD'
            }
        } else {
            $ci.OutputValue = 'No SQL instance named SMPRS found on the server.'
        }
        $lmCompliance.ComplianceItems.Add('SQLInstance', $ci)

        # Certs and ClientAuthTrustMode
        Write-SMPRSLog -Message ('Local machine #{0}: Cert trust' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Client Auth Trust Mode'
        $ci.Score = $true
        $ci.Display = $true
        if ($lm.Value.ClientAuthTrustMode -lt 0) {
            $ci.Value = 'not set'
        } else {
            $ci.Value = $lm.Value.ClientAuthTrustMode
        }
        if ($ci.Value -eq 2) {
            $ci.ADFR = 1
            if (-not ($result.Legend.ContainsKey('AuthTrustMode2'))) { $result.Legend.Add('AuthTrustMode2','If ClientAuthTrustMode is set to 2, root certificate misplacement will be ignored by Windows.') }
            $ci.Legend += 'AuthTrustMode2' 
        } elseif ($lm.Value.WrongRoots.Count -gt 0) {
            $ci.ADFR = 2
            if (-not ($result.Legend.ContainsKey('ClientAuthDisrupted'))) { $result.Legend.Add('ClientAuthDisrupted','If ClientAuthTrustMode is not set to 2, root certificate misplacement will disrupt ADFR agent communications.') }
            $ci.Legend += 'ClientAuthDisrupted'
        }
        $lmCompliance.ComplianceItems.Add('AuthTrustMode', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Root certificate misplacement'
        $ci.Score = $true
        $ci.Display = $true
        if ($lm.Value.WrongRoots.Count -gt 0) {
            $ci.Value = $true
            $ci.Label = ('Found {0} non-root certificates in the Trusted Roots store' -f $lm.Value.WrongRoots.Count)
            $ci.Data = $lm.Value.WrongRoots
            $wrFormatted = @()
            foreach ($wr in $lm.Value.WrongRoots) {
                $wrFormatted += ('<b>{0}:</b>&nbsp;{1}' -f ($wr -split '\:',2)[0], ($wr -split '\:',2)[1])
            }
            $ci.OutputValue = $wrFormatted -join '<br />'
        } else {
            $ci.Value = $false
            $ci.Label = 'Trusted Roots store only contains certificates signed by themselves'
            $ci.OutputValue = $ci.Label
        }
        if ($ci.Value) {
            if ($lm.Value.ClientAuthTrustMode -eq 2) {
                $ci.ADFR = 1
                if (-not ($result.Legend.ContainsKey('AuthTrustMode2'))) { $result.Legend.Add('AuthTrustMode2','If ClientAuthTrustMode is set to 2, root certificate misplacement will be ignored by Windows.') }
                $ci.Legend += 'AuthTrustMode2'
            } else {
                $ci.ADFR = 2
                if (-not ($result.Legend.ContainsKey('ClientAuthDisrupted'))) { $result.Legend.Add('ClientAuthDisrupted','If ClientAuthTrustMode is not set to 2, root certificate misplacement will disrupt ADFR agent communications.') }
                $ci.Legend += 'ClientAuthDisrupted'
            }
        }
        
        $lmCompliance.ComplianceItems.Add('WrongRoots', $ci)
        
        # Disk topology and free space
        Write-SMPRSLog -Message ('Local machine #{0}: Disk Topology' -f $lmCounter)
        # 2do map to backup and SYSVOL sizes of forests
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Hard Drives'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Data = $lm.Value.DiskDrives
        $ci.Value = ($lm.Value.DiskDrives.DeviceID -join ' ')
        $mFS = 0
        $mFD = $null
        foreach ($drv in $lm.Value.DiskDrives) {
            if ($drv.FreeSpace -gt $mFS) {
                $mFS = $drv.FreeSpace
                $mFD = $drv.DeviceID
            }
        }
        $ci.Label = ('Max free space ({0}) is on drive {1}' -f (Get-SMPRSFileSize -SizeBytes $mFS), $mFD)
        if ($mFS -lt 1GB) {
            $ci.ADFR = 3
            if (-not ($result.Legend.ContainsKey('ADFRFreeSpaceTooLow'))) { $result.Legend.Add('ADFRFreeSpaceTooLow','ADFR MS needs at least 1 GB of free space.') }
            $ci.Legend += 'ADFRFreeSpaceTooLow'
        }
        if ($mFS -lt 2GB) {
            $ci.DSP = 3
            if (-not ($result.Legend.ContainsKey('DSPFreeSpaceTooLow'))) { $result.Legend.Add('DSPFreeSpaceTooLow','DSP MS needs at least 2 GB of free space.') }
            $ci.Legend += 'DSPFreeSpaceTooLow'
        }
        $ci.OutputValue = ('{0}<br />{1}' -f $ci.Value, $ci.Label)
        $lmCompliance.ComplianceItems.Add('DiskDrives', $ci)

        # Browsers
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Supported Browsers'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Data = $lm.Value.Browsers
        $out = @()
        if ($lm.Value.Browsers.Count -eq 0) {
            $ci.Value = $false
            $out += 'No supported browsers found!'
        } else {
            $ci.Value = $false
            foreach ($b in $lm.Value.Browsers) {
                $majorVersion = ($b.Version -split '\.')[0] -as [int]
                if ($majorVersion -lt 100) {
                    $out += ('<b>outdated:</b> {0} version {1}' -f $b.Name, $b.Version)
                } else {
                    $out += ('<b>supported:</b> {0} version {1}' -f $b.Name, $b.Version)
                    $ci.Value = $true
                }
            }
        }
        $ci.OutputValue = ($out -join '<br />')
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 1
            if (-not ($result.Legend.ContainsKey('NoSupBrowser'))) { $result.Legend.Add('NoSupBrowser','A supported browser is recommended on management servers to enable local administration of Semperis products.') }
            $ci.Legend += 'NoSupBrowser' 
        }
        $lmCompliance.ComplianceItems.Add('Browsers', $ci)
                
        # Proxy Server
        Write-SMPRSLog -Message ('Local machine #{0}: System Proxy' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'System-level proxy server'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = (-not [string]::IsNullOrWhiteSpace($lm.Value.ProxyServer))
        $ci.Label = $lm.Value.ProxyServer
        if ($ci.Value) {
            $ci.OutputValue = $ci.Label
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('ProxyServer'))) { $result.Legend.Add('ProxyServer','A proxy server set at system level can affect agent communication of Semperis products.') }
            $ci.Legend += 'ProxyServer'
        } else {
            $ci.OutputValue = 'not set'
        }
        $lmCompliance.ComplianceItems.Add('ProxyServer', $ci)

        if (-not [string]::IsNullOrWhiteSpace($lm.Value.ProxyServer)) {
            $ci = [PSCustomObject]$cTpl
            $ci.Description = 'System-level proxy override'
            $ci.Score = $false
            $ci.Display = $true
            $ci.Value = (-not [string]::IsNullOrWhiteSpace($lm.Value.ProxyOverride))
            $ci.Label = $lm.Value.ProxyOverride
            $lmCompliance.ComplianceItems.Add('ProxyOverride', $ci)
        }
        
        # NTP Config
        Write-SMPRSLog -Message ('Local machine #{0}: NTP' -f $lmCounter)
        if ([string]::IsNullOrWhiteSpace($lm.Value.NTPPolicyProvider)) {
            $ntpProv = $lm.Value.NTPLocalProvider
            $ntpSrc = $lm.Value.NTPLocalSource
            $ntpFrom = 'Local'
        } else {
            $ntpProv = $lm.Value.NTPPolicyProvider
            $ntpSrc = $lm.Value.NTPPolicySource
            $ntpFrom = 'Policy'
        }
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'NTP Configuration'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $false
        $ci.ADFR = 2
        $ci.DSP = 2
        if (($lm.Value.DomainRole -eq 2) -and ($ntpProv -eq 'NTP') -and -not [string]::IsNullOrWhiteSpace($ntpSrc)) {
            $ci.Value = $true
            $ci.ADFR = 0
        } elseif (($lm.Value.DomainRole -eq 3) -and ($ntpProv -eq 'NT5DS')) {
            $ci.Value = $true
            $ci.DSP = 0
        }
        if ($ntpProv -eq 'NT5DS') { $ntpSrc = $null }
        $ci.Label = ('{0}: {1} {2}' -f $ntpFrom, $ntpProv, $ntpSrc)
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('NTPConfig', $ci)

        # Networks
        Write-SMPRSLog -Message ('Local machine #{0}: Networks' -f $lmCounter)
        $domainDNS = 0
        $domesticDNS = 0
        $foreignDNS = 0
        foreach ($nic in $lm.Value.Networks) {
            foreach ($dns in $nic.DNSServers.Where({$_ -notlike '127.0*'})) {
                if ($dns -in $allDCIPs) {
                    $domainDNS++
                } else {
                    if ($dns -in $allDNSServers) {
                        $domesticDNS++
                    } else {
                        $foreignDNS++
                    }
                }
            }
        }
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Networks'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Data = $lm.Value.Networks
        $ci.Value = $lm.Value.Networks.Count
        $lmCompliance.ComplianceItems.Add('Networks', $ci)

        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'DNS settings'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ((($domainDNS + $domesticDNS) -gt 0) -and ($foreignDNS -eq 0))
        $ci.Label = ('{0} DNS servers match DC IPs, {1} DNS servers match DNS used by DCs, {2} DNS servers not used by AD' -f $domainDNS, $domesticDNS, $foreignDNS)
        if (-not $ci.Value) {
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('InconsistentDNS'))) { $result.Legend.Add('InconsistentDNS','An inconsistent DNS configuration may disrupt DSP operations and prevent successful forest onboarding in ADFR.') }
            $ci.Legend += 'InconsistentDNS'
        }
        $ci.OutputValue = $ci.Label
        $lmCompliance.ComplianceItems.Add('DNSSettings', $ci)
        
        # Persistent routes
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Persistent Routes'
        $ci.Score = $false
        $ci.Display = $true
        $ci.Value = $lm.Value.Routes.Count
        $ci.Data = $lm.Value.Routes
        $lmCompliance.ComplianceItems.Add('PersistentRoutes', $ci)

        # Firewall settings
        Write-SMPRSLog -Message ('Local machine #{0}: Windows Firewall' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Restrictive Firewall Settings'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Data = $lm.Value.Firewall
        $lvl = 0
        if ($lm.Value.DomainRole -eq 3) {
            $profs = $lm.Value.Firewall.Where({$_.Profile -eq 'DomainProfile'})
            if ($profs.Count -gt 0) {
                $prof = $profs[0]
                if ($prof.Enabled -and (-not $prof.MergeLocal) -and (($prof.InboundMode -ne 0) -or ($prof.OutboundMode -ne 0))) {
                    $lvl = 2
                    $mode = @()
                    if ($prof.InboundMode -ne 0) { $mode += 'In' }
                    if ($prof.OutboundMode -ne 0) { $mode += 'Out' }
                    if ($prof.Policy) {
                        $msg = ('Traffic blocked without local exceptions for: {0}' -f ($mode -join ', '))
                    }
                }
            } else {
                $lvl = 1
                $msg = 'Settings for the domain profile not recorded'
            }
            if ($lvl -lt 2) {
                $profs = $lm.Value.Firewall.Where({$_.Profile -eq 'PrivateProfile'})
                if ($profs.Count -gt 0) {
                    $prof = $profs[0]
                    if ($prof.Enabled -and (-not $prof.MergeLocal) -and (($prof.InboundMode -ne 0) -or ($prof.OutboundMode -ne 0))) {
                        $lvl = 2
                        if (-not ($result.Legend.ContainsKey('FirewallPrivate'))) { $result.Legend.Add('FirewallPrivate','Although Domain Mode is open for Semperis communications, Private Mode is restricted. If this MS switches to Private Mode after a reboot, agent communications will be blocked.') }
                        $ci.Legend += 'FirewallPrivate'
                    }
                }
            }
        }
        $ci.Value = ($lvl -gt 0)
        if ($ci.Value) {
            $ci.Label = $msg
            $ci.OutputValue = $ci.Label
            $ci.ADFR = $lvl
            $ci.DSP = $lvl
            if (-not ($result.Legend.ContainsKey('Firewall'))) { $result.Legend.Add('Firewall','If Windows Firewall is active and blocks traffic but does not accept local exclusions, firewall policies have to be modified to allow Semperis agent communication.') }
            $ci.Legend += 'Firewall'
        } else {
            $ci.OutputValue = 'none'
        }
        $lmCompliance.ComplianceItems.Add('Firewall', $ci)

        
        # Antimalware
        Write-SMPRSLog -Message ('Local machine #{0}: Antimalware' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Known overzealous antimalware'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($lm.Value.Antimalware.Count -gt 0)
        if ($ci.Value) {
            $avNames = @()
            foreach ($av in $lm.Value.Antimalware) {
                if ($avsvc.ContainsKey($av)) {
                    $avname = $avsvc[$av]
                } else {
                    $avname = 'UNKNOWN'
                }
                $avNames += ('{0} [{1}]' -f $avname, $av)
            }
            $ci.Label = $avNames -join ', '
            $ci.ADFR = 2
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('AVSVC'))) { $result.Legend.Add('AVSVC','Antivirus products have been known to prevent ADFR and DSP from functioning correctly. Please make sure the required exclusions are in place.') }
            $ci.Legend += 'AVSVC'
            $ci.OutputValue = $ci.Label
        } else {
            $ci.OutputValue = 'none'
        }
        $lmCompliance.ComplianceItems.Add('Antivirus', $ci)

        # Image health
        Write-SMPRSLog -Message ('Local machine #{0}: Image Health' -f $lmCounter)
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Windows image health'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = $lm.Value.ImageHealth
        switch ($ci.Value) {
        -1 {
                $ci.ADFR = 3
                $ci.DSP = 3
                $ci.Label = 'Error determining image health'
                if (-not ($result.Legend.ContainsKey('DISMERROR'))) { $result.Legend.Add('DISMERROR','DISM error when trying to determine image health. Please review the CBS log for potential problems with installing roles and features!') }
                $ci.Legend += 'DISMERROR'
            }
        0 {
                $ci.Label = 'Healthy'
            }
        1 {
                $ci.ADFR = 2
                $ci.DSP = 2
                $ci.Label = 'Repairable errors'
                if (-not ($result.Legend.ContainsKey('DISMREP'))) { $result.Legend.Add('DISMREP','DISM reported repairable errors. Repair the image before installing a Semperis product.') }
                $ci.Legend += 'DISMREP'
            }
        2 {
                $ci.ADFR = 3
                $ci.DSP = 3
                $ci.Label = 'Non-repairable errors'
                if (-not ($result.Legend.ContainsKey('DISMNONREP'))) { $result.Legend.Add('DISMNONREP','DISM reported non-repairable errors. You may still be able to repair the image, but reinstalling the server is a safer option.') }
                $ci.Legend += 'DISMNONREP'
            }
            
        }
        $ci.OutputValue = ('{0} ({1})' -f $ci.Label, $ci.Value)
        $lmCompliance.ComplianceItems.Add('ImageHealth', $ci)


        # local user with domain name
        Write-SMPRSLog -Message ('Local machine #{0}: Problematic local users' -f $lmCounter)
        $problemUsers = $lm.Value.LocalUserNames.Where({$_ -in $allNBTDomains})
        $ci = [PSCustomObject]$cTpl
        $ci.Description = 'Local users with the name of a domain'
        $ci.Score = $true
        $ci.Display = $true
        $ci.Value = ($problemUsers.Count -gt 0)
        $ci.Label = ($problemUsers -join ', ')
        if ($ci.Value) {
            $ci.DSP = 2
            if (-not ($result.Legend.ContainsKey('LUDN'))) { $result.Legend.Add('LUDN','A local user with the sAMAccountName equal to NetBIOS name of a domain will disrupt DSP operations.') }
            $ci.Legend += 'LUDN'
            $ci.OutputValue = $ci.Label
        } else {
            $ci.OutputValue = 'No local users have sAMAccountName equal to domain name'
        }
        $lmCompliance.ComplianceItems.Add('LocalUserDomainName', $ci)
        Write-SMPRSLog -Severity 1 -Message ('Local machine #{0}: Overall compliance' -f $lmCounter)
        foreach ($ci in $LMCompliance.ComplianceItems.GetEnumerator()) {
            if ($ci.Value.Score) {
                $lmCompliance.Compliance.ADFR = [math]::Max($ci.Value.ADFR, $lmCompliance.Compliance.ADFR)
                $lmCompliance.Compliance.DSP = [math]::Max($ci.Value.DSP, $lmCompliance.Compliance.DSP)
            }
        }
        Write-SMPRSLog -Severity 1 -Message ('Local machine #{0}: Finished' -f $lmCounter)
        $result.LocalMachines += $lmCompliance
    }

    return $result
}

function Get-DSChildren {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ParentDN,
        [Parameter(Mandatory=$false)]
        [string]$LDAPFilter = "(objectClass=*)",
        [Parameter(Mandatory=$false)]
        [switch]$SearchSubtree,
        [Parameter(Mandatory=$false)]
        [string[]]$Properties,
        [Parameter(Mandatory=$false)]
        [switch]$SearchResults,
        [Parameter(Mandatory=$false)]
        [switch]$NamesOnly,
        [Parameter(Mandatory=$false)]
        [string]$Server,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$false)]
        [switch]$UseLDAPS
    )
    $parentParms = @{
        'ObjectDN' = $ParentDN
    }
    if ($PSBoundParameters.ContainsKey("Server")) {
        $parentParms.Add('Server', $Server)
        if ($UseLDAPS) {
            $parentParms.Add('UseLDAPS', $true)
        }
    }
    if ($PSBoundParameters.ContainsKey("Credential") -and ($null -ne $Credential)) {
        $parentParms.Add('Credential', $Credential)
    }
    $res = @()
    $parent = Get-DSObject @parentParms
    if ($parent.Success) {
        $ds = New-Object System.DirectoryServices.DirectorySearcher
        $ds.SearchRoot = $parent.DSEntry
        $ds.Filter = $LDAPFilter
        if ($SearchSubtree) {
            $ds.SearchScope = [System.DirectoryServices.SearchScope]::Subtree
        } else {
            $ds.SearchScope = [System.DirectoryServices.SearchScope]::OneLevel
        }
        $ds.PageSize = 1000
        if ($SearchResults) {
            foreach ($prop in $Properties) {
                $null = $ds.PropertiesToLoad.Add($prop)
            }
        }
        if ($NamesOnly) {
            $ds.PropertyNamesOnly = $true
        }
        $ds.FindAll().ForEach({
            if ($NamesOnly) {
                $item = $_
            } elseif ($SearchResults -or $NamesOnly) {
                if ($null -eq $_.Properties['distinguishedName']) {
                    Write-SMPRSLog -Severity 2 -Message ('Found a search result without distingiushedName while searching for {0} under {1}' -f $LDAPFilter, $ParentDN)
                    $item = $null
                } else {
                    $item = $_
                }
            } else {
                try {
                    $item = $_.GetDirectoryEntry()
                    if ($null -eq $item.Properties['distinguishedName']) {
                        Write-SMPRSLog -Severity 2 -Message ('Found a directory entry without distingiushedName while searching for {0} under {1}' -f $LDAPFilter, $ParentDN)
                        $item = $null
                    }
                } catch {
                    Write-SMPRSLog -Severity 2 -Message ('Error getting directory entry while searching for {0} under {1}: {2}' -f $LDAPFilter, $ParentDN, $_.Exception.Message)
                    $item = $null
                }
            }
            if ($item) {
                $res += $item
            }
        })
    } else {
        Write-SMPRSLog -Severity 0 -Message ('Parent not found: {0}' -f $ParentDN)
    }
    return $res
}

function Get-DSObject {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$ObjectDN = "RootDSE",
        [Parameter(Mandatory=$false)]
        [string]$Server,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$false)]
        [switch]$UseLDAPS,
        [Parameter(Mandatory=$false)]
        [switch]$UseGC
    )
    $res = [PSCustomObject]@{
        'Success' = $true
        'ErrorMessage' = $null
        'DSEntry' = $null
    }
    if ($UseLDAPS) { 
        if ($useGC) {
            $ldapPort = ':3269'
        } else {
            $ldapPort = ':636'
        }
    } else { 
        if ($useGC) {
            $ldapPort = ':3268'
        } else {
            $ldapPort = ':389'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($Server)) {
        $pathPrefix = "LDAP://$($Server)$($ldapPort)/"
    } else {
        $pathPrefix = "LDAP://$($ldapPort)/"
    }
    $objArgs = @("$($pathPrefix)$ObjectDN")
    if ($PSBoundParameters.ContainsKey("Credential") -and ($null -ne $Credential)) {
        $cred = $Credential
    } else {
        $cred = $null
    }
    if ($null -ne $cred) {
        $objArgs += $cred.UserName
        $objArgs += $cred.GetNetworkCredential().Password
        $objArgs += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing)
    }
    try {
        $dsE = New-Object System.DirectoryServices.DirectoryEntry($objArgs) -EA Stop
        $dsE.RefreshCache()
        $res.DSEntry = $dsE
    } catch {
        $res.ErrorMessage = $_.Exception.Message
        $res.Success = $false
    }
    return $res
}

function Get-SMPRSFileSize {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int64]$SizeBytes
    )
    if ($SizeBytes -lt 0) {
        return $null
    } elseif ($SizeBytes -gt 1099511627776) { # 1 TB
        return ('{0:0.00} TB' -f ($SizeBytes / 1TB))
    } elseif ($SizeBytes -gt 751619276) { # .7 GB
        return ('{0:0.00} GB' -f ($SizeBytes / 1GB))
    } elseif ($SizeBytes -gt 786432) { # .75 MB
        return ('{0:0.00} MB' -f ($SizeBytes / 1MB))
    } elseif ($SizeBytes -gt 8192) {
        return ('{0:0.00} KB' -f ($SizeBytes / 1KB))
    } else {
        return ('{0} Bytes' -f $SizeBytes)
    }
}

function Get-GPOVersion {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [uint32]$VersionNumber = 0
    )
    $result = [PSCustomObject]@{
        'Machine' = 0
        'User' = 0
    }
    if ($VersionNumber -gt 0) {
        $result.Machine = $VersionNumber -band [uint32]"0x0000FFFF"
        $result.User = ($VersionNumber -band [uint32]"0xFFFF0000") / 65536
    }
    return $result
}

function Get-SMPRSOnOff {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [int]$Value = -1
    )
    switch ($Value) {
        -1 { return 'Not configured' }
        0 { return 'Disabled' }
        1 { return 'Enabled' }
        default { return ('Other ({0})' -f $Value) }
    }
}

function Get-RootDSE {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,120)]
        [int]$Timeout = 3
    )
    $result = [PSCustomObject]@{
        'Argument' = $ComputerName
        'Success' = $true
        'FQDN' = $null
        'HostName' = $null
        'RootDomain' = $null
        'RootNC' = $null
        'FFL' = $null
        'ConfigNC' = $null
        'SchemaNC' = $null
        'Domain' = $null
        'ErrorMessage' = $null
    }
    try {
        Add-Type -AssemblyName System.DirectoryServices.Protocols -EA Stop
    } catch {
        $result.Success = $false
        $result.ErrorMessage = $_.Exception.Message
        return $result
    }
    try {
        $ldapIdentifier = New-Object -TypeName System.DirectoryServices.Protocols.LdapDirectoryIdentifier -ArgumentList $ComputerName,389, $false, $true
        $ldap = New-Object -TypeName System.DirectoryServices.Protocols.LdapConnection -ArgumentList $ldapIdentifier
        $ldap.AuthType = [System.DirectoryServices.Protocols.AuthType]::Anonymous
        $ldap.Timeout = New-TimeSpan -Seconds $Timeout
        $request = New-Object -TypeName System.DirectoryServices.Protocols.SearchRequest
        $request.DistinguishedName = $null
        $request.Filter = '(&(objectClass=*))'
        $request.Scope = [System.DirectoryServices.Protocols.SearchScope]::Base
        $null = $request.Attributes.Add('ldapServiceName')
        $null = $request.Attributes.Add('dnsHostName')
        $null = $request.Attributes.Add('forestFunctionality')
        $null = $request.Attributes.Add('rootDomainNamingContext')
        $null = $request.Attributes.Add('configurationNamingContext')
        $null = $request.Attributes.Add('schemaNamingContext')
        $response = $ldap.SendRequest($request)
        if ($response.ResultCode.value__ -eq 0) {
            $svcName = $response.Entries[0].Attributes['ldapServiceName'][0]
            if ($svcName -match '^(?<frd>[a-zA-Z0-9\-\.]+)\:(?<hn>[a-zA-Z0-9\-]+)\$\@(?<dom>[a-zA-Z0-9\-\.]+)$') {
                $result.RootDomain = $Matches['frd']
                $result.HostName = $Matches['hn'].ToUpper()
                $result.Domain = $Matches['dom'].ToLower()
            } else {
                $result.Success = $false
                $result.ErrorMessage = ('LDAP Service name has a wrong format [{0}]' -f $svcName)
            }
            $result.FQDN = $response.Entries[0].Attributes['dnsHostName'][0].ToLower()
            $result.RootNC = $response.Entries[0].Attributes['rootDomainNamingContext'][0]
            $result.ConfigNC = $response.Entries[0].Attributes['configurationNamingContext'][0]
            $result.SchemaNC = $response.Entries[0].Attributes['schemaNamingContext'][0]
            $result.FFL = $response.Entries[0].Attributes['forestFunctionality'][0]
        }
        $ldap.Dispose()
    } catch {
        $result.Success = $false
        $result.ErrorMessage = $_.Exception.Message
    }
    return $result
}

function Get-SMPRSSIDHash {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SID
    )
    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($SID))
    $hashString = [System.BitConverter]::ToString($hash)
    return $hashString.Replace('-', '')
}

function Get-SMPRSVersionData {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('FFL','DFL','ADSchema','EXSchemaRU','EXSchemaOV','DotNet','Build','OSLanguage','SkypeSchema','DCVersion','NetworkProfile')]
        [string]$Entity,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,
        [Parameter(Mandatory=$false)]
        [switch]$DoNotIncludeOriginal
    )
    if ($Version -eq -1) {
        return 'N/A'
    }
    switch ($Entity) {
        'FFL' {
            $metadata = @{
                '0' = '2000'
                '1' = '2003 interim'
                '2' = '2003'
                '3' = '2008'
                '4' = '2008R2'
                '5' = '2012'
                '6' = '2012R2'
                '7' = '2016'
                '10' = '2025'
            }
            if ($metadata.ContainsKey($Version)) {
                $result = ('{1} [{0}]' -f $Version, $metadata[$Version])
            } else {
                $result = ('*unknonwn FFL* [{0}]' -f $Version)
            }
        }
        'DFL' {
            $metadata = @{
                '0' = '2000'
                '1' = '2003 interim'
                '2' = '2003'
                '3' = '2008'
                '4' = '2008R2'
                '5' = '2012'
                '6' = '2012R2'
                '7' = '2016'
                '10' = '2025'
            }
        }
        'DCVersion' {
            $metadata = @{
                '0' = '2000'
                '2' = '2003'
                '3' = '2008'
                '4' = '2008R2'
                '5' = '2012'
                '6' = '2012R2'
                '7' = '2016'
                '10' = '2025'
            }
        }
        'ADSchema' {
            $metadata = @{
                '13' = '2000'
                '30' = '2003'
                '31' = '2003R2'
                '44' = '2008'
                '47' = '2008R2'
                '56' = '2012'
                '69' = '2012R2'
                '87' = '2016'
                '88' = '2019'
                '90' = '2025Preview'
                '91' = '2025'
            }
        }
        'EXSchemaRU' {
            $metadata = @{
                '17003' = '2019 CU10-15/SE'
                '17002' = '2019 CU08-09'
                '17001' = '2019 CU02-07'
                '17000' = '2019 RTM-CU01'
                '15334' = '2016 CU21-23'
                '15333' = '2016 CU19-20'
                '15332' = '2016 CU07-18'
                '15330' = '2016 CU06'
                '15326' = '2016 CU03-05'
                '15325' = '2016 CU02'
                '15323' = '2016 CU01'
                '15317' = '2016 RTM'
                '15312' = '2013 CU07-23'
                '15303' = '2013 CU06'
                '15300' = '2013 CU05'
                '15292' = '2013 CU04'
                '15283' = '2013 CU03'
                '15281' = '2013 CU02'
                '15254' = '2013 CU01'
                '15137' = '2013 RTM'
                '14734' = '2010 SP3'
                '14732' = '2010 SP2'
                '14726' = '2010 SP1'
                '14625' = '2007 SP3'
                '14622' = '2010 RTM/2007 SP2'
                '11116' = '2007 SP1'
                '10637' = '2007 RTM'
            }
        }
        'EXSchemaOV' {
            $metadata = @{
                '16763' = '2019 CU15/SE'
                '16762' = '2019 CU14'
                '16761' = '2019 CU13'
                '16760' = '2019 CU12'
                '16759' = '2019 CU11'
                '16758' = '2019 CU10'
                '16757' = '2019 CU09'
                '16756' = '2019 CU08'
                '16755' = '2019 CU07'
                '16754' = '2019 CU02-06'
                '16752' = '2019 CU01'
                '16751' = '2019 RTM'
                '16223' = '2016 CU23'
                '16222' = '2016 CU22'
                '16221' = '2016 CU21'
                '16220' = '2016 CU20'
                '16219' = '2016 CU19'
                '16218' = '2016 CU18'
                '16217' = '2016 CU13-17'
                '16215' = '2016 CU12'
                '16214' = '2016 CU11'
                '16213' = '2016 CU04-10/2019 Preview'
                '16212' = '2016 CU02-03'
                '16211' = '2016 CU01'
                '16210' = '2016 RTM'
                '16133' = '2013 CU23'
                '16131' = '2013 CU22'
                '16130' = '2013 CU10-21'
                '16041' = '2016 Preview'
                '15965' = '2013 CU06-09'
                '15870' = '2013 CU05'
                '15844' = '2013 CU04/SP1'
                '15763' = '2013 CU03'
                '15688' = '2013 CU02'
                '15614' = '2013 CU01'
                '15449' = '2013 RTM'
                '14322' = '2010 SP3'
                '14247' = '2010 SP2'
                '13214' = '2010 SP1'
                '12640' = '2010 RTM'
                '11222' = '2007 SP2-3'
                '11221' = '2007 SP1'
                '10666' = '2007 RTM'
            }
        }
        'SkypeSchema' {
            $metadata = @{
                '1006' = 'LCS 2005'
                '1007' = 'OCS 2007'
                '1008' = 'OCS 2007 R2'
                '1100' = 'Lync 2010'
                '1150' = 'Lync 2013/Skype for Business'
            }
        }
        'DotNet' {
            $metadata = @{
                '378389' = '4.5'
                '378675' = '4.5.1'
                '379893' = '4.5.2'
                '393295' = '4.6'
                '394254' = '4.6.1'
                '394802' = '4.6.2'
                '460798' = '4.7'
                '461308' = '4.7.1'
                '461808' = '4.7.2'
                '528040' = '4.8'
                '533320' = '4.8.1'
            }
            if (-not $metadata.ContainsKey($Version)) {
                if ($Version -match '^\d{6,7}$') {
                    $matchVersion = $metadata.Keys | Sort-Object -Descending | Where-Object {$_ -le $Version} | Select-Object -First 1
                    if ($null -ne $matchVersion) {
                        $metadata.Add($Version, $metadata[$matchVersion])
                    }
                }
            }
        }
        'Build' {
            $metadata = @{
                '1381' = 'NT4'
                '2195' = '2000'
                '3790' = '2003'
                '3790.1180' = '2003SP1'
                '6001' = '2008'
                '6002' = '2008SP2'
                '6003' = '2008SP2+KB4489887'
                '7600' = '2008R2'
                '7601' = '2008R2SP1'
                '9200' = '2012'
                '9600' = '2012R2'
                '14393' = '2016'
                '17763' = '2019'
                '20348' = '2022'
                '22000' = '2025RTM'
                '26100' = '2025LTSC'
            }
        }
        'OSLanguage' {
            $metadata = @{
                '4' = 'zh-CHS'
                '1025' = 'ar-SA'
                '1026' = 'bg-BG'
                '1027' = 'ca-ES'
                '1028' = 'zh-TW'
                '1029' = 'cs-CZ'
                '1030' = 'da-DK'
                '1031' = 'de-DE'
                '1032' = 'el-GR'
                '1033' = 'en-US'
                '1034' = 'es-ES_tradnl'
                '1035' = 'fi-FI'
                '1036' = 'fr-FR'
                '1037' = 'he-IL'
                '1038' = 'hu-HU'
                '1039' = 'is-IS'
                '1040' = 'it-IT'
                '1041' = 'ja-JP'
                '1042' = 'ko-KR'
                '1043' = 'nl-NL'
                '1044' = 'nb-NO'
                '1045' = 'pl-PL'
                '1046' = 'pt-BR'
                '1047' = 'rm-CH'
                '1048' = 'ro-RO'
                '1049' = 'ru-RU'
                '1050' = 'hr-HR'
                '1051' = 'sk-SK'
                '1052' = 'sq-AL'
                '1053' = 'sv-SE'
                '1054' = 'th-TH'
                '1055' = 'tr-TR'
                '1056' = 'ur-PK'
                '1057' = 'id-ID'
                '1058' = 'uk-UA'
                '1059' = 'be-BY'
                '1060' = 'sl-SI'
                '1061' = 'et-EE'
                '1062' = 'lv-LV'
                '1063' = 'lt-LT'
                '1064' = 'tg-Cyrl-TJ'
                '1065' = 'fa-IR'
                '1066' = 'vi-VN'
                '1067' = 'hy-AM'
                '1068' = 'az-Latn-AZ'
                '1069' = 'eu-ES'
                '1070' = 'hsb-DE'
                '1071' = 'mk-MK'
                '1074' = 'tn-ZA'
                '1076' = 'xh-ZA'
                '1077' = 'zu-ZA'
                '1078' = 'af-ZA'
                '1079' = 'ka-GE'
                '1080' = 'fo-FO'
                '1081' = 'hi-IN'
                '1082' = 'mt-MT'
                '1083' = 'se-NO'
                '1086' = 'ms-MY'
                '1087' = 'kk-KZ'
                '1088' = 'ky-KG'
                '1089' = 'sw-KE'
                '1090' = 'tk-TM'
                '1091' = 'uz-Latn-UZ'
                '1092' = 'tt-RU'
                '1093' = 'bn-IN'
                '1094' = 'pa-IN'
                '1095' = 'gu-IN'
                '1096' = 'or-IN'
                '1097' = 'ta-IN'
                '1098' = 'te-IN'
                '1099' = 'kn-IN'
                '1100' = 'ml-IN'
                '1101' = 'as-IN'
                '1102' = 'mr-IN'
                '1103' = 'sa-IN'
                '1104' = 'mn-MN'
                '1105' = 'bo-CN'
                '1106' = 'cy-GB'
                '1107' = 'km-KH'
                '1108' = 'lo-LA'
                '1110' = 'gl-ES'
                '1111' = 'kok-IN'
                '1113' = 'sd-Deva-IN'
                '1114' = 'syr-SY'
                '1115' = 'si-LK'
                '1116' = 'chr-Cher-US'
                '1117' = 'iu-Cans-CA'
                '1118' = 'am-ET'
                '1121' = 'ne-NP'
                '1122' = 'fy-NL'
                '1123' = 'ps-AF'
                '1124' = 'fil-PH'
                '1125' = 'dv-MV'
                '1128' = 'ha-Latn-NG'
                '1130' = 'yo-NG'
                '1131' = 'quz-BO'
                '1132' = 'nso-ZA'
                '1133' = 'ba-RU'
                '1134' = 'lb-LU'
                '1135' = 'kl-GL'
                '1136' = 'ig-NG'
                '1139' = 'ti-ET'
                '1141' = 'haw-US'
                '1144' = 'ii-CN'
                '1146' = 'arn-CL'
                '1148' = 'moh-CA'
                '1150' = 'br-FR'
                '1152' = 'ug-CN'
                '1153' = 'mi-NZ'
                '1154' = 'oc-FR'
                '1155' = 'co-FR'
                '1156' = 'gsw-FR'
                '1157' = 'sah-RU'
                '1158' = 'quc-Latn-GT'
                '1159' = 'rw-RW'
                '1160' = 'wo-SN'
                '1164' = 'prs-AF'
                '1169' = 'gd-GB'
                '1170' = 'ku-Arab-IQ'
                '2049' = 'ar-IQ'
                '2051' = 'ca-ES-valencia'
                '2052' = 'zh-CN'
                '2055' = 'de-CH'
                '2057' = 'en-GB'
                '2058' = 'es-MX'
                '2060' = 'fr-BE'
                '2064' = 'it-CH'
                '2067' = 'nl-BE'
                '2068' = 'nn-NO'
                '2070' = 'pt-PT'
                '2074' = 'sr-Latn-CS'
                '2077' = 'sv-FI'
                '2080' = 'ur-IN'
                '2092' = 'az-Cyrl-AZ'
                '2094' = 'dsb-DE'
                '2098' = 'tn-BW'
                '2107' = 'se-SE'
                '2108' = 'ga-IE'
                '2110' = 'ms-BN'
                '2115' = 'uz-Cyrl-UZ'
                '2117' = 'bn-BD'
                '2118' = 'pa-Arab-PK'
                '2121' = 'ta-LK'
                '2128' = 'mn-Mong-CN'
                '2137' = 'sd-Arab-PK'
                '2141' = 'iu-Latn-CA'
                '2143' = 'tzm-Latn-DZ'
                '2151' = 'ff-Latn-SN'
                '2155' = 'quz-EC'
                '2163' = 'ti-ER'
                '3073' = 'ar-EG'
                '3076' = 'zh-HK'
                '3079' = 'de-AT'
                '3081' = 'en-AU'
                '3082' = 'es-ES'
                '3084' = 'fr-CA'
                '3098' = 'sr-Cyrl-CS'
                '3131' = 'se-FI'
                '3179' = 'quz-PE'
                '4097' = 'ar-LY'
                '4100' = 'zh-SG'
                '4103' = 'de-LU'
                '4105' = 'en-CA'
                '4106' = 'es-GT'
                '4108' = 'fr-CH'
                '4122' = 'hr-BA'
                '4155' = 'smj-NO'
                '4191' = 'tzm-Tfng-MA'
                '5121' = 'ar-DZ'
                '5124' = 'zh-MO'
                '5127' = 'de-LI'
                '5129' = 'en-NZ'
                '5130' = 'es-CR'
                '5132' = 'fr-LU'
                '5146' = 'bs-Latn-BA'
                '5179' = 'smj-SE'
                '6145' = 'ar-MA'
                '6153' = 'en-IE'
                '6154' = 'es-PA'
                '6156' = 'fr-MC'
                '6170' = 'sr-Latn-BA'
                '6203' = 'sma-NO'
                '7169' = 'ar-TN'
                '7177' = 'en-ZA'
                '7178' = 'es-DO'
                '7194' = 'sr-Cyrl-BA'
                '7227' = 'sma-SE'
                '8193' = 'ar-OM'
                '8201' = 'en-JM'
                '8202' = 'es-VE'
                '8218' = 'bs-Cyrl-BA'
                '8251' = 'sms-FI'
                '9217' = 'ar-YE'
                '9225' = 'en-029'
                '9226' = 'es-CO'
                '9242' = 'sr-Latn-RS'
                '9275' = 'smn-FI'
                '10241' = 'ar-SY'
                '10249' = 'en-BZ'
                '10250' = 'es-PE'
                '10266' = 'sr-Cyrl-RS'
                '11265' = 'ar-JO'
                '11273' = 'en-TT'
                '11274' = 'es-AR'
                '11290' = 'sr-Latn-ME'
                '12289' = 'ar-LB'
                '12297' = 'en-ZW'
                '12298' = 'es-EC'
                '12314' = 'sr-Cyrl-ME'
                '13313' = 'ar-KW'
                '13321' = 'en-PH'
                '13322' = 'es-CL'
                '14337' = 'ar-AE'
                '14346' = 'es-UY'
                '15361' = 'ar-BH'
                '15370' = 'es-PY'
                '16385' = 'ar-QA'
                '16393' = 'en-IN'
                '16394' = 'es-BO'
                '17417' = 'en-MY'
                '17418' = 'es-SV'
                '18441' = 'en-SG'
                '18442' = 'es-HN'
                '19466' = 'es-NI'
                '20490' = 'es-PR'
                '21514' = 'es-US'
                '31748' = 'zh-CHT'
            }
        }
        'NetworkProfile' {
            $metadata = @{
                '0' = 'Public'
                '1' = 'Private'
                '2' = 'Domain'
            }
        }
        default {
            $metadata = @{}
        }
    }
    if ($metadata.ContainsKey($Version)) {
        if ($DoNotIncludeOriginal) {
            $result = $metadata[$Version]
        } else {
            $result = ('{1} [{0}]' -f $Version, $metadata[$Version])
        }
    } else {
        if ($DoNotIncludeOriginal) {
            $result = ('*unknonwn {0}*' -f $Entity)
        } else {
            $result = ('*unknonwn {1}* [{0}]' -f $Version, $Entity)
        }
    }
    return $result
}

$script:HTMLTemplate = @'
<!DOCTYPE html>
<html>
<head>
<title>###TITLE###</title>
<style>
*{
  box-sizing: border-box;
}
html {
  line-height: 1.15; /* 1 */
  -webkit-text-size-adjust: 100%; /* 2 */
}
body {
  padding: 0px;
  background-color: lightgray;
}
pre {
	line-height: 1;
}
a {
  color: inherit;
  text-decoration: inherit;
}
a:hover {
	text-decoration: underline;
}
body,td {
	font-family: Segoe UI,Roboto,Open Sans,Arial,Helvetica,system-ui,sans-serif;
	font-size: 1.0em;
}
th,td {
	text-align: left;
	padding: 3px;
}
td {
	vertical-align: top;
}
th {
	background-color: black;
	color: white;
	word-break: normal;
}
h1,h2,h3,h4,h5 {
	margin-bottom: 3px;
}
h1 {
	font-size: 1.6em;
	font-weight: bold;
	border-bottom: 1px solid #333;
	margin-top: 200px;
}
.firstheader {
	margin-top: 5px;
}
h2 {
	font-size: 1.4em;
	font-weight: bold;
	margin-top: 160px;
}
.firstheader2 {
	margin-top: 20px;
}
h3 {
	font-size: 1.2em;
	font-weight: bold;
	margin-top: 16px;
}
h4 {
	font-size: 1.05em;
	font-weight: bold;
	margin-top: 10px;
}
h5 {
	font-size: 1.2em;
	margin-top: 7px;
	font-weight: bold;
}
table {
	max-width: 1190px !important;
	word-break: break-word;
	border-spacing: 0px;
	border-bottom: 1px black solid;
}
#content {
	position: fixed;
	width: 99.5vw;
	margin: 0 auto;
	background-color: lightgray;
	display: grid;
	grid-template-areas:
	"logo logo"
    "navi content";
	grid-template-columns: 200px auto;
}
#logo {
	background-color: black;
	padding: 10px;
	grid-area: logo;
}
#logotext {
	display: inline-flex;
	vertical-align: top;
	color: white;
	font-weight: bold;
	font-size: 1.55em;
	margin-top: 7px;
	margin-left: 80px;
}
#navi {
	grid-area: navi;
	height: 99vh;
	padding: 12px;
	padding-top: 20px;
	padding-bottom: 100px;
	background-color: #222;
	min-width: 150px;
	max-width: 200px;
	color: white;
	float: left;
	overflow-x: hidden;
	overflow-y: auto;
}
.menu {
	font-size: .9em;
	font-weight: bold;
	margin-top: 5px;
	margin-bottom: 10px;
}
.submenu {
	font-size: .75em;
	font-weight: normal;
	padding-top: 3px;
	padding-bottom: 6px;
	padding-left: 10px;
}
.submenu-block {
	display: none;
}
.menu:hover {
	background-color: #666;
}

.submenu:hover {
	background-color: #666;
}
#reportcontainer {
	grid-area: content;
	background-color: lightgray;
	height: 93vh;
	padding: 8px;
	overflow-y: auto;
	overflow-x: auto;
}
#reportbody {
	background-color: white;
	padding-left: 12px;
	padding-right: 12px;
	padding-top: 3px;
	padding-bottom: 20px;
	border-bottom-left-radius: 8px;
	border-bottom-right-radius: 8px;
	border-top-left-radius: 8px;
	border-top-right-radius: 8px;
}
#footer {
	border-top: 1px solid #333;
	font-size: .8em;
	text-align: center;
	padding-top: 20px;
	padding-bottom: 8px;
	vertical-align: bottom;
}
.clearfix::after {
	content: "";
	clear: both;
	display: table;
}
.showhide {
	text-decoration: none;
}
.cnt {
	text-align: center;
}
.iconok {
	display: inline-flex;
	width: 15px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAGUSURBVDhPjZPPSwJREMe/+3YrCPwBCoHhRUgqjyKolxI0EfHUQQjRS3+AF69l4smT90L06iXq6B8gYnjLPyA89IMuIpjUutvMKobgat9hYOe995k3zM6T7CW7daSN8lNM3QA08k0SCpSBTdiqklyUrwi8mW/8W5TgWsxvXCuJzNAP+RSQyVSobkHh2lIZ1MkYLBwUkNnLYKpRBuIYNtUCHAONkwYquQrK52XwErspvARGG8jGssZ6/6W/qFXwITZ8UzQhpw1qxkqw9dRC8jHJByBJEoSu0zFVR/OsiW62i/BuGKqqAl9APVpfAuP3cWBrBnLyWdl0cfAwiMBRAPWLOjw7HtQiNeRiOWN7AW7/gSwZEaSoVL/+qSPkDcHldCHtSyN0HIIQwhQk9WScIqUIxd9+b2P8OkbYG4bT5twEsmawBs0vKzI6Hx1M3ibw7fvQfm4j8ZAwA1k9CUXc0sclR9xlo1k8UPw75l1dAbLujCGfBzxyBmC0kbrKSUxAHtGB5Cg5rENtmOdZpbV/vSoGLcJS/QU+7ZxWc2tqhAAAAABJRU5ErkJggg==");
}
.iconinfo {
	display: inline-flex;
	width: 15px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAE5SURBVDhPlVOxSgNBEH17m+hpJypIFCGIRL9BULBR8A/Ezi/QxlawstPGzka0EKz8AwvrBAURRCxstBIU1DN3O765JJiYXUIevLuZnXv3dm72TPnofQrAPjlLZmQvWPKG3FHxGYN1Xe0ThxEv6qiQFrkoT45MRF5517y9TirmVNy11UcHbE9EuFqJzcZohGfmHjgVd6MuWKsUzOL8AFZnLH7SllknvOKRosFxrS6n119ycpdinLkPXnFKxvymCYOYTwSM/eIPipanLTaXhsxCyeItMEB/z0TWdHMSsCWC4r8u/f0qejgLnOvTuVQEzh8ybF18yiWHPFloFv5BxXpWOxBzp9VvwcGLw30iGAxMSsW3jThvLic3aoYNTNnC8EV53l4nFTX9McYY7JIVUg9iuMmGUA2rAPZ+AZvLYLeAIu8dAAAAAElFTkSuQmCC");
}
.iconwarn {
	display: inline-flex;
	width: 16px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAPCAYAAADtc08vAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAIJSURBVDhPY8AHFGSYu0112bYxMDALQIVIAs5LuyT+H18u/x/IboQIEQ+YPOw4jr45qvb//xWt/025gu+BYooQKeJA/NYZMv//39YB4xtblYGuYJwFlSMI+DIieO98Pavx/8xqhf9rJ0r9/3ZO8//0erFfQDljiBL8oO7kCvn//69p/08K5gb5///DPSr/nx1U/a+lxrIJogQBmKA0DCg05ggWGmtxA7X9Z5AWYwULsrAwMkhKsDHUpIr6ArkeYEEoQDOAsSbMQ1CAmZURyGRkEBJgAYuyswKVAd3iZsXH4OvE0QAUYgZLAAGyAebT60UTNBQ5GBj+gsKMgYGfh5lBSZ6JgQ1kIFBMWJiFITNcxByoNhaiBckAUz3WJj8HfmYGJqBiEABSEsKsDOY67EAXQMWAhtgZ8zCkhfFUA3m8ICGYUwInVUpUmRvwQGwHASAlDPSCsQ4Xg4QIMCygwmwcTAzCfCxC89Z9/AzkHgG5gCPSh6vRxRJoIDDgkMGyrW8ZfHMeMLx48xvoVoQrTIGGVmcIFAF50iADMtJDRXT5+YEB9g+sBAKA6sWBNjuZckICEeYEIMXKzsQQ6SkkAjS1khHon6cTKmSkOIGCMDUwAOL+AdrICoxGkOOgbgAz/gH5DVOfMTC6WnEssTbiCGNiYvgDlYYAkAZgVAIRUDGayUAAFGI5ffnHHgD6I43GuERY6QAAAABJRU5ErkJggg==");
}
.iconerror {
	display: inline-flex;
	width: 15px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAK4SURBVDhPZVNdSFNhGH48+3fb0f2kbnPOZQQKkoFDulIjwq6zUvAm6L7S8EpcmiBFFlaX3Qm6WdLKC+fFwtZFRYqRWIimzsTfKe5Mz3RTv95z/OnvgY+P9/95n3O+NPwNNVSq2odqXY1bqfJoAMsOsBbZ2x2pTyZ8SCa7KYdc/4JD0WM9/2nGYmO72U7GcvLouORbsmfJ36nnh6FA8WHFITgUdvOmhd0TuWwJYDE6zJ5/0IBugWzJL8V9vHmZ8o8bqB7p+Y8pCkQoIeDzsUB7+0EDh1sufN3WxgJ+P5s9bEAMPlMdbaVW100TpWUKvOrpYRIEUWQB7105OdDUxGJbW7I/0NsrM5BWIG2ucw9U2honp0A6teImJxETRRh1OlTeacCo34+Kxkbw6ekQEglgago6ystVKtGh1l3DC968yAoKGSs9xwSLi71pbWUbgiBPOkIsHicm3t9aZOexPqMpymkddjPc+YDJBGNpMc42N2MoGJS0OMbbgSBKWlrA21xAMkWrqqA1Gi3ctkK5jrSDz705M4fR1nuoqKqS7SOcv1SFL14vhEWS9CQNOlWAbYt5TeExGCvLMk2nxZiAoborKL91ExkGA4TNTQz29yPH6USG0QhHWRnCxM42PgGlVoPB1ZX3XGPkh+9nQkQisY19t1sWJ07ivHv6DCXV1Qh3PgGpL4vIKC6KCcxTvGFu2q8gCb671JqL5Q5HrmEwhLDVhEgohPLnXcgq9cAe/oDwXhITS4s403YfOVYLuhbmh4PR1dtH/3Zhd1Fx6GqO3ba2GoWWaPGZmZK2kPSIb8QgEjNrlhUvlxdXasa/XqCaMcVBLaJ9qysDJk7hKTCbHVbamZNEPBRSqVZjXcHJE29MfLtMrjHJ//+rUiprO/LcNfnp+lINx1l39vfXIglxpH5uxodU6o9XBfwCsqFHB/mGIqUAAAAASUVORK5CYII=");
}
.copy {
	display: inline-flex;
	width: 15px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuOWxu2j4AAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAA8nYBAOgDAADydgEA6AMAAFBhaW50Lk5FVCA1LjEuOQADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAAArIfcnPEIHlAAAAoFJREFUOE9VUj1ME2EYfr4/e9dAm1ZojlZ7pUro6SRLY9JEty4OHQUSNRok4mAc3DTRODgZXZx10clVCUacYEAHF4wpXPCkoSHXglIStHflXgfvEJ/kyfd975P353vflyFErVYTi4uLTz3Pu+h5HmOMUSixkJBScinl13Q6PWnb9jcWOVer1cTa2tqMpmmzqVSqHQQBBwAhRNf3fb/b7R5RSnkrKyuPhRC81WpdYQBQKpWOttvtZ4yxE2EWHsbkvV6v09fXd6fRaCwBgGmaE77vX242m1UOAFtbW/c55/3JZHJK1/VpXdeva5o2ZRjGtVgsltvc3PxgmmYFAIhIMcaCqGJks9l3hUJh8sBwCENDQ+8BkFJqL5/Pj5mmOZ7L5WYBQABAIpGYYIwtW5b1fWBgYMwwjGOGYRzP5/N7QRB8llJmhBA9z/POx+Px5f39/dO7u7svo7+Bc97d2NiYcRxn3nGct47jzLuue3N1dfWj67q10dHRcaVUPxHpREQ41BgEQaA1Go1HlmVlLcsqWpaVdRznYaR3u11JRAGAaISQ0YUx5o+MjFywbXscgAcAg4ODHEBM07RPUsq5w46IModVgHNOuq6TrusIGei67nPOfQDE2N+1iE4ZPYhI1ev1N+VyeSkKFoIVi8Uf9Xq9FAboEZFAtHa5XG5WKfUcwEnXde8B+BV5ElEsmUzOFQqFu7ZtvyaiphDii+u6t6KGCQA8lUo9UUqVOefnIgohzkopbxDRb8/zhonoZzqdfnCQOZPJvBBCoFKp3BZC8CD4t0CMMSilegsLC5c6nc7V7e3tMwcaABSLxeGdnZ1XnPNT4Tj+A2OME1ErHo9Pr6+vz0f2PzcMAT2VrYr4AAAAAElFTkSuQmCC");
}
.copydone {
	display: inline-flex;
	width: 15px;
	height: 15px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAPCAYAAAA71pVKAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuOWxu2j4AAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAA8nYBAOgDAADydgEA6AMAAFBhaW50Lk5FVCA1LjEuOQADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAAArIfcnPEIHlAAAAiBJREFUOE9tkU1IVFEUx3/n3fccx4/RpDAEU2qdm2xRkBuZIIRihCQC0VYtGgV3LYIimGW4CWyhDrTQ6AtdZGhrIRLcFjo0EOKQRlYmjHPvfbfFm3FG6A93c8753f/5EGrUTvvkoRzeKrmSCOJqcw6HH/Pr/CZ/o+1E2+1cLpeXSrL7XvdFndd3zSmzVJeo++FC59XCIiKJv4mvhReFB6pZBbu7u6MCEDwKhjT6OR6HOBRwDCwrQLHc9arrjS7ooe2d7WsegEZfAWKEJHA04ohXnue8OJY4Ft8Lvcv6tO4ULYYah/CYR1kKRWhD+pr6SCaShC40juoq/tceAB4e1lp6G3qZvzPP5OAklMA4A+VNHYfLnwpC6KJmZm7O0HGyg83tTSh3U6nzagOdqhNMdBaKsHJjhZ5zPax9WSP1PgV1IHJ0oAi2RcvYmTHWx9bJnM/AT8j2Z0leSJIv5Bl8PRhVVrkqjMBB6YDW5lbSA2myA1mG+4fZ299j4uUEW8UtlFJVqnZmP+Yz+22WqaUpEo0JRq+OYqwh8zbD4vdF/MDHYitoiIs4D8BgIAbjq+MsrC5grGF6eZonn5+gYirKR3L7v/cvmQOTO4IBEQTqIfUhxcizEdKf0hCn1hEc9UFz8LGl1JI5ghXqj8MhnoDA3M4c+OXNSnVGcYK9bp9usLFDJdzwuKHDhvZ+WAzPaqelevFICiVBLPillX5nH9q5SvwfBxfTwFLrDywAAAAASUVORK5CYII=");
}
.back2forest {
	display: inline-flex;
	width: 30px;
	height: 30px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAKYSURBVEhLtZe9axRBGMZnL0rkFBExfoF/gK0YRLCIsbESUYIKKmKRQgWNiIUWno1V1MRKOwsLRQNBRYugNlaCFipY2Ah+Fn6GmPiR7Pp7Zuc2l727vd1z9+F+ed99L7vP7OzszJxnnM4Ys4VwAnpggWo56hc8hMGzxjxSwRpjepxwXjl6R/k7MWrUfyrgs5S4Ojw0A5gPeZj2cvAAfsJhGO3oLE95xsvHOAiC6T+TZbI+uATqzV4Z3yfZCvtoyTViYcKrn3AF7pX4sxnewCgUrZvwEXpk3AlfvVJpili05PENyjK2CnzfZYVK48aOncg4i3hWy+ECjMAuV86kzMYyJdyGAdgB16kdI2ZSJmMMVhDuwgZbmNVFvlNDUiu1sTO9A922UC91fWrzVMYpTKuS+VGXJ6qlMRdaSVD3tjKtaohzWj7zRGMusIqgO11vC+mlZ55o3tSYExcTRiBuGp9oJuBlmM6RzA+4vE5Jd6zlcWOYRtKSNhimkX7DHtArFpfm5oZKMv4ELGmRnsF2eGuPZjUPvsBOuKFCjV67WKemxqxUTwiH4Dncgm3Uxoma2+Oaz3fTxL1wDtT1asQpaKjEwcXFLnuljnXEPnjvyrW9MEcyh9MsODpnd805dUo0lir+zIxLU6vi+39d2lQtjRsol51JO8ZxtdWQdoxfuVgVm0PzOUzTK7MxA0YbQ4L5AC/gCAeTxEyKjBmJLmstjCqEtdBNbvfJKaU3wr4VclNru9j6LFQhrTAcB81aWbQIlsGEjMdgDWjaK1r7QTuYMe2rNR8/Br2vJ0Ezjnohnw192LW60+qspuNN9uKYHyRoo61594cjT+MloNVOE0s/j+hqdHHMtfxpDdUGX/+Up3Qj+tE2jOlTY4z5BxRykuqDKdz2AAAAAElFTkSuQmCC");
}
.back2top {
	display: inline-flex;
	width: 30px;
	height: 30px;
	background-image: url("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAB4AAAAeCAYAAAA7MK6iAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAARfSURBVEhLtVZraFRHFJ4zd3fjbrBZNcZ0tZGiBnxUELFF9I8ImlpFW6OgULTFB7QVg6RQRdzdBLFotdRX1foIUlC0FQ0K2l/1T/GHfcZEJVZalKp52Oq62ezdvTN+Mzu7aN3sxiT7wew958zsfHfOfGfuEDOgsvD7jMkaJtlk6UiXCQ8IyM27Me8VIvaVeBA8q2Oeiq2UiCW+lEKu16MA7uYRdEmYmRfrIzCHJJEQg7WXmu1z1hHeSLwsvFI44piOczrFiA74hhXf5haX6m/9AogwN8U6o2Mw2cfI5HsqhrmricpCzQhMAOkR2R5aZf5SEIDrO3AtJot+4UixIrW529pj+gsGYrRPG9ARZwIGp4feEu8/OlhA+EqLb0E/j5R4ud5wCSUJ2V8h5YXWjRYcbPXTF6D81lBpaIf7ta1eE8qPZ8TaJ2KI5CMpxEEpZW0ynmzwjd1eZLp6jZcnHhZcjT3am3576Yil3ZHYCe/Y7YNSkd7hpYhR8/Pw+BrtOT2IpHg3HomdLhq9zWdCedFrYlegfiZS+y1MSweI/YYy/F7bAMjn213x88hIhQnlRK+IrVfr3nISzhkof4gOEGsB6XwcONWw96fXj/5ZeFyA6MakIj0jLzGENBVnrSIdngqwFu6y5hHnVejb6S8fWoMyqcVRq7uBSTgeG/mIcKXxsyInMQ0PjYeQziDFAe0TXbfcVhXMuSLpHEbfhsft/52YsmDJLu7i69Irh/Am4EUPuUbVp7YlC3ISu7zutzGZ3jOQ3sCpU4W9nA3Sg2lVw1/8a+PpcyNeD+xHFtRZn65Wv2M7bmO/gJzE+CO+odSKdhUrmgN/BlZy9NmDQAFfoAX3W+9elknnIvb+HYxvwPgVsi3UbYa8gJzE4v6Wn9w+zxTZEZqGlY9GO4xwOqE/o51MmVimlDORlot4qSaM/8C5t+V305UVecVl/70pilKajpQ2YtJ0nTahVbPO8DKsLJh5lZSwfuDldeOM3yPyElvldW+ilM5mSomxa2iLQPqXcnCVqYPKoWrlAZJBkOK8FagfbyJZkZMYJTHRSepSKjOhZhAsBOlt42tgS3ZyDlUbYWF8JfRwnJUGezxGcxJbg1xzMM1I4zZDNAtxX3qONA3RFtyLl1oLM6F8JMDCh1+ZWZGTGHV6CWR/oP0ItS6CaP40XdnREf7G8lizse9f4Lkc43tUNeFslWTxB74hvsnRm5+2mXgGSLcXk9iJO5sdE+ozXnlj16gn7ZEmYQs/V7uC006R/686U4B4YgNBqqBunHjo/OurD8Qw2I7GS1SgkOjqjFbg3C/BLVNw/NwBcXGiy85c6AsFHDIfaoOoSd2r10FEu7XPaR+uuYe8ft89DMqkpR+QEKaMPeoKCNv5BAvU93Z8zVZSxayTdLfl5gGcTGtUEAPjKIR/lan8AYBkQg4FqUc5WNxu7rFq9OT+SXvocfvDVVKyWlziKvVde+BoddHiy3UdU+4oLilqiLR+Jp8CtArLdwKPPWgAAAAASUVORK5CYII=");
}
</style>
</head>
<body>
	<noscript><strong>We're sorry but this page doesn't work properly without JavaScript enabled. Please enable it to continue.</strong></noscript>
	<div id="content">
		<div id="logo"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAANkAAAAuCAYAAAClKbzXAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAA4WSURBVHhe7Z3fUxRXFsfHNVkTIwIxiRqVxejWVtQURH7MAIOMCooiAlGjMSaQH5LyRyluEtlYWyVP7qM+bNxHeUle44t52Qd40KfULkx3QyqpSmnxmu6Zyf4B9n5Pz52hu+/tXwMDlLmfqlt033Pu7fvr9Om+9/YQK5XsrqP1xp5jt3/d1Z/Vdh6dU2uP3VJf7d7BxBKJpBSydR1V+t7uQb2+e8qoP2Yabx03jd3vmNrOHlPbcdxUa/vN9LaBB9qWE+ehviqfSiKRBJJpTvUZjfvvGY2HTGPvYdN4+6hp1PVYRqbvHrCMTH2j19RgZGrNO6a69V1T3Xw6p258/5v/rn+3iWUjkUjsZOPxWqMleVtPpB4bzftNo6nTNBq6ELphZEdML0+m1ZyAkZ0ytS1nTHXTWVN97UNT2TA4l6785Lq65kP5OCn5fZPtqKvS2xKDelvLlNHaZhot7aaR6DCN+AEY2UEzkid7/TQzsg9MdcOQqVR9aqqVn5nply48UP54+RS7pETy+yDb1pAykol7ejKRzbS3mkYSoS3JjCxlenkyfU9vztg9MK7u7Pnez5ORkanVZGTDplpxyVRevGKqa67l0qs/v/tj7MtGVgyJ5NnEaG+6k+mIm8a+hJlpb4GBUYCR+Xgyve7I/V/3HOlnWVgolclqraZ/WN028L2fJ1PWXTTVtVdM5YURU3n+C1P5w6g5FRsdZdlIJGXHNM36p0+fdtgDE5WHTCpukpFlYGQGjMzLk+mNnff1vV1DNMPIknqiVPZUa5tPjyqbzmqenuyFa5aRqatHTSV24xFLKpGUHRjZJIIDJioPmY5my8hEnkxPJKf15vaRMIblhbr+9A6t+sPRdOUnmpcnk0YmWUpgU0tsZCJP1toyTrOLTGXR+M+aczu1dZceSU8mWU5gU8vvybJt8RQTLzrKmktd0pNJlhPY1PJ7snIbmfRkkuUENjWEMGYPTFQepCeTSMqMxzvZ7XK8kxHl9mS4K1U9ffq0D+EmwoRHIFkfSxIJ5F+LtFcRvmN5FQKd34S8nql6Ap0U6doDE1ng3F1+yvsqXZupOICM9G8z3UKgc886Qua4PpWJiSwoLYI7TwpUjsA6ikBar365h+BZPzt0beh6Tr/jfBCB8nNcA+mGmIrlyRDnqD8TCYE+jSnKV9QeFKy+RxAvBfjNLtIUvp7YN2E077+nNx64mWns7MjWHV6Q8Smxs9XKmitdU89dHU2v/uu/lFV/ezQd++p7Jl4QrKJZNEooSJfSsOS+QJ0MgzorEOg9xh/HOqIdyOgRxQGLpwFEaT2xlxenYfSn8IczirzUwTjFQ59uIIFtCB1qi1BjIWyeRFC+kAnfp/CnH2n92mLSygDQcT5qHiZygGgyrnt5jXBQGRAGWRZ5wq6T2Xd86PXdWb3+2AR96qK/2X91ZntP578rmjawLJcFVIwGU0lQWpaNEMhvM9VIIB0NGG75A3GckYF69jcMlL42fxgMykGDz1GOvMTBJPTusONQQJ8Mx9OrQUaDtNR+KXoeO4jnDATQO1YQkYwMUfTE4nsD84PakmUV7Mmi7F1Uavpy2raBh+ktJ++mN568PvPy2U4l1lPNLlU2UCfRoI2K8OUXjRXpTuaG0rOsiiCaK2+UwQhd8sCRBi/0R9jlLVh0EcqTHUYC6TgDJiguahkFcIaGOM5AQpY9kpEhz/tMtBDyj+BGR/NkVE8WdRe+umEop1V9+lCrGP56Zu3FL5XVl2F8FxbN+Dw6kway6DEpxWQOaLAwlSKIFt0hc9ClO77jHQbn5Iko3xyCG8dgwbnnTQF5P8GfcYQxug479wU6NCAoTwqUVlSG4iAjWJwQdk3Ki+pPj8kj+OuVL+nP37UZiOMerVm+lKfjcRDn/QiUvwPok/G4dUWerAi7BulY7UfHhTiWhTAPJirCou1Q3UVlr0KgMcWVH1iP4BbWBuH2+JiRjI/rbfHJUj1ZmF349h0fU89dm0uvGn2gxG4saJMwq5Adx4ASwTrAARMVYZ1cBOfT+OP70g85PWY4DIPyYWILRHkZGXUU5xVEZSVYebj3F8SRwXMGwcQWLIoDeTo8nh2IaUB5GUOx3DimQedGWDc7kItuavMDFeDcy8gsI2BqHJDZy+drZDgVlT9wmh867nz9xyHNLmbjbSkj3jFmNHXc0RsOTuoNnbkSPVlZ9y6iMo4BhU4XPsLYgbzg0YqBiSxwLurwULNq0BN1UnEiBMeckZHBMLEQyB2Gy/AsDxkL0ynCRBYsyk2o9SKPshQ9O+SORy3SZ6JAoO4wYqR136BERkb9H6pvCOgGGRn3votyfMfEnkDNPaY8jd4X2seYrTuc0t/qGTH29N75ddfApLaj57dSPNlirZO5O7UANQyCNbWKU88ZKxHQd3e2rxG4YcnsFAcwHeej5kH+nh6EgIp7YOSYSAjknKEzkQWLskMD1ffGVAB6ohtQsX6oi/sdKZTxEtAV3aCKBoRjzkBwPe5x1Q8k8TUyAlHckwDVC8FabkAIP6YyqabBTLJxwVv96VMXZVtvl7btxKi29eRdbfOZR+rG935bIk8m6hghaJwphMA1LcgcHQF9amDRGolXcA80+zsBZ2TAdwMA5O6B4fsoAnlUIwt8xC4AXdGd3hroOBTJqM1FbSQKovdr+1MAZyAgtBcjoB/GyER9JISV23utzz67aCQTj/VkYkJPtt7UE22DmURy4cYX66lW1g91pdd/PKpVfHZXeeniI3Xt5d8We8cHKhe6UeygYfh1DYC4hc6MuVnRRob6RvUGbqzy4G/oG14E7E8BgQYSBJKEygPR3PtnGNCWNOkz359h1sn0ptRjvbFzQt/beZN+rSpT370IxnehWold79Jio6Na7MYwi14QVDEE0Z0uEDSMY6odUSXl48MzbWRIf5/FPzNGRkBEu0NogqkU8u9kvutkrf6zi/qe3sf6rv4J9Y2jt5TanuGZmuOdyHKVlfEygsoVplVpMNPdiBqVe8YWUBzoOHZ3BKWnuJKCfRDjfMUZGfDNzw50RQvhliHgL7eozgYp1yYRQnECgZ07YKLQIEnkPKBCdaalBloaoDkALg830MsvQZSy4yNodnF668k57fUzD9XX3rulvHJueKbyo5VifNRQtO7jtf5UnC6m43xUHuj77gqJArJbiZ7MMYvnB9S5iQ+kL07csCg7oSc+gkBey2JkXiBpwfhovIgmS0Zi2fbGkcy+5lwpnizaOtkn5nTF8BzeyR6qL16+pTx/ZViJfbFg40M9aGeBY8MoxTGxJ6SD4G4U+yOdaAbN1xDsoBw0q1kM9rQ4XomezGEofkCPW2gGxckHyN1T+NxCvxdQp/2Y7rYrTibguOxGhlNa63SMKSbyBem4NgfzNxhrXawtnjLaWsboy2i9tW1yEXd8+M4upmM3Sv4hHVRCVDHPzbl20Hi0nmbHbmScEUKfJkMCp22hRwPDje86GVgJRkaPN77lgA63zQxxjnUwRIk8Hbe9zA3URFuxHEsVOF8KIxP1T2C/k05e1UGwF8/GO2qzDR0po2H/mNFwaFx/+9BkqZ6sHOtkqARXMXQUzRh6fuYBFbpTifYkuncXcI2NdNbOfRxyjU7XRBDd5R0GgfMVaWQFqG0Q6NMO+92cvIr7plSAW3SFLjdZgDia6u7DoeNJA+eFz4fcyx6EY5DifCmMjB7/HFDZ8cdvyYc8MDcjjbhQTwdC6JOX7O6elPHmwNjszmMPZrcf15ZxxwfXaAWo46iBWAialucGOuJ8p3FD5Ene0NE5OF/RRhYRYTkQL9zaZQdt52W0FpBzGwAQXXYjIxDlWXYqN0JhTPnVgfKojRn7mibwTnZTb08MZpKJBU/NP9k8sPfnLWdOqpve/cfsa2cfaK+e08rpyQhUJLBDQ+DwYnYg8zTiADgDIxC34oyMBjQFdhoWKpPn+y9kC+kXYd4s3gEThQZJAvNAFOfNSoBN4S/Rb3w8WXt+78/rLp7UKi5p5fgyGhWix0au8UJAgyDwuRk6tF4impH0gjyg8Dke8UthZNxUOhNZsCg71qBGoLIFGUaoNiOgV8gzLPSVg98m5SUxMgLRNBMdeY2MjZP5eYFn7Tc+UDkyNjII6zMHn0AdH2qCxA7S0OCltFye7Jr00u87uwk5eRnKwx58X6whp3zt+oGbT136FIrlwrEbh9Hi3F5GumEUjksaG0hHxkZfL3P9grjCpzqB/QEddzuEMnY7SGOtd4XNA3J63yp87uMoeyHY6sC3j9CT1dX5DpKFIH+tamWAweDG1zNKFoDIkzFRWZC/VrUyYIZlRxpZuRB5MtogzMSLzarpdRe+lZ5s+WGGZUcaWbnw2ruot7Q+pn8CmG3qiPQZgYBVSuUHp6YqP/42XTGck7+FvzJghmVHGlm5CLsL32g4eDtb1xXa4H54ub+Z/p1t+tVzuXKvk0miwwzLjjSycmHsa7J+SCfs3kX97UNTev2Rq6LfX/xhY09zemvf3fTWU3NRdnxosb/fZVlIlggYlWN2DSFwtlJSIvQvbLPtzSNGe3w66i58fU/vFP3uIn3qor3ROxd1x8fs6usPf4p9dZ4VRSJ59sm2NtUbrYk7eltLrhy78MmTaS9dmvv5hWv/fBL7fDu7rETy+0RvbR3SE8n7i7ELf2bDR+Zs1flvfll36QTLXiKRFKBd+HrzgRG98cCTqJ7sx03vqz+98sH5bOXVsi1uSyTPFDS7aDQcHtfru3Nenmym5sT/ftp26mt1ff8OlkwikZSC/tbRIX137yR5stk/HzNntx9/8EvNO/JxUCJZbLJ/6avN/qlPPg5KJEJisf8DhE6hJ7XN6bQAAAAASUVORK5CYII=" />
			<div id="logotext">###LOGOTEXT###</div>
		</div>
		<div id="navi">
			###MENUBLOCK###
		</div>
		<div id="reportcontainer">
			<div id="reportbody">
				###OVERVIEWBLOCK###
				###ADFORESTSBLOCK###
				###LOCALMACHINESBLOCK###
				###LEGENDBLOCK###
				<div id="footer">
					This report has been brought to you by the Semperis Community. Script version: ###SCRIPTVERSION###<br />Download the latest version of the Readiness Checker script at <a href="https://www.semperis.com/downloads/tools/public/SMPRS-ReadinessChecker.zip" target="_blank" style="text-decoration:underline;">https://www.semperis.com/downloads/tools/public/SMPRS-ReadinessChecker.zip</a>.
				</div>
			</div>
		</div>
	</div>
<script>
menuids = [###MENUIDLIST###];
var lastcopydone = 'nonexistent';
function copyToClipboard(spanid,text) {
	navigator.clipboard.writeText(text);
	document.getElementById(spanid).className = 'copydone';
	if (lastcopydone != 'nonexistent') {
		document.getElementById(lastcopydone).className = 'copy';
	}
	lastcopydone = spanid
}
function collapseForestMenu(id) {
	document.getElementById(id).style.display = 'none';
	document.getElementById(id + 'col').style.display = 'none';
	document.getElementById(id + 'exp').style.display = 'inline'
}
function expandForestMenu(id) {
	document.getElementById(id).style.display = 'block';
	document.getElementById(id + 'col').style.display = 'inline';
	document.getElementById(id + 'exp').style.display = 'none'
}
function expandMenu(menuid) {
	for (let id of menuids) {
		if (id == menuid) {
			document.getElementById(id).style.display = 'block';
			document.getElementById(id + 'tgl').style.display = 'none';
		} else {
			document.getElementById(id).style.display = 'none';
			document.getElementById(id + 'tgl').style.display = 'inline';
		}
	}
	
}
</script>
</body>
<!--
###COMMENTS###
-->
</html>
'@

function Resolve-DsaHeuristics {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidatePattern("^[0-9a-f]+$")]
        [string]$Heuristics
    )
    if (-not [string]::IsNullOrEmpty($Heuristics)) {
        $res = @()
        for($pos = 1; $pos -le $Heuristics.Length; $pos++) {
            $char = $Heuristics[($pos - 1)]
            $item = [PSCustomObject]@{
                'Position' = $pos
                'Character' = $char
                'Name' = ''
                'Value' = $false
                'IsValid' = $true
                'IsDefault' = $true
                'Behavior' = ''
                'URI' = ''
                'SupportedOn' = 'all versions'
            }
            $addItem = $true
            switch ($pos) {
                1 {
                    $item.Name = 'WriteCacheOnDITDisks'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Write cache on disks containing DIT and log files can be activated'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Write cache on disks containing DIT and log files is disabled and cannot be activated'
                    }
                    $item.URI = ''
                }
                2 {
                    $item.Name = 'SDPropSanityCheck'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'SD propagator will perform additional sanity checks on SDs'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'SD propagator will only perform the necessary checks on SDs'
                    }
                    $item.URI = ''
                }
                3 {
                    $item.Name = 'BypassLimitChecks'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Ignore LDAP policies: maxSearches, maxConnections, IPDenyList'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Respect LDAP policies: maxSearches, maxConnections, IPDenyList'
                    }
                    $item.URI = ''
                }
                4 {
                    $item.Name = ''
                    $item.Value = $null
                    if ($char -ne '0') {
                        $item.Behavior = 'This position is not in use, no need to set it to anything other than 0'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'This position is not in use'
                    }
                    $item.URI = ''
                }
                5 {
                    $item.Name = 'CompressIntersiteMail'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Activate compression of intersite replication mails (obsolete)'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Do not compress intersite replcation mails (obsolete)'
                    }
                    $item.URI = ''
                }
                6 {
                    $item.Name = 'SuppressBGActivities'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Suppress background activities'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Perform background activities'
                    }
                    $item.URI = ''
                }
                7 {
                    $item.Name = 'IgnoreBadDefaultSD'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Ignore bad default SD in schema to allow the DC to boot'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Crash on bad default SD'
                    }
                    $item.URI = ''
                }
                8 {
                    $item.Name = 'DisableCircularLog'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Disable circular logging'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Enable circular logging'
                    }
                    $item.URI = ''
                }
                9 {
                    $item.Name = 'ErrorOnWrongGCSearch'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Return error if a GC search is using a non-GC attribute'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Allow a GC search using a non-GC attribute'
                    }
                    $item.URI = ''
                }
                10 {
                    $item.Name = 'DecoupleBGOps'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Decouple background operations from garbage copllection'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Group all background operations and garbage collection together'
                    }
                    $item.URI = ''
                }
                11 {
                    $item.Name = 'DisableStrictBlobCheck'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Disable strict restart blob check'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Enable strict restart blob check'
                    }
                    $item.URI = ''
                }
                12 {
                    $item.Name = 'DisableSigOnPagedSearches'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Disable search signature check on paged searches'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Perform search signature check on paged searches'
                    }
                    $item.URI = ''
                }
                default {
                    $item.Value = $null
                    $item.IsValid = $false
                    $item.IsDefault = $false
                    $item.Behavior = 'This position in the DSA Heuristics string has not yet been assigned or is not publicly documented'
                }
            }
            if ($addItem) {
                $res += $item
            }
        }
        return $res
    }
}

function Resolve-DsHeuristics {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidatePattern("^[0-9a-f]+$")]
        [string]$Heuristics
    )
    if (-not [string]::IsNullOrEmpty($Heuristics)) {
        $res = @()
        for($pos = 1; $pos -le $Heuristics.Length; $pos++) {
            $char = $Heuristics[($pos - 1)]
            $item = [PSCustomObject]@{
                'Position' = $pos
                'Character' = $char
                'Name' = ''
                'Value' = $false
                'IsValid' = $true
                'IsDefault' = $true
                'Behavior' = ''
                'URI' = ''
                'SupportedOn' = 'all versions'
            }
            $addItem = $true
            switch ($pos) {
                1 {
                    $item.Name = 'fSupFirstLastANR'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Ambiguous Name Resolution will not include search by "Firstname Lastname"'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Ambiguous Name Resolution will include search by "Firstname Lastname"'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1a9177f4-0272-4ab8-aa22-3c3eafd39e4b'
                }
                2 {
                    $item.Name = 'fSupLastFirstANR'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Ambiguous Name Resolution will not include search by "Lastname Firstname"'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'Ambiguous Name Resolution will include search by "Lastname Firstname"'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1a9177f4-0272-4ab8-aa22-3c3eafd39e4b'
                }
                3 {
                    $item.Name = 'fDoListObject'
                    $item.Value = ($char -eq '1')
                    if ($item.Value) {
                        $item.Behavior = 'The "List Object" right will be enforced and children will be hidden if the searcher does not have the DS_LIST_OBJECT right on the parent'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'The "List Object" right will not be enforced and children willl be shown regardless of the DS_LIST_OBJECT right on the parent'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/990fb975-ab31-4bc1-8b75-5da132cd4584'
                }
                4 {
                    $item.Name = 'fDoNickRes'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'Ambiguous Name Resolution request via MAPI will attempt an exact match against the MAPI nickname'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'MAPI nickname will not be matched by Ambiguous Name Resolution'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1a9177f4-0272-4ab8-aa22-3c3eafd39e4b'
                }
                5 {
                    $item.Name = 'fLDAPUsePermMod'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.Behavior = 'LDAP will use the LDAP_SERVER_PERMISSIVE_MODIFY control (return success even if no modification is performed)'
                        $item.IsDefault = $false
                    } else {
                        $item.Behavior = 'LDAP will use strict modification behavior and return an error if no modifications are to be performed, like deleting an attribute that is not present.'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/49cdb1e3-3baa-4c7c-8cde-7c26b13d3ba7'
                }
                6 {
                    $item.Name = 'ulHideDSID'
                    switch ($char) {
                        '0' {
                            $item.Value = 0
                            $item.Behavior = 'DSID will always be returned'
                        }
                        '1' {
                            $item.Value = 1
                            $item.IsDefault = $false
                            $item.Behavior = 'DSID will only be returned if it does not reveal the identity of the object otherwise invisible to the client'
                        }
                        default {
                            $item.Value = -1
                            $item.IsDefault = $false
                            $item.Behavior = 'DSID will NOT be returned'
                        }
                    }
                }
                7 {
                    $item.Name = 'fLDAPBlockAnonOps'
                    $item.Value = ($char -ne '2')
                    if ($item.Value) {
                        $item.Behavior = 'LDAP will only allow searching RootDSE anonymously, regardless of ACL'
                    } else {
                        $item.IsDefault = $false
                        $item.Behavior = 'LDAP will allow anonymous searches if the ACLs permit them'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/4e11a7e6-e18c-46e4-a781-3ca2b4de6f30'
                    $item.SupportedOn = 'DC FL 2003 and newer'
                }
                8 {
                    $item.Name = 'fAllowAnonNSPI'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'Allow anonymous NSPI (RPC) calls'
                    } else {
                        $item.Behavior = 'Reject anonymous NSPI (RPC) calls'
                    }
                }
                9 {
                    $item.Name = 'fUserPwdSupport'
                    $item.Value = ($char -notin ('0','2'))
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'Disable access to userPassword attribute, regardless of permissions'
                    } else {
                        $item.Behavior = 'Allow access to userPassword attribute, ACLs permitting'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/4e11a7e6-e18c-46e4-a781-3ca2b4de6f30'
                }
                10 {
                    $item.Name = 'tenthChar'
                    $item.Value = ($char -eq '1')
                    if ($item.Value) {
                        $item.Behavior = 'If heuristics beyond the 9th char are to be set, the 10th char must have a value of 1'
                    } else {
                        $item.IsDefault = $false
                        $item.IsValid = $false
                        $item.Behavior = 'If 10th char is anything else than 1, the server should reject the update!'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/76df255d-dc67-4c1f-adc6-1e5b60021304'
                }
                11 {
                    $item.Name = 'fSpecifyGUIDOnAdd'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'On adding an object, specifying its GUID is allowed'
                    } else {
                        $item.Behavior = 'Specifying GUIDs is not allowed for add operations'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/7dfeb38c-3cb9-4215-ae1c-ef209fd251ae'
                }
                12 {
                    $item.Name = 'fDontStandardizeSDs'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'The order of ACEs supplied by the client is preserved'
                    } else {
                        $item.Behavior = 'ACEs are sorted according to the ordering rules'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/081c41f0-4c8d-4ab0-971d-77ec2504375a'
                }
                13 {
                    $item.Name = 'fAllowPasswordOperationsOverNonSecureConnection'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'Password operations are allowed without encryption (valid for ADLDS only!)'
                    } else {
                        $item.Behavior = 'Password operations require encryption (valid for ADLDS only!)'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/6e803168-f140-4d23-b2d3-c3a8ab5917d2'
                }
                14 {
                    $item.Name = 'fDontPropagateOnNoChangeUpdate'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'ntSecurityDescriptor is propagated to descendant objects on change, even if the new value is bitwise identical to the old one'
                    } else {
                        $item.Behavior = 'Changes in ntSecurityDescriptor where the old and the new value are bitwise identical, do not trigger propagation'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/b645c125-a7da-4097-84a1-2fa7cea07714#gt_b581857f-39aa-4979-876b-daba67a40f15'
                    $item.SupportedOn = 'Windows Server 2008 and newer'
                }
                15 {
                    $item.Name = 'fComputeANRStats'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'ANR searches are optimized using cardianlity estimates'
                    } else {
                        $item.Behavior = 'ANR searches are not optimized using cardinality from previous searches'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/1a9177f4-0272-4ab8-aa22-3c3eafd39e4b'
                }
                16 {
                    $item.Name = 'dwAdminSDExMask'
                    $item.Value = @()
                    $mask = "0x$char" -as [int]
                    if (($mask -band 1) -gt 0) { $item.Value += 'ACCOUNT_OPS' }
                    if (($mask -band 2) -gt 0) { $item.Value += 'SYSTEM_OPS' }
                    if (($mask -band 4) -gt 0) { $item.Value += 'PRINT_OPS' }
                    if (($mask -band 8) -gt 0) { $item.Value += 'BACKUP_OPS' }
                    if ($item.Value.Count -gt 0) {
                        $item.IsDefault = $false
                        $item.Behavior = ('The following groups will be excluded aus SDPROP: {0}' -f ($item.Value -join ','))
                    } else {
                        $item.Behavior = 'All privileged groups are included in SDPROP'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/dd3d29f3-8e1e-4e8c-a210-9eaef3abd628'
                }
                17 {
                    $item.Name = 'fKVNOEmuW2K'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'msDS-KeyVersionNumber will always equal 1 (W2K emulation)'
                    } else {
                        $item.Behavior = 'msDS-KeyVersionNumber will be read from object'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/cb85ccdf-6469-42d5-a61c-ebae09b72e9d'
                }
                18 {
                    $item.Name = 'fLDAPBypassUpperBoundsOnLimits'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'DCs will bypass implementation-dependent limits on LDAP policies'
                    } else {
                        $item.Behavior = 'DCs will respect implementation-dependent limits on LDAP policies'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/3f0137a1-63df-400c-bf97-e1040f055a99'
                    $item.SupportedOn = 'Windows Server 2008 and newer'
                }
                19 {
                    $item.Name = 'fDisableAutoIndexingOnSchemaUpdate'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'Index creation is triggered by index-related changes to the searchFlags attribute'
                    } else {
                        $item.Behavior = 'Index creation can be delayed upon detection of index-related changes to the searchFlags attribute until either an administrator issues the schemaUpdateNow rootDSE modify operation, the DC is rebooted, or an implementation-dependent time period has elapsed'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/3f0137a1-63df-400c-bf97-e1040f055a99'
                    $item.SupportedOn = 'Windows Server 2012 and newer'
                }
                20 {
                    $item.Name = 'twentiethChar'
                    $item.Value = ($char -eq '2')
                    if ($item.Value) {
                        $item.Behavior = 'If heuristics beyond the 19th char are to be set, the 20th char must have a value of 2'
                    } else {
                        $item.IsDefault = $false
                        $item.IsValid = $false
                        $item.Behavior = 'If 20th char is anything else than 2, the server should reject the update!'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/76df255d-dc67-4c1f-adc6-1e5b60021304'
                }
                21 {
                    $item.Name = 'DoNotVerifyUPNAndOrSPNUniqueness'
                    $item.Value = @()
                    $mask = "0x$char" -as [int]
                    if (($mask -band 1) -eq 0) { $item.Value += 'UPN' }
                    if (($mask -band 2) -eq 0) { $item.Value += 'SPN' }
                    if (($mask -band 4) -eq 0) { $item.Value += 'SPN alias' }
                    if ($item.Value.Count -gt 0) {
                        $item.IsDefault = $false
                        $item.Behavior = ('The following uniqueness consraints will not be checked prior to submitting the change: {0}' -f $item.Value -join ',')
                    } else {
                        $item.Behavior = 'All uniqueness constraints will be checked before submitting'
                    }
                    
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/3c154285-454c-4353-9a99-fb586e806944'
                    $item.SupportedOn = 'Windows Server 2012R2 and newer'
                }
                22 {
                    if ($pos -lt $Heuristics.Length) {
                        $char = ('0x{0}{1}' -f $Heuristics[$pos -1], $Heuristics[$pos])
                        $item.Character = ('{0}{1}' -f $Heuristics[$pos -1], $Heuristics[$pos])
                        $item.Value = $char
                        $minver = $char -as [int]
                        $item.Name = 'MinimumGetChangesRequestVersion'
                        if ($minver -eq 0) {
                            $item.Behavior = 'No restrictions on GETCHGREQ version will be imposed'
                        } else {
                            $item.IsDefault = $false
                            $item.Behavior = ('GETCHGREQ must have the minimum version of {0}' -f $minver)
                        }
                        $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-drsr/20ddf6d7-ac4e-4e16-8910-fbeca8f6e980'
                    } else {
                        $item.Name = '<MISSING DATA - position 23 must be set as well!>'
                        $item.IsValid = $false
                        $item.IsDefault = $false
                    }
                }
                23 {
                    Write-Verbose "Skipping byte 23 since it's paired with 22!"
                    $addItem = $false
                }
                24 {
                    if ($pos -lt $Heuristics.Length) {
                        $char = ('0x{0}{1}' -f $Heuristics[$pos -1], $Heuristics[$pos])
                        $item.Character = ('{0}{1}' -f $Heuristics[$pos -1], $Heuristics[$pos])
                        $item.Value = $char
                        $minver = $char -as [int]
                        $item.Name = 'MinimumGetChangesReplyVersion'
                        if ($minver -eq 0) {
                            $item.Behavior = 'No restrictions on GETCHGREPLY version will be imposed'
                        } else {
                            $item.IsDefault = $false
                            $item.Behavior = ('GETCHGREPLY must have the minimum version of {0}' -f $minver)
                        }
                        $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-drsr/20ddf6d7-ac4e-4e16-8910-fbeca8f6e980'
                    } else {
                        $item.Name = '<MISSING DATA - position 25 must be set as well!>'
                        $item.IsValid = $false
                        $item.IsDefault = $false
                    }
                }
                25 {
                    Write-Verbose "Skipping byte 25 since it's paired with 24!"
                    $addItem = $false
                }
                26 {
                    $item.Name = 'fLoadV1AddressBooksOnlySetting'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'MAPI address book is calculated using V1 attributes'
                    } else {
                        $item.Behavior = 'MAPI address book is calculated using V2 attributes'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/3f0137a1-63df-400c-bf97-e1040f055a99'
                    $item.SupportedOn = 'Windows Client/Server 1903 and newer'
                }
                27 {
                    $item.Name = 'fTreatTokenGroupsAsLDAPTransitiveAttribute'
                    $item.Value = ($char -ne '0')
                    if ($item.Value) {
                        $item.IsDefault = $false
                        $item.Behavior = 'LDAP Policy "MaxValueRangeTransitive" is respected for token groups'
                    } else {
                        $item.Behavior = 'LDAP Policy "MaxValueRange" is respected for token groups'
                    }
                    $item.URI = 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/01002598-92db-4c59-822e-b22f53168c90'
                    $item.SupportedOn = 'Windows Client/Server 1903 and newer'
                }
                28 {
                    $item.Name = 'AttributeAuthorizationOnLDAPAdd'
                    $enforcementDateHasPassed = ((Get-Date) -gt (Get-Date -Year 2023 -Month 4 -Day 11))
                    switch ($char) {
                        "0" { 
                            $item.Value = 0 
                            $item.Behavior = 'KB5008383 LDAP Add AuthZ verification disabled (not supported after 2023-04-11)'
                            $item.IsValid = (-not $enforcementDateHasPassed)
                            $item.IsDefault = (-not $enforcementDateHasPassed)
                        }
                        "2" { 
                            $item.IsDefault = $false
                            $item.Value = 2
                            $item.Behavior = 'KB5008383 LDAP Add AuthZ enforcement mode disabled, updated auditing disabled'
                        }
                        default { 
                            $item.Value = 1 
                            $item.IsDefault = $enforcementDateHasPassed
                            $item.Behavior = 'KB5008383 LDAP Add AuthZ enforcement mode'
                        }
                    }
                    $item.URI = 'https://support.microsoft.com/en-us/topic/kb5008383-active-directory-permissions-updates-cve-2021-42291-536d5555-ffba-4248-a60e-d6cbc849cde1'
                    $item.SupportedOn = 'Windows Server 2008R2 and higher'
                }
                29 {
                    $item.Name = 'BlockOwnerImplicitRights'
                    $enforcementDateHasPassed = ((Get-Date) -gt (Get-Date -Year 2023 -Month 4 -Day 11))
                    switch ($char) {
                        "0" { 
                            $item.Value = 0 
                            $item.Behavior = 'KB5008383 Owner Implicit Rights Audit enabled'
                            $item.IsDefault = (-not $enforcementDateHasPassed)
                        }
                        "2" { 
                            $item.IsDefault = $false
                            $item.Value = 2
                            $item.Behavior = 'KB5008383 Owner Implicit Rights enforcement mode disabled'
                        }
                        default { 
                            $item.Value = 1 
                            $item.IsDefault = $enforcementDateHasPassed
                            $item.Behavior = 'KB5008383 Owner Implicit Rights enforcement mode'
                        }
                    }
                    $item.URI = 'https://support.microsoft.com/en-us/topic/kb5008383-active-directory-permissions-updates-cve-2021-42291-536d5555-ffba-4248-a60e-d6cbc849cde1'
                    $item.SupportedOn = 'Windows Server 2008R2 and higher'
                }
                default {
                    $item.Value = $null
                    $item.IsValid = $false
                    $item.IsDefault = $false
                    $item.Behavior = 'This position in the dsHeuristics string has not yet been assigned'
                }
            }
            if ($addItem) {
                $res += $item
            }
        }
        return $res
    }
}

function Resolve-EncTypes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$Value
    )
    $res = @()
    if (($Value -band 1) -gt 0) { $res += 'DES_CBC_CRC' }
    if (($Value -band 2) -gt 0) { $res += 'DES_CBC_MD5' }
    if (($Value -band 4) -gt 0) { $res += 'RC4' }
    if (($Value -band 8) -gt 0) { $res += 'AES128' }
    if (($Value -band 16) -gt 0) { $res += 'AES256' }
    return $res
}

function Resolve-TrustAttributes {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$Value
    )
    $res = [PSCustomObject]@{
        'Value' = $Value
        'IsValid' = $true
        'ValidationErrors' = @()
        'SeeAlso' = @()
        'NonTransitive' = (($Value -band 1) -gt 0)
        'UplevelOnly' = (($Value -band 2) -gt 0)
        'Quarantined' = (($Value -band 4) -gt 0)
        'ForestTransitive' = (($Value -band 8) -gt 0)
        'CrossOrganization' = (($Value -band 16) -gt 0)
        'WithinForest' = (($Value -band 32) -gt 0)
        'TreatAsExternal' = (($Value -band 64) -gt 0)
        'UsesRC4' = (($Value -band 128) -gt 0)
        'NoDelegation' = (($Value -band 512) -gt 0)
        'PIMTrust' = (($Value -band 1024) -gt 0)
        'MustDelegate' = (($Value -band 2048) -gt 0)
        'LegacyTrustToParent' = (($Value -band 0x00400000) -gt 0)
        'LegacyTrustToTree' = (($Value -band 0x00800000) -gt 0)
        'ReservedBitsSet' = ((($Value -band 0x00000100) -gt 0) -or (($Value -band 0x00000800) -gt 0) -or (($Value -band 0x00002000) -gt 0) -or (($Value -band 0x00004000) -gt 0))
    }
    if ($res.TreatAsExternal) {
        if (-not $res.ForestTransitive) {
            $res.IsValid = $false
            $res.ValidationErrors += 'TRUST_ATTRIBUTE_TREAT_AS_EXTERNAL is set but TRUST_ATTRIBUTE_FOREST_TRANSITIVE is not set'
        }
        if ($res.LegacyTrustToParent -or $res.LegacyTrustToTree) {
            $res.IsValid = $false
            $res.ValidationErrors += 'TRUST_ATTRIBUTE_TREAT_AS_EXTERNAL is set but the trust is a legacy intraforest trust'
        }
    }
    if ($res.LegacyTrustToParent -and $res.LegacyTrustToTree) {
        $res.IsValid = $false
        $res.ValidationErrors += 'Trust is a legacy intraforest trust set to be both to parent and to different tree root'
    }
    if ($res.PIMTrust) {
        if (-not $res.TreatAsExternal) {
            $res.IsValid = $false
            $res.ValidationErrors += 'TRUST_ATTRIBUTE_PIM_TRUST is set but TRUST_ATTRIBUTE_TREAT_AS_EXTERNAL is not set'
        }
        if (-not $res.ForestTransitive) {
            $res.IsValid = $false
            $res.ValidationErrors += 'TRUST_ATTRIBUTE_PIM_TRUST is set but TRUST_ATTRIBUTE_FOREST_TRANSITIVE is not set'
        }
    }
    if ($res.Quarantined -or $res.TreatAsExternal -or $res.PIMTrust) {
        $res.SeeAlso += 'https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/55fc19f2-55ba-4251-8a6a-103dd7c66280'
    }
    return $res
}

function Start-SMPRSExecution {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Mode
    )
    $script:ExecutionID = [guid]::NewGuid().Guid
    $execUser = ('{0}\{1}' -f [System.Environment]::UserDomainName, [System.Environment]::UserName)
    Write-SMPRSLog -Restart -IgnoreLevel -Severity 1 -Message ('Starting Readiness Checker execution with ID {0} on machine {1} as user {2} in mode {3}' -f $script:ExecutionID, [System.Environment]::MachineName, $execUser, $Mode)
    $script:masterData = $null
    if (Update-SMPRSDataStore) {
        $script:masterData.Executions += [PSCustomObject]@{
            'ID' = $script:ExecutionID
            'Mode' = $Mode
            'From' = [System.Environment]::MachineName
            'By' = $execUser
            'Start' = [datetime]::Now
            'End' = $null
        }
        return Update-SMPRSDataStore
    } else {
        Write-SMPRSLog -Severity 3 -Message 'Could not update datastore!'
        return $false
    }
}

function Test-SMPRSConnectivity {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    $tgt = $ComputerName.Trim()
    $result = [PSCustomObject]@{
        'ComputerName' = $tgt
        'InputClassifiedAs' = 'unknown'
        'LocalMachine' = [Environment]::MachineName
        'ForwardNameResolution' = [PSCustomObject]@{
            'DNS' = $null
            'Platform' = $null
        }
        'ReverseNameResolution' = [PSCustomObject]@{
            'DNS' = $null
            'Platform' = $null
        }
        'Log' = @()
        'Errors' = @()
    }
    function Add-LogEntry {
        Param($Message)
        $result.Log += ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f [datetime]::Now, $Message)
    }
    Add-LogEntry ('Qualifying the input value of {0}' -f $tgt)
    if ($tgt -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
        $result.InputClassifiedAs = 'IPv4Address'
        Add-LogEntry 'ComputerName classified as IPv4Address'
        $dnsres = Resolve-DnsName -Type PTR -Name $tgt -DnsOnly -ErrorAction SilentlyContinue
        if ($null -ne $dnsres) {
            $result.ReverseNameResolution.DNS = $dnsres.NameHost
            Add-LogEntry ('DNS PTR resolution successful: {0}' -f ($dnsres.NameHost -join ', '))
        } else {
            Add-LogEntry 'DNS PTR resolution failed'
        }
        $dnsres = Resolve-DnsName -Type PTR -Name $tgt -ErrorAction SilentlyContinue
        if ($null -ne $dnsres) {
            $result.ReverseNameResolution.Platform = $dnsres.NameHost
            Add-LogEntry ('Platform PTR resolution successful: {0}' -f ($dnsres.NameHost -join ', '))
        } else {
            Add-LogEntry 'Platform PTR resolution failed'
        }
    } elseif ($tgt -match '^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$|$)') {
        $result.InputClassifiedAs = 'HostName'
        Add-LogEntry 'ComputerName classified as Hostname'
    } elseif ($tgt -match '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]\.|\.))+([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9]$|$))') {
        if ($tgt.Length -le 253) {
            $result.InputClassifiedAs = 'FQDN'
            Add-LogEntry 'ComputerName classified as valid FQDN'
        } else {
            $result.InputClassifiedAs = 'FQDNTooLong'
            Add-LogEntry 'ComputerName classified as FQDN exceeding the RFC limit of 253 characters'
            $result.Errors += 'Input value for ComputerName validated as FQDN but is longer than 253 characters'
        }
    } else {
        Add-LogEntry 'Input value for ComputerName could not be qualified'
        $result.Errors += 'Input value for ComputerName could not be qualified'
    }
    if ($result.InputClassifiedAs -in @('HostName','FQDN')) {
        $dnsres = Resolve-DnsName -Type A -Name $tgt -DnsOnly -ErrorAction SilentlyContinue
        if ($null -ne $dnsres) {
            $result.ForwardNameResolution.DNS = $dnsres.IPAddress
            Add-LogEntry ('DNS A resolution successful: {0}' -f ($dnsres.IPAddress -join ', '))
        } else {
            Add-LogEntry 'DNS A resolution failed'
        }
        $dnsres = Resolve-DnsName -Type A -Name $tgt -ErrorAction SilentlyContinue
        if ($null -ne $dnsres) {
            $result.ForwardNameResolution.Platform = $dnsres.IPAddress
            Add-LogEntry ('Platform A resolution successful: {0}' -f ($dnsres.IPAddress -join ', '))
        } else {
            Add-LogEntry 'Platform A resolution failed'
        }
    }
    return $result
}

function Test-DCConnection {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        [Parameter(Mandatory=$false)]
        [ValidateSet('ICMP','LDAP','LDAPS','WMI','SMB','WinRM','WinRMS')]
        [string[]]$Protocol,
        [Parameter(Mandatory=$false)]
        [int]$WinRMPort = 5985,
        [Parameter(Mandatory=$false)]
        [int]$WinRMSecurePort = 5986,
        [Parameter(Mandatory=$false)]
        [int]$IcmpCount = 3,
        [Parameter(Mandatory=$false)]
        [switch]$PreferInsecureWinRM
    )
    if (-not $PSBoundParameters.ContainsKey('Protocol')) {
        Write-SMPRSLog -Severity 0 -Message 'Protocol not supplied, assuming all of them'
        $Protocol = @('ICMP','LDAP','LDAPS','WMI','SMB','WinRM','WinRMS')
    }
    if (-not $PSBoundParameters.ContainsKey('Credential')) {
        Write-SMPRSLog -Severity 0 -Message 'Credential not supplied, assuming SSO'
    }
    $result = [PSCustomObject]@{
        'ICMP' = $null
        'DNS' = $null
        'LDAP' = $null
        'LDAPS' = $null
        'WMI' = $null
        'SMB' = $null
        'WinRM' = $null
        'WinRMS' = $null
        'PSVersion' = $null
        'PSLanguage' = $null
        'IPAddress' = $null
        'FQDN' = $null
        'Message' = @{
            'ICMP' = $null
            'DNS' = $null
            'LDAP' = $null
            'LDAPS' = $null
            'WMI' = $null
            'SMB' = $null
            'WinRM' = $null
            'WinRMS' = $null
            'RootDSE' = $null
        }
    }
    # determine if IP address or FQDN has been supplied and test DNS resolution to the DC's FQDN
    if ($ComputerName -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
        Write-SMPRSLog -Severity 0 -Message ('ComputerName supplied is an IPv4 address: {0}' -f $ComputerName)
        $result.IPAddress = $ComputerName
        Write-SMPRSLog -Severity 0 -Message 'Determining FQDN from RootDSE'
        $rootDSE = Get-RootDSE -ComputerName $ComputerName
        if ($rootDSE.Success) {
            $result.FQDN = $rootDSE.FQDN
            Write-SMPRSLog -Severity 0 -Message ('Trying to resolve {0} to an IPv4 address...' -f $result.FQDN)
            try {
                $dnsRes = Resolve-DnsName -Name $result.FQDN -Type A -DnsOnly -EA Stop
                $ipRes = $dnsRes.Where({$_.Section -eq 'Answer' -and $_.Type -eq 'A'})
                Write-SMPRSLog -Severity 0 -Message ('Resolved to {0} address(es)' -f $ipRes.Count)
                if ($ipRes.Count -eq 0) {
                    $result.DNS = $false
                    $result.Message['DNS'] = ('No A records resolved for {0}' -f $result.FQDN)
                } else {
                    $result.DNS = $true
                    $result.IPAddress = $ipRes[0].IPAddress
                }
            } catch {
                $result.DNS = $false
                $result.Message['DNS'] = $_.Exception.Message
            }
        } else {
            Write-SMPRSLog -Severity 2 -Message ('Could not get RootDSE from {0}: {1}' -f $ComputerName, $rootDSE.ErrorMessage)
            $result.Message.RootDSE = $rootDSE.ErrorMessage
        }
    } elseif ($ComputerName -notmatch '\.') {
        Write-SMPRSLog -Severity 0 -Message ('ComputerName supplied is a hostname: {0}' -f $ComputerName)
        Write-SMPRSLog -Severity 0 -Message 'Determining FQDN from RootDSE'
        $rootDSE = Get-RootDSE -ComputerName $ComputerName
        if ($rootDSE.Success) {
            $result.FQDN = $rootDSE.FQDN
            Write-SMPRSLog -Severity 0 -Message ('Trying to resolve {0} to an IPv4 address...' -f $result.FQDN)
            try {
                $dnsRes = Resolve-DnsName -Name $result.FQDN -Type A -DnsOnly -EA Stop
                $ipRes = $dnsRes.Where({$_.Section -eq 'Answer' -and $_.Type -eq 'A'})
                Write-SMPRSLog -Severity 0 -Message ('Resolved to {0} address(es)' -f $ipRes.Count)
                if ($ipRes.Count -eq 0) {
                    $result.DNS = $false
                    $result.Message['DNS'] = ('No A records resolved for {0}' -f $result.FQDN)
                } else {
                    $result.DNS = $true
                    $result.IPAddress = $ipRes[0].IPAddress
                }
            } catch {
                $result.DNS = $false
                $result.Message['DNS'] = $_.Exception.Message
            }
        } else {
            Write-SMPRSLog -Severity 2 -Message ('Could not get RootDSE from {0}: {1}' -f $ComputerName, $rootDSE.ErrorMessage)
            $result.Message.RootDSE = $rootDSE.ErrorMessage
        }
    } else {
        Write-SMPRSLog -Severity 0 -Message ('Trying to resolve {0} to an IPv4 address...' -f $ComputerName)
        try {
            $dnsRes = Resolve-DnsName -Name $ComputerName -Type A -DnsOnly -EA Stop
            $ipRes = $dnsRes.Where({$_.Section -eq 'Answer' -and $_.Type -eq 'A'})
            Write-SMPRSLog -Severity 0 -Message ('Resolved to {0} address(es)' -f $ipRes.Count)
            if ($ipRes.Count -eq 0) {
                $result.DNS = $false
                $result.Message['DNS'] = ('No A records resolved for {0}' -f $ComputerName)
            } else {
                $result.DNS = $true
                $result.IPAddress = $ipRes[0].IPAddress
                $result.FQDN = $ComputerName
            }
        } catch {
            $result.DNS = $false
            $result.Message['DNS'] = $_.Exception.Message
        }
    }
    if ($null -eq $result.IPAddress) {
        Write-SMPRSLog -Severity 2 -Message 'IP address cannot be determined, returning prematurely'
        return $result
    }
    if ($Protocol -contains 'ICMP') {
        Write-SMPRSLog -Severity 0 -Message ('Testing ICMP for {0}' -f $result.IPAddress)
        $result.ICMP = (Test-Connection -ComputerName $result.IPAddress -Count $IcmpCount -Quiet)
        Write-SMPRSLog -Severity 0 -Message ('ICMP result: {0}' -f $result.ICMP)
    }
    if ($result.DNS) {
        Write-SMPRSLog -Severity 0 -Message 'Using FQDN for subsequent checks'
        $tgtName = $result.FQDN
    } else {
        Write-SMPRSLog -Severity 0 -Message 'Using IP address for subsequent checks because DNS failed'
        $tgtName = $result.IPAddress
    }
    if ($Protocol -contains 'LDAP') {
        Write-SMPRSLog -Severity 0 -Message ('Testing LDAP for {0}' -f $tgtName)
        $args = @("LDAP://$($tgtName)/RootDSE")
        if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
            Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0}' -f $Credential.UserName)
            $args += $Credential.UserName
            $args += $Credential.GetNetworkCredential().Password
            $args += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing) #+[System.DirectoryServices.AuthenticationTypes]::ServerBind)
        }
        try {
            $dsE = New-Object System.DirectoryServices.DirectoryEntry($args) -EA Stop
            $dsE.RefreshCache()
            $result.LDAP = $true
        } catch {
            $result.LDAP = $false
            $result.Message['LDAP'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('LDAP exception: {0}' -f $_.Exception.Message)
        }
        Write-SMPRSLog -Severity 0 -Message ('LDAP result: {0}' -f $result.LDAP)
    }
    if ($Protocol -contains 'LDAPS') {
        Write-SMPRSLog -Severity 0 -Message ('Testing LDAPS for {0}' -f $tgtName)
        $args = @("LDAP://$($tgtName):636/RootDSE")
        if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
            Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0}' -f $Credential.UserName)
            $args += $Credential.UserName
            $args += $Credential.GetNetworkCredential().Password
            $args += ([System.DirectoryServices.AuthenticationTypes]::Secure+[System.DirectoryServices.AuthenticationTypes]::Sealing) #+[System.DirectoryServices.AuthenticationTypes]::ServerBind)
        }
        try {
            $dsE = New-Object System.DirectoryServices.DirectoryEntry($args) -EA Stop
            $dsE.RefreshCache()
            $result.LDAPS = $true
        } catch {
            $result.LDAPS = $false
            $result.Message['LDAPS'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('LDAPS exception: {0}' -f $_.Exception.Message)
        }
        Write-SMPRSLog -Severity 0 -Message ('LDAPS result: {0}' -f $result.LDAPS)
    }
    if ($Protocol -contains 'WMI') {
        Write-SMPRSLog -Severity 0 -Message ('Testing WMI for {0}' -f $tgtName)
        $args = @{
            'ComputerName' = $tgtName
            'Class' = 'Win32_OperatingSystem'
        }
        if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
            Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0}' -f $Credential.UserName)
            $args.Add('Credential', $Credential)
        }
        try {
            $wmiOS = Get-WmiObject @args -EA Stop
            $result.WMI = $true
        } catch {
            $result.WMI = $false
            $result.Message['WMI'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('WMI exception: {0}' -f $_.Exception.Message)
        }
        Write-SMPRSLog -Severity 0 -Message ('WMI result: {0}' -f $result.WMI)
    }
    if ($Protocol -contains 'SMB') {
        Write-SMPRSLog -Severity 0 -Message ('Testing SMB for {0}' -f $tgtName)
        try {
            $drvName = "TEST$(Get-Date -Format 'yyyyMMddHHmmss')"
            $args = @{
                'Name' = $drvName
                'PSProvider' = 'FileSystem'
                'Root' = "\\$($tgtName)\NETLOGON"
            }
            if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
                Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0}' -f $Credential.UserName)
                $args.Add('Credential', $Credential)
            }
            $null = New-PSDrive @args -EA Stop
            $result.SMB = $true
            try {
                Remove-PSDrive -Name $drvName -Force -EA Stop
            } catch {
                Write-SMPRSLog -Severity 0 -Message ('Error removing PSDrive after successful addition: {0}' -f $_.Exception.Message)
            }
        } catch {
            $result.SMB = $false
            $result.Message['SMB'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('Error adding PSDrive: {0}' -f $_.Exception.Message)
        }
        Write-SMPRSLog -Severity 0 -Message ('SMB result: {0}' -f $result.SMB)
    }
    if ($Protocol -contains 'WinRM') {
        Write-SMPRSLog -Severity 0 -Message ('Testing PS Remoting for {0}' -f $tgtName)
        $args = @{
            'ComputerName' = $tgtName
            'Port' = $WinRMPort
            'ScriptBlock' = {$PSVersionTable}
        }
        if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
            Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0} and setting Authentication to Kerberos' -f $Credential.UserName)
            $args.Add('Credential', $Credential)
            $args.Add('Authentication', 'Kerberos')
        }
        try {
            $psRemVT = Invoke-Command @args -EA Stop
            Write-SMPRSLog -Severity 0 -Message ('Raw PSVersion retrieved: {0}' -f $psRemVT.PSVersion)
            $result.WinRM = $true
            $result.PSVersion = $psRemVT.PSVersion
            if ($psRemVT.PSVersion -match '^(?<psver>\d+\.\d+)\..*') {
                $result.PSVersion = $Matches['psver']
            }
        } catch {
            $result.WinRM = $false
            $result.Message['WinRM'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('PS Remoting exception: {0}' -f $_.Exception.Message)
        }
        if ($result.WinRM) {
            $args['ScriptBlock'] = {$ExecutionContext.SessionState.LanguageMode.Value__}
            try {
                $psRemLM = Invoke-Command @args -EA Stop
                $result.PSLanguage = [System.Management.Automation.PSLanguageMode]$psRemLM
            } catch {
                Write-SMPRSLog -Severity 0 -Message ('Exception trying to get language mode: {0}' -f $_.Exception.Message)
            }
        }
        Write-SMPRSLog -Severity 0 -Message ('PS Remoting result: {0}' -f $result.WinRM)
    }
    if (($Protocol -contains 'WinRMS') -and (-not ($result.WinRM -and $PreferInsecureWinRM))) {
        Write-SMPRSLog -Severity 0 -Message ('Testing PS Remoting over HTTPS for {0}' -f $tgtName)
        $args = @{
            'ComputerName' = $tgtName
            'Port' = $WinRMSecurePort
            'UseSSL' = $true
            'ScriptBlock' = {$PSVersionTable}
        }
        if ($PSBoundParameters.ContainsKey('Credential') -and ($null -ne $Credential)) {
            Write-SMPRSLog -Severity 0 -Message ('Adding Credential for {0} and setting Authentication to Kerberos' -f $Credential.UserName)
            $args.Add('Credential', $Credential)
            $args.Add('Authentication', 'Kerberos')
        }
        try {
            $psRemVT = Invoke-Command @args -EA Stop
            Write-SMPRSLog -Severity 0 -Message ('Raw PSVersion retrieved: {0}' -f $psRemVT.PSVersion)
            $result.WinRMS = $true
        } catch {
            $result.WinRMS = $false
            $result.Message['WinRM'] = $_.Exception.Message
            Write-SMPRSLog -Severity 0 -Message ('PS Remoting over HTTPS exception: {0}' -f $_.Exception.Message)
        }
        if ($result.WinRMS -and ($null -eq $result.PSVersion)) {
            $result.PSVersion = $psRemVT.PSVersion
            if ($psRemVT.PSVersion -match '^(?<psver>\d+\.\d+)\..*') {
                $result.PSVersion = $Matches['´psver']
            }
            $args['ScriptBlock'] = {$ExecutionContext.SessionState.LanguageMode.Value__}
            try {
                $psRemLM = Invoke-Command @args -EA Stop
                $result.PSLanguage = [System.Management.Automation.PSLanguageMode]$psRemLM
            } catch {
                Write-SMPRSLog -Severity 0 -Message ('Exception trying to get language mode: {0}' -f $_.Exception.Message)
            }
        }
        Write-SMPRSLog -Severity 0 -Message ('PS Remoting over HTTPS result: {0}' -f $result.WinRMS)
    }
    return $result
}

function Test-Elevation {
    [CmdletBinding()]
    Param()
    $res = $false
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $res = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {}
    return $res
}

function Update-SMPRSDataStore {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Project','Forest','Domain','LocalMachine','DomainController')]
        [string]$DataArea,
        [Parameter(Mandatory=$false)]
        [PSObject]$Data
    )
    Write-SMPRSLog -Severity 0 -Message ('Datastore update invoked for [{0}]' -f $DataArea)
    $datastorePath = Join-Path -Path $PSScriptRoot -ChildPath 'SMPRS-ReadinessChecker.datastore'
    if ($null -eq $script:masterData) {
        Write-SMPRSLog -Severity 0 -Message ('Internal structure not initialized, trying to load from {0}' -f $datastorePath)
        if (Test-Path -Path $datastorePath -PathType Leaf) {
            try {
                $script:masterData = Import-Clixml -Path $datastorePath -EA Stop
                Write-SMPRSLog -Severity 0 -Message 'Master data loaded successfully'
            } catch {
                Write-SMPRSLog -Severity 3 -Message $_.Exception.Message
                $script:masterData = $null
                return $false
            }
        } else {
            Write-SMPRSLog -Severity 0 -Message 'Cache not found, will initialize with defaults'
        }
    }
    if ($null -eq $script:masterData) {
        $script:masterData = [PSCustomObject]@{
            'Project' = [PSCustomObject]@{
                'Name' = $null
                'Operator' = $null
                'Description' = $null
            }
            'CreationDate' = [datetime]::Now
            'LocalMachines' = @{}
            'Forests' = @{}
            'Domains' = @{}
            'DomainControllers' = @{}
            'Executions' = @()
        }
    }
    if (($null -ne $DataArea) -and ($null -ne $Data)) {
        switch ($DataArea) {
            'Project' {
                if ($null -ne $Data.Name) {
                    $script:masterData.Project.Name = $Data.Name
                }
                if ($null -ne $Data.Operator) {
                    $script:masterData.Project.Operator = $Data.Operator
                }
                if ($null -ne $Data.Description) {
                    $script:masterData.Project.Description = $Data.Description
                }
            }
            'Forest' {
                if ($null -ne $Data.ForestGUID) {
                    if ($script:masterData.Forests.ContainsKey($Data.ForestGUID)) {
                        $script:masterData.Forests[$Data.ForestGUID] = $Data
                        Write-SMPRSLog -Severity 0 -Message ('Updated existing forest {0}' -f $Data.ForestGUID)
                    } else {
                        $script:masterData.Forests.Add($Data.ForestGUID, $Data)
                        Write-SMPRSLog -Severity 0 -Message ('Added new forest {0}' -f $Data.ForestGUID)
                    }
                }
            }
            'Domain' {
                if ($null -ne $Data.DomainGUID) {
                    if ($script:masterData.Domains.ContainsKey($Data.DomainGUID)) {
                        $script:masterData.Domains[$Data.DomainGUID] = $Data
                        Write-SMPRSLog -Severity 0 -Message ('Updated existing domain {0}' -f $Data.DomainGUID)
                    } else {
                        $script:masterData.Domains.Add($Data.DomainGUID, $Data)
                        Write-SMPRSLog -Severity 0 -Message ('Added new domain {0}' -f $Data.DomainGUID)
                    }
                }
            }
            'LocalMachine' {
                if ($script:masterData.LocalMachines.ContainsKey($Data.MachineName)) {
                    $script:masterData.LocalMachines[$Data.MachineName] = $Data
                    Write-SMPRSLog -Severity 0 -Message ('Updated existing local machine {0}' -f $Data.MachineName)
                } else {
                    $script:masterData.LocalMachines.Add($Data.MachineName, $Data)
                    Write-SMPRSLog -Severity 0 -Message ('Added new local machine {0}' -f $Data.MachineName)
                }
            }
            'DomainController' {
                if ($null -ne $Data.FQDN) {
                    if ($script:masterData.DomainControllers.ContainsKey($Data.FQDN)) {
                        $script:masterData.DomainControllers[$Data.FQDN] = $Data
                        Write-SMPRSLog -Severity 0 -Message ('Updated existing domain controller {0}' -f $Data.FQDN)
                    } else {
                        $script:masterData.DomainControllers.Add($Data.FQDN, $Data)
                        Write-SMPRSLog -Severity 0 -Message ('Added new domain controller {0}' -f $Data.FQDN)
                    }
                }
            }
            default {
                Write-SMPRSLog -Severity 3 -Message ('This should not be possible if invoked correctly, DataArea={0}' -f $DataArea)
            }
        }
    }
    if ($null -ne $script:masterData) {
        Write-SMPRSLog -Severity 0 -Message ('Saving master data for [{0}] to CLIXML {1}' -f $DataArea, $datastorePath)
        try {
            $script:masterData | Export-Clixml -Path $datastorePath -Depth 20 -Encoding UTF8 -Force -EA Stop
            Write-SMPRSLog -Severity 0 -Message 'Done saving master data to CLIXML'
            return $true
        } catch {
            Write-SMPRSLog -Severity 3 -Message $_.Exception.Message
            return $false
        }
    }
}

function Write-SMPRSLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateRange(0,3)]
        [int]$Severity = 0,
        [Parameter(Mandatory=$false)]
        [datetime]$TimeStamp,
        [Parameter(Mandatory=$false)]
        [switch]$Restart,
        [Parameter(Mandatory=$false)]
        [switch]$LogToConsole,
        [Parameter(Mandatory=$false)]
        [switch]$IgnoreLevel
    )
    if (($null -eq $script:LogPath) -or $Restart) {
        $script:LogPath = Join-Path -Path ($env:TEMP) -ChildPath ('SMPRS.ReadinessChecker.{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    }
    if ($null -eq $script:LogLevel) { $script:LogLevel = 0 }
    if (($script:LogLevel -gt $Severity) -and -not $IgnoreLevel) { return }
    switch ($Severity) {
        1 { $sevText = 'INFO';  $sevCol = 'Green' }
        2 { $sevText = 'WARNING';  $sevCol = 'Yellow'; $script:WarningsEncountered = $true }
        3 { $sevText = 'ERROR';  $sevCol = 'Red'; $script:ErrorsEncountered = $true }
        default { $sevText = 'DEBUG';  $sevCol = 'Gray' }
    }
    try {
        $cs = Get-PSCallStack -EA Stop
    } catch {
        $cs = $null
        Write-Warning $_.Exception.Message
    }
    if ($cs.Count -gt 2) {
        $csparts = for ($i = $cs.Count - 2; $i -ge 1; $i--) {
            if ($cs[$i].Command -notlike "*.ps*1") { $cs[$i].Command }
        }
        $csMessage = ($csparts -join '][').Trim()
        if (-not [string]::IsNullOrWhiteSpace($csMessage)) { $csMessage = " [$csMessage] [$($cs[1].ScriptLineNumber)]"}
    } else {
        $csMessage = ''
    }
    if (-not $PSBoundParameters.ContainsKey('TimeStamp')) {
        $TimeStamp = [datetime]::Now
    }
    $outMessage = ('{0} {1}{2} {3}' -f (Get-Date $TimeStamp -Format 'yyyy-MM-ddTHH:mm:ss'), $sevText.PadRight(7,' '), $csMessage, $Message)
    try {
        $outMessage | Add-Content -Path $script:LogPath -Force -EA Stop
    } catch {}
    if ($LogToConsole -and ($Severity -gt 0)) {
        Write-Host $outMessage -ForegroundColor $sevCol
    }
}

#endregion
#region RED ALERT
trap {
    $raPath = (Join-Path -Path $env:TEMP -ChildPath 'SMPRS-ReadinessChecker-RED-ALERT.log')
    Write-Host ('RED ALERT! Please review the log file {0}' -f $raPath) -ForegroundColor Red
    ('=== {0} [{1}] ===' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $_.Exception.GetType().Name) | Add-Content -Path $raPath
    '' | Add-Content -Path $raPath
    $_.Exception.Message | Add-Content -Path $raPath
    '' | Add-Content -Path $raPath
    $_.ScriptStackTrace | Add-Content -Path $raPath
    if ($_.Exception.StackTrace) { $_.Exception.StackTrace | Add-Content -Path $raPath }
    break
}
#endregion
$execOK = Start-SMPRSExecution -Mode $PSCmdlet.ParameterSetName
if (-not $execOK) {
    Write-Warning 'Could not initialize data structures and datastore, check log for details'
    exit
}
if (-not ([string]::IsNullOrWhiteSpace($ProjectName) -and [string]::IsNullOrWhiteSpace($ProjectOperator) -and [string]::IsNullOrWhiteSpace($ProjectDescription))) {
    Write-SMPRSLog -Severity 1 -Message 'Project metadata will be updated'
    $proj = [PSCustomObject]@{
        'Name' = $Script:masterData.Project.Name
        'Operator' = $Script:masterData.Project.Operator
        'Description' = $Script:masterData.Project.Description
    }
    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        Write-SMPRSLog -Severity 0 -Message ('Project Name: {0}' -f $ProjectName)
        if ($ProjectName -eq '#CLEAR#') {
            $proj.Name = ''
        } else {
            $proj.Name = $ProjectName.Trim()
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ProjectOperator)) {
        Write-SMPRSLog -Severity 0 -Message ('Project operator: {0}' -f $ProjectOperator)
        if ($ProjectOperator -eq '#CLEAR#') {
            $proj.Operator = ''
        } else {
            $proj.Operator = $ProjectOperator.Trim()
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ProjectDescription)) {
        Write-SMPRSLog -Severity 0 -Message ('Project Description: {0}' -f $ProjectDescription)
        if ($ProjectDescription -eq '#CLEAR#') {
            $proj.Description = ''
        } else {
            $proj.Description = $ProjectDescription.Trim()
        }
    }
    if (Update-SMPRSDataStore -DataArea Project -Data $proj) {
        Write-SMPRSLog -Severity 1 -Message 'Project metadata updated successfully'
    } else {
        Write-SMPRSLog -Severity 2 -Message 'There was a problem updating project metadata'
    }
    
}
Write-Host ('Running in mode [{0}] at log level {1}' -f $PSCmdlet.ParameterSetName, $script:LogLevelCaption) -ForegroundColor Cyan
switch ($PSCmdlet.ParameterSetName) {
    'Interactive' {
        $interCred = $null
        do {
            Write-SMPRSLog -Severity 1 -Message 'Generating interactive menu'
            $exitNow = $false
            Clear-Host
            Write-Host 'Semperis pre-deployment Readiness checker, 2026 edition' -ForegroundColor Cyan
            Write-Host ' '
            Write-Host ('Logging at {1} level to: {0}' -f $script:LogPath, $script:LogLevelCaption)
            Write-Host ' '
            Write-Host 'OBJECTS CURRENTLY IN DATASTORE:' -ForegroundColor Cyan
            $nLM = $Script:masterData.LocalMachines.Count
            $nFO = $Script:masterData.Forests.Count
            $nDO = $Script:masterData.Domains.Count
            $nDOX = $Script:masterData.Domains.GetEnumerator().Where({$_.Value.IsExplored}).Count
            $nDC = $Script:masterData.DomainControllers.Count
            $nDCX = $Script:masterData.DomainControllers.GetEnumerator().Where({$_.Value.IsExplored}).Count
            if ($nLM -gt 0) { $fc = 'Green' } else { $fc = 'Gray' }
            Write-Host ('Local machines: {0}' -f $nLM) -ForegroundColor $fc
            if ($nFO -gt 0) { $fc = 'Green' } else { $fc = 'Gray' }
            Write-Host ('AD Forests    : {0}' -f $nFO) -ForegroundColor $fc
            if ($nDO -gt 0) { $fc = 'Green' } elseif ($nFO -gt 0) { $fc = 'Magenta' } else { $fc = 'Gray' }
            Write-Host ('AD Domains    : {0} ({1} explored)' -f $nDO, $nDOX) -ForegroundColor $fc
            if ($nDC -gt 0) { $fc = 'Green' } elseif ($nFO -gt 0) { $fc = 'Magenta' } else { $fc = 'Gray' }
            Write-Host ('AD DCs        : {0} ({1} explored)' -f $nDC, $nDCX) -ForegroundColor $fc
            Write-Host ' '
            if ($null -eq $interCred) { 
                $crstr = '- not set -'; $fc = 'Gray'
            } else { 
                $crstr = $interCred.UserName; $fc = 'Green' 
            }
            Write-SMPRSLog -Severity 0 -Message ('EA credential: {0}' -f $crstr)
            Write-Host ('EA Credential : {0}' -f $crstr) -ForegroundColor $fc
            Write-Host ' '
            if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Name)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Name }
            Write-Host ('Project name  : {0}' -f $pnText) -ForegroundColor $fc
            if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Operator)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Operator }
            Write-Host ('Operator name : {0}' -f $pnText) -ForegroundColor $fc
            if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Description)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Description }
            Write-Host ('Description   : {0}' -f $pnText) -ForegroundColor $fc
            Write-Host ' '
            Write-Host 'Actions allowed in this state:' -ForegroundColor Cyan
            $ops = @('0','3','8')
            $wmiCS = Get-WmiObject Win32_ComputerSystem
            if (Test-Elevation) {
                if ($wmiCS.DomainRole -ge 4) {
                    Write-Host '  - Local machine is a domain controller' -ForegroundColor DarkGray
                } elseif ($wmiCS.DomainRole -le 1) {
                    Write-Host '  - Local machine is a workstation' -ForegroundColor DarkGray
                } else {
                    Write-Host '1 - Explore local machine' -ForegroundColor Green
                    $ops += '1'
                }
            } else {
                Write-Host '  - Local machine exploration requires elevation' -ForegroundColor DarkGray
            }
            if ($wmiCS.PartOfDomain) {
                if ($env:USERDOMAIN -eq $env:COMPUTERNAME) {
                    Write-Host '  - local user is logged on, forest exploration by SSO is not possible' -ForegroundColor DarkGray
                } else {
                    $logonSrv = ($env:LOGONSERVER).Trim('\\')
                    Write-Host ('2 - Explore own AD forest including domains and DCs against {0} as the logged-on user {1}\{2}' -f $logonSrv, $env:USERDOMAIN, $env:USERNAME) -ForegroundColor Green
                    $ops += '2'
                }
            } else {
                Write-Host '  - workgroup machine, forest exploration by SSO is not possible' -ForegroundColor DarkGray
            }
            if ($null -ne $interCred) {
                $credStr = ' (enter CLEAR! as user name to clear)'
            } else {
                $credStr = $null
            }
            Write-Host ('3 - Set or update credential for forest exploration with explicit auth{0}' -f $credStr) -ForegroundColor Green
            if ($null -ne $interCred) {
                $credStr = ' (previously entered credential will be used)'
            } else {
                $credStr = ''
            }
            if ($wmiCS.PartOfDomain -or ($null -ne $interCred)) {
                
                Write-Host ('4 - Explore an AD forest by specifying a target server{0}' -f $credStr) -ForegroundColor Green
                $ops += '4'
            } else {
                Write-Host '  - need credential to explore AD forest from workgroup machine' -ForegroundColor DarkGray
            }
            if ($nFO -gt 0) {
                if ($nFO -eq 1) { $fMsg = 'the saved forest' } else { $fMsg = 'one or multiple saved forest(s)' }
                Write-Host ('5 - Explore domains in {0}{1}' -f $fMSG, $credStr) -ForegroundColor Green
                $ops += '5'
            } else {
                Write-Host '  - a forest is required for domain exploration' -ForegroundColor DarkGray
            }
            if ($nFO -gt 0) {
                if ($nFO -eq 1) { $fMsg = 'the saved forest' } else { $fMsg = 'one or multiple saved forest(s)' }
                Write-Host ('6 - Explore all DCs in {0}{1}' -f $fMSG, $credStr) -ForegroundColor Green
                $ops += '6'
            } else {
                Write-Host '  - a forest is required for DC exploration' -ForegroundColor DarkGray
            }
            if ($nFO -gt 0) {
                if ($nFO -eq 1) { $fMsg = 'the saved forest' } else { $fMsg = 'one of the saved forests' }
                Write-Host ('7 - Explore a selection of DCs in {0}{1}' -f $fMSG, $credStr) -ForegroundColor Green
                $ops += '7'
            } else {
                Write-Host '  - a forest is required for DC exploration' -ForegroundColor DarkGray
            }
            Write-Host '8 - Set or update project metadata' -ForegroundColor Green
            if (($nLM -gt 0) -or ($nFO -gt 0)) {
                Write-Host '9 - Create report (HTML + JSON) and exit' -ForegroundColor Green
                $ops += '9'
            } else {
                Write-Host '  - not enough data for report' -ForegroundColor DarkGray
            }
            Write-Host '0 - Exit' -ForegroundColor Green
            $opStr = ($ops | Sort-Object) -join ' '
            Write-SMPRSLog -Severity 1 -Message ('Actions allowed in this pass: {0}' -f $opStr)
            do {
                $choice = Read-Host -Prompt ('Enter [{0}] ' -f $opStr)
                Write-SMPRSLog -Severity 0 -Message ('Operator choice: {0}' -f $choice)
            } until ($choice -in $ops)
            switch ($choice) {
                '1' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 1 ======'
                    Write-SMPRSLog -Severity 1 -Message 'Invoking local machine exploration'
                    $lmResult = Explore-SMPRSLocalMachine
                    Write-SMPRSLog -Severity 1 -Message ('Returned from local machine exploration, success: {0}' -f $lmResult)
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 1 ======'
                }
                '2' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 2 ======'
                    Write-SMPRSLog -Severity 1 -Message ('Invoking forest exploration starting from {0}' -f $logonSrv)
                    $forestRes = Explore-SMPRSForest -ComputerName $logonSrv -PassThru
                    Write-SMPRSLog -Severity 1 -Message ('Returned from forest exploration, success: {0}' -f $forestRes.Success)
                    if ($forestRes.Success) {
                        Write-SMPRSLog -Severity 1 -Message ('Forest GUID: {0} explored, will explore domains' -f $forestRes.ForestGUID)
                        Write-Host ('Forest explored, will explore domains for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                        $domRes = Explore-SMPRSDomain -ForestGUID $forestRes.ForestGUID
                        if ($domRes) {
                            Write-Host 'Domains explored successfully' -ForegroundColor Cyan
                            Write-SMPRSLog -Severity 1 -Message 'Domains explored successfully'
                        } else {
                            Write-Host 'Domain exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                            Write-SMPRSLog -Severity 2 -Message 'Domain exploration unsuccessfull, see log for details'
                        }
                        Write-Host ('Now exploring domain controllers for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                        Write-SMPRSLog -Severity 1 -Message 'Now exploring domain controllers'
                        $dcRes = Explore-SMPRSDomainController -ForestGUID $forestRes.ForestGUID
                        if ($dcRes) {
                            Write-Host 'Domain Controllers explored successfully' -ForegroundColor Cyan
                            Write-SMPRSLog -Severity 1 -Message 'Domain Controllers explored successfully'
                        } else {
                            Write-Host 'Domain Controller exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                            Write-SMPRSLog -Severity 2 -Message 'Domain Controller exploration unsuccessfull, see log for details'
                        }
                    } else {
                         Write-SMPRSLog -Severity 2 -Message ('Forest exploration unsuccessful: {0}' -f $forestRes.ErrorMessage)
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 2 ======'
                }
                '3' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 3 ======'
                    Write-SMPRSLog -Severity 1 -Message 'Asking for EA admin credential using Get-Credential'
                    $crmsg = 'Enterprise Admin account credential or CLEAR! to clear'
                    if ($null -eq $interCred) {
                        $interCred = Get-Credential -Message $crmsg
                    } else {
                        $interCred = Get-Credential -Message $crmsg -UserName $interCred.UserName
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Operator entry: {0}' -f $interCred.UserName)
                    if ($interCred.UserName -ceq 'CLEAR!') { $interCred = $null }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 3 ======'
                }
                '4' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 4 ======'
                    Write-SMPRSLog -Severity 1 -Message 'Prompting for FQDN or IP for forest exploration'
                    do {
                        $tgtServer = Read-Host -Prompt 'Enter IP or FQDN of the target Domain Controller'
                        Write-SMPRSLog -Severity 1 -Message ('Operator entry: {0}' -f $tgtServer)
                    } until (-not [string]::IsNullOrWhiteSpace($tgtServer))
                    if ($null -ne $interCred) {
                        Write-SMPRSLog -Severity 1 -Message ('Exploring forest from {0} as {1}' -f $tgtServer, $interCred.UserName)
                        $forestRes = Explore-SMPRSForest -ComputerName $tgtServer -Credential $interCred -PassThru
                    } else {
                        Write-SMPRSLog -Severity 1 -Message ('Exploring forest from {0} as logged-on user' -f $tgtServer)
                        $forestRes = Explore-SMPRSForest -ComputerName $tgtServer -PassThru
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Returned from forest exploration, success: {0}' -f $forestRes.Success)
                    if (-not $forestRes.Success) {
                        Write-SMPRSLog -Severity 2 -Message ('Returned error: {0}' -f $forestRes.ErrorMessage)
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 4 ======'
                }
                '5' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 5 ======'
                    $fGuids = @()
                    if ($nFO -eq 1) {
                        Write-SMPRSLog -Severity 1 -Message ('Only forest for domain exploration: {0}' -f $fGuids[0])
                        $fGuids = @($Script:masterData.Forests.Keys[0])
                    } elseif ($nFO -gt 1) {
                        Write-SMPRSLog -Severity 1 -Message ('{0} forests for domain exploration, propmpting with GridView' -f $nFO)
                        $fList = @()
                        foreach ($zf in $Script:masterData.Forests.GetEnumerator()) {
                            $fList += [PSCustomObject]@{
                                'GUID' = $zf.Name
                                'ForestRootDomain' = $zf.Value.ForestRootDomain
                            }
                        }
                        $fListOp = $fList | Out-GridView -PassThru -Title 'Please select forests to explore domains in'
                        $fGuids = $fListOp | Select-Object -ExpandProperty GUID
                        Write-SMPRSLog -Severity 1 -Message ('Operator choice: {0}' -f ($fGuids -join ', '))
                    }
                    foreach ($guid in $fGuids) {
                        Write-SMPRSLog -Severity 1 -Message ('Exploring domains in forest {0}' -f $guid)
                        Write-Host ('Exploring domains in forest {0}' -f $guid)
                        if ($null -ne $interCred) {
                            $domainRes = Explore-SMPRSDomain  -ForestGUID $guid -Credential $interCred
                        } else {
                            $domainRes = Explore-SMPRSDomain  -ForestGUID $guid
                        }
                        if ($domainRes) {
                            Write-SMPRSLog -Severity 1 -Message 'Domains explored successfully'
                        } else {
                            Write-SMPRSLog -Severity 2 -Message 'Domain exploration unsuccessfull, see log for details'
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 5 ======'
                }
                '6' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 6 ======'
                    $fGuids = @()
                    if ($nFO -eq 1) {
                        Write-SMPRSLog -Severity 1 -Message ('Only forest for domain controller exploration: {0}' -f $fGuids[0])
                        $fGuids = @($Script:masterData.Forests.Keys[0])
                    } elseif ($nFO -gt 1) {
                        Write-SMPRSLog -Severity 1 -Message ('{0} forests for domain controller exploration, propmpting with GridView' -f $nFO)
                        $fList = @()
                        foreach ($zf in $Script:masterData.Forests.GetEnumerator()) {
                            $fList += [PSCustomObject]@{
                                'GUID' = $zf.Name
                                'ForestRootDomain' = $zf.Value.ForestRootDomain
                            }
                        }
                        $fListOp = $fList | Out-GridView -PassThru -Title 'Please select forests to explore domain controllers in'
                        $fGuids = $fListOp | Select-Object -ExpandProperty GUID
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Operator choice: {0}' -f ($fGuids -join ', '))
                    foreach ($guid in $fGuids) {
                        Write-SMPRSLog -Severity 1 -Message ('Exploring domain controllers in forest {0}' -f $guid)
                        if ($null -ne $interCred) {
                            $domainRes = Explore-SMPRSDomainController -ForestGUID $guid -Credential $interCred
                        } else {
                            $domainRes = Explore-SMPRSDomainController -ForestGUID $guid
                        }
                        if ($domainRes) {
                            Write-SMPRSLog -Severity 1 -Message 'Domain controllers explored successfully'
                        } else {
                            Write-SMPRSLog -Severity 2 -Message 'Domain controller exploration unsuccessfull, see log for details'
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 6 ======'
                }
                '7' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 7 ======'
                    $fGuids = @()
                    if ($nFO -eq 1) {
                        Write-SMPRSLog -Severity 1 -Message ('Only forest for domain controller exploration: {0}' -f $fGuids[0])
                        $fGuids = @($Script:masterData.Forests.Keys[0])
                    } elseif ($nFO -gt 1) {
                        Write-SMPRSLog -Severity 1 -Message ('{0} forests for domain controller exploration, propmpting with GridView' -f $nFO)
                        $fList = @()
                        foreach ($zf in $Script:masterData.Forests.GetEnumerator()) {
                            $fList += [PSCustomObject]@{
                                'GUID' = $zf.Name
                                'ForestRootDomain' = $zf.Value.ForestRootDomain
                            }
                        }
                        do {
                            $fListOp = $fList | Out-GridView -PassThru -Title 'Please select ONE FOREST to explore domain controllers'
                        } until ($fListOp.Count -le 1)
                        $fGuids = $fListOp | Select-Object -ExpandProperty GUID
                        Write-SMPRSLog -Severity 1 -Message ('Operator choice: {0}' -f ($fGuids -join ', '))
                    }
                    foreach ($guid in $fGuids) {
                        $dcList = @()
                        foreach ($dc in $script:masterData.DomainControllers.GetEnumerator().Where({$_.Value.ForestGUID -eq $guid})) {
                            $dcList += [PSCustomObject]@{
                                'FQDN' = $dc.Name
                                'Domain' = $dc.Value.Domain
                                'Site' = $dc.Value.Site
                            }
                        }
                        Write-SMPRSLog -Severity 1 -Message ('Prompting with GridView for choosing out of {0} DCs in {1}' -f $dcList.Count, $guid)
                        $dcList = $dcList | Out-GridView -PassThru
                        Write-SMPRSLog -Severity 1 -Message ('Operator choice: {0}' -f ($dcList -join ', '))
                        if ($null -ne $interCred) {
                            $domainRes = Explore-SMPRSDomainController -Targets $dcList.FQDN -Credential $interCred
                        } else {
                            $domainRes = Explore-SMPRSDomainController -Targets $dcList.FQDN
                        }
                        if ($domainRes) {
                            Write-SMPRSLog -Severity 1 -Message 'Domain controllers explored successfully'
                        } else {
                            Write-SMPRSLog -Severity 2 -Message 'Domain controller exploration unsuccessfull, see log for details'
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 7 ======'
                }
                '8' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 8 ======'
                    $proj = [PSCustomObject]@{
                        'Name' = $Script:masterData.Project.Name
                        'Operator' = $Script:masterData.Project.Operator
                        'Description' = $Script:masterData.Project.Description
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Prompting for new project name (current: {0})' -f $Script:masterData.Project.Name)
                    Write-Host ('Enter the new value for project name [{0}]' -f $Script:masterData.Project.Name)
                    if (-not [string]::IsNullOrWhiteSpace($Script:masterData.Project.Name)) {
                        Write-Host '[Enter] to keep the current value, #CLEAR# to clear' -ForegroundColor DarkGray
                    } 
                    $newPName = Read-Host
                    Write-SMPRSLog -Severity 1 -Message ('Operator input for project name: {0}' -f $newPName)
                    if (-not [string]::IsNullOrWhiteSpace($newPName)) {
                        if ($newPName -eq '#CLEAR#') {
                            $proj.Name = ''
                        } else {
                            $proj.Name = $newPName
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Prompting for new operator name (current: {0})' -f $Script:masterData.Project.Operator)
                    Write-Host ('Enter the new value for operator name [{0}]' -f $Script:masterData.Project.Operator)
                    if (-not [string]::IsNullOrWhiteSpace($Script:masterData.Project.Operator)) {
                        Write-Host '[Enter] to keep the current value, #CLEAR# to clear' -ForegroundColor DarkGray
                    } 
                    $newPName = Read-Host
                    Write-SMPRSLog -Severity 1 -Message ('Operator input for project operator: {0}' -f $newPName)
                    if (-not [string]::IsNullOrWhiteSpace($newPName)) {
                        if ($newPName -eq '#CLEAR#') {
                            $proj.Operator = ''
                        } else {
                            $proj.Operator = $newPName
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Prompting for new project description (current: {0})' -f $Script:masterData.Project.Description)
                    Write-Host ('Enter the new value for project description [{0}]' -f $Script:masterData.Project.Description)
                    if (-not [string]::IsNullOrWhiteSpace($Script:masterData.Project.Description)) {
                        Write-Host '[Enter] to keep the current value, #CLEAR# to clear' -ForegroundColor DarkGray
                    } 
                    $newPName = Read-Host
                    if (-not [string]::IsNullOrWhiteSpace($newPName)) {
                        if ($newPName -eq '#CLEAR#') {
                            $proj.Description = ''
                        } else {
                            $proj.Description = $newPName
                        }
                    }
                    Write-SMPRSLog -Severity 1 -Message ('Operator input for project description: {0}' -f $newPName)
                    Update-SMPRSDataStore -DataArea Project -Data $proj
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 8 ======'
                }
                '9' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 9 ======'
                    if (Export-SMPRSReport) {
                        Write-SMPRSLog -Severity 1 -Message 'Report created successfully'
                        Write-Host ('Report created successfully in {0}' -f [Environment]::GetFolderPath('MyDocuments')) -ForegroundColor Green
                        $exitNow = $true 
                    } else {
                        Write-SMPRSLog -Severity 2 -Message 'Error creating report, see log for details'
                        Write-Warning 'Error creating report - please review log for details!'
                    }
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 9 ======'
                }
                '0' {
                    Write-SMPRSLog -Severity 1 -Message '====== BEGIN OPTION 0 ======'
                    $exitNow = $true 
                    Write-SMPRSLog -Severity 1 -Message '====== END OPTION 0 ======'
                }
            }
        } until ($exitNow)
        Write-SMPRSLog -Severity 1 -Message 'Exiting interactive mode'
    }
    'Report' {
        Write-SMPRSLog -Severity 1 -Message 'Invoke report creation'
        if (Export-SMPRSReport -ADFRVersion $ADFRVersion -DSPVersion $DSPVersion) {
            Write-SMPRSLog -Severity 1 -Message 'Report created successfully'
        } else {
            Write-SMPRSLog -Severity 2 -Message 'Error creating report, see log for details'
        }
    }
    'Status' {
        Write-SMPRSLog -Severity 1 -Message 'Displaying datastore status'
        Clear-Host
        Write-Host 'Semperis pre-deployment Readiness checker, 2026 edition' -ForegroundColor Cyan
        Write-Host ' '
        Write-Host ('Logging at {1} level to: {0}' -f $script:LogPath, $script:LogLevelCaption)
        Write-Host ' '
        Write-Host 'OBJECTS CURRENTLY IN DATASTORE:' -ForegroundColor Cyan
        $nLM = $Script:masterData.LocalMachines.Count
        $nFO = $Script:masterData.Forests.Count
        $nDO = $Script:masterData.Domains.Count
        $nDOX = $Script:masterData.Domains.GetEnumerator().Where({$_.Value.IsExplored}).Count
        $nDC = $Script:masterData.DomainControllers.Count
        $nDCX = $Script:masterData.DomainControllers.GetEnumerator().Where({$_.Value.IsExplored}).Count
        if ($nLM -gt 0) { $fc = 'Green' } else { $fc = 'Gray' }
        Write-Host ('Local machines: {0}' -f $nLM) -ForegroundColor $fc
        if ($nFO -gt 0) { $fc = 'Green' } else { $fc = 'Gray' }
        Write-Host ('AD Forests    : {0}' -f $nFO) -ForegroundColor $fc
        if ($nDO -gt 0) { $fc = 'Green' } elseif ($nFO -gt 0) { $fc = 'Magenta' } else { $fc = 'Gray' }
        Write-Host ('AD Domains    : {0} ({1} explored)' -f $nDO, $nDOX) -ForegroundColor $fc
        if ($nDC -gt 0) { $fc = 'Green' } elseif ($nFO -gt 0) { $fc = 'Magenta' } else { $fc = 'Gray' }
        Write-Host ('AD DCs        : {0} ({1} explored)' -f $nDC, $nDCX) -ForegroundColor $fc
        Write-Host ' '
        if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Name)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Name }
        Write-Host ('Project name  : {0}' -f $pnText) -ForegroundColor $fc
        if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Operator)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Operator }
        Write-Host ('Operator name : {0}' -f $pnText) -ForegroundColor $fc
        if ([string]::IsNullOrWhiteSpace($Script:masterData.Project.Description)) { $fc = 'Gray'; $pnText = '- not set -' } else { $fc = 'Green'; $pnText = $Script:masterData.Project.Description }
        Write-Host ('Description   : {0}' -f $pnText) -ForegroundColor $fc
    }
    'LMOnly' {
        Write-SMPRSLog -Severity 1 -Message 'Local machine exploration triggered'
        Clear-Host
        if (Test-Elevation) {
            Write-SMPRSLog -Severity 1 -Message 'Elevation detected, will proceed with local machine exploration'
            Write-Host 'Script is running elevated, will explore the local machine if it is not a client and not a DC' -ForegroundColor Cyan
            $lmResult = Explore-SMPRSLocalMachine
            if ($lmResult) {
                Write-SMPRSLog -Severity 1 -Message 'Local machine explored successfully'
                Write-Host ' - local machine explored successfully'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'Local machine exploration unsuccessful, see log for details'
            }
        } else {
            Write-SMPRSLog -Severity 1 -Message 'Not running elevated, will not proceed with local machine exploration'
            Write-Host 'Script is not running elevated, skipping local machine exploration' -ForegroundColor Cyan
        }
    }
    'ADOnly' {
        Write-SMPRSLog -Severity 1 -Message 'Local AD Forest exploration triggered'
        Clear-Host
        $wmiCS = Get-WmiObject Win32_ComputerSystem
        if ($wmiCS.DomainRole -lt 4) {
            Write-SMPRSLog -Severity 1 -Message 'Local machine is not a DC, will not proceed with local forest exploration'
            Write-Host 'Local machine is not a DC, skipping forest exploration' -ForegroundColor Cyan
        } elseif (-not (Test-Elevation)) {
            Write-SMPRSLog -Severity 1 -Message 'Local machine is a DC but script is not running elevated, will not proceed with local forest exploration'
            Write-Host 'Script is not running elevated, skipping forest exploration' -ForegroundColor Cyan
        } else {
            Write-SMPRSLog -Severity 1 -Message 'Running elevated on a DC, starting local forest exploration'
            Write-Host 'Script is running elevated on a DC, exploring its local forest' -ForegroundColor Cyan
            $forestRes = Explore-SMPRSForest -ComputerName localhost -PassThru
            if ($forestRes.Success) {
                Write-SMPRSLog -Severity 1 -Message ('Local AD Forest exploration successful, GUID={0}' -f $forestRes.ForestGUID)
                Write-Host ('Forest explored, will explore domains for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                $domRes = Explore-SMPRSDomain -ForestGUID $forestRes.ForestGUID
                if ($domRes) {
                    Write-SMPRSLog -Severity 1 -Message 'Domains explored successfully'
                    Write-Host 'Domains explored successfully' -ForegroundColor Cyan
                } else {
                    Write-SMPRSLog -Severity 2 -Message 'Domain exploration unsuccessful, see log for details'
                    Write-Host 'Domain exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                }
                Write-SMPRSLog -Severity 1 -Message ('Now exploring domain controllers for forest {0}' -f $forestRes.ForestGUID)
                Write-Host ('Now exploring domain controllers for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                $dcRes = Explore-SMPRSDomainController -ForestGUID $forestRes.ForestGUID
                if ($dcRes) {
                    Write-SMPRSLog -Severity 1 -Message 'Domain controllers explored successfully'
                    Write-Host 'Domain Controllers explored successfully' -ForegroundColor Cyan
                } else {
                    Write-SMPRSLog -Severity 2 -Message 'Domain controller unsuccessful, see log for details'
                    Write-Host 'Domain Controller exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                }
            } else {
                Write-SMPRSLog -Severity 2 -Message ('Local AD Forest exploration unsuccessful: {0}' -f $forestRes.ErrorMessage)
            }
        }
    }
    'DCTarget' {
        Write-SMPRSLog -Severity 1 -Message 'Targeted AD Forest exploration triggered'
        if (Test-Elevation) {
            Write-SMPRSLog -Severity 1 -Message 'Script is running elevated, will explore the local machine in addition to AD forest if it is not a client and not a DC'
            Write-Host 'Script is running elevated, will explore the local machine in addition to AD forest if it is not a client and not a DC' -ForegroundColor Cyan
            $lmResult = Explore-SMPRSLocalMachine
            if ($lmResult) {
                Write-SMPRSLog -Severity 1 -Message 'Local machine explored successfully'
                Write-Host ' - local machine explored successfully'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'Local machine exploraiton unsuccessful, see log for details'
            }
        } else {
            Write-SMPRSLog -Severity 1 -Message 'Script is not running elevated, skipping local machine exploration'
            Write-Host 'Script is not running elevated, skipping local machine exploration' -ForegroundColor Cyan
        }
        Write-SMPRSLog -Severity 1 -Message ('Checking connectivity to DCTarget {0}...' -f $DomainController)
        Write-Host ('Checking connectivity to DCTarget {0}...' -f $DomainController) -ForegroundColor Cyan
        $dcReach = Test-DCConnection -ComputerName $DomainController -Credential $Credential
        if ($dcReach.DNS) {
            Write-SMPRSLog -Severity 1 -Message ('DC {0} resolvable via DNS and LDAP-UDP' -f $DomainController)
            Write-Host ('DC {0} resolvable via DNS and LDAP-UDP' -f $DomainController)
            if ($dcReach.LDAP -or $dcReach.LDAPS) {
                Write-SMPRSLog -Severity 1 -Message 'DC accessible via LDAP, will perform forest exploration'
                Write-Host 'DC accessible via LDAP, will perform forest exploration'
                $forestRes = Explore-SMPRSForest -ComputerName $DomainController -Credential $Credential -PassThru
                if ($forestRes.Success) {
                    Write-SMPRSLog -Severity 1 -Message ('Forest explored, will explore domains for forest {0}' -f $forestRes.ForestGUID)
                    Write-Host ('Forest explored, will explore domains for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                    $domRes = Explore-SMPRSDomain -ForestGUID $forestRes.ForestGUID -Credential $Credential
                    if ($domRes) {
                        Write-Host 'Domains explored successfully' -ForegroundColor Cyan
                    } else {
                        Write-Host 'Domain exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                    }
                    Write-Host ('Now exploring domain controllers for forest {0}' -f $forestRes.ForestGUID) -ForegroundColor Cyan
                    if ($null -eq $Credential) {
                        $dcRes = Explore-SMPRSDomainController -ForestGUID $forestRes.ForestGUID
                    } else {
                        $dcRes = Explore-SMPRSDomainController -ForestGUID $forestRes.ForestGUID -Credential $Credential
                    }
                    if ($dcRes) {
                        Write-Host 'Domain Controllers explored successfully' -ForegroundColor Cyan
                    } else {
                        Write-Host 'Domain Controller exploration unsuccessfull, see log for details' -ForegroundColor Yellow
                    }
                } else {
                    Write-SMPRSLog -Severity 2 -Message ('Forest exploration failed: {0}' -f $forestRes.ErrorMessage)
                    Write-Host 'Forest exploration failed' -ForegroundColor Yellow
                }
            } else {
                Write-SMPRSLog -Severity 2 -Message 'DC not reachable via LDAP(S)'
                Write-Host 'DC not reachable via LDAP(S)' -ForegroundColor Yellow
            }
        } else {
            Write-SMPRSLog -Severity 2 -Message 'DC not resolvable via DNS and LDAP-UDP'
            Write-Host 'DC not resolvable via DNS and LDAP-UDP' -ForegroundColor Yellow
        }
        if (-not $SkipReport) {
            Write-SMPRSLog -Severity 1 -Message 'Invoke report creation'
            if (Export-SMPRSReport) {
                Write-SMPRSLog -Severity 1 -Message 'Report created successfully'
            } else {
                Write-SMPRSLog -Severity 2 -Message 'Error creating report, see log for details'
            }
        } else {
            Write-SMPRSLog -Severity 1 -Message 'Report creation will be skipped due to -SkipReport switch'
        }
    }
    default {
        Write-SMPRSLog -Severity 3 -Message ('Execution mode [{0}] is unknown' -f $PSCmdlet.ParameterSetName)
        Write-Warning ('Execution mode [{0}] is unknown' -f $PSCmdlet.ParameterSetName)
    }
}
Write-SMPRSLog -Severity 1 -Message 'Completing script execution...'
$null = Complete-SMPRSExecution
Write-SMPRSLog -Severity 1 -Message 'Sayonara!'

# SIG # Begin signature block
# MIIsrQYJKoZIhvcNAQcCoIIsnjCCLJoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUcX7HwYP1QJwWIVoMwWlCoa+m
# r0yggiXnMIIFbzCCBFegAwIBAgIQSPyTtGBVlI02p8mKidaUFjANBgkqhkiG9w0B
# AQwFADB7MQswCQYDVQQGEwJHQjEbMBkGA1UECAwSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHDAdTYWxmb3JkMRowGAYDVQQKDBFDb21vZG8gQ0EgTGltaXRlZDEh
# MB8GA1UEAwwYQUFBIENlcnRpZmljYXRlIFNlcnZpY2VzMB4XDTIxMDUyNTAwMDAw
# MFoXDTI4MTIzMTIzNTk1OVowVjELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3Rp
# Z28gTGltaXRlZDEtMCsGA1UEAxMkU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5n
# IFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjeeUEiIE
# JHQu/xYjApKKtq42haxH1CORKz7cfeIxoFFvrISR41KKteKW3tCHYySJiv/vEpM7
# fbu2ir29BX8nm2tl06UMabG8STma8W1uquSggyfamg0rUOlLW7O4ZDakfko9qXGr
# YbNzszwLDO/bM1flvjQ345cbXf0fEj2CA3bm+z9m0pQxafptszSswXp43JJQ8mTH
# qi0Eq8Nq6uAvp6fcbtfo/9ohq0C/ue4NnsbZnpnvxt4fqQx2sycgoda6/YDnAdLv
# 64IplXCN/7sVz/7RDzaiLk8ykHRGa0c1E3cFM09jLrgt4b9lpwRrGNhx+swI8m2J
# mRCxrds+LOSqGLDGBwF1Z95t6WNjHjZ/aYm+qkU+blpfj6Fby50whjDoA7NAxg0P
# OM1nqFOI+rgwZfpvx+cdsYN0aT6sxGg7seZnM5q2COCABUhA7vaCZEao9XOwBpXy
# bGWfv1VbHJxXGsd4RnxwqpQbghesh+m2yQ6BHEDWFhcp/FycGCvqRfXvvdVnTyhe
# Be6QTHrnxvTQ/PrNPjJGEyA2igTqt6oHRpwNkzoJZplYXCmjuQymMDg80EY2NXyc
# uu7D1fkKdvp+BRtAypI16dV60bV/AK6pkKrFfwGcELEW/MxuGNxvYv6mUKe4e7id
# FT/+IAx1yCJaE5UZkADpGtXChvHjjuxf9OUCAwEAAaOCARIwggEOMB8GA1UdIwQY
# MBaAFKARCiM+lvEH7OKvKe+CpX/QMKS0MB0GA1UdDgQWBBQy65Ka/zWWSC8oQEJw
# IDaRXBeF5jAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEMGA1Ud
# HwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0FBQUNlcnRpZmlj
# YXRlU2VydmljZXMuY3JsMDQGCCsGAQUFBwEBBCgwJjAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuY29tb2RvY2EuY29tMA0GCSqGSIb3DQEBDAUAA4IBAQASv6Hvi3Sa
# mES4aUa1qyQKDKSKZ7g6gb9Fin1SB6iNH04hhTmja14tIIa/ELiueTtTzbT72ES+
# BtlcY2fUQBaHRIZyKtYyFfUSg8L54V0RQGf2QidyxSPiAjgaTCDi2wH3zUZPJqJ8
# ZsBRNraJAlTH/Fj7bADu/pimLpWhDFMpH2/YGaZPnvesCepdgsaLr4CnvYFIUoQx
# 2jLsFeSmTD1sOXPUC4U5IOCFGmjhp0g4qdE2JXfBjRkWxYhMZn0vY86Y6GnfrDyo
# XZ3JHFuu2PMvdM+4fvbXg50RlmKarkUT2n/cR/vfw1Kf5gZV6Z2M8jpiUbzsJA8p
# 1FiAhORFe1rYMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUgiSEcCjANBgkqhkiG
# 9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYw
# HhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1Ymxp
# YyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIB
# igKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeVF3llMwsRHgBGRmxD
# eEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwdjioXan1hlaGFt4Wk
# 9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAfI3v0VdJiJPFy/7Xw
# iunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q52PN43jc4T9OkoXZ
# 0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdzFf4ed8peNWh1OaZX
# nYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Ccv2jrOW+LPmnOyB+t
# AfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBECELcvzUHf9shoFvr
# n35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2OIypxR//YEb3fkDn
# 3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka/zWWSC8oQEJwIDaR
# XBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQwwDgYDVR0PAQH/BAQD
# AgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwGwYD
# VR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBCMECgPqA8hjpodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RS
# NDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdSb290UjQ2LnA3YzAj
# BggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEM
# BQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+FoetAQLHI1uBy/YXK
# ZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQbDCx6mn7yIawsppWk
# vfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz2Hyxf5XWKZpRvr3d
# MapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aaen1l4c+w3DC+IkwF
# kvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAmi2XlZnuchC4NPSZa
# PATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aYcKCsdbh0czchOm8b
# kinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQpf93at3VDcOK4N7Ew
# oIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03zl8l75jy+hOds9TW
# SenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83axHMViw1+sVpbPxg
# 51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh2Prqooq2bYNMvUoU
# KD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuAh9kcMIIGOzCCBKOg
# AwIBAgIQHdAGLCATbV3zXCkwcR/6uDANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIzMDQxMTAwMDAwMFoXDTI2
# MDcxMDIzNTk1OVowUjELMAkGA1UEBhMCREUxDzANBgNVBAgMBkJlcmxpbjEYMBYG
# A1UECgwPRXZnZW5paiBTbWlybm92MRgwFgYDVQQDDA9FdmdlbmlqIFNtaXJub3Yw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDWU++8HQhIm3mNseP1FGyx
# SibWo0LTbiuxipenEUIPY2TXUjDuGeoaDLSG9btqm8q4gbF2aNvYRyr+x2n6w4qO
# SPck+U3VQbjoaC9g8D5Bj0Ef1qdRBtdPxrW2enqVAHZTVo6UuFFspahqQJwFS6Nu
# 0iwTNwn4/S26RpQH40H7v3TzYkBOSH7/eahw5TceGVj+ua3tQCNAXQunUZGAZ0Su
# a8PY6HIKTurz9YCyq+/fqQ8URdFPBFE52SLrImLAhIBJ0q++nTvOo1cfsIHNg4gj
# lsqWG7iCC1jPP05W/vanzY/WT6Z5rSm4kU+0FWdO0sN+ArYCBvx25WrNI3HoqRDV
# lxi+lXmu9il0I1n25eriI6gi/b1fzN5M78gcCPjIkHhvL2FCV4gYGrbGt9jaZVY/
# Dcu+6zTYzNIQCx1oClheAh+PF1lz15Dn7jb7PwKXlGaTQDkAcDlJL10HrFo86yNO
# szaDaZK9cAlKFa0ZfWiX0jhsn03nzYMl84pFgztqIyi59CoTclIJti7hp4r9cLBn
# xvEIY+38Avh4rUhPOmgJb9jQjt/D+2TS9VbTZXmwJq8jsyhCQmUkt+NnLrVNUq8i
# meJ6Yb79sfzOOsgTRCCcNM3jCyE8X81qS+aB11TwbHCDQ7Z4InJGzbi0NvSrJXv4
# 7CEd9PXu+C13NWP5tho17wIDAQABo4IBiTCCAYUwHwYDVR0jBBgwFoAUDyrLIIco
# uOxvSK4rVKYpqhekzQwwHQYDVR0OBBYEFFlOpEfGcbuN/LvFXLoY6WLG6qZMMA4G
# A1UdDwEB/wQEAwIHgDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMD
# MEoGA1UdIARDMEEwNQYMKwYBBAGyMQECAQMCMCUwIwYIKwYBBQUHAgEWF2h0dHBz
# Oi8vc2VjdGlnby5jb20vQ1BTMAgGBmeBDAEEATBJBgNVHR8EQjBAMD6gPKA6hjho
# dHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NB
# UjM2LmNybDB5BggrBgEFBQcBAQRtMGswRAYIKwYBBQUHMAKGOGh0dHA6Ly9jcnQu
# c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3J0MCMG
# CCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwF
# AAOCAYEACIils2uUHfaHVcfC8fzE0Kwk/cyQ7AjsjcteTH0iOIE+ydu1F4mG1BxS
# 5klnIQd0vf7R8w/74oMDPOzN17Nt+pgjuXScYAkjgkMicwMLy4ke8YAzthq8NZIF
# dlXqNOBorC9CBEN/f7B/nMKW8O98gvYHvLj434ALsJOxJBL/SolO2P8/gmLQevCL
# Pc0LDFlTrH3jMHbManDNXRsdMjpOi9vCfaVGnTsNxshaKTCzbbMGqNxwBnMdPkbv
# BCZrY4e3BTUPJ/8LuR31/3xs746KhUc7W8PIpO6VLofQ/vWtzfpuGCzLIQtWX1JD
# RX7Et140msmZExAPCPXqTeLPVo4vmt7OjmDsR7JHTh3GqX5tBZqoJicd8Qq/NuXi
# R29/Xa4og8vMfFzqPblSX0lvWuPoXWb1yW+k/GKtdD6BYerMLYuqXN+U2bAJNPqk
# IK7IfyX2Jmm7aBNIq+wyaCaQuMZ01yJcVVhoWIel+YRS4iJZlrsPzyexeimhKdRT
# sI72fLNuMIIGgjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0B
# AQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNV
# BAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# LjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkw
# HhcNMjEwMzIyMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1Ymxp
# YyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAiJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTk
# dizICFNeINCSJS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfh
# pdXJ2aHHsPHggGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmU
# CO2GAXsePHi+/JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tN
# K/WABKf+Gnoi4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHf
# lm/FDDrOJ3rWqauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXK
# rop06m7NUNHdlTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6
# aEtE9vtiTMzz/o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1
# R5vj3NgevsAsvxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGO
# JEoqzEIbW3q0b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9l
# o3l7jk27MAe145GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOC
# ARYwggESMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQW
# BBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/
# BAUwAwEB/zATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
# UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkw
# JzAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG
# 9w0BAQwFAAOCAgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39r
# AARaAdAxUeiX1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8
# hjsDLRhsyeIiJsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb
# 1SxVf7nkNtUjPfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa
# 6HAJyz9gvEOcF1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwD
# iGinCwKPyFO7ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1Ni
# urMp4pmAWjR+Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn
# 6G/UYOy8k60mKcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0
# a7SBIkiRzfPfS9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl
# 14suVFBmbzrt5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43E
# T7HHFHeRPRYrMBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8wggan
# MIIEj6ADAgECAhEAkKwIciD9xafEa1zHDfc9BjANBgkqhkiG9w0BAQwFADBXMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVT
# ZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MB4XDTI2MDMyNTAw
# MDAwMFoXDTQxMDMyNDIzNTk1OVowVTELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFt
# cGluZyBDQSBSNDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCu5Eqi
# Aa2CHGL5Zi1bmgPM8NUXwYZJ+BtQqHps43GLTC+sjVLypsBh+8uv+TLkgtVGD//v
# SmA0qrzELf9YRCh2MTAA/aGaQZKGg0BRCmziR3pbCnvgWjtGXBDUyn3j3K2lZAO8
# KxgFtlxwOYEAkL+CCqK4v9zzTl8ZwzDpPMiDIFa5THk8an1ieF5I09cXNrPQw+1E
# R1liThaG0z6FrOpqwxZWmPRZQBw2E32878UB1bL0Zp91vuWZgsMpNNiPCoBj0/1F
# +LE8+NRokfqacFI0F2tftrRB2W7HQClLR9zjxFbWb5be2rceIfNyHUUfKGIvMI2N
# zoxSlxXnFqUG887D8W1Cj8DFok688JKxWvHR/9aQykSbd+9Vutj36ij2sgq/125w
# TpUZ/AgC0ph50bRs7gFrUyaXE9wSsOqMvCCC+sEm7vd/BemSG0TSHNXSmyCba+FC
# zekeWX03TRIcF3Laqd0Rw24OH7jpei4zaGhcI7nfdhBA4c8RScxNY6jeHLHHmSMM
# Tk9Wqn7H4dLhUBP5YEwbgbN4uv1i9ltTnHli8t1xHV0StX9BFgrnmunTX19kUXY1
# H5ORJbRZyZDdvm1oZyteDj0SnMozr+YSmdIleDUTXdfoY7b2taz8s2+QbOxLxcah
# EIYGWzqu6h955tKwcANHcZ4gTmAhT3btuOiQsQIDAQABo4IBbjCCAWowHwYDVR0j
# BBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYDVR0OBBYEFDp0pQxnxkJQwv21
# /Me7KTSC9Hq5MA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMG
# A1UdJQQMMAoGCCsGAQUFBwMIMCMGA1UdIAQcMBowCAYGZ4EMAQQCMA4GDCsGAQQB
# sjEBAgEDCDBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcB
# AQRwMG4wRwYIKwYBBQUHMAKGO2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGln
# b1B1YmxpY1RpbWVTdGFtcGluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAMt5SR2bxngNm
# +N8oc6Gq76Gx1c235fkX7jw8Ho9MAkJGADerHE7dhsBXttqmzgr/7ZZahZSykGRP
# hPY1crj028kB8KzO0dKC2qQBAwtfgqMLKkkX/6bYq2uT33eD6ByAp2/XKD0LcmZh
# 0kKecvSBr6ln9ajX6u1dnx2fA7xEKy1M3qBhfQSUWLtjs2nFt0ELVLptzTlX9ID0
# cL+iOPfdboZ3CelT+JXKVKR2Sge0d4YiFAtPZkfSo8z1Z1x7y/Z9mwMIlBAnyuWX
# s4YsNuxdrYIt/QxE31PDOJ9DesS4Bc7H9OTORlEV/AvfiF/VepKZpira1MzLYuCw
# +uoLZn/pkpvd+CvNTS+mEHjBJNa6WK1j8qXFu+jIq+sG9QILHiyB6p/xpHrkJu8z
# kw393+VqF9eKlTY2VjRxdycZLrVemZ4Yp3wi33b+W58CllH3HqjmowlZ7SOrgmx8
# YwYOkgrHsXOQHyBp6O4FRb8In0+FzjT7ElGie9V7CfhL3IlVFZ4zjuKsZtH1iU3f
# Gu4z/JnOGT6sCb0BbTqe/uhvpFCQBdH5xPGIA/LrbQUXjU2tWJgHhTIqnN/HvHyO
# Hi5tM4zP3nhgh2rJ6Kqq2xsHBeNYs/R18xQ8DeIg+c90Eoaeh0YlN1KU8AyYol3K
# 9M+qY5ez8syd/7ZlrRnoVewgH3P1pcswggbiMIIEyqADAgECAhEA507yVbBQT/rb
# pt/3/IujFTANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIENBIFI0MTAeFw0yNjAzMjUwMDAwMDBaFw0zNzA2MjQyMzU5NTlaMHIx
# CzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5HcmVhdGVyIExvbmRvbjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFNpZ25lciBSMzcwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQCy/8NtS9xQ2UUtBRF32bj7VK3n4m50Uqjk/zTciSziYV40H1LKah0/oEklYG42
# E4VCP3DvsBUB6DmpCkDZ0jCnZBPIEevaH15ZJOQwFWP2ZXr5YjlJpb68Nlbs+ElN
# vKx32/1YHde3qqUSLybjulxPLz6T85+HOIqK7M1Bep8LspyhEP/q6nw5kGxTSrGv
# ufmeH+JF8CnVBcVMFA40FlIYh0cDJVFhhfTfdWgLy/vWuLMQoKkf3s/FvByf16r0
# rtbyHm/iemwxSioJL9zyZDDKUNAbHXl0dhXo2VxUV2NcPXWXuoKsjL+6cfk6Vm2D
# HnxAlFdFsaBDIF1JOkSnC6PeLlBznZn2buF3vIIYJcq6N/zeFRCk4/HXDz7zgRsR
# RMdUB+rhyk5FoZaBjw0nLq3GZ3fClLUx5es5pUAxzNODMBn7JkFYip2BAGBPER5e
# V0ROhk6tGTG+fUiMiV+vgjg1YnP5FvnYWyEtWeQD/B2hp3vz0RvtdkM0p3igyadz
# rfpOBq5ppVk/YsuhTQkP99ivneHAGfi5e7lmxJ+meoBPrRLuzMmb81rzzbESjJHM
# sn5RVtc6Ucs7rcMqQC13PUIO7BbGBETV2ufCmV6lPTp3P7XJOvmnUCRTPbVvMTpx
# P/z+SOHg4/OCBhiqs4FA9+4oQvlkk9w32NGASli9GWrm5wIDAQABo4IBjjCCAYow
# HwYDVR0jBBgwFoAUOnSlDGfGQlDC/bX8x7spNIL0erkwHQYDVR0OBBYEFGEQ6XoS
# r1HEhdTyz6R0D1DNIK/4MA4GA1UdDwEB/wQEAwIGwDAMBgNVHRMBAf8EAjAAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEwCAYGZ4EMAQQCMDUGDCsG
# AQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQ
# UzBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3Rp
# Z29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcmwwegYIKwYBBQUHAQEEbjBsMEUG
# CCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNU
# aW1lU3RhbXBpbmdDQVI0MS5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAD6j2N0azN+hl6k6bKB5/U6VuS
# Os93ZBb3Pczy9VtBIKu4947Z5GwL0aFngIxl+GSuLFrJgPruBCRvKJEJsm7kv+LQ
# 1COVCEG9tZ+IRtr4ocUoa53lgdFaENlS0N4wgkZkbQEPv+x+1lSjYh+T4JeL9mUz
# nT7Erc6Sp5dWLka5sMP/m3GZi6oJPdPcsCKWagH7m2H2xDGIyHJC5PdH9phvi/Km
# hkktiSVTNNqVeV5bWdX2zhRE6UTfz0IcMoCL996lFIydXxOCE4MNDHDM0as4lnTi
# T/KHMccO6l8c9TnUVgmpci9ar1IABZ2U1XUkYjGGSn9MC3EHDP9V39VuBVvZ33/B
# EV/EWSRrf07T7jFplKX+gQr/UOqPGMlE7ZJ72UaUkNJy7bVl3bcLKzdpjIHzLkf/
# 4MVa1V7w8wqCv5W4gOnRGTlud5UMARbRM8BPxR/CXYXoMmIOD8pmTk2axgRL4LG8
# XtuchISdCHRmtacAmLGq5XSYSVTHTXADlO48iDKh3HM2r98LSF6f0sG12d8V9Jn7
# C3wDUieOxuKj4MdWrW+hiJU2kF87v6eH00HgCFFc2V0+CvfOCMn7juzS41jLaINc
# BlKWQ/fKb/uDLfWOW73z1I2lFY7Xj8tQ1XYtK5eREjWItM8jpl1cbQOc88btR+0X
# S2TmboE/141+va2PWzGCBjAwggYsAgEBMGgwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIQHdAGLCATbV3zXCkwcR/6uDAJBgUrDgMCGgUAoHgw
# GAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQx
# FgQUnb3EEm+1gw9E9BGEZll3pL2jo+swDQYJKoZIhvcNAQEBBQAEggIAqHk/YTqi
# nS9Xe9MYfYHLvo//t+N9HHHnUj8g6IiSott8Oa2aIofrq0X6aQeNlvA1QrPudTyK
# cMVsm6i6eYRL8tF3SThQyMILaEANj9AylQ5h2hnzumbZrmXCRuZFY7I3pyzTjtdL
# JHnwqOuynSuRKrkPNlxookMFdZ4RZNmrYWGt7ivTXSI4jq06paa4CD4FFTfaQc+G
# PhS7Q2IxxsCU/s1t6Me+j4Xj2c6nCmk6816pQiuCObX00QQfFEicjMXvPJZqU4+4
# V/b6vnyU8LM3edbv6XBhsmGBP5YYKzIphUJe/hpVg41Bmv1KmJrrG4W5DMNdfNAW
# YdKkKTsEDkU4bggk6SHFmnl8WjeFTPvS1uJeT5/Xa4dL8jk9Ij6U137t7gn4YuxU
# YLgLaiYDHsg+TDydh8MiF17aK3/wpKSTp6XHtBUUZXAr8ILXKL+1Yf4Z5cHEUWEG
# fnQS/son5wq0uTPVhsWRNqvTNxHt2Da4UwsvupqsedIAvpYTHvsVwwdU9Xr1qfBq
# IMnXCXFlKwMN8D+7lLkDKWpROShr9Sbf9he3EZHlVhR2/pc2v/BEs4VmTPGpyXiW
# hMc6Gq33PuJxdGJ0rX8N+V7f6pI48hlz0vryNxiBf1Yds1GogUjcnjZS/jam5u4P
# ECE78NzW6O2z/E6/ObHuMqiNS89qsCFNOU6hggMjMIIDHwYJKoZIhvcNAQkGMYID
# EDCCAwwCAQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0
# MQIRAOdO8lWwUE/626bf9/yLoxUwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0B
# CQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNjA2MjMxNTUwMTRaMD8G
# CSqGSIb3DQEJBDEyBDDA2WiqzZ4kg0IswWKldsfligl6LuqbR3q78Py4yf3rkDP/
# 6ByCKrieT+KOQIbmeT8wDQYJKoZIhvcNAQEBBQAEggIAgSYgddRMdaOjXNH2yXh9
# uixVHQbq/BRuCxyRJGdf+gPaqF98vaYFogWuD9R99nLAhWkdyuxTIPvXq4h6Rc+s
# blPPLN2afoSCga8/bb6purjG+nhgpjo+qw0Rrler4oPJmpagy5cF26u3mIELjjou
# oOuYu4AXAjj0axiNsMqiSMhfMeldrWBTimqF1gpOi0gtcDmrMuLZK7yYy5yZW5so
# /cUOSHIbaehXF+kvQQADeaoT2Ur0/1qssHChar+rxtD1TcS/0HogQ0j6OJ/h5IH5
# fOjZH9tWeECawpPJO6QuqrZNNXrmSaq3TqhZZ2267tdEB+Io4A3bUiqbsUyr4Kx3
# 1xt+VUHuws+YCIfhbzm2c/WcYvwiTloWT6MBDqdDDVvausQ7qD9Bm4Z88SqafagN
# dVNcsK4hsYTVZ/0Cp0ASNiR6bPSXXbhoiHj4hkhP2mLl8VVyg2w/HFlx8264jBFu
# 2e/PeVPSNac/4714SJ3/lYWbI8zlvxnOeNGXS2ZB/RwBgyvq89WjC946MvSofYCo
# J/XS33Axqqn6UtNviJuPn6Yk/+hm03fzCk9coBgT8LR/TdKTcdnBrUt9yCYRvBTw
# oKsBGqXAZOsCxLYSd9gWeXUYeo419SL57aBoFBNVOtvZnNBO3i2QtYFw2ImOwlGi
# sOQFeDKEQUMxmRQ5x2oJjGw=
# SIG # End signature block
