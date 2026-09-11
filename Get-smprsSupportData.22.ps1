<# 
	Run this script as Administrator on the Semperis server or DC from which you need to collect support files for troubleshooting.
	The script creates a folder and .ZIP file under your account's Documents\Semperis folder.  
	If ZIP fails to generate (e.g., the compress-archive cmdlet has a 2 GB size limitation, so it’ll fail if larger than that),
	there will be a folder in that same directory that contains all the data under it.  Just ZIP up that directory manually and upload it.
	You may see errors for things that don’t exist on some systems, that's perfectly normal and expected.

	The instance switch can be used to differentiate between production and test environments where the machine names may be the same.

Version History:
	22 - 18-Jan-23
		- Format the time in the output filename to UTC
		- fixed issue with capturing the IIS logs
		- moved the VSS data to Server\VSS folder
		- Added output list of installed applications
		- Moved the DCPromo logs to Server\ADDS folder
		- Added collection of detatiled Process Data for Semperis processes
		- Added collection of Uninstall data for installed Semperis components
		- Added logging of progress to logfile
		- Changed the GPO collection to only collect data for the current domain.
		- The path to the zip file is returned by the script to enable automation of Support Data collection
	21 - 07-May-22
		- Added collection time to the script info log
		- Added collection of HKLM:\CurrentControlSet\Control\Session Manager\Memory Management -recurse
		- Fixed issue with output of Application log data
		- Fixed issue with creation of Semperis working folder path 
			Will attempt to create a Sempers folder in:
				$env:userprofile\documents,$env:temp,C:\Temp
		- Added -SemperisFolderPath parameter to allow for custom working folder paths to be used.
		- Added collection of information to help with analysis of GPOs with out collecting GPO data.
			Data is logged per domain in the Server\ADDS folder
	20 - 18-Apr-22
		- Fixed header line for services.txt being written to wrong folder
		- Changed WindowsFeature output to Server folder
		- Changed Certificate output to Server folder
		- Added collection of IIS logs
		- Added collection of ADSI registry entries on a Domain Controller
		- Added collection of the ADSI Schema cache file
		- Added collection of HKLM\SOFTWARE\Microsoft\Cryptography - recurse
		- Application and System EventLog data is now exported in UTC to make it easier to match with Semperis logs
		- Added output from diskshadow (list writers detailed) to Server folder
		- Added collection of firewall data using netsh
			Data is logged per domain in the Server\WFP folder
	19 - 03-Jan-2022
		- Added recurse to .NETFramework\v4 to get installed SKUs
		- Added collection of HKLM\SOFTWARE\Microsoft\NTDS -recurse
		- Added collection of HKLM\SOFTWARE\Microsoft\PowerShell -recurse
		- Added collection of HKLM\SYSTEM\CurrentControlSet\Services\NTDS -recurse
		- Added check for HKLM\SOFTWARE\Semperis before exporting the Semperis Key
	18 - 19-Nov-2021
		- Fixed error in getting productVersion from the registry
		- Added collection of netsetup.log when collecting dcpromo logs
		- Collects the last Cookie log on DSP and optionally the last n logs
		- Fixed reporting of non-Semperis files with matching Major.Minor build numbers as patched files
	17 - 16-Nov-2021
		- Added detection of patched files
		- Fixed issue with detection of DCPromo files when run on a server with failed dcPromo operation
		- Fixed issue with running Get-ComputerInfo on systems running PoSh v4
	16 - 20-Sep-2021
		- Added a version identifier to the console and output folder structure
		- Changed Write-Error to Write-Warning for readability
		- Output all registry entries collected to single txt file
		- Added netsetup.log to files collected from Windows\Debug
		- Added LanmanWorkstation and LanmanServer \Parameters to registry collection
		- Added LanmanServer\Shares to registry collections for path to SYSVOL
		- Added NTDS\Parameters to registry collection on DCs for size, location and Schema Version
		- Added ComputerInfo file to Server folder
		- Added collection of patches installed to Server folder
		- Added Collection of Cert:\Local Machine\ My, Root and CA information
		- Added List Providers to VSS collection data
		- Added collection of Microsoft SQL Server registry data
		- Added collection of Microsoft SQL Server installation logs
	15 - 18-Jun-2021 
		- Get Scheduled Tasks no longer reports errors when \Semperis\ folder does not exist 
		- Added collection of Installed Windows Features
		- Added collection of Service details
	14 - 28-Apr-2021 
		- Added collection of Directory Service and DFS Replication logs
		- Added collection of DCPromo logs
		- Added handling for Compress-Archive missing on PoSh v4
	13 - 22-Apr-2021 
		- Fixed issue when there are no Semperis event logs on the systems
	12 - 20-Apr-2021 
		- Changed the Folder Structure to separate Semperis data from Server data
	11 - 16-Apr-2021 
		- Added collection of GPO Settings
	10 - 14-Apr-2021 
		- Added collection of Semperis File version data

	#>
	
	[cmdletbinding()]
	param (
		[string]$Instance = 'Semperis',
		[string[]]$SemperisFolderPath,
		[string]$ProductSuiteVersion,
		[int]$CookieLogs,
		[Alias ('LL')]
		[int]$LogLevel = 2

	)

Function isAdmin {
	# Returns true/false
	([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
 
 }
 
Function Copy-smprsProgramDataFolder ([string]$workFolder ,[string]$smprsProgramDataPath ,[string]$folder ,[string[]]$exclude) {
	$item = get-item ($smprsProgramDataPath + '\' + $folder) -ErrorAction SilentlyContinue
	if ($item) {
		switch ($item.getType().Name) {
			'FileInfo' {
				Copy-Item $item.FullName $workfolder
			}
		
			'DirectoryInfo' {
				Copy-Item $item.FullName -recurse $workFolder -exclude $exclude
			}
			
		}
		
	}
	
}

Function Copy-smprsProgramDataItem ([string]$workFolder ,[string]$smprsProgramDataPath ,[string]$folder ,[string[]]$file) {
	foreach ($filename in $file) {
		$item = get-item ("$smprsProgramDataPath\$folder\$filename") -ErrorAction SilentlyContinue
		if ($item) {
			Copy-Item $item.FullName $workfolder

		}
		
	}
	
}

Function Copy-RegistryToFile {
	param ([string]$Key ,[string]$File ,[switch]$Recurse = $false)
	
	[string[]]$RegKey = $Key.Split('\',2)
	$reg = Get-Item ($RegKey[0] + ':' + $RegKey[1]) -ErrorAction SilentlyContinue
	if ($reg) {
		if ($Recurse) {
			reg query $reg.name /s >> $File
		}
		else {
			reg query $reg.name >> $File
		}
		
	}

}

function Write-smprsLog {
	param (
		[int]$LogType = 1,
#		[int]$LogLevel = 2,
		[string]$Message
	)
	
	if ($LogType -le $LogLevel) {
		Write-Host $Message
	}
	
	if ($LogFile) {
		$Message >> $LogFile
	}

}

	$IsDevBuild = $false
	[string]$scriptVersion = '22'
	If ($IsDevBuild) {$scriptVersion += ' (Dev)'}

	# Create a script info string
	$scriptInfo = ("Name: Get-smprsSupportData`nVersion: v{0}`nCollectionUTCTime: {1}" -f $scriptVersion, ((get-date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')))
	Write-smprsLog 1 $scriptInfo

	if (!(isAdmin)) {
		Write-smprsLog 0 "  Script must be run as Administrator"
		return $null

	}
	
	Write-smprsLog 2 "Generating Semperis Support Data ..."

	$CollectSemperisData = $true
	$CollectServerData = $true
	
	$computer = $env:COMPUTERNAME
	$last30days = (get-date).adddays(-30)
	$today = (get-date).ToUniversalTime().ToString("yyyyMMdd.HHmm")
	$smprsProgramDataFolder = "$env:ProgramData\Semperis"
	# Create a folder for Semperis
	$targetParentFolders = @("$env:UserProfile\Documents","$env:Temp", "C:\Temp")
	$semperisRegistryKey = 'HKLM:\SOFTWARE\Semperis'

	if (!($SemperisFolderPath)) {$SemperisFolderPath = $targetParentFolders}

	[string]$sdir
	foreach ($pFolder in $SemperisFolderPath) {
		if ((Test-Path $pFolder -ErrorAction SilentlyContinue)) {
			$sFolder = "$pFolder\Semperis"
			if (Test-Path -Path $sFolder -ErrorAction SilentlyContinue) {
				$sdir = $sFolder
				break
			}
			else {
				try {
					$folder = New-Item -Path $sFolder -ItemType Directory
					$sdir = $sFolder
					break
				}
				catch {
					Write-smprsLog 0 "Unable to create working folder: $sFolder"
				}
			}		
		}
	}
	
	if(!$sdir) {
		Write-smprsLog 0 ("Unable to create Sempers working folder for data collection in`nAttempted:{0}" -f ('  ' + ($SemperisFolderPath -join '`n  ')))
		Write-smprsLog 0 "Please check folder permissions and try again, or specify temp working folder path on command line using -SemperisFolderPath"
		return
	}

	# Support file name path
	[string]$supportFile = "$sdir\$instance." + $computer.ToLower() + ".$today.zip"

	# Create a working directory for computer data, cleanup previously existing folders
	$wdir = "$sdir\$computer"

	if (Test-Path $wdir -ErrorAction SilentlyContinue) {
		if (Test-Path ($wdir + "_old") -ErrorAction SilentlyContinue) {
			remove-item ($wdir + "_old") -force -recurse -ErrorAction SilentlyContinue
		}
		
		rename-item $wdir ($wdir + "_old") -ErrorAction SilentlyContinue
		
		# At this point the working folder should not exist
		if (Test-Path $wdir -ErrorAction SilentlyContinue) {
			# Its still here, try to delete it
			remove-item $wdir -force -recurse -ErrorAction SilentlyContinue
			
			if (Test-Path $wdir -ErrorAction SilentlyContinue) {
				Write-Warning "Can't remove existing working folder`nRemove $wdir and re-run the script"
				return $null
				
			}

		}
		
	}	

	$folder = New-Item -Path $wdir -ItemType Directory
	$logFile = $wdir + '\ScriptInfo.log'
	Write-smprsLog 2 $scriptInfo
	
	$wdirSemperisProgramdata = $wdir + '\Semperis\ProgramData'
	$wdirSemperisConfiguration = $wdir + '\Semperis\Configuration'
	$wdirSemperisProcessData = $wdir + '\Semperis\ProcessData'
	$wdirSemperisUninstallData = $wdir + '\Semperis\Uninstall'
	$wdirServer = $wdir + '\Server'

	if ($CollectSemperisData) {
		# Collect Semperis files
		$folder = New-Item -Path $wdirSemperisProgramdata -ItemType Directory
		$folder = New-Item -Path $wdirSemperisConfiguration -ItemType Directory
		$folder = New-Item -Path $wdirSemperisProcessData -ItemType Directory
		$folder = New-Item -Path $wdirSemperisUninstallData -ItemType Directory

		Write-smprsLog 2 "  Collecting Semperis Data"
		
		# If not supplied, then see if we can get it from the registry
		if (!$ProductSuiteVersion) {
			# ToDo: This is wrong for upgraded ADFR installation it returns the pre-upgrade versions for 3.5SP2 and earlier
			if (Test-Path $semperisRegistryKey -ErrorAction SilentlyContinue) {
				if ((Get-Item $semperisRegistryKey).GetValueNames() -Contains 'SemperisSuiteVersion') {
					$ProductSuiteVersion = (Get-Item $semperisRegistryKey).GetValue('SemperisSuiteVersion')
				}
			}
			
		}
		if ($ProductSuiteVersion) {
			$productMajorVersion = $ProductSuiteVersion.split('.')[0..1] -join('.')
			$productBuild = $ProductSuiteVersion.split('.')[2..3] -join('.')
		}
		
		if (Test-Path "$env:ProgramFiles\Semperis" -ErrorAction SilentlyContinue) {
			Write-smprsLog 2 "    Installed File Versions"
			$systemPatched = $false

			$files = Get-ChildItem "$env:ProgramFiles\Semperis" -Include "*.dll","*.exe" -Recurse | where {($_.VersionInfo.ProductVersion) -ne $null}
			if ($files) {
				$fileDetailsHeader = "FullName`tProductVersion`tFileVersion"
				Write-Output $fileDetailsHeader > "$wdirSemperisConfiguration\FileVersions.csv"
				foreach ($file in $files) {
					$fileProductVersion = $file.VersionInfo.ProductVersion.ToString()

					$fileDetails = "{0}`t{1}`t{2}" -f $file.FullName,$fileProductVersion,$file.VersionInfo.FileVersion.ToString()
					Write-Output $fileDetails >> "$wdirSemperisConfiguration\FileVersions.csv"
					
					# track potential patching, if the build does not match the product Suite version
					if ($fileProductVersion) {
						$fileProductMajorVersion = $fileProductVersion.Split('.')[0..1] -join('.')

						# only test Semperis built files if we have a productSuite version to test against
						if ($ProductSuiteVersion) {
							if ($productMajorVersion -eq $fileProductMajorVersion) {
								# Only check Semperis Build numbers [2] will be 5 character long
								if ($fileProductVersion.Split('.')[2].Length -eq 5) {
									$fileProductBuild = $fileProductVersion.Split('.')[2..3] -join('.')
									if ($productBuild -ne $fileProductBuild) {
										Write-smprsLog 2 ("Patched file: {0}" -f $fileDetails)

										if (!$systemPatched) {Write-Output $fileDetailsHeader > "$wdirSemperisConfiguration\PatchedFiles.csv"}
										Write-Output $fileDetails >> "$wdirSemperisConfiguration\PatchedFiles.csv"

										$systemPatched = $true
										
									}
									
								}

							}

						}

					}
					

				}
				
			}

		}

		# Collect details from registry
		if (Test-Path $semperisRegistryKey -ErrorAction SilentlyContinue) {
			Write-smprsLog 2 "    Collecting Semperis Registry data"
			$x = reg export HKLM\SOFTWARE\Semperis $wdirSemperisConfiguration\semperis.reg /y
		}
		
		Write-smprsLog 2 "    Collecting Eventlog data"
		# Export any Semperis Logs
		ForEach ($eventLogfile in (Get-ChildItem -Path ("$env:windir\System32\winevt\Logs") -ErrorAction SilentlyContinue | where {$_.name -like "Semperis*.evtx"}).Name) {
				$log = $eventLogfile.replace('.evtx','')
				wevtutil epl ($log.replace('%4','/')) ("$wdirSemperisConfiguration\" + $log.replace('%4Operational','') + ".evtx")

		}

		Write-smprsLog 2 "    ProgramData"
		Write-smprsLog 2 "      Global folders"

		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'ADSN'
		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'General'
		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'Install' -Exclude '*.msi','*.exe'
		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'Logs' -Exclude 'AdCookie.*' 
		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'Tasks'
		copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder 'ForestAgentsInfo.xml'
		
		# on DSP server get the last n cookie logs
		if (Test-Path "$env:ProgramData\Semperis\Logs\Cookie.log" -ErrorAction SilentlyContinue) {
			[string[]]$cookieLogFiles = Cookie.log
			if ($CookieLogs) {foreach ($n in 1..$CookieLogs) {$cookieLogFiles += "Cookie.$n.log"}}
			copy-smprsProgramDataItem $wdirSemperisProgramdata $smprsProgramDataFolder 'Logs' $cookieLogFiles
			
		}

		# If we are running ADFR 3.0 or later get the Forest folders
		$MultiForest = Get-Item HKLM:\SOFTWARE\Semperis\MultiForest -ErrorAction SilentlyContinue
		if ($MultiForest) {
			foreach ($SubKey in $multiForest.GetSubKeyNames()) {
				if ($subKey -eq 'Upgrade') {continue}
				$Forest = Get-Item ("HKLM:\SOFTWARE\Semperis\MultiForest\$SubKey") -ErrorAction SilentlyContinue
				#Is it a real forest subKey then collect the data
				if ($Forest) {
					$ForestId = $Forest.GetValue('ForestId')
					$ForestDnsName =  $Forest.GetValue('ForestDnsName')
					$ForestFolderName = $ForestDnsName + '.' + $ForestId
					
					Write-smprsLog 2 "      Forest $ForestDnsName"
					copy-smprsProgramDataFolder $wdirSemperisProgramdata $smprsProgramDataFolder $ForestFolderName

				}
				
			}

		}

		# Collect Semperis Scheduled Tasks details from Task Scheduler
		Write-smprsLog 2 "    Collecting Semperis scheduled Tasks"
		$smprsScheduledTasks = Get-ScheduledTask -taskpath "\semperis\*" -ErrorAction SilentlyContinue
		if ($smprsScheduledTasks.count -gt 0) {$smprsScheduledTasks | Export-ScheduledTask >> $wdirSemperisConfiguration\tasks.xml}
		
		# Collect Semperis detailed process data
		Write-smprsLog 2 "    Collecting Semperis Process Information"
		Get-Process -Name *Semperis* | % { $_ | Select * | ConvertTo-Json -Depth 10 | Out-File ("{0}\{1}.json" -f $wdirSemperisProcessData, $_.Name)}
		
		# Collect Semperis Uninstall settings
		Write-smprsLog 2 "    Collecting Semperis Uninstall Settings"
		$smprsUninstall = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' | where {$_.getValue('Publisher') -eq 'Semperis'}
		foreach ($item in $smprsUninstall) {
			$itemNameParts = $item.Name.Split('\')
			$itemName = "{0}.{1}.json" -f $item.GetValue('DisplayName'),$itemNameParts[($itemNameParts.Count - 1)]
			$itemContents = @{}
			foreach ($itemProperty in $item.GetValuenames()) {
				$itemContents += @{$itemProperty = $item.GetValue($itemProperty)}
			}
			ConvertTo-Json $itemContents -Depth 10 | Out-File ("{0}\{1}" -f $wdirSemperisUninstallData, $itemName)

		}
		
	}

	if ($CollectServerData) {
		# Collect Server Data
		Write-smprsLog 2 "  Collecting Server Information"
		$folder = New-Item -Path $wdirServer -ItemType Directory
		
		# Get-ComputerInfo is only supported in PoSh v5 and later
		if ($PSVersionTable.PSVersion.Major -ge 5) {
			$pp = $ProgressPreference
			$ProgressPreference = "SilentlyContinue"
			$ci = Get-ComputerInfo
			$ci > "$wdirServer\ComputerInfo.txt"
			$ci.OsHotFixes | Format-Table > "$wdirServer\ComputerInfo.Hotfixes.txt"
			$ProgressPreference = $pp
		}

		if (Test-Path "$env:windir\System32\gpresult.exe") {
			Write-smprsLog 2 "    Collecting Applied Policies"
			start-process ("$env:windir\System32\gpresult.exe") -ArgumentList "/x $wdirServer\GPResult.xml /scope computer /f" -WindowStyle Minimized -wait
			start-process ("$env:windir\System32\gpresult.exe") -ArgumentList "/h $wdirServer\GPResult.html /scope computer /f" -WindowStyle Minimized -wait

		}

		# Collect details from registry
		Write-smprsLog 2 "    Collecting Registry data"
#		$x = reg export HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL $wdirServer\schannel.reg /y
#		$x = reg export HKLM\SYSTEM\CurrentControlSet\Control\Cryptography $wdirServer\cryptography.reg /y
#		$x = reg export HKLM\SYSTEM\CurrentControlSet\Services\VSS $wdirServer\vss.reg /y

		copy-RegistryToFile "HKCU\SOFTWARE\Microsoft\Ads" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\.NETFramework\v2.0.50727" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\.NETFramework\v3.0" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\.NETFramework\v4.0.30319" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Ads" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Cryptography" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\NTDS" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\PowerShell" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Cryptography" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\LSA" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\LSA\FipsAlgorithmPolicy" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\LSA\SSO" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Services\adsi" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Services\LanmanServer\Parameters" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Services\LanmanServer\Shares" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Services\LanmanWorkstation\Parameters" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Services\NTDS\Parameters" $wdirServer\regentries.txt -Recurse
		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Services\NTDS" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SYSTEM\CurrentControlSet\Services\VSS" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v2.0.50727" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v3.0" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319" $wdirServer\regentries.txt -Recurse

		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" $wdirServer\regentries.txt
		copy-RegistryToFile "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\System" $wdirServer\regentries.txt

		# Collect details from event logs
		Write-smprsLog 2 "    Collecting Eventlog data"
<#		
		foreach ($eventLog in "Application","System") {
			$events = get-eventlog -logname $eventLog -after $last30days 
			$events | select-object @{N='TimeGeneratedUTC';E={$_.timegenerated.ToUniversalTime()}},source,eventid,message | export-csv $wdirServer\EventLog.$eventLog.csv -notype
			
			# export specific Application log entries
			if ($eventLog -eq "Application") {
				$AgentLog = $events | where {$_.source -like "ADSMAgent"} | select-object @{N='TimeGeneratedUTC';E={$_.timegenerated.ToUniversalTime()}},source,eventid,message 
				if ($AgentLog) {
					$AgentLog | export-csv $wdirServer\ADSMAgent.CRC_Error.csv -notype
					
				}
				
			}

		}
#>

		foreach ($eventLog in "Application","System","Microsoft-Windows-TaskScheduler%4Operational","Microsoft-Windows-Backup%4Operational","Directory Service","DFS Replication") {
			$eventLogPath = "$env:windir\System32\winevt\Logs\$eventLog.evtx"
			# Rem only attempt to get the event log if it exists
			if (Test-Path -Path $eventLogPath -ErrorAction SilentlyContinue) {
				wevtutil epl $eventLogPath "$wdirServer\$eventLog.evtx" /lf:true

			}
			
		}

		# Collect VSS details
		Write-smprsLog 2 "    Collecting VSS information"
		$wdirServerFolder = "$wdirServer\VSS"
		if (!(Test-Path -Path "$wdirServerFolder" -ErrorAction SilentlyContinue)) {
			$f = New-Item -Path "$wdirServerFolder" -Type Directory
		}
		foreach ($vsscmd in 'Providers','Writers','Shadows','ShadowStorage') {
			("List $vsscmd ------") >> $wdirServerFolder\vss_info.txt
			vssadmin list $vsscmd >> $wdirServerFolder\vss_info.txt
			("-------------------") >> $wdirServerFolder\vss_info.txt
			("") >> $wdirServerFolder\vss_info.txt

			# Collect disk writer details.
			# Note: diskshadow does not like unicode input files, so jump through hoops to generate.
			('# Capture Writer details','list writers detailed','exit') | Out-File -Filepath $wdirServerFolder\DiskShadow.dsh -Encoding ascii
			$result = diskshadow /L "$wdirServerFolder\DiskShadow.WriterDetails.txt" /S "$wdirServerFolder\DiskShadow.dsh"

			
		}	

		# Collect Debug logs
		if (Test-Path "$env:windir\debug\DCPromo*.log" -ErrorAction SilentlyContinue) {
			Write-smprsLog 2 "    Collecting DCPromo Logs"

			$adDataPath = "$wdirserver\ADDS"
			if (!(Test-Path -Path $adDataPath -ErrorAction SilentlyContinue)) {
				$folder = New-Item -Path $adDataPath -ItemType Directory
			}

			foreach ($f in (Get-ChildItem "$env:windir\debug" | where {($_.Name -like "DCPromo*.log") -or ($_.Name -like "netsetup.log")})) {
				Copy-Item $f.FullName $adDataPath
				
			}
			
		}
		
		# Collect IIS logs
		if (Test-Path "C:\Inetpub\Logs\Logfiles\W3SVC2\*.log" -ErrorAction SilentlyContinue) {
			Write-smprsLog 2 "    Collecting IIS Logs"
			$wdirServerFolder = "$wdirServer\VSS"
			if (!(Test-Path -Path "$wdirServerFolder" -ErrorAction SilentlyContinue)) {
				$f = New-Item -Path "$wdirServerFolder" -Type Directory
			}
			foreach ($f in (Get-ChildItem "C:\Inetpub\Logs\Logfiles\W3SVC2")) {
				Copy-Item $f.FullName "$wdirServerFolder" -force
				
			}
			
		}
		
		# Collect details of Services installed on Server
		Write-smprsLog 2 "    Collecting Service data"
		$services = Get-Service
		if ($services) {
			Write-Output ("ServiceName`tDisplayName`tStartType`tStatus") > "$wdirServer\Services.csv"
			foreach ($service in $services) {
				Write-Output ($service.ServiceName + "`t" + $service.DisplayName + "`t" + $service.StartType+ "`t" + $service.Status) >> "$wdirServer\Services.csv"

			}
			
		}

		# Collect details of installed Windows Features
		Write-smprsLog 2 "    Collecting installed Windows Features"
		$vp = $VerbosePreference
		$VerbosePreference = "SilentlyContinue"
		Get-WindowsFeature -ErrorAction SilentlyContinue > "$wdirServer\WindowsFeatures.txt"
		$VerbosePreference = $vp

		# Collect local machine certs
		Write-smprsLog 2 "    Collecting Installed Certificate information"
		Get-ChildItem Cert:\LocalMachine\My | Select-Object * > "$wdirServer\Certs.LocalMachine.My.txt"
		Get-ChildItem Cert:\LocalMachine\Root | Select-Object * > "$wdirServer\Certs.LocalMachine.Root.txt"
		Get-ChildItem Cert:\LocalMachine\CA | Select-Object * > "$wdirServer\Certs.LocalMachine.CA.txt"
		
		# Collect SQL Server Data if it exists
		if (Test-Path "hklm:\SOFTWARE\Microsoft\Microsoft SQL Server" -ErrorAction SilentlyContinue) {
			Write-smprsLog 2 "    Collecting SQL Server Install Logs"
			foreach ($sqlSetup in (Get-Item "hklm:\SOFTWARE\Microsoft\Microsoft SQL Server\*\Bootstrap")) {
				$sqlBootStrapDirLog = $sqlSetup.GetValue("BootstrapDir") + "\Log"
			#	mkdir "$wdirServer\SQL Logs"
				Copy-Item $sqlBootStrapDirLog "$wdirServer\SQL Logs" -recurse -force
				
			}
			
		}
		
		# Collect Firewall data.
		# netsh only outputs in the current directory, so create one to hold the data.
		$fwDataPath = "$wdirserver\WFP"
		if (!(Test-Path -Path $fwDataPath -ErrorAction SilentlyContinue)) {
			$folder = New-Item -Path $fwDataPath -ItemType Directory
		}
		
		cd $fwDataPath
		
		$r = @()
		foreach ($netshcmd in 'filters','state','sysports') {$r += (netsh wfp show ($netshcmd)) ; $r += "`n"}
		$r > netsh.log
		
		cd $sdir

		# Check we are a domain member, and not an ADFR server which would be in a different domain to the forest we are protecting
		if (($ci.CsPartOfDomain) -and (!(Get-Item "HKLM:\SOFTWARE\Semperis\MultiForest" -ErrorAction SilentlyContinue))) {
			if ((Get-WindowsFeature RSAT-AD-PowerShell).Installed) {
				$adDataPath = "$wdirserver\ADDS"
				if (!(Test-Path -Path $adDataPath -ErrorAction SilentlyContinue)) {
					$folder = New-Item -Path $adDataPath -ItemType Directory
				}
				
				Write-smprsLog 2 "    Collecting Policy ExtensionNames"

				Get-ADObject -LDAPFilter '(objectClass=groupPolicyContainer)' -Server ($ci.CsDomain) -SearchScope subTree -Properties name,displayName,objectGUID,gPCMachineExtensionNames,gPCUserExtensionNames,whenCreated,whenChanged | Select name,displayName,objectGUID,gPCMachineExtensionNames,gPCUserExtensionNames,whenCreated,whenChanged | ConvertTo-Json > ("$adDataPath\GPO_Info_{0}.json" -f $ci.CsDomain)

			}
			
		}
	
		# Collect VSS details
		Write-smprsLog 2 "    Collecting Installed Applications"
		$installedApplications = Get-WmiObject -Class Win32_Product | Select Name,Version,InstallState,Description,InstallDate,Language,Vendor
		$installedApplications | fl > "$wdirServer\Installed Applications.txt"
		
	}

	cd $sdir


	# ZIP it all up
	if ($PSVersionTable.PSVersion.Major -ge 5) {
		Write-smprsLog 2 "  Creating Support file:`n    $supportFile"
		try {
			Compress-Archive -Path $wdir -DestinationPath $supportFile -force
			
			Write-smprsLog 2 "Completed"
			Write-smprsLog 2 ""

			return $supportFile

		}
		catch {
			Write-smprsLog 0 ""
			Write-smprsLog 0 "The PowerShell command Compress-Archive failed to compress the archive"
			Write-smprsLog 0 "Please compress the working folder using another mechanism"
			Write-smprsLog 0 "Folder: $wdir"
			Write-smprsLog 0 ""
			
			return $null
			
		}

	}
	else {
		Write-smprsLog 0 ""
		Write-smprsLog 0 "The PowerShell command Compress-Archive is not available on $env:computername"
		Write-smprsLog 0 "Please compress the working folder using another mechanism"
		Write-smprsLog 0 "Folder: $wdir"
		Write-smprsLog 0 ""
		
		return $null
		
	}
