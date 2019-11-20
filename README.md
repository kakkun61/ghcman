# ghcups; ghcup for PowerShell on Windows

[![GitHub Actions: windows](https://github.com/kakkun61/ghcups/workflows/windows/badge.svg)](https://github.com/kakkun61/ghcups/actions?query=workflow%3Awindows) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/ghcups.svg)](https://www.powershellgallery.com/packages/ghcups/)

## Install

Download and load ghcups to PowerShell.

```
> Install-Module ghcups
> Import-Module ghcups
```

Confirm its info.

```
> Get-Module ghcups

ModuleType Version    Name     ExportedCommands
---------- -------    ----     ----------------
Manifest   1.0        ghcups   {Clear-Cabal, Clear-Ghc, Install-Cabal, Install-Ghc...}
```

Show help. Add the `-Full` option for more details.

```
> Get-Help Set-Ghc

NAME
    Set-Ghc

SYNOPSIS
    Sets the version or variant of GHC to the Path environment variable of the current session.


SYNTAX
    Set-Ghc [-Ghc] <String> [<CommonParameters>]


DESCRIPTION


RELATED LINKS


```

## Configuration

_ghcups.yaml_ is the local configuration file. ghcups searches it in the current directory and its parents recursively until _`$Env:USERPROFILE`_ or the root. The user global configuration file is _`$Env:APPDATA`\ghcups\config.yaml_, and the system global one is _`$Env:ProgramData`\ghcups\config.yaml_.

This is a sample of _ghcups.yaml_ and _config.yaml_.

```yaml
ghc:
  HEAD: somewhere\directory\which\contains\ghc
  fix-some-issue: other\directory

cabal:
  HEAD: somewhere\directory\which\contains\cabal
```

`Write-GhcupsConfigTemplate` function creates _ghcups.yaml_ with the template.

## Functions

- `Install-Ghc`
  - Installs the specified GHC with the Chocolatey.
- `Uninstall-Ghc`
  - Uninstalls the specified GHC with the Chocolatey.
- `Set-Ghc`
  - Sets the version or variant of GHC to the Path environment variable of the current session.
- `Clear-Ghc`
  - Removes all GHC values from the Path environment variable of the current session.
- `Show-Ghc`
  - Shows the GHCs which is specified by the ghcups.yaml and config.yaml, which is installed by the Chocolatey and which is hosted on the Chocolatey repository.
- `Install-Cabal`
  - Installs the specified Cabal with the Chocolatey.
- `Uninstall-Cabal`
  - Uninstalls the specified Cabal with the Chocolatey.
- `Set-Cabal`
  - Sets the version or variant of Cabal to the Path environment variable of the current session.
- `Clear-Cabal`
  - Removes all Cabal values from the Path environment variable of the current session.
- `Show-Cabal`
  - Shows the Cabals which is specified by the ghcups.yaml and config.yaml, which is installed by the Chocolatey and which is hosted on the Chocolatey repository.
- `Write-GhcupsConfigTemplate`
  - Creats the ghcups.yaml with the default contents.
- `Install-Choco`
  - Install the Chocolatey.
