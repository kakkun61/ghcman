# ghcups; ghcup for PowerShell on Windows

[![GitHub Actions: windows](https://github.com/kakkun61/ghcups/workflows/windows/badge.svg)](https://github.com/kakkun61/ghcups/actions?query=workflow%3Awindows) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/ghcups.svg)](https://www.powershellgallery.com/packages/ghcups/) [![Join the chat at https://gitter.im/ghcups/community](https://badges.gitter.im/ghcups/community.svg)](https://gitter.im/ghcups/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

## Dependency

This depends on the [7-Zip](https://sourceforge.net/projects/sevenzip/files/7-Zip/).

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

When you want to check the loaded configuration, use `Show-GhcupsConfig` function.

You can set _`$Env:GhcupsInstall`_ to specify the directory where GHCs and Cabals are installed. The default is _`$Env:APPDATA`\ghcups_.

## Functions

- `Install-Ghc`
  - Installs the specified GHC.
- `Uninstall-Ghc`
  - Uninstalls the specified GHC.
- `Set-Ghc`
  - Sets the version or variant of GHC to the Path environment variable of the current session.
- `Clear-Ghc`
  - Removes all GHC values from the Path environment variable of the current session.
- `Show-Ghc`
  - Shows the GHCs which are specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not yet installed..
- `Install-Cabal`
  - Installs the specified Cabal.
- `Uninstall-Cabal`
  - Uninstalls the specified Cabal.
- `Set-Cabal`
  - Sets the version or variant of Cabal to the Path environment variable of the current session.
- `Clear-Cabal`
  - Removes all Cabal values from the Path environment variable of the current session.
- `Show-Cabal`
  - Shows the Cabals which is specified by the ghcups.yaml and config.yaml, which is installed by the Ghcups and which is not yet installed..
- `Write-GhcupsConfigTemplate`
  - Creates the ghcups.yaml with the default contents.
- `Show-GhcupsConfig`
  - Shows the loaded configurations which are re-generated to YAML.
