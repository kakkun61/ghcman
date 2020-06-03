Set-StrictMode -Version Latest

# Constant

Set-Variable systemGlobalDataPath -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable userGlobalDataPath -Option Constant -Value "$Env:APPDATA\ghcups"
Set-Variable versionPattern -Option Constant -Value '[0-9]+(\.[0-9]+)*'
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

function Get-InstalledItems {
    param (
        [Parameter(Mandatory)][String] $App
    )

    $path = "$(Get-GhcupsInstall)\$App-"
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

function Get-GhcupsInstall {
    param ()
    if ([String]::IsNullOrEmpty($Env:GhcupsInstall)) {
        $userGlobalDataPath
        return
    }
    $Env:GhcupsInstall
}

# only x86_64, i386 supported
function Get-Architecture {
    if ([Environment]::Is64BitOperatingSystem) {
        'x86_64'
        return
    }
    'i386'
    return
}

# GHC

function Get-GhcupsGhc {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    "$(Get-GhcupsInstall)\ghc-$Version\bin"
}

function Get-GhcPathPattern {
    param ()
    [Regex]::Escape((Get-GhcupsInstall)) + '\\ghc-' + $versionPattern + '\\bin'
}

# .SYNOPSIS
#   Sets the version or variant of GHC to the Path environment variable of the current session.
function Set-Ghc {
    param (
        [Parameter(Mandatory)][String] $Name
    )

    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    [Hashtable] $cs = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $ghcDir = Get-HashtaleItem -Name 'ghc', $Name -Hashtable $cs
    if ([String]::IsNullOrEmpty($ghcDir)) {
        if ($Name -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No sutch GHC: $Name"
            return
        }
        $ghcDir = Get-GhcupsGhc $Name
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'ghc' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += Get-GhcPathPattern
    Set-PathEnv $patterns $ghcDir
}

# .SYNOPSIS
#   Removes all GHC values from the Path environment variable of the current session.
function Clear-Ghc {
    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'ghc' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += Get-GhcPathPattern
    Set-PathEnv $patterns $null
}

# .SYNOPSIS
#   Installs the specified GHC.
function Install-Ghc {
    param (
        [Parameter(Mandatory)][String] $Version,
        [Switch] $Set = $false,
        [Switch] $Force = $false
    )

    $ErrorActionPreference = 'Stop'

    if (Test-Path "$(Get-GhcupsInstall)\ghc-$Version") {
        if ($Force) {
            Uninstall-Ghc $Version
        }
        else {
            $choice = Read-Host "GHC $Version looks already installed. Do you want to reinstall? [y/N]"
            if ('y' -ne $choice) {
                return
            }
            Uninstall-Ghc $Version
        }
    }
    $tempDir = [System.IO.Path]::GetTempPath()
    $arch = Get-Architecture
    $fileName = "ghc-$Version-$arch-unknown-mingw32"
    if (Test-Path "$tempDir$fileName.tar.xz") {
        Write-Host "A downloaded archive file is found: $tempDir$fileName.tar.xz"
        $choice = Read-Host "Do you want to use this? [y/N]"
        if ('y' -ne $choice) {
            Remove-Item "$tempDir$fileName.tar.xz"
            (New-Object System.Net.WebClient).DownloadFile("https://downloads.haskell.org/~ghc/$Version/$fileName.tar.xz", "$tempDir$fileName.tar.xz")
        }
    }
    else {
        (New-Object System.Net.WebClient).DownloadFile("https://downloads.haskell.org/~ghc/$Version/$fileName.tar.xz", "$tempDir$fileName.tar.xz")
    }
    if (Test-Path "$tempDir$fileName.tar") {
        Remove-Item "$tempDir$fileName.tar"
    }
    7z x "-o$tempDir$fileName.tar" "$tempDir$fileName.tar.xz"
    7z x "-o$(Get-GhcupsInstall)" "$tempDir$fileName.tar"

    if ($Set) {
        Set-Ghc -Ghc $Version
    }
}

# .SYNOPSIS
#   Uninstalls the specified GHC.
function Uninstall-Ghc {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    $ErrorActionPreference = 'Stop'

    Remove-Item -Recurse -Force "$(Get-GhcupsInstall)\ghc-$Version"
}

# .SYNOPSIS
#   Shows the GHCs which is specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not yet installed.
function Show-Ghc {
    $ErrorActionPreference = 'Stop'

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfigDir = $null
    if (-not [String]::IsNullOrEmpty($localConfigPath)) {
        $localConfigDir = Split-Path $localConfigPath -Parent
    }
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $names = Get-HashtaleItem 'ghc' $config
    if ($null -eq $names -or 0 -eq $names.Count) {
        Write-Output 'No configurations found'
    }
    else {
        Write-Output "$localConfigName ($(($localConfigDir, $userGlobalDataPath, $systemGlobalDataPath | Where-Object { $null -ne $_ }) -Join ', '))"
        foreach ($k in $config.ghc.Keys) {
            Write-Output "    ${k}:    $($config.ghc[$k])"
        }
    }
    Write-Output ''
    Write-Output 'Installed'
    $versions = Get-InstalledItems 'ghc'
    if ($null -eq $versions) {
        Write-Output '    None'
    }
    else {
        foreach ($v in $versions) {
            Write-Output "    ${v}:$(' ' * (10 - $v.Length))$(Get-GhcupsInstall)\ghc-$v\bin"
        }
    }
    Write-Output ''
    Write-Output 'Supported (You can specify unsupported versions too)'
    $arch = Get-Architecture
    $versions = Get-HashtaleItem 'ghc', $arch (Get-Config "$($MyInvocation.MyCommand.Module.ModuleBase)\version.yaml")
    foreach ($v in $versions) {
        Write-Output "    ${v}"
    }
}

# Cabal

function Get-GhcupsCabal {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    "$(Get-GhcupsInstall)\cabal-$Version"
}

function Get-CabalPathPattern {
    [Regex]::Escape((Get-GhcupsInstall)) + '\\cabal-' + $versionPattern
}

# .SYNOPSIS
#   Sets the version or variant of Cabal to the Path environment variable of the current session.
function Set-Cabal {
    param (
        [Parameter(Mandatory)][String] $Name
    )

    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $cabalDir = Get-HashtaleItem -Name 'cabal', $Name -Hashtable (Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig)
    if ([String]::IsNullOrEmpty($cabalDir)) {
        if ($Name -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No sutch Cabal: $Name"
            return
        }
        $cabalDir = Get-GhcupsCabal $Name
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'cabal' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += Get-CabalPathPattern
    Set-PathEnv $patterns $cabalDir
}

# .SYNOPSIS
#   Removes all Cabal values from the Path environment variable of the current session.
function Clear-Cabal {
    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'cabal' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += Get-CabalPathPattern
    Set-PathEnv $patterns $null
}

# .SYNOPSIS
#   Installs the specified Cabal.
function Install-Cabal {
    param (
        [Parameter(Mandatory)][String] $Version,
        [Switch] $Set = $false,
        [Switch] $Force = $false
    )

    $ErrorActionPreference = 'Stop'

    if (Test-Path "$(Get-GhcupsInstall)\cabal-$Version") {
        if ($Force) {
            Uninstall-Cabal $Version
        }
        else {
            $choice = Read-Host "Cabal $Version looks already installed. Do you want to reinstall? [y/N]"
            if ('y' -ne $choice) {
                return
            }
            Uninstall-Cabal $Version
        }
    }
    $tempDir = [System.IO.Path]::GetTempPath()
    $arch = Get-Architecture
    $fileName = "cabal-install-$Version-$arch-unknown-mingw32.zip"
    if (Test-Path "$tempDir$fileName") {
        Write-Host "A downloaded archive file is found: $tempDir$fileName"
        $choice = Read-Host "Do you want to use this? [y/N]"
        if ('y' -ne $choice) {
            Remove-Item "$tempDir$fileName"
            (New-Object System.Net.WebClient).DownloadFile("https://downloads.haskell.org/~cabal/cabal-install-$Version/$fileName", "$tempDir$fileName")
        }
    }
    else {
        (New-Object System.Net.WebClient).DownloadFile("https://downloads.haskell.org/~cabal/cabal-install-$Version/$fileName", "$tempDir$fileName")
    }
    Expand-Archive "$tempDir$fileName" "$(Get-GhcupsInstall)\cabal-$Version"

    if ($Set) {
        Set-Cabal -Cabal $Version
    }
}

# .SYNOPSIS
#   Uninstalls the specified Cabal.
function Uninstall-Cabal {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    $ErrorActionPreference = 'Stop'

    Remove-Item -Recurse -Force "$(Get-GhcupsInstall)\cabal-$Version"
}

# .SYNOPSIS
#   Shows the Cabals which is specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not installed yet.
function Show-Cabal {
    $ErrorActionPreference = 'Stop'

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfigDir = $null
    if (-not [String]::IsNullOrEmpty($localConfigPath)) {
        $localConfigDir = Split-Path $localConfigPath -Parent
    }
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $names = Get-HashtaleItem 'cabal' $config
    if ($null -eq $names -or 0 -eq $names.Count) {
        Write-Output 'No configurations found'
    }
    else {
        Write-Output "$localConfigName ($(($localConfigDir, $userGlobalDataPath, $systemGlobalDataPath | Where-Object { $null -ne $_ }) -Join ', '))"
        foreach ($k in $config.cabal.Keys) {
            Write-Output "    ${k}:    $($config.cabal[$k])"
        }
    }
    Write-Output ''
    Write-Output 'Installed'
    $versions = Get-InstalledItems 'cabal'
    if ($null -eq $versions) {
        Write-Output '    None'
    }
    else {
        foreach ($v in $versions) {
            Write-Output "    ${v}:$(' ' * (10 - $v.Length))$(Get-GhcupsInstall)\cabal-$v\bin"
        }
    }
    Write-Output ''
    Write-Output 'Supported (You can specify unsupported versions too)'
    $arch = Get-Architecture
    $versions = Get-HashtaleItem 'cabal', $arch (Get-Config "$($MyInvocation.MyCommand.Module.ModuleBase)\version.yaml")
    foreach ($v in $versions) {
        Write-Output "    ${v}"
    }
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
        'Write-GhcupsConfigTemplate'
