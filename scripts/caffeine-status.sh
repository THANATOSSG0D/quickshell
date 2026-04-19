#!/bin/bash
# Status do hypridle

if systemctl --user is-active hypridle >/dev/null 2>&1; then
  TEXT="💤"
  CLASS="active"
  STATUS="Hypridle ATIVO"
else
  TEXT="☕"
  CLASS="notactive"
  STATUS="Hypridle INATIVO"
fi

SLEEP_LIST=""
IDLE_LIST=""
OTHER_LIST=""

# Processar inibidores
first_line=true
while IFS= read -r line; do
  # Pular linha vazia ou linha de contagem
  [[ -z "$line" ]] && continue
  [[ "$line" =~ inhibitor.*listed ]] && continue

  # Na primeira linha, apenas pular o cabeçalho
  if $first_line; then
    first_line=false
    continue
  fi

  # Extrair WHO (tudo até o primeiro número que é o UID), depois trim
  who=$(echo "$line" | sed -E 's/^([^0-9]+)[0-9].*/\1/' | sed 's/[[:space:]]*$//')

  # Extrair todos os números (campos numéricos)
  numbers=($(echo "$line" | grep -oE '[0-9]+'))
  uid="${numbers[0]}"
  pid="${numbers[1]}"

  # Extrair WHAT - procurar por sleep, idle, shutdown, handle-*
  what=$(echo "$line" | grep -oE '(sleep|idle|shutdown|handle-[a-z-]+)(:[a-z-]+)*' | head -1)

  case "$what" in
  *sleep*:*idle* | *idle*:*sleep*)
    SLEEP_LIST+="- $who (PID: $pid)\n"
    IDLE_LIST+="- $who (PID: $pid)\n"
    ;;
  *sleep*)
    SLEEP_LIST+="- $who (PID: $pid)\n"
    ;;
  *idle*)
    IDLE_LIST+="- $who (PID: $pid)\n"
    ;;
  *)
    OTHER_LIST+="- $who [$what] (PID: $pid)\n"
    ;;
  esac
done < <(systemd-inhibit --list --no-pager 2>/dev/null)

TOOLTIP="$STATUS\n\n"
[ -n "$SLEEP_LIST" ] && TOOLTIP+="🛌 [Sleep]\n$SLEEP_LIST\n"
[ -n "$IDLE_LIST" ] && TOOLTIP+="⏸️  [Idle]\n$IDLE_LIST\n"
[ -n "$OTHER_LIST" ] && TOOLTIP+="📋 [Outros]\n$OTHER_LIST\n"

if [[ "$TOOLTIP" == "$STATUS\n\n" ]]; then
  TOOLTIP+="✅ Nenhum inibidor ativo"
fi

TOOLTIP_ESCAPED=$(echo -e "$TOOLTIP" | sed ':a;N;$!ba;s/\n/\\n/g' | sed 's/"/\\"/g')
echo "{\"text\":\"$TEXT\",\"class\":\"$CLASS\",\"tooltip\":\"$TOOLTIP_ESCAPED\"}"
