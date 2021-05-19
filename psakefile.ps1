Task Import {
    Import-Module powershell-yaml, Pester, PSScriptAnalyzer
}

Task Test {
    Invoke-Pester
}

Task Lint {
    Invoke-ScriptAnalyzer . -Recurse -Severity Information
}

Task Publish {
    Publish-Module `
      -Name ..\ghcups `
      -NuGetApiKey (Get-Content .psg.key) `
      -Exclude '.github\**', '.vscode\**', '.psg.key', 'debug.log', 'Dockerfile'
}