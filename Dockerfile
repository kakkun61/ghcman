FROM mcr.microsoft.com/powershell

SHELL ["pwsh", "-Command"]

RUN Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

RUN choco install -y 7zip

RUN Set-PSRepository PSGallery

RUN Install-Module -Force powershell-yaml

CMD pwsh
