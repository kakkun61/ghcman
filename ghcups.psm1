Set-StrictMode -Version Latest

# Constant

Set-Variable dataDir -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable ghcPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\ghc-[0-9]+\.[0-9]+\.[0-9]+\\bin')
Set-Variable cabalPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\cabal-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
Set-Variable configFileName -Option Constant -Value 'ghcups.yaml'

# Common

Function Find-Config () {
    Param (
        [Parameter(Mandatory)][String] $Dir
    )

    $configPath = ''
    While ($true) {
        If ($Dir -eq $Env:USERPROFILE -or [String]::IsNullOrEmpty($Dir)) {
            break
        }
        $test = Join-Path $Dir $configFileName
        If (Test-Path $test) {
            $configPath = $test
            break
        }
        $Dir = Split-Path $Dir -Parent
    }
    If ([String]::IsNullOrEmpty($configPath)) {
        $test = Join-Path $dataDir $configFileName
        If (Test-Path $test) {
            $configPath = $test
        }
        Else {
            ''
            return
        }
    }
    $configPath
}

Function Get-Config() {
    Param (
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][String] $Path
    )

    If ([String]::IsNullOrEmpty($Path)) {
        $null
        return
    }
    ConvertFrom-Yaml (Get-Content $Path -Raw)
}

Function All() {
    Param ([Parameter(ValueFromPipeline)][Boolean[]] $ps)
    Begin { $acc = $true }
    Process { ForEach ($p in $ps) { $acc = $acc -and $p } }
    End { $acc }
}

Function Set-PathEnv() {
    Param (
        [Parameter(Mandatory)][String[]] $patterns,
        [Parameter(Mandatory)][AllowEmptyString()][String] $path
    )

    If (-not [String]::IsNullOrEmpty($path) -and -not (Test-Path $path)) {
        Write-Warning "`"$path`" is not an existing path"
    }
    $restPaths = $Env:Path -Split ';' | Where-Object { $v = $_; $patterns | ForEach-Object { $v -NotMatch $_ } | All }
    $newPaths = ,$path + $restPaths | Where-Object { -not [String]::IsNullOrEmpty($_) }
    Set-Item Env:\Path -Value ($newPaths -Join ';')
}

Function Get-InstalledChocoItems() {
    Param (
        [Parameter(Mandatory)][String] $App
    )

    $path = "$Env:ChocolateyInstall\lib\$App."
    Get-Item "$path*" | ForEach-Object { ([String]$_).Remove(0, "$path".Length) }
}

# .SYNOPSIS
#   Creats the ghcups.yaml with the default contents.
function Write-GhcupsConfigTemplate () {
    Param (
        [String] $Path = '.'
    )

    "# The key is the name you want, the value is the path of directory which contains ghc, ghci, etc.`nghc: {}`n`n# The same with ghc for cabal.`ncabal: {}" | Out-File (Join-Path $Path $configFileName) -NoClobber
}

# GHC

Function Get-GhcPatterns() {
    Param (
        [Parameter(Mandatory)][AllowNull()][Hashtable] $Config
    )

    $patterns = ,$ghcPathPattern
    If ($null -ne $Config -and $null -ne $Config['ghc']) {
        ForEach ($path in $Config.ghc.Values) {
            If (-not [String]::IsNullOrEmpty($path)) {
                $patterns += [Regex]::Escape($path)
            }
        }
    }
    $patterns
}

Function Get-ChocoGhc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin"
}

# .SYNOPSIS
#   Sets the version or variant of GHC to the Path environment variable of the current session.
Function Set-Ghc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    $config = Get-Config (Find-Config (Get-Location))
    $ghcDir = ''
    If ($null -eq $config -or $null -eq $config['ghc'] -or $null -eq $config['ghc'][$Ghc]) {
        $ghcDir = Get-ChocoGhc $Ghc
    }
    Else {
        $ghcDir = $config['ghc'][$Ghc]
    }
    Set-PathEnv (Get-GhcPatterns $config) $ghcDir
}

# .SYNOPSIS
#   Removes all GHC values from the Path environment variable of the current session.
Function Clear-Ghc() {
    Set-PathEnv (Get-GhcPatterns (Get-Config (Find-Config (Get-Location)))) $null
}

# .SYNOPSIS
#   Installs the specified GHC with the Chocolatey.
Function Install-Ghc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc,
        [Switch] $Set = $false
    )

    choco install ghc --version $Ghc --side-by-side

    If ($Set) {
        Set-Ghc -Ghc $Ghc
    }
}

# .SYNOPSIS
#   Uninstalls the specified GHC with the Chocolatey.
Function Remove-Ghc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    choco uninstall ghc --version $Ghc
}

# .SYNOPSIS
#   Shows the GHCs which is specified by the ghcups.yaml, is installed by the Chocolatey and is hosted on the Chocolatey repository.
Function Show-Ghc() {
    $configPath = Find-Config (Get-Location)
    $config = Get-Config $configPath
    $span = $false
    If ($null -ne $config -and $null -ne $config['ghc'] -and 0 -lt $config['ghc'].Count) {
        Write-Host "$configFileName ($(Split-Path $configPath -Parent))"
        ForEach ($k in $config.ghc.Keys) {
            Write-Host "    ${k}:    $($config.ghc[$k])"
        }
        $span = $true
    }
    $chocoGhcs = Get-InstalledChocoItems 'ghc'
    If ($null -ne $chocoGhcs) {
        If ($span) {
            Write-Host
        }
        Write-Host 'Chocolatey (Installed)'
        ForEach ($g in $chocoGhcs) {
            Write-Host "    ${g}:    $Env:ChocolateyInstall\lib\ghc.$g\tools\ghc-$g\bin"
        }
        $span = $true
    }
    If ($span) {
        Write-Host
    }
    choco list ghc --by-id-only --all-versions
}

# Cabal

Function Get-CabalPatterns() {
    Param (
        [Parameter(Mandatory)][AllowNull()][Hashtable] $Config
    )

    $patterns = ,$cabalPathPattern
    If ($null -ne $Config -and $null -ne $Config['cabal']) {
        ForEach ($path in $Config.cabal.Values) {
            If (-not [String]::IsNullOrEmpty($path)) {
                $patterns += [Regex]::Escape($path)
            }
        }
    }
    $patterns
}

Function Get-ChocoCabal() {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    "$Env:ChocolateyInstall\lib\cabal.$Cabal\tools\cabal-$Cabal"
}

# .SYNOPSIS
#   Sets the version or variant of Cabal to the Path environment variable of the current session.pa
Function Set-Cabal() {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    $config = Get-Config (Get-Location)
    $cabalDir = ''
    If ($null -eq $config -or $null -eq $config['cabal'] -or $null -eq $config['cabal'][$Cabal]) {
        $cabalDir = Get-ChocoCabal $Cabal
    }
    Else {
        $cabalDir = $config['cabal'][$Cabal]
    }
    Set-PathEnv (Get-CabalPatterns $config) $cabalDir
}

# .SYNOPSIS
#   Removes all Cabal values from the Path environment variable of the current session.
Function Clear-Cabal() {
    Set-PathEnv (Get-CabalPatterns (Get-Config (Get-Location))) $null
}

# .SYNOPSIS
#   Installs the specified Cabal with the Chocolatey.
Function Install-Cabal() {
    Param (
        [Parameter(Mandatory)][String] $Cabal,
        [Switch] $Set = $false
    )

    choco install cabal --version $Cabal --side-by-side

    If ($Set) {
        Set-Cabal -Cabal $Cabal -Method $Method
    }
}

# .SYNOPSIS
#   Uninstalls the specified Cabal with the Chocolatey.
Function Remove-Cabal() {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    choco uninstall cabal --version $Cabal
}

# .SYNOPSIS
#   Shows the Cabals which is specified by the ghcups.yaml, is installed by the Chocolatey and is hosted on the Chocolatey repository.
Function Show-Cabal() {
    $configPath = Find-Config (Get-Location)
    $config = Get-Config $configPath
    $span = $false
    If ($null -ne $config -and $null -ne $config['cabal'] -and 0 -lt $config['cabal'].Count) {
        Write-Host "$configFileName ($(Split-Path $configPath -Parent))"
        ForEach ($k in $config.cabal.Keys) {
            Write-Host "    ${k}:    $($config.cabal[$k])"
        }
        $span = $true
    }
    $chocoCabals = Get-InstalledChocoItems 'cabal'
    If ($null -ne $chocoCabals) {
        If ($span) {
            Write-Host
        }
        Write-Host 'Chocolatey (Installed)'
        ForEach ($c in $chocoCabals) {
            Write-Host "    ${c}:    $Env:ChocolateyInstall\lib\cabal.$c\tools\cabal-$c"
        }
        $span = $true
    }
    If ($span) {
        Write-Host
    }
    choco list cabal --by-id-only --all-versions
}

# Export

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Remove-Ghc', 'Show-Ghc', 'Set-Cabal', 'Clear-Cabal', 'Install-Cabal', 'Remove-Cabal', 'Show-Cabal', 'Write-GhcupsConfigTemplate'
