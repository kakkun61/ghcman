$bridgeDir = "$Env:ProgramData\ghcups"
$ghcPathRegex = [Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\ghc-[0-9]+\.[0-9]+\.[0-9]+\\bin'
$cabalPathRegex = [Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\cabal-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'

Function Get-ChocoGhc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin"
}

Function Set-GhcAlias() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    Set-Alias -Scope Global ghc "$(Get-ChocoGhc $Ghc)\ghc.exe"
    Set-Alias -Scope Global ghci "$(Get-ChocoGhc $Ghc)\ghci.exe"
    Set-Alias -Scope Global ghc-pkg "$(Get-ChocoGhc $Ghc)\ghc-pkg.exe"
    Set-Alias -Scope Global haddock "$(Get-ChocoGhc $Ghc)\haddock.exe"
    Set-Alias -Scope Global hp2ps "$(Get-ChocoGhc $Ghc)\hp2ps.exe"
    Set-Alias -Scope Global hpc "$(Get-ChocoGhc $Ghc)\hpc.exe"
    Set-Alias -Scope Global hsc2hs "$(Get-ChocoGhc $Ghc)\hsc2hs.exe"
    Set-Alias -Scope Global runghc "$(Get-ChocoGhc $Ghc)\runghc.exe"
    Set-Alias -Scope Global runhaskell "$(Get-ChocoGhc $Ghc)\runhaskell.exe"
}

Function Set-GhcBridge() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    If (-not (Test-Path "$bridgeDir")) {
        New-Item -ItemType Directory -Path "$bridgeDir" | Out-Null
    }

    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\ghc.exe @Args" -FilePath "$bridgeDir\ghc.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\ghci.exe @Args" -FilePath "$bridgeDir\ghci.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\ghc-pkg.exe @Args" -FilePath "$bridgeDir\ghc-pkg.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\haddock.exe @Args" -FilePath "$bridgeDir\haddock.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\hp2ps.exe @Args" -FilePath "$bridgeDir\hp2ps.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\hpc.exe @Args" -FilePath "$bridgeDir\hpc.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\hsc2hs.exe @Args" -FilePath "$bridgeDir\hsc2hs.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\runghc.exe @Args" -FilePath "$bridgeDir\runghc.ps1"
    Out-File -InputObject "$(Get-ChocoGhc $Ghc)\runhaskell.exe @Args" -FilePath "$bridgeDir\runhaskell.ps1"

    If (-not ("$Env:PATH" -Match [regex]::escape("$bridgeDir"))) {
        Write-Host "Add `"$bridgeDir`" to the PATH enviroment variable"
    }
}

Function Set-GhcEnv() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    Set-Item Env:\Path -Value ((,(Get-ChocoGhc $Ghc) + ((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $ghcPathRegex })) -Join ';')
}

Function Set-Ghc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc,
        [ValidateSet('alias', 'bridge', 'env')]$Method = 'alias'
    )

    Switch ($Method) {
        'alias' {
            Set-GhcAlias -Ghc $Ghc
        }
        'bridge' {
            Set-GhcBridge -Ghc $Ghc
        }
        'env' {
            Set-GhcEnv -Ghc $Ghc
        }
    }
}

Function Clear-Ghc() {
    Param (
        [ValidateSet('alias', 'bridge', 'env')]$Method = 'alias'
    )

    Switch ($method) {
        'alias' {
            Remove-Item Alias:\ghc
            Remove-Item Alias:\ghci
            Remove-Item Alias:\ghc-pkg
            Remove-Item Alias:\haddock
            Remove-Item Alias:\hp2ps
            Remove-Item Alias:\hpc
            Remove-Item Alias:\hsc2hs
            Remove-Item Alias:\runghc
            Remove-Item Alias:\runhaskell
        }
        'bridge' {
            Remove-Item "$bridgeDir\ghc.ps1"
            Remove-Item "$bridgeDir\ghci.ps1"
            Remove-Item "$bridgeDir\ghc-pkg.ps1"
            Remove-Item "$bridgeDir\haddock.ps1"
            Remove-Item "$bridgeDir\hp2ps.ps1"
            Remove-Item "$bridgeDir\hpc.ps1"
            Remove-Item "$bridgeDir\hsc2hs.ps1"
            Remove-Item "$bridgeDir\runghc.ps1"
            Remove-Item "$bridgeDir\runhaskell.ps1"
        }
        'env' {
            Set-Item Env:\Path -Value (((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $ghcPathRegex }) -Join ';')
        }
    }
}

Function Install-Ghc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc,
        [Switch]$Set = $false,
        [ValidateSet('alias', 'bridge')]$Method = 'alias'
    )

    choco install ghc --version $Ghc --side-by-side

    If ($Set) {
        Set-Ghc -Ghc $Ghc -Method $Method
    }
}

Function Remove-Ghc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    choco uninstall ghc --version $Ghc
}

Function Get-ChocoCabal() {
    Param (
        [Parameter(Mandatory)][string]$Cabal
    )

    "$Env:ChocolateyInstall\lib\cabal.$Cabal\tools\cabal-$Cabal"
}

Function Set-CabalAlias() {
    Param (
        [Parameter(Mandatory)][string]$Cabal
    )

    Set-Alias -Scope Global cabal "$(Get-ChocoCabal $Cabal)\cabal.exe"
}

Function Set-CabalBridge() {
    Param (
        [Parameter(Mandatory)][string]$Cabal
    )

    If (-not (Test-Path "$bridgeDir")) {
        New-Item -ItemType Directory -Path "$bridgeDir" | Out-Null
    }

    Out-File -InputObject "$(Get-ChocoCabal $Cabal)\cabal.exe @Args" -FilePath "$bridgeDir\cabal.ps1"

    If (-not ("$Env:PATH" -Match [regex]::escape("$bridgeDir"))) {
        Write-Host "Add `"$bridgeDir`" to the PATH enviroment variable"
    }

Function Set-CabalEnv() {
    Param (
        [Parameter(Mandatory)][string]$Cabal
    )

    Set-Item Env:\Path -Value ((,(Get-ChocoCabal $Cabal) + ((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $cabalPathRegex })) -Join ';')
}

Function Set-Cabal() {
    Param (
        [Parameter(Mandatory)][string]$Cabal,
        [ValidateSet('alias', 'bridge', 'env')]$Method = 'alias'
    )

    Switch ($Method) {
        'alias' {
            Set-CabalAlias -Cabal $Cabal
        }
        'bridge' {
            Set-CabalBridge -Cabal $Cabal
        }
        'env' {
            Set-CabalEnv -Cabal $Cabal
        }
    }
}

Function Clear-Cabal() {
    Param (
        [ValidateSet('alias', 'bridge', 'env')]$Method = 'alias'
    )

    Switch ($method) {
        'alias' {
            Remove-Item Alias:\cabal
        }
        'bridge' {
            Remove-Item "$bridgeDir\cabal.ps1"
        }
        'env' {
            Set-Item Env:\Path -Value (((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $cabalPathRegex }) -Join ';')
        }
    }
}

Function Install-Cabal() {
    Param (
        [Parameter(Mandatory)][string]$Cabal,
        [Switch]$Set = $false,
        [ValidateSet('alias', 'bridge')]$Method = 'alias'
    )

    choco install cabal --version $Cabal --side-by-side

    If ($Set) {
        Set-Cabal -Cabal $Cabal -Method $Method
    }
}

Function Remove-Cabal() {
    Param (
        [Parameter(Mandatory)][string]$Cabal
    )

    choco uninstall cabal --version $Cabal
}

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Remove-Ghc', 'Set-Cabal', 'Clear-Cabal', 'Install-Cabal', 'Remove-Cabal'
