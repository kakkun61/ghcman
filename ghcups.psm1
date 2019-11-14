# Constant

Set-Variable dataDir -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable ghcPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\ghc-[0-9]+\.[0-9]+\.[0-9]+\\bin')
Set-Variable cabalPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\cabal-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
Set-Variable configFileName -Option Constant -Value 'ghcups.yaml'

# Common

Function Get-Config() {
    Param (
        [Parameter(Mandatory)][String] $Dir
    )

    $configPath = ''
    While ($true) {
        If ($Dir -eq $Env:USERPROFILE -or '' -eq $Dir) {
            break
        }
        $test = Join-Path $Dir $configFileName
        If (Test-Path $test) {
            $configPath = $test
            break
        }
        $Dir = Split-Path $Dir -Parent
    }
    If ('' -eq $configPath) {
        $test = Join-Path $dataDir $configFileName
        If (Test-Path $test) {
            $configPath = $test
        }
        Else {
            $null
            return
        }
    }
    ConvertFrom-Yaml (Get-Content $configPath -Raw)
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

    If ('' -ne $path -and -not (Test-Path $path)) {
        Write-Warning "`"$path`" is not an existing path"
    }
    $restPaths = $Env:Path -Split ';' | Where-Object { $v = $_; $patterns | ForEach-Object { $v -NotMatch $_ } | All }
    $newPaths = ,$path + $restPaths | Where-Object { '' -ne $_ }
    Set-Item Env:\Path -Value ($newPaths -Join ';')
}

# GHC

Function Get-GhcPatterns() {
    Param (
        [Parameter(Mandatory)][Hashtable] $Config
    )

    $patterns = ,$ghcPathPattern
    If ($null -ne $Config -and $null -ne $Config['ghc']) {
        ForEach ($path in $Config.ghc.Values) {
            $patterns += [Regex]::Escape($path)
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

Function Set-Ghc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    $config = Get-Config (Get-Location)
    $ghcDir = ''
    If ($null -eq $config -or $null -eq $config['ghc'] -or $null -eq $config['ghc'][$Ghc]) {
        $ghcDir = Get-ChocoGhc $Ghc
    }
    Else {
        $ghcDir = $config['ghc'][$Ghc]
    }
    Set-PathEnv (Get-GhcPatterns $config) $ghcDir
}

Function Clear-Ghc() {
    Set-PathEnv (Get-GhcPatterns (Get-Config (Get-Location))) $null
}

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

Function Remove-Ghc() {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    choco uninstall ghc --version $Ghc
}

# Cabal

Function Get-CabalPatterns() {
    Param (
        [Parameter(Mandatory)][Hashtable] $Config
    )

    $patterns = ,$cabalPathPattern
    If ($null -ne $Config -and $null -ne $Config['cabal']) {
        ForEach ($path in $Config.cabal.Values) {
            $patterns += [Regex]::Escape($path)
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

Function Clear-Cabal() {
    Set-PathEnv (Get-CabalPatterns (Get-Config (Get-Location))) $null
}

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

Function Remove-Cabal() {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    choco uninstall cabal --version $Cabal
}

# Export

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Remove-Ghc', 'Set-Cabal', 'Clear-Cabal', 'Install-Cabal', 'Remove-Cabal', 'Get-Config'
