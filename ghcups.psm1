$bridgeDir = "$Env:ProgramData\ghcups"

Function Get-ChocoGhc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin\ghc.exe"
}

Function Set-GhcAlias() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    Set-Alias -Scope Global ghc (Get-ChocoGhc $Ghc)
}

Function Set-GhcBridge() {
    Param (
        [Parameter(Mandatory)][string]$Ghc
    )

    If (-not (Test-Path "$bridgeDir")) {
        New-Item -ItemType Directory -Path "$bridgeDir" | Out-Null
    }

    Out-File -InputObject "$(Get-ChocoGhc $Ghc) @Args" -FilePath "$bridgeDir\ghc.ps1"

    If (-not ("$Env:PATH" -Match [regex]::escape("$bridgeDir\ghc"))) {
        Write-Host "Add `"$bridgeDir`" to the PATH enviroment variable"
    }
}

Function Set-Ghc() {
    Param (
        [Parameter(Mandatory)][string]$Ghc,
        [ValidateSet('alias', 'bridge')]$Method = 'alias'
    )

    Switch ($Method) {
        'alias' {
            Set-GhcAlias -Ghc $Ghc
        }
        'bridge' {
            Set-GhcBridge -Ghc $Ghc
        }
    }
}

Function Clear-Ghc() {
    Param (
        [ValidateSet('alias', 'bridge')]$Method = 'alias'
    )

    Switch ($method) {
        'alias' {
            Remove-Item Alias:\ghc
        }
        'bridge' {
            Remove-Item "$bridgeDir\ghc.ps1"
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

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Remove-Ghc'
