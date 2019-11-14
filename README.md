# ghcups; ghcup for PowerShell

## Install

Download and load this to PowerShell.

```
> git clone git@github.com:kakkun61/ghcups.git
> Import-Module ghcups
```

Show its info.

```
>  Get-Module ghcups

ModuleType Version    Name     ExportedCommands
---------- -------    ----     ----------------
Manifest   1.0        ghcups   {Clear-Ghc, Install-Ghc, Remove-Ghc, Set-Ghc}
```

## Auto load

Copy _ghcups_ folder under `Env:\PSModulePath` folder like _`$Env:USERPROFILE`\Documents\WindowsPowerShell\Modules_.
