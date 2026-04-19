#!/bin/bash
QUIET_MODE=0
while [[ "${1:-}" == --* ]]; do
  case "$1" in
  --quiet)
    QUIET_MODE=1
    ;;
  esac
  shift # ← isso aqui estava faltando
done

toggle() {
  if systemctl --user is-active hypridle >/dev/null; then
    systemctl --user stop hypridle
    [[ $QUIET_MODE -eq 0 ]] && notify-send "Hypridle" "Suspensão desabilitada"
  else
    systemctl --user start hypridle
    [[ $QUIET_MODE -eq 0 ]] && notify-send "Hypridle" "Suspensão habilitada"
  fi
}

on() {
  systemctl --user stop hypridle
  [[ $QUIET_MODE -eq 0 ]] && notify-send "Hypridle" "Suspensão desabilitada"
}

off() {
  systemctl --user start hypridle
  [[ $QUIET_MODE -eq 0 ]] && notify-send "Hypridle" "Suspensão habilitada"
}

case "$1" in
on)
  on
  ;;
off)
  off
  ;;
*)
  toggle
  ;;
esac
