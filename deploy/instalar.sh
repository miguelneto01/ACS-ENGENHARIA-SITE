#!/usr/bin/env bash
# Instala ou atualiza o site da ACS no Debian (proot) do homelab.
# Uso (dentro do Debian):  bash instalar.sh /root/acs-site.tar.gz
# - Faz backup antes de mudar qualquer coisa.
# - Não toca no primeiro sistema (/opt/gest-confec, porta 8080).
# - Só recarrega o nginx se "nginx -t" passar.
set -euo pipefail

PACOTE="${1:-/root/acs-site.tar.gz}"
SITE=/opt/acs-site
PORTA=8081
CONF_NOME=acs-site.conf
BACKUPS=/root/backups
DATA=$(date +%Y%m%d-%H%M%S)

ok()   { printf '  [ok] %s\n' "$1"; }
info() { printf '\n>> %s\n' "$1"; }
erro() { printf '\n[ERRO] %s\n' "$1" >&2; exit 1; }

[ -f /etc/debian_version ] || erro "Rode este script dentro do Debian (proot-distro login debian)."
[ "$(id -u)" = 0 ] || erro "Rode como root dentro do Debian."
[ -f "$PACOTE" ] || erro "Pacote não encontrado: $PACOTE"
for c in nginx tar curl; do command -v "$c" >/dev/null || erro "Comando ausente no Debian: $c"; done

# ---------------------------------------------------------------- 1. estado atual
info "Estado atual"
nginx -t >/dev/null 2>&1 || erro "A configuração atual do nginx já falha no 'nginx -t'. Corrija antes de instalar. Nada foi alterado."
ok "configuração atual do nginx é válida"
ANTES_8080=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8080/ || true)
ok "primeiro sistema (8080) responde HTTP $ANTES_8080"
OUTRO=$(nginx -T 2>/dev/null | awk -v p="$PORTA" '
  /^# configuration file /{ f=$4 }
  !/^[[:space:]]*#/ && $0 ~ "(^|[[:space:]{;])listen[[:space:]]+([^;]*[:[:space:]])?" p "([;[:space:]]|$)" { print f }' | grep -v "$CONF_NOME" | sort -u || true)
[ -z "$OUTRO" ] || erro "A porta $PORTA já é usada em: $OUTRO. Nada foi alterado."

# Onde o nginx deste Debian lê blocos extras
if grep -qE 'include[^;]*conf\.d/\*\.conf' /etc/nginx/nginx.conf; then
  CONF_DESTINO=/etc/nginx/conf.d/$CONF_NOME; LINK=""
elif grep -qE 'include[^;]*sites-enabled' /etc/nginx/nginx.conf; then
  CONF_DESTINO=/etc/nginx/sites-available/$CONF_NOME; LINK=/etc/nginx/sites-enabled/$CONF_NOME
else
  erro "nginx.conf não inclui conf.d nem sites-enabled. Nada foi alterado."
fi
ok "bloco do nginx vai para $CONF_DESTINO"

# ---------------------------------------------------------------- 2. backup
info "Backup antes de mudar"
mkdir -p "$BACKUPS"
ARQ_BKP="$BACKUPS/antes-acs-site-$DATA.tar.gz"
ITENS=(etc/nginx)
[ -d "$SITE" ] && ITENS+=("${SITE#/}")
tar -czf "$ARQ_BKP" -C / "${ITENS[@]}"
ok "backup em $ARQ_BKP"
ls -1t "$BACKUPS"/antes-acs-site-*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f   # guarda os 5 mais recentes

# ---------------------------------------------------------------- 3. arquivos do site
info "Copiando o site"
NOVO="$SITE.novo"
rm -rf "$NOVO"; mkdir -p "$NOVO"
tar -xzf "$PACOTE" -C "$NOVO"
[ -f "$NOVO/index.html" ] && [ -f "$NOVO/media/ceara.json" ] || { rm -rf "$NOVO"; erro "Pacote incompleto (falta index.html ou media/). Nada foi alterado."; }
CONF_NOVA="$NOVO/deploy/nginx/$CONF_NOME"
[ -f "$CONF_NOVA" ] || { rm -rf "$NOVO"; erro "Pacote sem deploy/nginx/$CONF_NOME."; }
chmod -R a+rX "$NOVO"
if [ -d "$SITE" ]; then rm -rf "$SITE.anterior"; mv "$SITE" "$SITE.anterior"; fi
mv "$NOVO" "$SITE"
ok "site em $SITE (versão anterior em $SITE.anterior, se havia)"

# ---------------------------------------------------------------- 4. nginx
info "Configurando o nginx"
mkdir -p /var/log/nginx
if [ -f "$CONF_DESTINO" ] && cmp -s "$CONF_DESTINO" "$SITE/deploy/nginx/$CONF_NOME"; then
  ok "bloco do nginx já está atualizado (sem recarregar)"
  RECARREGAR=0
else
  CONF_ANTIGA=""
  [ -f "$CONF_DESTINO" ] && { CONF_ANTIGA="$CONF_DESTINO.antes-$DATA"; cp "$CONF_DESTINO" "$CONF_ANTIGA"; }
  cp "$SITE/deploy/nginx/$CONF_NOME" "$CONF_DESTINO"
  [ -n "$LINK" ] && ln -sf "$CONF_DESTINO" "$LINK"
  if nginx -t 2>&1; then
    ok "nginx -t passou"
    RECARREGAR=1
    [ -n "$CONF_ANTIGA" ] && rm -f "$CONF_ANTIGA"
  else
    echo "nginx -t falhou: desfazendo."
    if [ -n "$CONF_ANTIGA" ]; then mv "$CONF_ANTIGA" "$CONF_DESTINO"; else rm -f "$CONF_DESTINO"; [ -n "$LINK" ] && rm -f "$LINK"; fi
    nginx -t >/dev/null 2>&1 && echo "configuração anterior restaurada e válida."
    erro "Bloco do nginx desfeito. O primeiro sistema não foi afetado."
  fi
fi
if [ "$RECARREGAR" = 1 ]; then
  if pgrep -x nginx >/dev/null 2>&1; then
    nginx -s reload && ok "nginx recarregado"
  else
    echo "  [aviso] o nginx não está rodando; quem o inicia é o supervisor do primeiro sistema."
    echo "          Não iniciei aqui para não concorrer com ele. Veja o README (seção Boot)."
  fi
fi
sleep 1

# ---------------------------------------------------------------- 5. testes
info "Testes"
FALHOU=0
t() { # descrição, código esperado, curl args...
  local d=$1 esp=$2; shift 2
  local c; c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$@" || true)
  if [ "$c" = "$esp" ]; then ok "$d (HTTP $c)"; else echo "  [FALHA] $d: esperado $esp, veio $c"; FALHOU=1; fi
}
t "página inicial"            200 "http://127.0.0.1:$PORTA/"
t "mapa (JSON)"               200 "http://127.0.0.1:$PORTA/media/ceara.json"
t "vídeo com Range (celular)" 206 -r 0-1023 "http://127.0.0.1:$PORTA/media/hero-540.mp4"
t "pasta deploy bloqueada"    404 "http://127.0.0.1:$PORTA/deploy/instalar.sh"
DEPOIS_8080=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 http://127.0.0.1:8080/ || true)
if [ "$DEPOIS_8080" = "$ANTES_8080" ]; then ok "primeiro sistema inalterado (HTTP $DEPOIS_8080)"; else echo "  [FALHA] primeiro sistema: antes $ANTES_8080, agora $DEPOIS_8080"; FALHOU=1; fi

info "Resumo"
echo "  site:    $SITE"
echo "  porta:   127.0.0.1:$PORTA (aponte o Cloudflare Tunnel para http://localhost:$PORTA)"
echo "  nginx:   $CONF_DESTINO"
echo "  logs:    /var/log/nginx/acs-site.access.log e acs-site.error.log"
echo "  backup:  $ARQ_BKP"
[ "$FALHOU" = 0 ] && echo "  status:  TUDO OK" || { echo "  status:  HÁ FALHAS ACIMA"; exit 2; }
