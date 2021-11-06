# Call Invoke-Pester

Set-StrictMode -Version Latest

Import-Module powershell-yaml

Describe "Set-Ghc" {
    It "Add foo of config to the empty path" {
        $Env:Path = ''
        'ghc: { foo: ''C:\'' }' | Out-File ghcman.yaml
        Set-Ghc 'foo'
        $Env:Path | Should -Be 'C:\'
    }

    It "Add foo of config to the path which contains another directory which exits in config" {
        $Env:Path = 'D:\'
        'ghc: { foo: ''C:\'', bar: ''D:\'' }' | Out-File ghcman.yaml
        Set-Ghc 'foo'
        $Env:Path | Should -Be 'C:\'
    }

    It "Add foo of config to the path which contains another directory which does not exit in config" {
        $Env:Path = 'D:\'
        'ghc: { foo: ''C:\'' }' | Out-File ghcman.yaml
        Set-Ghc 'foo'
        $Env:Path | Should -Be 'C:\;D:\'
    }

    It "Add foo of config to the path which contains a subdirectory of foo" {
        $Env:Path = 'C:\Windows'
        'ghc: { foo: ''C:\'' }' | Out-File ghcman.yaml
        Set-Ghc 'foo'
        $Env:Path | Should -Be 'C:\;C:\Windows'
    }

    It "Add foo in system global config when local config exists" {
        $Env:Path = ''
        'ghc: { foo: ''C:\'' }' | Out-File "$Env:ProgramData\ghcman\config.yaml"
        'ghc: { bar: ''C:\Windows'' }' | Out-File ghcman.yaml
        Set-Ghc 'foo'
        $Env:Path | Should -Be 'C:\'
    }

    It "Add bar in user global config when local and system global configs exists" {
        $Env:Path = ''
        'ghc: { foo: ''C:\'' }' | Out-File "$Env:ProgramData\ghcman\config.yaml"
        'ghc: { bar: ''C:\Users'' }' | Out-File "$Env:APPDATA\ghcman\config.yaml"
        'ghc: { buz: ''C:\Windows'' }' | Out-File ghcman.yaml
        Set-Ghc 'bar'
        $Env:Path | Should -Be 'C:\Users'
    }

    BeforeAll {
        Set-Variable originalPath -Option Constant -Value "$Env:Path"
        Set-Variable originalProgramData -Option Constant -Value "$Env:ProgramData"
        Set-Variable originalAPPDATA -Option Constant -Value "$Env:APPDATA"
        Set-Variable originalPWD -Option Constant -Value "$PWD"
        Set-Variable originalGhcmanInstall -Option Constant -Value "$Env:GhcmanInstall"

        function New-TemporaryDirectory {
            $parent = [System.IO.Path]::GetTempPath()
            [String] $name = [System.Guid]::NewGuid()
            New-Item -ItemType Directory -Path (Join-Path $parent $name)
        }

        $Env:ProgramData = New-TemporaryDirectory
        New-Item -ItemType Directory -Path "$Env:ProgramData\ghcman"

        $Env:APPDATA = New-TemporaryDirectory
        New-Item -ItemType Directory -Path "$Env:APPDATA\ghcman"

        Import-Module -Force (Join-Path "$PSScriptRoot" 'ghcman.psm1')

        $tempPWD = New-TemporaryDirectory
        Set-Location $tempPWD

        $Env:GhcmanInstall = $tempPWD
    }

    AfterAll {
        Remove-Item $Env:ProgramData -Recurse -ErrorAction Ignore
        Set-Location $originalPWD
        Remove-Item $tempPWD -Recurse
        Set-Item Env:\Path -Value $originalPath
        Set-Item Env:\ProgramData -Value $originalProgramData
        Set-Item Env:\APPDATA -Value $originalAPPDATA
        Set-Item Env:\GhcmanInstall -Value $originalGhcmanInstall
    }

    AfterEach {
        Remove-Item 'ghcman.yaml' -ErrorAction Ignore
    }
}
