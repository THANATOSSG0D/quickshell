import QtQuick
import Quickshell
import Quickshell.Io
import qs

// ── PopupConfig ───────────────────────────────────────────────────────────────
// NÃO é mais singleton — cada instância do Bar (bar/dock) cria a sua própria,
// apontando pro próprio arquivo (ver Bar.qml: popupConfigJsonPath). Isso
// separa completamente a config de aparência/posição dos popups entre a
// barra principal e a dock, do mesmo jeito que Bar.json/Dock.json já são
// separados. Quem precisa da instância certa lê via barRef.popupConfigRef
// (ver BarPopup.qml) — nunca mais um singleton global "PopupConfig".
//
// Lê/escreve o JSON apontado por `path` (state/PopupConfig.json por padrão).
//
// Estrutura do JSON:
//   {
//     "globals": {
//       "animationStyle": "slide",   // "slide"|"fade"|"scale"|"scale-slide"|"none"
//       "borderWidth":    1,
//       "borderColor":    "auto",    // "auto" = Colors.outline_variant | "#rrggbb"
//       "shadowEnabled":  true,
//       "shadowBlur":     16,
//       "shadowOffsetX":  0,
//       "shadowOffsetY":  4,
//       "shadowColor":    "auto",    // "auto" = Colors.shadow @ 0.45 opacity
//       "shadowOpacity":  0.45,
//       "bgOpacity":      0.97,      // 0.0–1.0
//       "layoutMode":     "single",  // "single"|"dual"
//       "sidebarWidth":   200
//     },
//     "overrides": {
//       "AudioPopup": {
//         "popupW":     400,
//         "layoutMode": "dual"
//       },
//       "Launcher": {
//         "animationStyle": "fade",
//         "shadowEnabled":  false
//       }
//     }
//   }
//
// API pública:
//   PopupConfig.get(popupName, key, fallback)  → any
//     Lê na ordem: overrides[popupName][key] → globals[key] → fallback
//
//   PopupConfig.set(key, value, popupName?)    → void
//     Sem popupName: grava em globals.
//     Com popupName: grava em overrides[popupName].
//
//   PopupConfig.reset(popupName?)              → void
//     Sem popupName: limpa globals.
//     Com popupName: limpa overrides[popupName].

QtObject {
  id: root

  // Caminho do JSON — cada instância (bar/dock) passa o seu ao instanciar:
  //   PopupConfig { path: Quickshell.shellDir + "/state/PopupConfig.json" }
  //   PopupConfig { path: Quickshell.shellDir + "/state/DockPopupConfig.json" }
  property string path: Quickshell.shellDir + "/state/PopupConfig.json"

  // ── Defaults hardcoded (usados quando o JSON não tem o campo) ─────────────
  readonly property var _defaults: ({
    animationStyle: "slide",
    animDuration:   220,
    bgRadius:       12,
    cornerMode:     "all",
    borderWidth:    0,
    borderColor:    "auto",
    shadowEnabled:  false,
    shadowBlur:     16,
    shadowOffsetX:  0,
    shadowOffsetY:  4,
    shadowColor:    "auto",
    shadowOpacity:  0.45,
    bgOpacity:      0.97,
    layoutMode:     "single",
    sidebarWidth:   200
  })

  // ── Token de reatividade ──────────────────────────────────────────────────
  property int _dep: 0
  function _bump() { _dep++ }

  // ─────────────────────────────────────────────────────────────────────────
  // API PÚBLICA
  // ─────────────────────────────────────────────────────────────────────────

  // get(popupName, key, fallback?) → any
  // Cascata: overrides[popupName][key] → globals[key] → _defaults[key] → fallback
  function get(popupName, key, fallback) {
    var _ = root._dep  // reatividade
    try {
      var ov = _adapter.overrides
      if (ov && ov[popupName] && ov[popupName][key] !== undefined)
        return ov[popupName][key]
    } catch(e) {}
    try {
      var gl = _adapter.globals
      if (gl && gl[key] !== undefined) return gl[key]
    } catch(e) {}
    var d = _defaults[key]
    if (d !== undefined) return d
    return (fallback !== undefined) ? fallback : undefined
  }

  // set(key, value, popupName?) → void
  function set(key, value, popupName) {
    var gl = {}
    var ov = {}
    try { gl = JSON.parse(JSON.stringify(_adapter.globals))   } catch(e) {}
    try { ov = JSON.parse(JSON.stringify(_adapter.overrides)) } catch(e) {}

    if (popupName) {
      if (!ov[popupName]) ov[popupName] = {}
      ov[popupName][key] = value
      _adapter.overrides = ov
    } else {
      gl[key] = value
      _adapter.globals = gl
    }
    _file.writeAdapter()
    _bump()
  }

  // reset(popupName?) → void
  function reset(popupName) {
    var gl = {}
    var ov = {}
    try { gl = JSON.parse(JSON.stringify(_adapter.globals))   } catch(e) {}
    try { ov = JSON.parse(JSON.stringify(_adapter.overrides)) } catch(e) {}

    if (popupName) {
      delete ov[popupName]
      _adapter.overrides = ov
    } else {
      _adapter.globals = {}
    }
    _file.writeAdapter()
    _bump()
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ARQUIVO
  // ─────────────────────────────────────────────────────────────────────────
  property var _file: FileView {
    id: _file
    path: root.path
    watchChanges: true

    JsonAdapter {
      id: _adapter
      property var globals:   ({})
      property var overrides: ({})
      onGlobalsChanged:   root._bump()
      onOverridesChanged: root._bump()
    }
  }

  // Garante que o arquivo exista na primeira execução
  property var _mkdir: Process {
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      // Se arquivo vazio, escreve estrutura inicial
      if (!_adapter.globals || Object.keys(_adapter.globals).length === 0) {
        _adapter.globals   = {}
        _adapter.overrides = {}
        _file.writeAdapter()
      }
    }
  }

  Component.onCompleted: _mkdir.running = true
}
