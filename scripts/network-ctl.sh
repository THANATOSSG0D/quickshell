#!/usr/bin/env bash
# network-ctl.sh — Controle de rede para o Quickshell
#
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
# Saída sempre usa "|" como separador — sem problemas de locale ou ":" em nomes.
# ESTRATÉGIA LOCALE-INVARIANTE:
#   • Em vez de parsear STATE (texto traduzido), verifica se o campo
#     CONNECTION está preenchido (não vazio e não "--").
#     CONNECTION preenchido = dispositivo conectado, em qualquer locale.
#   • Para wifi radio: usa "nmcli -g WIFI radio" que sempre retorna en.

export LANG=C LC_ALL=C

# ── Estado próprio (NÃO GUARDA SENHA — só metadados não-sensíveis) ───────────
# A senha em si nunca passa por aqui: quem guarda e protege o segredo é o
# próprio NetworkManager, no mesmo arquivo/keyfile que nmcli e nmtui usam
# (/etc/NetworkManager/system-connections/*.nmconnection, root:root, modo
# 600). O que a gente guarda aqui é só:
#   last-ssid              → nome da última rede conectada com sucesso
#   autoreconnect-enabled  → flag (existe = ligado) do toggle do usuário
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-network"
mkdir -p "$STATE_DIR" 2>/dev/null
LAST_WIFI_FILE="$STATE_DIR/last-ssid"
AUTORECONNECT_FLAG="$STATE_DIR/autoreconnect-enabled"

# ── Helpers ──────────────────────────────────────────────────────────────────

eth_dev() {
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
        | awk -F: '$2=="ethernet" && $3!="unmanaged" {print $1; exit}'
}

wifi_dev() {
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
        | awk -F: '$2=="wifi" && $3!="unmanaged" && $2!="wifi-p2p" {print $1; exit}'
}

# Verifica se dispositivo está conectado pela presença do campo CONNECTION
# Funciona em qualquer locale — CONNECTION é nome de perfil, não texto traduzido.
dev_has_connection() {
    local dev="$1"
    local conn
    conn=$(nmcli -t -f DEVICE,CONNECTION device status 2>/dev/null \
        | awk -F: -v d="$dev" '$1==d {
            out=""
            for(i=2;i<=NF;i++) out=(i==2)?$i:out":"$i
            print out; exit
          }')
    [ -n "$conn" ] && [ "$conn" != "--" ] && echo "connected" || echo "disconnected"
}

dev_connection() {
    nmcli -t -f DEVICE,CONNECTION device status 2>/dev/null \
        | awk -F: -v d="$1" '$1==d {
            out=""
            for(i=2;i<=NF;i++) out=(i==2)?$i:out":"$i
            print out; exit
          }'
}

# Acha o UUID do perfil de conexão salvo cujo SSID (802-11-wireless.ssid)
# bate com o SSID dado — em vez de assumir que o nome do perfil == SSID.
# Isso é o que causava o "esquecimento" de senha: nmcli cria perfis com
# sufixo (ex.: "MinhaRede-1") quando já existe um perfil com aquele nome,
# e a busca antiga (nmcli connection show "$ssid") nunca achava o perfil
# novo na tentativa seguinte, então sempre parecia que a senha não tinha
# sido salva.
wifi_profile_for_ssid() {
    local ssid="$1"
    while IFS=: read -r uuid _name; do
        [ -z "$uuid" ] && continue
        local psid
        psid=$(nmcli -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null)
        if [ "$psid" = "$ssid" ]; then
            echo "$uuid"
            return 0
        fi
    done < <(nmcli -t -f UUID,NAME,TYPE connection show 2>/dev/null \
              | awk -F: '$3=="802-11-wireless"{print $1":"$2}')
    return 1
}

# Grava a última rede conectada com sucesso e, se o autoreconnect estiver
# ligado, migra o autoconnect/priority do NM pra essa rede (e tira da
# anterior, pra não ir acumulando redes com autoconnect=yes).
_record_last_ssid() {
    local ssid="$1"
    local prev
    prev=$(cat "$LAST_WIFI_FILE" 2>/dev/null)
    echo "$ssid" > "$LAST_WIFI_FILE" 2>/dev/null

    if [ -f "$AUTORECONNECT_FLAG" ]; then
        if [ -n "$prev" ] && [ "$prev" != "$ssid" ]; then
            local prev_uuid
            prev_uuid=$(wifi_profile_for_ssid "$prev")
            [ -n "$prev_uuid" ] && nmcli connection modify "$prev_uuid" \
                connection.autoconnect no >/dev/null 2>&1
        fi
        local cur_uuid
        cur_uuid=$(wifi_profile_for_ssid "$ssid")
        [ -n "$cur_uuid" ] && nmcli connection modify "$cur_uuid" \
            connection.autoconnect yes connection.autoconnect-priority 10 \
            >/dev/null 2>&1
    fi
}

# ── Comandos ─────────────────────────────────────────────────────────────────

cmd_status() {
    # WiFi radio — -g sempre retorna "enabled"/"disabled" em inglês
    local radio
    radio=$(nmcli -g WIFI radio 2>/dev/null | tr -d '[:space:]')
    local radio_on="off"
    [ "$radio" = "enabled" ] && radio_on="on"
    echo "WIFI_RADIO=${radio_on}"

    local wdev
    wdev=$(wifi_dev)
    echo "WIFI_DEV=${wdev}"

    if [ "$radio_on" = "on" ] && [ -n "$wdev" ]; then
        # IMPORTANTE: --rescan no aqui. "status" só precisa do SSID já
        # conectado (se houver) — não da lista completa de redes. Sem
        # --rescan no, o nmcli usa a política padrão "auto" e dispara um
        # scan de WiFi ATIVO sempre que o cache estiver "velho" (ex.: logo
        # após o boot, ou >30s desde o último scan), o que pode levar vários
        # segundos e travar tanto o tooltip quanto o painel. --rescan no usa
        # só o cache já existente do NetworkManager, praticamente instantâneo.
        local ssid
        ssid=$(nmcli --escape no -t -f IN-USE,SSID device wifi list --rescan no 2>/dev/null \
            | awk -F: '$1=="*" {sub(/^\*:/, ""); print; exit}')
        echo "WIFI_SSID=${ssid}"
    else
        echo "WIFI_SSID="
    fi

    local edev
    edev=$(eth_dev)
    echo "ETH_DEV=${edev}"
    if [ -n "$edev" ]; then
        local estate econn
        estate=$(dev_has_connection "$edev")
        econn=$(dev_connection "$edev")
        if [ "$estate" = "connected" ]; then
            echo "ETH_CONNECTED=true"
            echo "ETH_CONN=${econn}"
        else
            echo "ETH_CONNECTED=false"
            echo "ETH_CONN="
        fi
    else
        echo "ETH_CONNECTED=false"
        echo "ETH_CONN="
    fi
}

cmd_wifi_list() {
    # --rescan no: essa função é usada tanto pelo tooltip/status quanto pelo
    # botão "list" do painel. A varredura ativa fica só em cmd_wifi_scan,
    # que é chamada explicitamente quando o usuário pede pra atualizar a
    # lista. Sem isso, o nmcli decide sozinho quando rescanear (política
    # "auto"), o que pode travar essa função por vários segundos.
    nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null \
        | awk -F: '
            {
                inuse = $1
                line = $0
                sub(/^[^:]*:/, "", line)
                n = split(line, parts, ":")
                security = parts[n]
                signal   = parts[n-1]
                ssid = ""
                for (i = 1; i <= n-2; i++) {
                    ssid = (i == 1) ? parts[i] : ssid ":" parts[i]
                }
                if (ssid == "" || ssid == "--") next
                if (security == "--" || security == "") security = ""
                print inuse "|" ssid "|" signal "|" security
            }
        ' | sort -t'|' -k1,1r -k3,3rn | awk -F'|' '!seen[$2]++'
}

cmd_wifi_scan() {
    local wdev
    wdev=$(wifi_dev)
    if [ -z "$wdev" ]; then
        echo "ERR|Nenhum dispositivo WiFi encontrado" >&2
        exit 1
    fi
    nmcli device wifi rescan ifname "$wdev" 2>/dev/null
    sleep 2
    cmd_wifi_list
}

cmd_wifi_on()  { nmcli radio wifi on  2>/dev/null && echo "OK" || { echo "ERR|Falha ao ligar WiFi"    >&2; exit 1; } }
cmd_wifi_off() { nmcli radio wifi off 2>/dev/null && echo "OK" || { echo "ERR|Falha ao desligar WiFi" >&2; exit 1; } }


# Detecta erro de autorização do PolicyKit — a causa mais comum de "a senha
# não fica salva" em setups DIY tipo Hyprland: criar/alterar um perfil de
# conexão do NetworkManager exige autorização do polkit
# (org.freedesktop.NetworkManager.settings.modify.system), e sem um agente
# de autenticação rodando (hyprpolkitagent, polkit-gnome-authentication-
# agent-1, lxqt-policykit-agent etc.) o pedido falha silenciosamente — sem
# esse agente NADA fica gravado em disco, mas o nmcli não avisa isso de
# forma óbvia, e o script antigo engolia o stderr com "2>/dev/null".
_is_polkit_err() {
    echo "$1" | grep -qi "not authorized\|insufficient privileges\|polkit\|Not authorized to control networking"
}

cmd_wifi_connect() {
    local ssid="$1" pass="$2"
    [ -z "$ssid" ] && { echo "ERR|SSID não informado" >&2; exit 1; }

    local uuid
    uuid=$(wifi_profile_for_ssid "$ssid")

    # Perfil já existe e não veio senha nova — tenta subir com o que já
    # está salvo (fluxo normal de "clicar numa rede conhecida").
    if [ -n "$uuid" ] && [ -z "$pass" ]; then
        local out
        out=$(nmcli connection up "$uuid" 2>&1)
        if [ $? -eq 0 ]; then
            _record_last_ssid "$ssid"
            echo "OK|connected"; return
        fi
        if _is_polkit_err "$out"; then
            echo "ERR|Sem permissão do PolicyKit — falta um agente de autenticação rodando (ex.: hyprpolkitagent)" >&2
            exit 1
        fi
        # Provavelmente a senha salva está errada/expirada — pede de novo
        # em vez de insistir cego.
        echo "NEED_PASS"; return
    fi

    if [ -n "$pass" ]; then
        local out rc
        if [ -n "$uuid" ]; then
            # IMPORTANTE: atualiza a senha do perfil EXISTENTE em vez de
            # deixar "nmcli device wifi connect" criar um perfil duplicado
            # (era exatamente isso que fazia parecer que a senha "não
            # salvava" — o perfil novo nunca era achado na próxima vez).
            # wifi-sec.psk cobre WPA/WPA2-PSK, o caso mais comum; redes
            # WPA3-SAE/enterprise usam outra propriedade e continuam caindo
            # no fallback abaixo.
            nmcli connection modify "$uuid" wifi-sec.psk "$pass" >/dev/null 2>&1
            out=$(nmcli connection up "$uuid" 2>&1); rc=$?
        else
            out=$(nmcli device wifi connect "$ssid" password "$pass" 2>&1); rc=$?
        fi

        if [ $rc -eq 0 ] || echo "$out" | grep -qi "successfully"; then
            _record_last_ssid "$ssid"
            echo "OK|connected"
        elif _is_polkit_err "$out"; then
            echo "ERR|Sem permissão do PolicyKit — falta um agente de autenticação rodando (ex.: hyprpolkitagent)" >&2
            exit 1
        else
            echo "ERR|Falha: ${out}" >&2; exit 1
        fi
    else
        local out
        out=$(nmcli device wifi connect "$ssid" 2>&1)
        if echo "$out" | grep -qi "successfully"; then
            _record_last_ssid "$ssid"
            echo "OK|connected"
        elif _is_polkit_err "$out"; then
            echo "ERR|Sem permissão do PolicyKit — falta um agente de autenticação rodando (ex.: hyprpolkitagent)" >&2
            exit 1
        elif echo "$out" | grep -qi "password\|secret\|802-11"; then
            echo "NEED_PASS"
        else
            echo "ERR|Falha: $out" >&2; exit 1
        fi
    fi
}

# ── Reconexão automática ──────────────────────────────────────────────────
# Liga/desliga o autoconnect nativo do NetworkManager para a última rede
# conectada. Não existe daemon/timer nosso rodando em background: o próprio
# NetworkManager já reconecta sozinho a qualquer perfil salvo com
# autoconnect=yes assim que ele entra no alcance — é exatamente esse
# mecanismo nativo que a gente está ligando/desligando aqui, então funciona
# mesmo com o Quickshell fechado.
cmd_autoreconnect() {
    local sub="${1:-status}"
    case "$sub" in
        status)
            if [ -f "$AUTORECONNECT_FLAG" ]; then
                echo "AUTORECONNECT=on"
            else
                echo "AUTORECONNECT=off"
            fi
            local last=""
            [ -f "$LAST_WIFI_FILE" ] && last=$(cat "$LAST_WIFI_FILE")
            echo "LAST_SSID=${last}"
            ;;
        on)
            touch "$AUTORECONNECT_FLAG"
            local last uuid
            last=$(cat "$LAST_WIFI_FILE" 2>/dev/null)
            if [ -n "$last" ]; then
                uuid=$(wifi_profile_for_ssid "$last")
                if [ -n "$uuid" ]; then
                    nmcli connection modify "$uuid" connection.autoconnect yes \
                        connection.autoconnect-priority 10 >/dev/null 2>&1
                fi
            fi
            echo "OK"
            ;;
        off)
            rm -f "$AUTORECONNECT_FLAG"
            local last uuid
            last=$(cat "$LAST_WIFI_FILE" 2>/dev/null)
            if [ -n "$last" ]; then
                uuid=$(wifi_profile_for_ssid "$last")
                if [ -n "$uuid" ]; then
                    nmcli connection modify "$uuid" connection.autoconnect no >/dev/null 2>&1
                fi
            fi
            echo "OK"
            ;;
        try)
            # Opcional: reconexão "na mão" (ex.: botão "Reconectar agora"),
            # útil logo depois de ligar o toggle sem esperar o NM notar a
            # rede sozinho. Não é necessária para o autoconnect nativo
            # funcionar em segundo plano.
            [ ! -f "$AUTORECONNECT_FLAG" ] && { echo "SKIP|desligado"; return; }
            local wdev; wdev=$(wifi_dev)
            [ -z "$wdev" ] && { echo "SKIP|sem dispositivo"; return; }
            [ "$(dev_has_connection "$wdev")" = "connected" ] && { echo "SKIP|já conectado"; return; }
            local last; last=$(cat "$LAST_WIFI_FILE" 2>/dev/null)
            [ -z "$last" ] && { echo "SKIP|sem histórico"; return; }
            if ! nmcli --escape no -t -f SSID device wifi list --rescan no 2>/dev/null \
                | grep -Fxq "$last"; then
                echo "SKIP|fora de alcance"; return
            fi
            local uuid; uuid=$(wifi_profile_for_ssid "$last")
            [ -z "$uuid" ] && { echo "SKIP|perfil não encontrado"; return; }
            if nmcli connection up "$uuid" >/dev/null 2>&1; then
                echo "OK|reconectado a ${last}"
            else
                echo "ERR|falha ao reconectar" >&2; exit 1
            fi
            ;;
        *) echo "ERR|Subcomando autoreconnect desconhecido: $sub" >&2; exit 1 ;;
    esac
}

cmd_wifi_disconnect() {
    local wdev
    wdev=$(wifi_dev)
    [ -z "$wdev" ] && { echo "ERR|Nenhum dispositivo WiFi" >&2; exit 1; }
    nmcli device disconnect "$wdev" 2>/dev/null && echo "OK" || { echo "ERR|Falha ao desconectar" >&2; exit 1; }
}

cmd_eth_on()  {
    local dev="${1:-$(eth_dev)}"
    [ -z "$dev" ] && { echo "ERR|Nenhum dispositivo Ethernet" >&2; exit 1; }
    nmcli device connect    "$dev" 2>/dev/null && echo "OK" || { echo "ERR|Falha ao conectar $dev"    >&2; exit 1; }
}
cmd_eth_off() {
    local dev="${1:-$(eth_dev)}"
    [ -z "$dev" ] && { echo "ERR|Nenhum dispositivo Ethernet" >&2; exit 1; }
    nmcli device disconnect "$dev" 2>/dev/null && echo "OK" || { echo "ERR|Falha ao desconectar $dev" >&2; exit 1; }
}

cmd_eth_list() {
    # Saída: "DEVICE|CONNECTED|CONNECTION"
    # CONNECTED = "true" ou "false" — sem texto de STATE traduzido.
    # Usa campo CONNECTION para determinar estado, igual ao tile.
    nmcli -t -f DEVICE,TYPE,CONNECTION device status 2>/dev/null \
        | awk -F: '
            $2=="ethernet" {
                dev=$1
                # Recompõe CONNECTION (pode ter ":")
                conn=""
                for(i=3;i<=NF;i++) conn=(i==3)?$i:conn":"$i
                connected = (conn != "" && conn != "--") ? "true" : "false"
                if(conn == "" || conn == "--") conn = dev
                print dev "|" connected "|" conn
            }
        '
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

CMD="${1:-status}"; shift || true

case "$CMD" in
    status) cmd_status ;;
    wifi)
        SUB="${1:-list}"; shift || true
        case "$SUB" in
            list)       cmd_wifi_list ;;
            scan)       cmd_wifi_scan ;;
            on)         cmd_wifi_on ;;
            off)        cmd_wifi_off ;;
            connect)    cmd_wifi_connect "$@" ;;
            disconnect) cmd_wifi_disconnect ;;
            *) echo "ERR|Subcomando wifi desconhecido: $SUB" >&2; exit 1 ;;
        esac ;;
    eth)
        SUB="${1:-list}"; shift || true
        case "$SUB" in
            list) cmd_eth_list ;;
            on)   cmd_eth_on  "$@" ;;
            off)  cmd_eth_off "$@" ;;
            *) echo "ERR|Subcomando eth desconhecido: $SUB" >&2; exit 1 ;;
        esac ;;
    autoreconnect) cmd_autoreconnect "$@" ;;
    *) echo "ERR|Comando desconhecido: $CMD" >&2; exit 1 ;;
esac
