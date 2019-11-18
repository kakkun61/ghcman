Set-StrictMode -Version Latest

# Constant

Set-Variable systemGlobalDataPath -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable userGlobalDataPath -Option Constant -Value "$Env:APPDATA\ghcups"
Set-Variable versionPattern -Option Constant -Value '[0-9]+(\.[0-9]+)*'
Set-Variable ghcPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.' + $versionPattern + '\\tools\\ghc-' + $versionPattern + '\\bin')
Set-Variable cabalPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal\.' + $versionPattern + '\\tools\\cabal-' + $versionPattern)
Set-Variable localConfigName -Option Constant -Value 'ghcups.yaml'
Set-Variable globalConfigName -Option Constant -Value 'config.yaml'

# Common

function Find-LocalConfigPath {
    param (
        [Parameter(Mandatory)][String] $Dir
    )

    While ($true) {
        if ($Dir -eq $Env:USERPROFILE -or [String]::IsNullOrEmpty($Dir)) {
            ''
            return
        }
        $test = Join-Path $Dir $localConfigName
        if (Test-Path $test) {
            $test
            return
        }
        $Dir = Split-Path $Dir -Parent
    }
}

function Get-Config {
    param (
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][String] $Path
    )

    if ([String]::IsNullOrEmpty($Path)) {
        $null
        return
    }
    if (-not (Test-Path $Path)) {
        $null
        return
    }
    ConvertFrom-Yaml (Get-Content $Path -Raw)
}

function Get-HashtaleItem {
    param (
        [Parameter(Mandatory)][Object[]] $Name,
        [Hashtable] $Hashtable
    )

    $item = $Hashtable
    foreach ($n in $Name) {
        if ($null -eq $item) {
            $null
            return
        }
        $item = $item[$n]
    }
    $item
}

function Copy-HashtableDeeply {
    param (
        [Hashtable] $Hashtable
    )

    $result = @{}
    foreach ($key in $Hashtable.Keys) {
        $item = $Hashtable[$key]
        if ($item -is [Hashtable]) {
            $result.Add($key, (Copy-HashtableDeeply $item))
            continue
        }
        if ($null -eq $item) {
            $result.Add($key, $null)
            continue
        }
        $result.Add($key, $item.Clone())
    }
    $result
}

function Join-Hashtables {
    param (
        [Hashtable[]] $Hashtables,
        [Switch] $Breaking = $false
    )

    if ($null -eq $Hashtables -or @() -eq $Hashtables) {
        $null
        return
    }

    $result = $null
    foreach ($h in $Hashtables) {
        if ($null -eq $h) {
            continue
        }
        if ($null -eq $result) {
            if ($Breaking) {
                $result = $h
            }
            else {
                $result = Copy-HashtableDeeply $h
            }
            continue
        }
        foreach ($key in $h.Keys) {
            $value = $h[$key]
            if ($result.ContainsKey($key) -and $result -is [Hashtable] -and $value -is [Hashtable]) {
                [void] (Join-Hashtables $result[$key], $value -Breaking)
            }
            else {
                $result.Add($key, $h[$key])
            }
        }
    }
    $result
}

function All {
    param ([Parameter(ValueFromPipeline)][Boolean[]] $ps)
    begin { $acc = $true }
    process { foreach ($p in $ps) { $acc = $acc -and $p } }
    end { $acc }
}

function Set-PathEnv {
    param (
        [Parameter(Mandatory)][String[]] $patterns,
        [Parameter(Mandatory)][AllowEmptyString()][String] $path
    )

    if (-not [String]::IsNullOrEmpty($path) -and -not (Test-Path $path)) {
        Write-Warning "`"$path`" is not an existing path"
    }
    $restPaths = $Env:Path -split ';' | Where-Object { $v = $_; $patterns | ForEach-Object { $v -notmatch $_ } | All }
    $newPaths = ,$path + $restPaths | Where-Object { -not [String]::IsNullOrEmpty($_) }
    Set-Item Env:\Path -Value ($newPaths -join ';')
}

function Get-InstalledChocoItems {
    param (
        [Parameter(Mandatory)][String] $App
    )

    $path = "$Env:ChocolateyInstall\lib\$App."
    Get-Item "$path*" | ForEach-Object { ([String]$_).Remove(0, $path.Length) }
}

# .SYNOPSIS
#   Creats the ghcups.yaml with the default contents.
function Write-GhcupsConfigTemplate {
    param (
        [String] $Path = '.'
    )

    "# The key is the name you want, the value is the path of directory which contains ghc, ghci, etc.`nghc: {}`n`n# The same with ghc for cabal.`ncabal: {}" | Out-File (Join-Path $Path $localConfigName) -NoClobber
}

function Get-ExePathsFromConfigs {
    param (
        [Hashtable[]] $Configs,
        [String] $name
    )

    $patterns = `
      $Configs | `
      ForEach-Object { Get-HashtaleItem $name $_ } | `
      Where-Object { $null -ne $_ } | `
      ForEach-Object -begin { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseDeclaredVarsMoreThanAssignments', 'paths')] $paths = @() } -process { $paths += $_.Values } -end { $paths } | `
      Where-Object { -not [String]::IsNullOrEmpty($_) }
    if ($null -eq $patterns) {
        @()
    }
    $patterns
}

function Start-Choco {
    try {
        choco @Args
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $choice = Read-Host '"choco" is not found. Will you install Chocoratey? [y/N]'
        if ('y' -ne $choice) {
            return
        }
        Install-Choco
    }
}

# .SYNOPSIS
#   Install the Chocolatey.
function Install-Choco {
    if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
       # with administrative privileges
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        return
    }
    Write-Host 'Installing Chocolatey...'
    $logFile = "$Env:TEMP\ghcups.log"
    Start-process `
        -FilePath powershell `
        -ArgumentList "-Command & { Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')) | Tee-Object $logFile }" `
        -Verb RunAs `
        -Wait
    Write-Host "Log file is at `"$logFile`""
    Write-Host 'Update Env:\Path or restart the PowerShell'
}

# GHC

function Get-ChocoGhc {
    param (
        [Parameter(Mandatory)][String] $Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin"
}

# .SYNOPSIS
#   Sets the version or variant of GHC to the Path environment variable of the current session.
function Set-Ghc {
    param (
        [Parameter(Mandatory)][String] $Ghc
    )

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    [Hashtable] $cs = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $ghcDir = Get-HashtaleItem -Name 'ghc', $Ghc -Hashtable $cs
    if ([String]::IsNullOrEmpty($ghcDir)) {
        if ($Ghc -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No sutch GHC: $Ghc"
            return
        }
        $ghcDir = Get-ChocoGhc $Ghc
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'ghc' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $ghcPathPattern
    Set-PathEnv $patterns $ghcDir
}

# .SYNOPSIS
#   Removes all GHC values from the Path environment variable of the current session.
function Clear-Ghc {
    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'ghc' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $ghcPathPattern
    Set-PathEnv $patterns $null
}

# .SYNOPSIS
#   Installs the specified GHC with the Chocolatey.
function Install-Ghc {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param (
        [Parameter(Mandatory)][String] $Ghc,
        [Switch] $Set = $false
    )

    Start-Choco install ghc --version $Ghc --side-by-side

    if ($Set) {
        Set-Ghc -Ghc $Ghc
    }
}

# .SYNOPSIS
#   Uninstalls the specified GHC with the Chocolatey.
function Uninstall-Ghc {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param (
        [Parameter(Mandatory)][String] $Ghc
    )

    Start-Choco uninstall ghc --version $Ghc
}

# .SYNOPSIS
#   Shows the GHCs which is specified by the ghcups.yaml and config.yaml, which is installed by the Chocolatey and which is hosted on the Chocolatey repository.
function Show-Ghc {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param ()

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfigDir = $null
    if (-not [String]::IsNullOrEmpty($localConfigPath)) {
        $localConfigDir = Split-Path $localConfigPath -Parent
    }
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $span = $false
    $ghcs = Get-HashtaleItem 'ghc' $config
    if ($null -ne $ghcs -and 0 -lt $ghcs.Count) {
        Write-Output "$localConfigName ($(($localConfigDir, $userGlobalDataPath, $systemGlobalDataPath | Where-Object { $null -ne $_ }) -Join ', '))"
        foreach ($k in $config.ghc.Keys) {
            Write-Output "    ${k}:    $($config.ghc[$k])"
        }
        $span = $true
    }
    $chocoGhcs = Get-InstalledChocoItems 'ghc'
    if ($null -ne $chocoGhcs) {
        if ($span) {
            Write-Output ''
        }
        Write-Output 'Chocolatey (Installed)'
        foreach ($g in $chocoGhcs) {
            Write-Output "    ${g}:    $Env:ChocolateyInstall\lib\ghc.$g\tools\ghc-$g\bin"
        }
        $span = $true
    }
    if ($span) {
        Write-Output ''
    }
    Write-Output 'Chocolatey (Remote)'
    Start-Choco list ghc --by-id-only --all-versions | ForEach-Object { "    $_" }
}

# Cabal

function Get-ChocoCabal {
    param (
        [Parameter(Mandatory)][String] $Cabal
    )

    "$Env:ChocolateyInstall\lib\cabal.$Cabal\tools\cabal-$Cabal"
}

# .SYNOPSIS
#   Sets the version or variant of Cabal to the Path environment variable of the current session.
function Set-Cabal {
    param (
        [Parameter(Mandatory)][String] $Cabal
    )

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $cabalDir = Get-HashtaleItem -Name 'cabal', $Cabal -Hashtable (Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig)
    if ([String]::IsNullOrEmpty($cabalDir)) {
        if ($Cabal -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No sutch Cabal: $Cabal"
            return
        }
        $cabalDir = Get-ChocoCabal $Cabal
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'cabal' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $cabalPathPattern
    Set-PathEnv $patterns $cabalDir
}

# .SYNOPSIS
#   Removes all Cabal values from the Path environment variable of the current session.
function Clear-Cabal {
    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'cabal' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $cabalPathPattern
    Set-PathEnv $patterns $null
}

# .SYNOPSIS
#   Installs the specified Cabal with the Chocolatey.
function Install-Cabal {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param (
        [Parameter(Mandatory)][String] $Cabal,
        [Switch] $Set = $false
    )

    Start-Choco install cabal --version $Cabal --side-by-side

    if ($Set) {
        Set-Cabal -Cabal $Cabal -Method $Method
    }
}

# .SYNOPSIS
#   Uninstalls the specified Cabal with the Chocolatey.
function Uninstall-Cabal {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param (
        [Parameter(Mandatory)][String] $Cabal
    )

    Start-Choco uninstall cabal --version $Cabal
}

# .SYNOPSIS
#   Shows the Cabals which is specified by the ghcups.yaml and config.yaml, which is installed by the Chocolatey and which is hosted on the Chocolatey repository.
function Show-Cabal {
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'Start-Choco')]
    param ()

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfigDir = $null
    if (-not [String]::IsNullOrEmpty($localConfigPath)) {
        $localConfigDir = Split-Path $localConfigPath -Parent
    }
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $span = $false
    $cabals = Get-HashtaleItem 'cabal' $config
    if ($null -ne $cabals -and 0 -lt $cabals.Count) {
        Write-Output "$localConfigName ($(($localConfigDir, $userGlobalDataPath, $systemGlobalDataPath | Where-Object { $null -ne $_ }) -Join ', '))"
        foreach ($k in $config.cabal.Keys) {
            Write-Output "    ${k}:    $($config.cabal[$k])"
        }
        $span = $true
    }
    $chocoCabals = Get-InstalledChocoItems 'cabal'
    if ($null -ne $chocoCabals) {
        if ($span) {
            Write-Output ''
        }
        Write-Output 'Chocolatey (Installed)'
        foreach ($g in $chocoCabals) {
            Write-Output "    ${g}:    $Env:ChocolateyInstall\lib\cabal.$g\tools\cabal-$g\bin"
        }
        $span = $true
    }
    if ($span) {
        Write-Output ''
    }
    Write-Output 'Chocolatey (Remote)'
    Start-Choco list cabal --by-id-only --all-versions | ForEach-Object { "    $_" }
}

# Export

Export-ModuleMember `
    -Function `
        'Set-Ghc', `
        'Clear-Ghc', `
        'Install-Ghc', `
        'Uninstall-Ghc', `
        'Show-Ghc', `
        'Set-Cabal', `
        'Clear-Cabal', `
        'Install-Cabal', `
        'Uninstall-Cabal', `
        'Show-Cabal', `
        'Write-GhcupsConfigTemplate', `
        'Install-Choco'
