#requires -PSEdition Core

Set-StrictMode -Version Latest

# Constant

Set-Variable ghcmanVersion -Option Constant -Value "4.8"
Set-Variable systemGlobalDataPath -Option Constant -Value "$Env:ProgramData\ghcman"
Set-Variable userGlobalDataPath -Option Constant -Value "$Env:APPDATA\ghcman"
Set-Variable versionPattern -Option Constant -Value '[0-9]+(\.[0-9]+)*'
Set-Variable localConfigName -Option Constant -Value 'ghcman.yaml'
Set-Variable globalConfigName -Option Constant -Value 'config.yaml'
Set-Variable default7ZipPath -Option Constant -Value 'C:\Program Files\7-Zip'
Set-Variable localAppData -Option Constant -Value "$Env:LOCALAPPDATA\ghcman"
Set-Variable versionFile -Option Constant -Value "$localAppData\version.$ghcmanVersion.yaml"

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
            if ($result.ContainsKey($key)) {
                if ($value -is [Hashtable]) {
                    if ($null -ne $result[$key]) {
                        [void] (Join-Hashtables $result[$key], $value -Breaking)
                    }
                    else {
                        $result.Remove($key)
                        $result.Add($key, $h[$key])
                    }
                }
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

    if (-not (Test-Path (Get-GhcmanInstall))) {
        @()
        return
    }
    $path = "$(Get-GhcmanInstall)\$App-"
    Get-Item "$path*" | ForEach-Object { ([String]$_).Remove(0, $path.Length) }
}

# .SYNOPSIS
#   Creats the ghcman.yaml with the default contents.
function Write-GhcmanConfigTemplate {
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

function Get-GhcmanInstall {
    param ()
    if ([String]::IsNullOrEmpty($Env:GhcmanInstall)) {
        $userGlobalDataPath
        return
    }
    $Env:GhcmanInstall
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

function Write-StatusLine {
    param (
        [Parameter(Mandatory)][String] $Name,
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][String] $Path,
        [Bool] $Supported = $false
    )

    Write-Host "$Name$(' ' * [Math]::Abs(8 - $Name.Length)) " -NoNewline
    if ($Supported) {
        Write-Host "S" -ForegroundColor DarkBlue -BackgroundColor White -NoNewline
    }
    else {
        Write-Host " " -BackgroundColor White -NoNewline
    }
    if (-not ([String]::IsNullOrEmpty($Path))) {
        Write-Host " $Path" -NoNewline
    }
    Write-Host
}

function Write-Quote {
    param (
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][String] $Content
    )

    foreach ($line in $Content -Split [Environment]::NewLine) {
        Write-Host '     | ' -ForegroundColor Gray -NoNewline
        Write-Host $line
    }
}

function Start-7Zip {
    try {
        7z @Args
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $originalException = $_.Exception
        try {
            & "$default7ZipPath\7z" @Args
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            $choice = Read-Host '"7z" is not found. Will you install 7-Zip? [y/N]'
            if ('y' -ne $choice) {
                throw $originalException
            }
            Install-7Zip
            & "$default7ZipPath\7z" @Args
        }
    }
}

function Install-7Zip {
    param ()

    $tempDir = [System.IO.Path]::GetTempPath()
    # https://www.7-zip.org/a/7z1900-x64.msi
    $fileName = "7z1900-x64.msi"
    if (Test-Path "$tempDir$fileName") {
        Write-Host "A downloaded archive file is found: $tempDir$fileName"
        $choice = Read-Host "Do you want to use this? [y/N]"
        if ('y' -ne $choice) {
            Remove-Item "$tempDir$fileName"
            (New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/$fileName", "$tempDir$fileName")
        }
    }
    else {
        (New-Object System.Net.WebClient).DownloadFile("https://www.7-zip.org/a/$fileName", "$tempDir$fileName")
    }

    Start-Process -FilePath 'msiexec' -ArgumentList "/i `"$tempDir$fileName`" /qn" -Wait -Verb RunAs
}

# .SYNOPSIS
#   Download version data.
function Update-GhcmanVersionFile() {
    param ()

    if (-not (Test-Path $localAppData)) {
        New-Item -ItemType Directory -Path $localAppData
    }
    (Invoke-WebRequest "https://raw.githubusercontent.com/kakkun61/ghcman/master/version.$ghcmanVersion.yaml").Content | Out-File $versionFile -NoClobber
}

function Get-GhcmanVersionFile {
    param ()

    if (Test-Path -PathType Leaf $versionFile) {
        Write-Debug "A downloaded version file is found: $versionFile"
        Get-Config $versionFile
        return
    }
    Write-Debug "A downloaded version file is not found, a bundled one is used instead: $($MyInvocation.MyCommand.Module.ModuleBase)\version.$ghcmanVersion.yaml"
    Get-Config "$($MyInvocation.MyCommand.Module.ModuleBase)\version.$ghcmanVersion.yaml"
}

# GHC

function Get-GhcmanGhc {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    "$(Get-GhcmanInstall)\ghc-$Version\bin"
}

function Get-GhcPathPattern {
    param ()
    [Regex]::Escape((Get-GhcmanInstall)) + '\\ghc-' + $versionPattern + '\\bin'
}

class GhcInstalledValidateSetValuesGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return (Get-Ghc -OnlyInstalled).Keys
    }
}

# .SYNOPSIS
#   Sets the version or variant of GHC to the Path environment variable of the current session.
function Set-Ghc {
    param (
        [Parameter(Mandatory)][ValidateSet([GhcInstalledValidateSetValuesGenerator])][String] $Name
    )

    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    [Hashtable] $cs = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $ghcDir = Get-HashtaleItem -Name 'ghc', $Name -Hashtable $cs
    if ([String]::IsNullOrEmpty($ghcDir)) {
        if ($Name -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No such GHC: $Name"
            return
        }
        $ghcDir = Get-GhcmanGhc $Name
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

    if (Test-Path "$(Get-GhcmanInstall)\ghc-$Version") {
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
        Remove-Item -Recurse "$tempDir$fileName.tar"
    }
    Start-7Zip x -bso0 -bsp0 "-o$tempDir$fileName.tar" "$tempDir$fileName.tar.xz"
    Start-7Zip x -bso0 -bsp0 "-o$(Get-GhcmanInstall)" "$tempDir$fileName.tar"

    if ([Version]$Version -ge [Version]"9.0") {
        Move-Item -Path "$(Get-GhcmanInstall)\ghc-$Version-x86_64-unknown-mingw32" -Destination "$(Get-GhcmanInstall)\ghc-$Version"
    }

    if ($Set) {
        Set-Ghc -Name $Version
    }
}

# .SYNOPSIS
#   Uninstalls the specified GHC.
function Uninstall-Ghc {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    $ErrorActionPreference = 'Stop'

    Remove-Item -Recurse -Force "$(Get-GhcmanInstall)\ghc-$Version"
}

# .SYNOPSIS
#   [DEPRECATED] Shows the GHCs which is specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not yet installed.
function Show-Ghc {
    Write-Warning "Show-Ghc is deprecated, invoke Get-Ghc instead"
    Get-Ghc
}

# .SYNOPSIS
#   Gets the GHCs which is specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not yet installed.
function Get-Ghc {
    param (
        [Switch] $HumanReadable = $false,
        [Switch] $OnlySupported = $false,
        [Switch] $OnlyInstalled = $false
    )

    $ErrorActionPreference = 'Stop'

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $paths = if ($OnlySupported) { $null } else {Get-HashtaleItem 'ghc' $config }
    $installeds = Get-InstalledItems 'ghc'
    $arch = Get-Architecture
    $supporteds = Get-HashtaleItem 'ghc', $arch (Get-GhcmanVersionFile)

    if ($HumanReadable) {
        if ($null -ne $paths) {
            foreach ($name in $paths.Keys) {
                Write-StatusLine $name $paths[$name]
            }
        }
        $result = @{}
        foreach ($version in $installeds) {
            $result.Add($version, @{ 'Supported' = $false; 'Path' = "$(Get-GhcmanInstall)\ghc-$version" })
        }
        foreach ($version in $supporteds) {
            if ($null -eq $result[$version]) {
                $result.Add($version, @{ 'Supported' = $true; 'Path' = $null })
            }
            else {
                $result[$version].Supported = $true
            }
        }
        foreach ($version in $result.Keys | ForEach-Object { [Version]$_ } | Sort-Object -Descending | ForEach-Object { [String]$_ }) {
            if ($OnlySupported -and -not ($result[$version].Supported)) { continue }
            if ($OnlyInstalled -and [String]::IsNullOrEmpty($result[$version].Path)) { continue }
            Write-StatusLine $version $result[$version].Path -Supported $result[$version].Supported
        }
        Write-Output 'S: supported'
        return
    }

    $result = @{}
    if ($null -ne $paths) {
        foreach ($name in $paths.Keys) {
            $result.Add($name, @{ 'Name' = $name; 'Path' = $paths[$name]; 'Supported' = $false })
        }
    }
    foreach ($version in $installeds) {
        $result.Add($version, @{ 'Name' = $version; 'Path' = "$(Get-GhcmanInstall)\ghc-$version"; 'Supported' = $false })
    }
    foreach ($version in $supporteds) {
        if ($null -eq $result[$version]) {
            $result.Add($version, @{ 'Name' = $version; 'Path' = $null; 'Supported' = $true })
        }
        else {
            $result[$version].Supported = $true
        }
    }
    if ($OnlySupported) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if ($result[$version].Supported) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    if ($OnlyInstalled) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if (-not [String]::IsNullOrEmpty($result[$version].Path)) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    $result
}

# Cabal

function Get-GhcmanCabal {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    "$(Get-GhcmanInstall)\cabal-$Version"
}

function Get-CabalPathPattern {
    [Regex]::Escape((Get-GhcmanInstall)) + '\\cabal-' + $versionPattern
}

class CabalValidateSetValuesGenerator : System.Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return (Get-Cabal -OnlyInstalled).Keys
    }
}

# .SYNOPSIS
#   Sets the version or variant of Cabal to the Path environment variable of the current session.
function Set-Cabal {
    param (
        [Parameter(Mandatory)][ValidateSet([CabalValidateSetValuesGenerator])][String] $Name
    )

    $ErrorActionPreference = 'Stop'

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $cabalDir = Get-HashtaleItem -Name 'cabal', $Name -Hashtable (Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig)
    if ([String]::IsNullOrEmpty($cabalDir)) {
        if ($Name -notmatch ('\A' + $versionPattern + '\Z')) {
            Write-Error "No such Cabal: $Name"
            return
        }
        $cabalDir = Get-GhcmanCabal $Name
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

    if (Test-Path "$(Get-GhcmanInstall)\cabal-$Version") {
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
    if ([Version]$Version -ge [Version]"3.4") {
        $fileName = "cabal-install-$Version-$arch-windows.zip"
    }

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
    Expand-Archive "$tempDir$fileName" "$(Get-GhcmanInstall)\cabal-$Version"

    if ($Set) {
        Set-Cabal -Name $Version
    }
}

# .SYNOPSIS
#   Uninstalls the specified Cabal.
function Uninstall-Cabal {
    param (
        [Parameter(Mandatory)][String] $Version
    )

    $ErrorActionPreference = 'Stop'

    Remove-Item -Recurse -Force "$(Get-GhcmanInstall)\cabal-$Version"
}


# .SYNOPSIS
#   [DEPRECATED] Shows the Cabals which is specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not installed yet.
function Show-Cabal {
    Write-Warning "Show-Cabal is deprecated, invoke Get-Cabal instead"
    Get-Cabal
}

# .SYNOPSIS
#   Gets the Cabals which is specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not installed yet.
function Get-Cabal {
    param (
        [Switch] $HumanReadable = $false,
        [Switch] $OnlySupported = $false,
        [Switch] $OnlyInstalled = $false
    )

    $ErrorActionPreference = 'Stop'

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfig = Get-Config $localConfigPath
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $paths = if ($OnlySupported) { $null } else { Get-HashtaleItem 'cabal' $config }
    $installeds = Get-InstalledItems 'cabal'
    $arch = Get-Architecture
    $supporteds = Get-HashtaleItem 'cabal', $arch (Get-GhcmanVersionFile)

    if ($HumanReadable) {
        if ($null -ne $paths) {
            foreach ($name in $paths.Keys) {
                Write-StatusLine $name $paths[$name]
            }
        }
        $result = @{}
        foreach ($version in $installeds) {
            $result.Add($version, @{ 'Supported' = $false; 'Path' = "$(Get-GhcmanInstall)\cabal-$version" })
        }
        foreach ($version in $supporteds) {
            if ($null -eq $result[$version]) {
                $result.Add($version, @{ 'Supported' = $true; 'Path' = $null })
            }
            else {
                $result[$version].Supported = $true
            }
        }
        foreach ($version in $result.Keys | ForEach-Object { [Version]$_ } | Sort-Object -Descending | ForEach-Object { [String]$_ }) {
            if ($OnlySupported -and -not ($result[$version].Supported)) { continue }
            if ($OnlyInstalled -and [String]::IsNullOrEmpty($result[$version].Path)) { continue }
            Write-StatusLine $version $result[$version].Path -Supported $result[$version].Supported
        }
        Write-Output 'S: supported'
        return
    }

    $result = @{}
    if ($null -ne $paths) {
        foreach ($name in $paths.Keys) {
            $result.Add($name, @{ 'Name' = $name; 'Path' = $paths[$name]; 'Supported' = $false })
        }
    }
    foreach ($version in $installeds) {
        $result.Add($version, @{ 'Name' = $version; 'Path' = "$(Get-GhcmanInstall)\cabal-$version"; 'Supported' = $false })
    }
    foreach ($version in $supporteds) {
        if ($null -eq $result[$version]) {
            $result.Add($version, @{ 'Name' = $version; 'Path' = $null; 'Supported' = $true })
        }
        else {
            $result[$version].Supported = $true
        }
    }
    if ($OnlySupported) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if ($result[$version].Supported) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    if ($OnlyInstalled) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if (-not [String]::IsNullOrEmpty($result[$version].Path)) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    $result
}

# .SYNOPSIS
#   [DEPRECATED] Shows the loaded configurations which are re-generated to YAML.
function Show-GhcmanConfig {
    Write-Warning "Show-GhcmanConfig is deprecated, Get-GhcmanConfig instead"
}

# .SYNOPSIS
#   Gets the loaded configurations which are re-generated to YAML.
function Get-GhcmanConfig {
    $ErrorActionPreference = 'Stop'

    $localConfigPath = Find-LocalConfigPath (Get-Location)
    $localConfig = Get-Config $localConfigPath

    $userGlobalConfigPath = Join-Path $userGlobalDataPath $globalConfigName
    $userGlobalConfig = Get-Config $userGlobalConfigPath

    $systemGlobalConfigPath = Join-Path $systemGlobalDataPath $globalConfigName
    $systemGlobalConfig = Get-Config $systemGlobalConfigPath

    $config = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig

    if ([String]::IsNullOrEmpty($localConfigPath)) {
        Write-Host "Local config:"
        Write-Host "    Not found"
    }
    elseif ($null -eq $localConfig) {
        Write-Host "Local config: $localConfigPath"
        Write-Host "    Empty"
    }
    else {
        Write-Host "Local config: $localConfigPath"
        Write-Quote (ConvertTo-Yaml $localConfig)
    }
    Write-Host

    Write-Host "User global config: $userGlobalConfigPath"
    if (-not (Test-Path $userGlobalDataPath)) {
        Write-Host "    Not found"
    }
    elseif ($null -eq $userGlobalConfig) {
        Write-Host "    Empty file"
    }
    else {
        Write-Quote (ConvertTo-Yaml $userGlobalConfig)
    }
    Write-Host

    Write-Host "System global config: $systemGlobalConfigPath"
    if (-not (Test-Path $systemGlobalDataPath)) {
        Write-Host "    Not found"
    }
    elseif ($null -eq $systemGlobalConfig) {
        Write-Host "    Empty file"
    }
    else {
        Write-Quote (ConvertTo-Yaml $systemGlobalConfig)
    }
    Write-Host

    Write-Host "Merged config:"
    if ($null -eq $config) {
        Write-Host "    Nothing"
    }
    else {
        Write-Quote (ConvertTo-Yaml $config)
    }
}

# Export

Export-ModuleMember `
    -Function `
        'Set-Ghc', `
        'Get-Ghc', `
        'Clear-Ghc', `
        'Install-Ghc', `
        'Uninstall-Ghc', `
        'Show-Ghc', `
        'Set-Cabal', `
        'Get-Cabal', `
        'Clear-Cabal', `
        'Install-Cabal', `
        'Uninstall-Cabal', `
        'Show-Cabal', `
        'Write-GhcmanConfigTemplate', `
        'Get-GhcmanConfig', `
        'Show-GhcmanConfig', `
        'Update-GhcmanVersionFile'
