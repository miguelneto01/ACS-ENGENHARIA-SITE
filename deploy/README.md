# Publicar o site da ACS no homelab (Galaxy A20)

O site é **estático** (HTML, CSS, JavaScript, vídeos e fotos). Não tem backend, banco de dados, login nem tempo real. Por isso não há processo próprio nem porta 3001: o **nginx que já roda no Debian** entrega os arquivos direto, num bloco novo na porta **8081**, separado do primeiro sistema (porta 8080). O consumo extra de memória é praticamente zero.

| Item | Onde fica |
|---|---|
| Site | `/opt/acs-site` (versão anterior em `/opt/acs-site.anterior`) |
| Bloco do nginx | `/etc/nginx/conf.d/acs-site.conf` (ou `sites-available` + link, conforme o seu nginx) |
| Porta interna | `127.0.0.1:8081` (só o próprio celular acessa; o público entra pelo Cloudflare Tunnel) |
| Logs | `/var/log/nginx/acs-site.access.log` e `/var/log/nginx/acs-site.error.log` (no Debian) |
| Backups antes de cada instalação | `/root/backups/antes-acs-site-DATA.tar.gz` (no Debian, guarda os 5 últimos) |
| Banco de dados | não existe |

Todos os comandos abaixo rodam no **PowerShell do PC**, na pasta do repositório clonado. Nenhum deles mostra ou pede senha.

---

## Passo 1 — Reconhecimento (somente leitura)

Lê como o primeiro sistema sobe, quem inicia o nginx e como o túnel está configurado. Senhas e tokens aparecem como `***`; do `gest-confec.env` saem só os **nomes** das variáveis.

```powershell
Get-Content -Raw .\deploy\reconhecimento.sh | ssh homelab "tr -d '\r' | bash -s" | Tee-Object reconhecimento.txt
```

Confira o `reconhecimento.txt` antes de compartilhar com alguém. Pontos que decidem os próximos passos:
- **Quem inicia o nginx no boot** (seções "scripts de boot" e "iniciar.sh").
- **Caminho do Debian** (seção "caminho do Debian"): deve terminar em `installed-rootfs/debian`. Se for outro, ajuste `$Rootfs` em `publicar.ps1` e `backup-acs.ps1`.
- **Túnel**: se aparece um `config.yml` com `ingress:`, o túnel é por arquivo; se o cloudflared roda com `--token`, ele é gerenciado pelo painel.
- **Porta 8081 livre** e **nginx -t** passando.

## Passo 2 — Instalar (ou atualizar)

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\publicar.ps1
```

O script empacota o site, envia ao celular e roda `instalar.sh` no Debian, que:
1. para sem mexer em nada se o `nginx -t` atual já falhar ou se a porta 8081 estiver em uso;
2. faz **backup** de `/etc/nginx` e da versão atual do site;
3. troca os arquivos de uma vez (a versão anterior fica guardada);
4. instala o bloco do nginx, roda **`nginx -t`** e só então recarrega; se o teste falhar, desfaz;
5. testa a página, o mapa, o vídeo (pedido parcial, como o celular faz) e confirma que o **primeiro sistema responde igual a antes**.

Se o nginx não estiver rodando, o script **não** o inicia, para não concorrer com o supervisor do primeiro sistema.

**Para atualizar depois:** `git pull` no PC e o mesmo comando. Se só o conteúdo mudou, o nginx nem é recarregado.

**Para voltar à versão anterior** (no Debian):
```bash
mv /opt/acs-site /opt/acs-site.ruim && mv /opt/acs-site.anterior /opt/acs-site
```

## Passo 3 — Endereço público (Cloudflare Tunnel)

Escolha um hostname (ex.: um subdomínio do seu domínio no Cloudflare) e aponte para `http://localhost:8081`.

- **Túnel gerenciado pelo painel** (cloudflared com `--token`): Cloudflare Zero Trust → Networks → Tunnels → seu túnel → *Public Hostname* → *Add*: subdomínio e domínio escolhidos, *Service* `HTTP` e URL `localhost:8081`. Não precisa reiniciar nada.
- **Túnel por arquivo** (`config.yml`): acrescente, **antes** da regra final `- service: http_status:404`:
  ```yaml
    - hostname: SEU-HOSTNAME
      service: http://localhost:8081
  ```
  Depois reinicie só o cloudflared. O primeiro sistema pode ficar alguns segundos fora durante o reinício; faça num horário tranquilo.

## Passo 4 — Boot e reinício automático

O site depende só do nginx. Pelo reconhecimento:
- **Se o boot ou o `iniciar.sh` do primeiro sistema já inicia e vigia o nginx:** não faça nada. O site sobe e volta junto.
- **Se ninguém vigia o nginx:** instale o vigia opcional, **ao lado** do script existente (o `gest-confec` não é alterado):
  ```powershell
  scp .\deploy\termux-boot\acs-site homelab:.termux/boot/acs-site
  ssh homelab "sed -i 's/\r$//' ~/.termux/boot/acs-site && chmod +x ~/.termux/boot/acs-site && ls -la ~/.termux/boot"
  ```
  Ele espera 90 s após o boot e, a cada 2 minutos, inicia o nginx se ele tiver caído (com `nginx -t` antes). Registro em `~/acs-site-boot.log` no Termux.

## Passo 5 — Backup no PC

Copie `deploy\backup-acs.ps1` para `D:\Homelab\` e acrescente ao final do `D:\Homelab\backup.ps1`:
```powershell
. "$PSScriptRoot\backup-acs.ps1"
```
Ele salva o site e o bloco do nginx em `D:\Homelab\backups\acs-site\` e mantém as 10 cópias mais recentes. O conteúdo do site também está no GitHub.

---

## O que foi testado e o que não foi

**Testado** (num Debian/Ubuntu com nginx 1.24, simulando o primeiro sistema na 8080):
- instalação, reinstalação/atualização e recarga só quando o bloco muda;
- detecção de porta 8081 ocupada (várias formas de `listen`) e de configuração atual inválida, sem alterar nada;
- bloco com erro: `nginx -t` falha, o bloco é desfeito e os dois sites continuam no ar;
- página 200, mapa 200, vídeo com pedido parcial 206, pastas internas 404, cabeçalhos de segurança e cache;
- máscara de senhas e tokens do reconhecimento.

**Não testado** (depende do seu celular):
- o proot do Termux e o caminho do Debian;
- o `publicar.ps1` e o `backup-acs.ps1` no Windows (o `tar` do Windows 10/11 e o `scp`);
- o vigia de boot opcional;
- o Cloudflare Tunnel e o acesso pelo endereço público.
