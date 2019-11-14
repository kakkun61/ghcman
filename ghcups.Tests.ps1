# Call Invoke-Pester

Set-StrictMode -Version Latest

Import-Module powershell-yaml
Import-Module -Force (Join-Path "$PSScriptRoot" 'ghcups.psm1')

Describe "Set-Ghc" {
    It "Add 8.8.1 to the empty path" {
        $Env:Path = ''
        Set-Ghc 8.8.1
        $Env:Path | Should Be "$Env:ChocolateyInstall\lib\ghc.8.8.1\tools\ghc-8.8.1\bin"
    }

    It "Add 8.8.1 to the path which contains 8.6.5" {
        $Env:Path = "$Env:ChocolateyInstall\lib\ghc.8.6.5\tools\ghc-8.6.5\bin"
        Set-Ghc 8.8.1
        $Env:Path | Should Be "$Env:ChocolateyInstall\lib\ghc.8.8.1\tools\ghc-8.8.1\bin"
    }

    It "Add foo of config to the empty path" {
        $Env:Path = ''
        'ghc: { foo: ''C:\'' }' | Out-File ghcups.yaml
        Set-Ghc 'foo'
        $Env:Path | Should Be 'C:\'
    }

    It "Add foo of config to the path which contains another directory which exits in config" {
        $Env:Path = 'D:\'
        'ghc: { foo: ''C:\'', bar: ''D:\'' }' | Out-File ghcups.yaml
        Set-Ghc 'foo'
        $Env:Path | Should Be 'C:\'
    }

    It "Add foo of config to the path which contains another directory which does not exit in config" {
        $Env:Path = 'D:\'
        'ghc: { foo: ''C:\'' }' | Out-File ghcups.yaml
        Set-Ghc 'foo'
        $Env:Path | Should Be 'C:\;D:\'
    }

    It "Add foo of config to the path which contains a subdirectory of foo" {
        $Env:Path = 'C:\Windows'
        'ghc: { foo: ''C:\'' }' | Out-File ghcups.yaml
        Set-Ghc 'foo'
        $Env:Path | Should Be 'C:\;C:\Windows'
    }

    AfterEach {
        Remove-Item 'ghcups.yaml' -ErrorAction Ignore
    }
}
