# Publica (instala ou atualiza) o site da ACS no homelab.
# Rode no PowerShell do PC, na pasta do repositório:
#     powershell -ExecutionPolicy Bypass -File .\deploy\publicar.ps1
# Usa o alias SSH "homelab". Não pede nem mostra senhas.

$ErrorActionPreference = 'Stop'
$Repo   = Split-Path -Parent $PSScriptRoot
$Rootfs = '/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian'
$Pacote = Join-Path $env:TEMP 'acs-site.tar.gz'

Write-Host '>> Conferindo o acesso ao homelab...'
ssh homelab "test -d $Rootfs/root && echo ok-rootfs"
if ($LASTEXITCODE -ne 0) { throw "Não achei o Debian em $Rootfs. Rode o reconhecimento e me mande a saída." }

Write-Host '>> Empacotando o site...'
if (Test-Path $Pacote) { Remove-Item $Pacote }
tar -czf $Pacote -C $Repo --exclude=.git --exclude=marca --exclude=*.zip .
if ($LASTEXITCODE -ne 0) { throw 'Falha ao empacotar.' }
'{0:N1} MB' -f ((Get-Item $Pacote).Length / 1MB) | Write-Host

Write-Host '>> Enviando para o celular...'
scp $Pacote "homelab:$Rootfs/root/acs-site.tar.gz"
scp (Join-Path $PSScriptRoot 'instalar.sh') "homelab:$Rootfs/root/acs-instalar.sh"
if ($LASTEXITCODE -ne 0) { throw 'Falha no envio.' }

Write-Host '>> Instalando no Debian (backup, nginx -t, recarga e testes)...'
ssh -t homelab "proot-distro login debian -- bash -c `"sed -i 's/\r$//' /root/acs-instalar.sh && bash /root/acs-instalar.sh /root/acs-site.tar.gz`""
if ($LASTEXITCODE -ne 0) { throw "A instalação terminou com erro (código $LASTEXITCODE). Veja as mensagens acima." }

Remove-Item $Pacote
Write-Host '>> Pronto.'
