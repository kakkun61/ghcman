# ghcman; ghcup for PowerShell on Windows

[![GitHub Actions: test](https://github.com/kakkun61/ghcman/workflows/test/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Atest) [![GitHub Actions: install](https://github.com/kakkun61/ghcman/workflows/install/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Ainstall) [![GitHub Actions: lint](https://github.com/kakkun61/ghcman/workflows/lint/badge.svg)](https://github.com/kakkun61/ghcman/actions?query=workflow%3Alint) [![PowerShell Gallery](https://img.shields.io/powershellgallery/p/ghcman.svg)](https://www.powershellgallery.com/packages/ghcman/) [![Join the chat at https://gitter.im/ghcman/community](https://badges.gitter.im/ghcman/community.svg)](https://gitter.im/ghcman/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-red?logo=GitHub)](https://github.com/sponsors/kakkun61)

## ❗ Planned breaking changes

I will rename “ghcups” to “**ghcman**” in a half years on November 2021 ([discussion](https://github.com/kakkun61/ghcman/discussions/16)).

## Install

Download and load ghcman to PowerShell.

```powershell
> Install-Module ghcman
> Import-Module ghcman
```

Confirm its info.

```powershell
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

## How to use

Retrieve new versions data.

```powershell
> Update-GhcmanVersionFile
```

Install a specified GHC and set it to `$Env:Path`.

```powershell
> Install-Ghc 9.2.1
> Set-Ghc 9.2.1
> ghc --version
The Glorious Glasgow Haskell Compilation System, version 9.2.1
```

Install a specified Cabal and set it to `$Env:Path`.

```powershell
> Install-Cabal 3.4.0.0
> Set-Cabal 3.4.0.0
> cabal --version
cabal-install version 3.4.0.0
compiled using version 3.4.0.0 of the Cabal library
```

Check which versions are installed or not.

```powershell
> Get-Ghc -HumanReadable
9.2.1    S C:\Users\kazuki\AppData\Roaming\ghcman\ghc-9.2.1
9.0.1    S
8.10.6   S
8.10.5   S
8.10.4   S
8.10.3   S
8.10.2   S
8.10.1   S
8.8.4    S
8.8.3    S
8.8.2    S
8.8.1    S
8.6.5    S
8.6.4    S
8.6.3    S
8.6.2    S
8.6.1    S
8.4.4    S
8.4.3    S
8.4.2    S
8.4.1    S
8.2.2    S
8.2.1    S
8.0.2    S
8.0.1    S
S: supported
```

```powershell
> Get-Cabal -HumanReadable
3.4.0.0  S C:\Users\kazuki\AppData\Roaming\ghcman\cabal-3.4.0.0
3.2.0.0  S
3.0.0.0  S
2.4.1.0  S
2.4.0.0  S
2.2.0.0  S
2.0.0.1  S
2.0.0.0  S
S: supported
```

## Configuration

_ghcman.yaml_ is a local configuration file. ghcman searches it in the current directory and its parents recursively until _`$Env:USERPROFILE`_ or the root. A user global configuration file is _`$Env:APPDATA`\ghcman\config.yaml_, and a system global one is _`$Env:ProgramData`\ghcman\config.yaml_.

This is a sample of _ghcman.yaml_ and _config.yaml_.

```yaml
ghc:
  HEAD: somewhere\directory\which\contains\ghc
  fix-some-issue: other\directory

cabal:
  HEAD: somewhere\directory\which\contains\cabal
```

`Write-GhcmanConfigTemplate` function creates _ghcman.yaml_ with the template.

When you want to check the loaded configuration, use `Get-GhcmanConfig` function.

You can set _`$Env:GhcmanInstall`_ to specify a directory where GHCs and Cabals are installed. Its default is _`$Env:APPDATA`\ghcman_.

- _.\ghcman.yaml_
  - local configuration
- _`$Env:APPDATA`\ghcman\config.yaml_
  - user global configuration
- _`$Env:ProgramData`\ghcman\config.yaml_
  - system global configuration
- _`$Env:GhcmanInstall`_
  - installation directory
  - default: _`$Env:APPDATA`\ghcman_

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
- `Update-GhcmanVersionFile`
  - Download versions data.
