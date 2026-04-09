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
        local ssid
        ssid=$(cmd_wifi_list | awk -F'|' '$1=="*" {print $2; exit}')
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
    nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
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

cmd_wifi_connect() {
    local ssid="$1" pass="$2"
    [ -z "$ssid" ] && { echo "ERR|SSID não informado" >&2; exit 1; }

    if nmcli connection show "$ssid" &>/dev/null; then
        if nmcli connection up "$ssid" 2>/dev/null; then
            echo "OK|connected"; return
        fi
    fi

    if [ -n "$pass" ]; then
        if nmcli device wifi connect "$ssid" password "$pass" 2>/dev/null; then
            echo "OK|connected"
        else
            echo "ERR|Senha incorreta ou falha na conexão" >&2; exit 1
        fi
    else
        local out
        out=$(nmcli device wifi connect "$ssid" 2>&1)
        if echo "$out" | grep -qi "successfully"; then
            echo "OK|connected"
        elif echo "$out" | grep -qi "password\|secret\|802-11"; then
            echo "NEED_PASS"
        else
            echo "ERR|Falha: $out" >&2; exit 1
        fi
    fi
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
    *) echo "ERR|Comando desconhecido: $CMD" >&2; exit 1 ;;
esac
