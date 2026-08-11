import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.singletons

// ── PopupConfig ───────────────────────────────────────────────────────────────
// NÃO é singleton — cada instância do Bar (bar/dock) cria a sua própria,
// apontando pro próprio arquivo (ver Bar.qml: popupConfigJsonPath). Isso
// separa completamente a config de aparência/posição dos popups entre a
// barra principal e a dock, do mesmo jeito que Bar.json/Dock.json já são
// separados. Quem precisa da instância certa lê via barRef.popupConfigRef
// (ver BarPopup.qml) — nunca mais um singleton global "PopupConfig".
//
// Lê/escreve o JSON apontado por `path` (state/PopupConfig.json por padrão).
//
// ── POR TEMA ─────────────────────────────────────────────────────────────
// Cada instância (bar/dock) tem seu próprio `theme` (ver Bar.qml, onde
// `popupConfig.theme: barState.currentTheme` é bindado). A config de
// aparência/posição dos popups passa a ser isolada POR TEMA, no mesmo
// espírito de BarConfig/BarState.json: trocar de tema na barra troca junto
// as cores/tamanhos dos painéis, e cada tema guarda seus próprios ajustes
// sem afetar os outros.
//
// Estrutura do JSON:
//   {
//     // ── LEGADO (pré-tema) — preservado como CAMADA-BASE compartilhada.
//     // Nunca mais é escrito por set()/reset() (que agora gravam sempre
//     // dentro de themes[tema]), mas continua sendo LIDO como fallback
//     // pra qualquer tema que ainda não tenha um override próprio — assim
//     // nada do que já estava salvo se perde, e a transição é invisível
//     // até o usuário customizar um painel com um tema específico ativo.
//     "globals":   { "animationStyle": "slide", ... },
//     "overrides": { "AudioPopup": { "popupW": 400 }, ... },
//
//     // ── POR TEMA — overrides do usuário, isolados por tema
//     "themes": {
//       "Pill": {
//         "globals":   { "bgOpacity": 0.9 },
//         "overrides": { "AudioPopup": { "popupW": 420 } }
//       },
//       "Notch": {
//         "globals":   { "layoutMode": "dual" },
//         "overrides": {}
//       }
//     }
//   }
//
// CASCATA de leitura (get):
//   1. themes[tema].overrides[popupName][key]  — override do usuário NESTE tema
//   2. themes[tema].globals[key]               — global do usuário NESTE tema
//   3. overrides[popupName][key]               — legado (base compartilhada)
//   4. globals[key]                            — legado (base compartilhada)
//   5. _defaults[key]                          — default hardcoded
//   6. fallback                                — passado pelo chamador
//
// API pública (inalterada — quem já usa get/set/reset não precisa mudar):
//   PopupConfig.get(popupName, key, fallback)  → any
//   PopupConfig.set(key, value, popupName?)    → void   (grava em themes[tema atual])
//   PopupConfig.reset(popupName?)              → void   (limpa themes[tema atual])

QtObject {
  id: root

  // Caminho do JSON — cada instância (bar/dock) passa o seu ao instanciar:
  //   PopupConfig { path: Quickshell.shellDir + "/state/PopupConfig.json" }
  //   PopupConfig { path: Quickshell.shellDir + "/state/DockPopupConfig.json" }
  property string path: Quickshell.shellDir + "/state/PopupConfig.json"

  // Tema atual desta instância (bar ou dock) — bindado externamente a partir
  // de barState.currentTheme (ver Bar.qml). Trocar de tema recalcula get()
  // automaticamente (via _dep, ver onThemeChanged abaixo).
  property string theme: "Pill"
  onThemeChanged: root._bump()

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

  // ── Helpers internos: leem/escrevem o bloco themes[theme] com segurança ──
  function _themeBlock(themeName) {
    try {
      var t = _adapter.themes
      if (t && t[themeName]) return t[themeName]
    } catch(e) {}
    return { globals: {}, overrides: {} }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API PÚBLICA
  // ─────────────────────────────────────────────────────────────────────────

  // get(popupName, key, fallback?) → any
  // Cascata: themes[tema].overrides[popupName][key] → themes[tema].globals[key]
  //          → overrides[popupName][key] (legado) → globals[key] (legado)
  //          → _defaults[key] → fallback
  function get(popupName, key, fallback) {
    var _ = root._dep  // reatividade (inclui mudança de tema)

    var tb = _themeBlock(root.theme)
    try {
      var tov = tb.overrides
      if (tov && tov[popupName] && tov[popupName][key] !== undefined)
        return tov[popupName][key]
    } catch(e) {}
    try {
      var tgl = tb.globals
      if (tgl && tgl[key] !== undefined) return tgl[key]
    } catch(e) {}

    // Legado — base compartilhada entre temas ainda não customizados
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
  // Grava sempre dentro de themes[tema atual] — nunca mais toca no legado
  // (que fica congelado como base/fallback compartilhado).
  function set(key, value, popupName) {
    var themes = {}
    try { themes = JSON.parse(JSON.stringify(_adapter.themes)) } catch(e) {}
    if (!themes[root.theme]) themes[root.theme] = { globals: {}, overrides: {} }
    if (!themes[root.theme].globals)   themes[root.theme].globals   = {}
    if (!themes[root.theme].overrides) themes[root.theme].overrides = {}

    if (popupName) {
      if (!themes[root.theme].overrides[popupName]) themes[root.theme].overrides[popupName] = {}
      themes[root.theme].overrides[popupName][key] = value
    } else {
      themes[root.theme].globals[key] = value
    }

    _adapter.themes = themes
    _file.writeAdapter()
    _bump()
  }

  // reset(popupName?) → void
  // Limpa o override deste popup (ou os globals) SÓ dentro do tema atual —
  // volta a cair na cascata (legado/defaults) automaticamente.
  function reset(popupName) {
    var themes = {}
    try { themes = JSON.parse(JSON.stringify(_adapter.themes)) } catch(e) {}
    if (!themes[root.theme]) themes[root.theme] = { globals: {}, overrides: {} }

    if (popupName) {
      if (themes[root.theme].overrides) delete themes[root.theme].overrides[popupName]
    } else {
      themes[root.theme].globals = {}
    }

    _adapter.themes = themes
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
      // Legado — preservado só-leitura como base compartilhada (ver cascata acima)
      property var globals:   ({})
      property var overrides: ({})
      // Novo — overrides do usuário isolados por tema
      property var themes:    ({})
      onGlobalsChanged:   root._bump()
      onOverridesChanged: root._bump()
      onThemesChanged:    root._bump()
    }
  }

  // Garante que o arquivo exista na primeira execução
  Component.onCompleted: StateDir.whenReady(() => {
    // Se arquivo vazio (primeira execução mesmo, sem legado nenhum),
    // escreve estrutura inicial. NÃO mexe em globals/overrides/themes
    // se já existir QUALQUER coisa salva — isso é o que preserva 100%
    // do que já estava configurado antes desta mudança.
    var hasGlobals   = _adapter.globals   && Object.keys(_adapter.globals).length > 0
    var hasOverrides = _adapter.overrides && Object.keys(_adapter.overrides).length > 0
    var hasThemes    = _adapter.themes    && Object.keys(_adapter.themes).length > 0
    if (!hasGlobals && !hasOverrides && !hasThemes) {
      _adapter.globals   = {}
      _adapter.overrides = {}
      _adapter.themes    = {}
      _file.writeAdapter()
    }
  })
}
