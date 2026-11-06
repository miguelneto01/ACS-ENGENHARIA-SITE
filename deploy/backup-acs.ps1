# Backup do site da ACS no homelab — para incluir no D:\Homelab\backup.ps1.
# Copie este arquivo para D:\Homelab\ e acrescente ao final do backup.ps1 a linha:
#     . "$PSScriptRoot\backup-acs.ps1"
# Ele guarda o site (/opt/acs-site) e o bloco do nginx em D:\Homelab\backups\acs-site\,
# mantendo as 10 cópias mais recentes. Não mostra nem pede senhas.

$AcsDestino = 'D:\Homelab\backups\acs-site'
$AcsRootfs  = '/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian'
$AcsData    = Get-Date -Format 'yyyyMMdd-HHmmss'
$AcsArquivo = "acs-site-$AcsData.tar.gz"

New-Item -ItemType Directory -Force -Path $AcsDestino | Out-Null
Write-Host '>> Backup ACS: gerando no celular...'
ssh homelab "proot-distro login debian -- bash -c 'cd / && tar -czf /root/$AcsArquivo opt/acs-site `$(ls etc/nginx/conf.d/acs-site.conf etc/nginx/sites-available/acs-site.conf 2>/dev/null)'"
if ($LASTEXITCODE -ne 0) { Write-Warning 'Backup ACS: falha ao gerar no celular.'; return }

scp "homelab:$AcsRootfs/root/$AcsArquivo" (Join-Path $AcsDestino $AcsArquivo)
$AcsOk = ($LASTEXITCODE -eq 0)
ssh homelab "rm -f $AcsRootfs/root/$AcsArquivo"
if (-not $AcsOk) { Write-Warning 'Backup ACS: falha ao copiar para o PC.'; return }

Get-ChildItem $AcsDestino -Filter 'acs-site-*.tar.gz' | Sort-Object LastWriteTime -Descending |
  Select-Object -Skip 10 | Remove-Item
Write-Host ">> Backup ACS: $AcsDestino\$AcsArquivo"
