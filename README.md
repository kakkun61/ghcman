# ghcman; ghcup for PowerShell on Windows

[![GitHub Actions: test](https://github.com/kakkun61/ghcman/workflows/test/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Atest) [![GitHub Actions: install](https://github.com/kakkun61/ghcman/workflows/install/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Ainstall) [![GitHub Actions: lint](https://github.com/kakkun61/ghcman/workflows/lint/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Alint) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/ghcman.svg)](https://www.powershellgallery.com/packages/ghcman/) [![Join the chat at https://gitter.im/ghcman/community](https://badges.gitter.im/ghcman/community.svg)](https://gitter.im/ghcman/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-red?logo=GitHub)](https://github.com/sponsors/kakkun61)

## ❗ Planned breaking changes

I will rename “ghcups” to “**ghcman**” in a half years on November 2021 ([discussion](https://github.com/kakkun61/ghcman/discussions/16)).

## Dependency

This depends on the [7-Zip](https://sourceforge.net/projects/sevenzip/). You must add the _7z_ to the `$Env:Path`.

## Install

Download and load ghcman to PowerShell.

```
> Install-Module ghcman
> Import-Module ghcman
```

Confirm its info.

```
> Get-Module ghcman

ModuleType Version    Name     ExportedCommands
---------- -------    ----     ----------------
Manifest   1.0        ghcman   {Clear-Cabal, Clear-Ghc, Install-Cabal, Install-Ghc...}
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

_ghcman.yaml_ is the local configuration file. ghcman searches it in the current directory and its parents recursively until _`$Env:USERPROFILE`_ or the root. The user global configuration file is _`$Env:APPDATA`\ghcman\config.yaml_, and the system global one is _`$Env:ProgramData`\ghcman\config.yaml_.

This is a sample of _ghcman.yaml_ and _config.yaml_.

```yaml
ghc:
  HEAD: somewhere\directory\which\contains\ghc
  fix-some-issue: other\directory

cabal:
  HEAD: somewhere\directory\which\contains\cabal
```

`Write-GhcmanConfigTemplate` function creates _ghcman.yaml_ with the template.

When you want to check the loaded configuration, use `Show-GhcmanConfig` function.

You can set _`$Env:GhcmanInstall`_ to specify the directory where GHCs and Cabals are installed. The default is _`$Env:APPDATA`\ghcman_.

## Functions

- `Install-Ghc`
  - Installs the specified GHC.
- `Uninstall-Ghc`
  - Uninstalls the specified GHC.
- `Set-Ghc`
  - Sets the version or variant of GHC to the Path environment variable of the current session.
- `Get-Ghc`
  - Gets the GHCs which are specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not yet installed.
- `Clear-Ghc`
  - Removes all GHC values from the Path environment variable of the current session.
- `Install-Cabal`
  - Installs the specified Cabal.
- `Uninstall-Cabal`
  - Uninstalls the specified Cabal.
- `Set-Cabal`
  - Sets the version or variant of Cabal to the Path environment variable of the current session.
- `Get-Cabal`
  - Gets the Cabals which is specified by the ghcman.yaml and config.yaml, which is installed by the Ghcman and which is not yet installed.
- `Clear-Cabal`
  - Removes all Cabal values from the Path environment variable of the current session.
- `Write-GhcmanConfigTemplate`
  - Creates the ghcman.yaml with the default contents.
- `Get-GhcmanConfig`
  - Gets the loaded configurations which are re-generated to YAML.
