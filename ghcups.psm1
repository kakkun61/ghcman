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
            if ($result.ContainsKey($key)) {
                if ($value -is [Hashtable]) {
                    [void] (Join-Hashtables $result[$key], $value -Breaking)
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

    if (-not (Test-Path (Get-GhcupsInstall))) {
        @()
        return
    }
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

    Remove-Item -Recurse -Force "$(Get-GhcupsInstall)\ghc-$Version"
}

# .SYNOPSIS
#   Shows the GHCs which is specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not yet installed.
function Show-Ghc {
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
    $supporteds = Get-HashtaleItem 'ghc', $arch (Get-Config "$($MyInvocation.MyCommand.Module.ModuleBase)\version.yaml")

    if ($HumanReadable) {
        if ($null -ne $paths) {
            foreach ($name in $paths.Keys) {
                Write-StatusLine $name $paths[$name]
            }
        }
        $result = @{}
        foreach ($version in $installeds) {
            $result.Add($version, @{ 'Supported' = $false; 'Path' = "$(Get-GhcupsInstall)\ghc-$version" })
        }
        foreach ($version in $supporteds) {
            if ($null -eq $result[$version]) {
                $result.Add($version, @{ 'Supported' = $true; 'Path' = $null })
            }
            else {
                $result[$version]['Supported'] = $true
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
            $result.Add($name, @{ 'Name' = $name; 'Path' = $paths[$name] })
        }
    }
    foreach ($version in $installeds) {
        $result.Add($version, @{ 'Name' = $version; 'Path' = "$(Get-GhcupsInstall)\ghc-$version" })
    }
    foreach ($version in $supporteds) {
        if ($null -eq $result[$version]) {
            $result.Add($version, @{ 'Name' = $version; 'Supported' = $true })
        }
        else {
            $result[$version]['Supported'] = $true
        }
    }
    if ($OnlySupported) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if ($result[$version]['Supported']) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    if ($OnlyInstalled) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if (-not [String]::IsNullOrEmpty($result[$version]['Path'])) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    $result
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

    Remove-Item -Recurse -Force "$(Get-GhcupsInstall)\cabal-$Version"
}

# .SYNOPSIS
#   Shows the Cabals which is specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not installed yet.
function Show-Cabal {
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
    $paths = if ($OnlySupported) { $null } else {Get-HashtaleItem 'cabal' $config }
    $installeds = Get-InstalledItems 'cabal'
    $arch = Get-Architecture
    $supporteds = Get-HashtaleItem 'cabal', $arch (Get-Config "$($MyInvocation.MyCommand.Module.ModuleBase)\version.yaml")

    if ($HumanReadable) {
        if ($null -ne $paths) {
            foreach ($name in $paths.Keys) {
                Write-StatusLine $name $paths[$name]
            }
        }
        $result = @{}
        foreach ($version in $installeds) {
            $result.Add($version, @{ 'Supported' = $false; 'Path' = "$(Get-GhcupsInstall)\cabal-$version" })
        }
        foreach ($version in $supporteds) {
            if ($null -eq $result[$version]) {
                $result.Add($version, @{ 'Supported' = $true; 'Path' = $null })
            }
            else {
                $result[$version]['Supported'] = $true
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
            $result.Add($name, @{ 'Name' = $name; 'Path' = $paths[$name] })
        }
    }
    foreach ($version in $installeds) {
        $result.Add($version, @{ 'Name' = $version; 'Path' = "$(Get-GhcupsInstall)\cabal-$version" })
    }
    foreach ($version in $supporteds) {
        if ($null -eq $result[$version]) {
            $result.Add($version, @{ 'Name' = $version; 'Supported' = $true })
        }
        else {
            $result[$version]['Supported'] = $true
        }
    }
    if ($OnlySupported) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if ($result[$version]['Supported']) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    if ($OnlyInstalled) {
        $result_ = @{}
        foreach ($version in $result.Keys) {
            if (-not [String]::IsNullOrEmpty($result[$version]['Path'])) {
                $result_.Add($version, $result[$version])
            }
        }
        $result = $result_
    }
    $result
}

# .SYNOPSIS
#   Shows the loaded configurations which are re-generated to YAML.
function Show-GhcupsConfig {
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
        'Show-GhcupsConfig'
