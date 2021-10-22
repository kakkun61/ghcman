# Change log

## Unreleased

Support installing 7-Zip.

## 4.6

*2021.08.19*

Support GHC 8.10.6.

## 4.5

*2021.06.07*

Support GHC 8.10.5.

## 4.4

*2021.05.19*

Fix a bug that `Install-Ghc` adds an unexpected “)”.

## 4.3

*2021.05.19*

Support Cabal 3.4.0.0.

## 4.2

*2021.02.07*

Support GHC 8.10.4.

## 4.1

*2021.02.05*

Support 9.0.1.

## 4.0

*2020.12.31*

### Breaking changes

Remove PowerShell Desktop support.

### Others

Add tab completion for `Set-Ghc` and `Set-Cabal`.

## 3.9

*2020.12.31*

Support 8.10.3.

## 3.8

*2020.09.30*

Fix an issue about configs merging.

## 3.7

*2020.08.09*

Support 8.10.2.
`Show-Ghc` and `Show-Cabal` will be renamed to `Get-Ghc` and `Get-Cabal` respectively.
`-OnlySupported` and `-OnlyInstalled` options are added to `Get-Ghc` and `Get-Cabal`.

## 3.6

*2020.07.18*

Support 8.8.4.

## 3.5

Remove Microsoft.PowerShell.Core module from required modules.

## 3.4

Add Microsoft.PowerShell.Archive, Microsoft.PowerShell.Management and Microsoft.PowerShell.Utility modules to required modules. #13

## 3.3

The `-Set` option error of `Install-*` is fixed.

The unintentional bumping of the required PowerShell version is fixed.

The error on `Install-Module` may be fixed.

## 3.2

The version sorting bug is fixed.

## 3.1

`Show-*` returns objects. For humans, use the `-HumanReadable` option.

A bug about configuration merging is fixed

`Show-GhcupsConfig` is added.

## 3.0

### Breaking changes

The ghcups ≧ 3.0 cannot uninstall apps which is installed with the ghcups < 3.0. Please uninstall apps before upgrading the ghcups, or use the Chocolatey manually.

`-Ghc` and `-Cabal` options are renamed to `-Name` or `-Version`.

### Others

Now no dependencies on the Chocolatey.

Gets to depend on the 7-Zip.

Supports 32-bit Windows.

## 2.1

Fix the problem that `Show-*` and `Clear-*` ignore configurations other than the local one.

Add the feature of installation of the Chocolatey.

## 2.0.1

Fix README about #3.

## 2.0

### Breaking changes

Rename Remove-Ghc and Remove-Cabal to Uninstall-Ghc and Uninstall-Cabal respectively. #2

The global configuration file's name is changed from _ghcups.yaml_ to _config.yaml_.

### Others

The configuration search algorithm is changed. #1

Add the user global configuration. #3

## 1.0.1

Remove the files not to publish.

## 1.0

First release.
