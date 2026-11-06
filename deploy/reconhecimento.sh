#!/data/data/com.termux/files/usr/bin/bash
# Reconhecimento do homelab — SOMENTE LEITURA. Não altera nada.
# Roda no Termux e entra no Debian para ler a configuração do primeiro sistema.
# Valores que pareçam senha, token ou chave aparecem como ***.

mascara() {
  sed -E \
    -e 's/(--token[= ]+)[^ ]+/\1***/Ig' \
    -e 's/(([A-Za-z_]*(TOKEN|SECRET|SENHA|PASS|PASSWORD|KEY|CHAVE|JWT|SALT)[A-Za-z_]*)[[:space:]]*[=:][[:space:]]*).*/\1***/Ig'
}

titulo() { printf '\n===== %s =====\n' "$1"; }

titulo "TERMUX: scripts de boot (~/.termux/boot)"
ls -la ~/.termux/boot 2>&1
for f in ~/.termux/boot/*; do
  [ -f "$f" ] || continue
  printf -- '--- %s\n' "$f"
  mascara < "$f"
done

titulo "TERMUX: processos relevantes"
ps -eo pid,args 2>/dev/null | grep -Ei 'cloudflared|nginx|node|iniciar|proot' | grep -v grep | mascara

titulo "TERMUX: caminho do Debian (proot)"
ls -d "$PREFIX"/var/lib/proot-distro/installed-rootfs/* 2>&1

titulo "TERMUX: cloudflared"
command -v cloudflared 2>&1
ls -la ~/.cloudflared 2>&1 | sed -E 's/[0-9a-f-]{36}\.json/<credencial>.json/'
[ -f ~/.cloudflared/config.yml ] && grep -Ev 'credentials-file|token' ~/.cloudflared/config.yml

titulo "MEMÓRIA E ESPAÇO (Termux)"
free -m 2>/dev/null || cat /proc/meminfo | head -3
df -h ~ 2>/dev/null | tail -1

proot-distro login debian -- bash -s <<'DEBIAN'
mascara() {
  sed -E \
    -e 's/(--token[= ]+)[^ ]+/\1***/Ig' \
    -e 's/(([A-Za-z_]*(TOKEN|SECRET|SENHA|PASS|PASSWORD|KEY|CHAVE|JWT|SALT)[A-Za-z_]*)[[:space:]]*[=:][[:space:]]*).*/\1***/Ig'
}
titulo() { printf '\n===== %s =====\n' "$1"; }

titulo "DEBIAN: /opt"
ls -la /opt

titulo "DEBIAN: /opt/gest-confec/iniciar.sh"
[ -f /opt/gest-confec/iniciar.sh ] && mascara < /opt/gest-confec/iniciar.sh || echo "(não encontrado)"

titulo "DEBIAN: nomes das variáveis em gest-confec.env (sem valores)"
for f in /opt/gest-confec/gest-confec.env /root/gest-confec.env /etc/gest-confec.env; do
  [ -f "$f" ] && { echo "--- $f"; grep -Eo '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$f" | tr -d ' ='; }
done

titulo "DEBIAN: nginx"
nginx -v 2>&1
grep -nE 'include|worker_processes|user ' /etc/nginx/nginx.conf
ls -la /etc/nginx/conf.d /etc/nginx/sites-enabled 2>&1
echo "--- portas em uso pelo nginx:"
nginx -T 2>/dev/null | grep -nE '^\s*listen' | sort -u
echo "--- teste de configuração atual:"
nginx -t 2>&1

titulo "DEBIAN: porta 8081 livre?"
if nginx -T 2>/dev/null | grep -qE 'listen[^;]*8081'; then echo "8081 JÁ USADA no nginx"; else echo "8081 não aparece no nginx"; fi
(command -v ss >/dev/null && ss -ltn 2>/dev/null | grep -E ':(3000|8080|8081)\b') || echo "(ss indisponível ou sem escutas nessas portas)"

titulo "DEBIAN: cloudflared"
command -v cloudflared 2>&1
for d in /root/.cloudflared /etc/cloudflared; do
  [ -d "$d" ] && { echo "--- $d"; ls -la "$d" | sed -E 's/[0-9a-f-]{36}\.json/<credencial>.json/'; [ -f "$d/config.yml" ] && grep -Ev 'credentials-file|token' "$d/config.yml"; }
done

titulo "DEBIAN: ferramentas"
for c in curl tar git ss pgrep; do printf '%-6s ' "$c"; command -v "$c" || echo "(ausente)"; done

titulo "DEBIAN: espaço em /opt"
df -h /opt | tail -1

titulo "DEBIAN: resposta atual do primeiro sistema"
curl -s -o /dev/null -w 'porta 8080 -> HTTP %{http_code}\n' http://127.0.0.1:8080/ 2>&1
curl -s -o /dev/null -w 'porta 3000 -> HTTP %{http_code}\n' http://127.0.0.1:3000/ 2>&1
DEBIAN

titulo "FIM DO RECONHECIMENTO (nada foi alterado)"
