# Change log

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
