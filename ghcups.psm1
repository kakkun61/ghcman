Set-StrictMode -Version Latest

# Constant

Set-Variable systemGlobalDataPath -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable userGlobalDataPath -Option Constant -Value "$Env:APPDATA\ghcups"
Set-Variable ghcPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\ghc-[0-9]+\.[0-9]+\.[0-9]+\\bin')
Set-Variable cabalPathPattern -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal .[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\cabal-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
Set-Variable localConfigName -Option Constant -Value 'ghcups.yaml'
Set-Variable globalConfigName -Option Constant -Value 'config.yaml'

# Common

Function Find-LocalConfigPath {
    Param (
        [Parameter(Mandatory)][String] $Dir
    )

    While ($true) {
        If ($Dir -eq $Env:USERPROFILE -or [String]::IsNullOrEmpty($Dir)) {
            ''
            return
        }
        $test = Join-Path $Dir $localConfigName
        If (Test-Path $test) {
            $test
            return
        }
        $Dir = Split-Path $Dir -Parent
    }
}

Function Get-Config {
    Param (
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][String] $Path
    )

    If ([String]::IsNullOrEmpty($Path)) {
        $null
        return
    }
    If (-not (Test-Path $Path)) {
        $null
        return
    }
    ConvertFrom-Yaml (Get-Content $Path -Raw)
}

Function Get-HashtaleItem {
    Param (
        [Parameter(Mandatory)][Object[]] $Name,
        [Hashtable] $Hashtable
    )

    $item = $Hashtable
    ForEach ($n in $Name) {
        If ($null -eq $item) {
            $null
            return
        }
        $item = $item[$n]
    }
    $item
}

Function Copy-HashtableDeeply {
    Param (
        [Hashtable] $Hashtable
    )

    $result = @{}
    ForEach ($key in $Hashtable.Keys) {
        $item = $Hashtable[$key]
        If ($item -is [Hashtable]) {
            $result.Add($key, (Copy-HashtableDeeply $item))
            continue
        }
        If ($null -eq $item) {
            $result.Add($key, $null)
            continue
        }
        $result.Add($key, $item.Clone())
    }
    $result
}

Function Join-Hashtables {
    Param (
        [Hashtable[]] $Hashtables,
        [Switch] $Breaking = $false
    )

    If ($null -eq $Hashtables -or @() -eq $Hashtables) {
        $null
        return
    }

    $result = $null
    ForEach ($h in $Hashtables) {
        If ($null -eq $h) {
            continue
        }
        If ($null -eq $result) {
            If ($Breaking) {
                $result = $h
            }
            Else {
                $result = Copy-HashtableDeeply $h
            }
            continue
        }
        ForEach ($key in $h.Keys) {
            $value = $h[$key]
            If ($result.ContainsKey($key) -and $result -is [Hashtable] -and $value -is [Hashtable]) {
                [void] (Join-Hashtables $result[$key], $value -Breaking)
            }
            Else {
                $result.Add($key, $h[$key])
            }
        }
    }
    $result
}

Function All {
    Param ([Parameter(ValueFromPipeline)][Boolean[]] $ps)
    Begin { $acc = $true }
    Process { ForEach ($p in $ps) { $acc = $acc -and $p } }
    End { $acc }
}

Function Set-PathEnv {
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

Function Get-InstalledChocoItems {
    Param (
        [Parameter(Mandatory)][String] $App
    )

    $path = "$Env:ChocolateyInstall\lib\$App."
    Get-Item "$path*" | ForEach-Object { ([String]$_).Remove(0, $path.Length) }
}

# .SYNOPSIS
#   Creats the ghcups.yaml with the default contents.
function Write-GhcupsConfigTemplate {
    Param (
        [String] $Path = '.'
    )

    "# The key is the name you want, the value is the path of directory which contains ghc, ghci, etc.`nghc: {}`n`n# The same with ghc for cabal.`ncabal: {}" | Out-File (Join-Path $Path $localConfigName) -NoClobber
}

Function Get-ExePathsFromConfigs {
    Param (
        [Hashtable[]] $Configs,
        [String] $name
    )

    $patterns = `
      $Configs | `
      ForEach-Object { Get-HashtaleItem $name $_ } | `
      Where-Object { $null -ne $_ } | `
      ForEach-Object -Begin { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('UseDeclaredVarsMoreThanAssignments', 'paths')] $paths = @() } -Process { $paths += $_.Values } -End { $paths } | `
      Where-Object { -not [String]::IsNullOrEmpty($_) }
    If ($null -eq $patterns) {
        @()
    }
    $patterns
}

# GHC

Function Get-ChocoGhc {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin"
}

# .SYNOPSIS
#   Sets the version or variant of GHC to the Path environment variable of the current session.
Function Set-Ghc {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    [Hashtable] $cs = Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig
    $ghcDir = Get-HashtaleItem -Name 'ghc', $Ghc -Hashtable $cs
    If ($null -eq $ghcDir) {
        $ghcDir = Get-ChocoGhc $Ghc
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'ghc' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $ghcPathPattern
    Set-PathEnv $patterns $ghcDir
}

# .SYNOPSIS
#   Removes all GHC values from the Path environment variable of the current session.
Function Clear-Ghc {
    Set-PathEnv (Get-GhcPatterns (Get-Config (Find-LocalConfigPath (Get-Location))), (Get-Config $globalConfigPath)) $null
}

# .SYNOPSIS
#   Installs the specified GHC with the Chocolatey.
Function Install-Ghc {
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
Function Uninstall-Ghc {
    Param (
        [Parameter(Mandatory)][String] $Ghc
    )

    choco uninstall ghc --version $Ghc
}

# .SYNOPSIS
#   Shows the GHCs which is specified by the ghcups.yaml, is installed by the Chocolatey and is hosted on the Chocolatey repository.
Function Show-Ghc {
    $configPath = Find-LocalConfigPath (Get-Location)
    $config = Get-Config $configPath
    $span = $false
    If ($null -ne $config -and $null -ne $config['ghc'] -and 0 -lt $config['ghc'].Count) {
        Write-Host "$localConfigName ($(Split-Path $configPath -Parent))"
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

Function Get-ChocoCabal {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    "$Env:ChocolateyInstall\lib\cabal.$Cabal\tools\cabal-$Cabal"
}

# .SYNOPSIS
#   Sets the version or variant of Cabal to the Path environment variable of the current session.
Function Set-Cabal {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    $localConfig = Get-Config (Find-LocalConfigPath (Get-Location))
    $userGlobalConfig = Get-Config (Join-Path $userGlobalDataPath $globalConfigName)
    $systemGlobalConfig = Get-Config (Join-Path $systemGlobalDataPath $globalConfigName)
    $cabalDir = Get-HashtaleItem -Name 'cabal', $Cabal -Hashtable (Join-Hashtables $localConfig, $userGlobalConfig, $systemGlobalConfig)
    If ($null -eq $cabalDir) {
        $cabalDir = Get-ChocoCabal $Cabal
    }
    $patterns = Get-ExePathsFromConfigs $localConfig, $userGlobalConfig, $systemGlobalConfig 'cabal' | ForEach-Object { '\A' + [Regex]::Escape($_) + '\Z' }
    $patterns += $cabalPathPattern
    Set-PathEnv $patterns $cabalDir
}

# .SYNOPSIS
#   Removes all Cabal values from the Path environment variable of the current session.
Function Clear-Cabal {
    Set-PathEnv (Get-CabalPatterns (Get-Config (Find-LocalConfigPath (Get-Location))), (Get-Config $globalConfigPath)) $null
}

# .SYNOPSIS
#   Installs the specified Cabal with the Chocolatey.
Function Install-Cabal {
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
Function Uninstall-Cabal {
    Param (
        [Parameter(Mandatory)][String] $Cabal
    )

    choco uninstall cabal --version $Cabal
}

# .SYNOPSIS
#   Shows the Cabals which is specified by the ghcups.yaml, is installed by the Chocolatey and is hosted on the Chocolatey repository.
Function Show-Cabal {
    $configPath = Find-LocalConfigPath (Get-Location)
    $config = Get-Config $configPath
    $span = $false
    If ($null -ne $config -and $null -ne $config['cabal'] -and 0 -lt $config['cabal'].Count) {
        Write-Host "$localConfigName ($(Split-Path $configPath -Parent))"
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

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Uninstall-Ghc', 'Show-Ghc', 'Set-Cabal', 'Clear-Cabal', 'Install-Cabal', 'Uninstall-Cabal', 'Show-Cabal', 'Write-GhcupsConfigTemplate'
