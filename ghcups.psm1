Set-Variable bridgeDir -Option Constant -Value "$Env:ProgramData\ghcups"
Set-Variable ghcPathRegex -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\ghc\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\ghc-[0-9]+\.[0-9]+\.[0-9]+\\bin')
Set-Variable cabalPathRegex -Option Constant -Value ([Regex]::Escape($Env:ChocolateyInstall) + '\\lib\\cabal.[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\tools\\cabal-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

Function Get-ChocoGhc() {
    Param (
        [Parameter(Mandatory)][String]$Ghc
    )

    "$Env:ChocolateyInstall\lib\ghc.$Ghc\tools\ghc-$Ghc\bin"
}

Function Set-Ghc() {
    Param (
        [Parameter(Mandatory)][String]$Ghc
    )

    Set-Item Env:\Path -Value ((,(Get-ChocoGhc $Ghc) + ((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $ghcPathRegex })) -Join ';')
}

Function Clear-Ghc() {
    Set-Item Env:\Path -Value (((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $ghcPathRegex }) -Join ';')
}

Function Install-Ghc() {
    Param (
        [Parameter(Mandatory)][String]$Ghc,
        [Switch]$Set = $false
    )

    choco install ghc --version $Ghc --side-by-side

    If ($Set) {
        Set-Ghc -Ghc $Ghc
    }
}

Function Remove-Ghc() {
    Param (
        [Parameter(Mandatory)][String]$Ghc
    )

    choco uninstall ghc --version $Ghc
}

Function Get-ChocoCabal() {
    Param (
        [Parameter(Mandatory)][String]$Cabal
    )

    "$Env:ChocolateyInstall\lib\cabal.$Cabal\tools\cabal-$Cabal"
}

Function Set-Cabal() {
    Param (
        [Parameter(Mandatory)][String]$Cabal
    )

    Set-Item Env:\Path -Value ((,(Get-ChocoCabal $Cabal) + ((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $cabalPathRegex })) -Join ';')
}

Function Clear-Cabal() {
    Set-Item Env:\Path -Value (((Get-ChildItem Env:\Path).Value -Split ';' | Where-Object { $_ -NotMatch $cabalPathRegex }) -Join ';')
}

Function Install-Cabal() {
    Param (
        [Parameter(Mandatory)][String]$Cabal,
        [Switch]$Set = $false
    )

    choco install cabal --version $Cabal --side-by-side

    If ($Set) {
        Set-Cabal -Cabal $Cabal -Method $Method
    }
}

Function Remove-Cabal() {
    Param (
        [Parameter(Mandatory)][String]$Cabal
    )

    choco uninstall cabal --version $Cabal
}

Export-ModuleMember -Function 'Set-Ghc', 'Clear-Ghc', 'Install-Ghc', 'Remove-Ghc', 'Set-Cabal', 'Clear-Cabal', 'Install-Cabal', 'Remove-Cabal'
