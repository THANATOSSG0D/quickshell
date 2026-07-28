import QtQuick
import Quickshell
import Quickshell.Io
import qs

// PowerMenuConfig — API central de leitura/escrita das configs do Power Menu.
//
// Persiste em state/PowerMenu.json (chave "entries" = lista de ações,
// chave "settings" = aparência + comportamento, tudo num único bucket
// flat — o Power Menu não tem conceito de "tema" nem "estilo por módulo"
// como a Bar, então não precisa da cascata BarState→Bar.json→Schema).
//
// LEITURA:
//   config.get("colorAccent", "primary")   → string (token de paleta) ou número/bool
//   config.getEntries()                    → array de entradas (com fallback pros defaults)
//
// ESCRITA:
//   config.set("colorAccent", "tertiary")
//   config.updateEntry("shutdown", { keybind: "p" })
//   config.moveEntry(0, 2)
//
// Cores são guardadas como TOKEN de paleta (ex: "primary", "on_surface_variant")
// e resolvidas via resolve() → Colors[token], igual ao palette* do BarConfig.
//
// IMPORTANTE sobre reatividade: get()/getEntries() leem _entriesCache/
// _settingsCache (propriedades QML normais), NÃO adapter.entries/adapter.settings
// diretamente. Ler uma propriedade var de JsonAdapter dentro de uma função
// chamada por outro binding pode reemitir cnbchanged() a cada leitura e causar
// "Binding loop detected" (loop de leitura-dispara-mudança). Os handlers
// onEntriesChanged/onSettingsChanged abaixo copiam pro cache UMA VEZ; tudo
// que lê usa só o cache, então bindings dependem de uma property comum
// (comportamento QML padrão, sem função com efeito colateral no meio).

Item {
  id: root
  visible: false

  property string jsonPath: Quickshell.shellDir + "/state/PowerMenu.json"
  property bool   configLoaded: false

  // Cache local — única fonte que get()/getEntries() leem. Atualizado
  // pelos handlers onEntriesChanged/onSettingsChanged do JsonAdapter.
  property var _entriesCache:  []
  property var _settingsCache: ({})

  signal entriesChanged()

  // ══════════════════════════════════════════════════════════════════════
  // DEFAULTS — usados na primeira execução (entries vazio no JSON) e como
  // fallback de resetEntries(). IDs são estáveis: nunca renomeie um "id"
  // existente sem migrar quem depende dele (keybinds globais, etc).
  // ══════════════════════════════════════════════════════════════════════
  readonly property var defaultEntries: [
    { id: "lock",     text: "\uf023", label: "Travar",     keybind: "l",
      action: "qs ipc call screenLock lock", confirm: false, danger: false },
    { id: "suspend",  text: "\uf186", label: "Suspender",  keybind: "s",
      action: "systemctl suspend",     confirm: false, danger: false },
    { id: "logout",   text: "\uf08b", label: "Sair",       keybind: "e",
      action: "hyprctl dispatch exit", confirm: true,  danger: false },
    { id: "reboot",   text: "\uf021", label: "Reiniciar",  keybind: "r",
      action: "systemctl reboot",      confirm: true,  danger: true  },
    { id: "shutdown", text: "\uf011", label: "Desligar",   keybind: "d",
      action: "systemctl poweroff",    confirm: true,  danger: true  },
  ]

  // Defaults de "settings" (aparência + comportamento). Cores como token
  // de paleta (ver resolve()); tamanhos/tempos em px/ms.
  readonly property var defaultSettings: ({
    // comportamento
    confirmDestructive: true,   // liga/desliga globalmente a exigência de confirmação
    confirmTimeoutMs:   4000,   // tempo até o botão em confirmação voltar ao normal
    closeOnClickOutside: true,
    title: "SESSÃO",

    // janela
    fullscreen:      true,  // true = cobre a tela toda (padrão) · false = card flutuante centralizado
    windowedPadding: 40,    // espaço interno do card quando fullscreen=false
    windowedRadius:  24,    // raio de borda do card quando fullscreen=false

    // layout dos botões
    buttonLayoutMode: "row", // "row" (uma linha só) · "grid" (grade com N colunas) · "column" (empilhado)
    gridColumns:      3,     // usado só quando buttonLayoutMode === "grid"

    // layout dos cards
    cardWidth:   160,
    cardHeight:  180,
    cardSpacing: 20,
    cardRadius:  20,
    iconSize:    42,

    // animação
    hoverAnimMs: 160,
    panelAnimMs: 200,
    focusScale:  1.06,
    overlayOpacity: 0.72,

    // cores (tokens de paleta — ver Colors singleton)
    colorAccent:            "primary",
    colorCardBg:             "surface_container",
    colorCardBgFocused:      "primary_container",
    colorBorder:             "outline_variant",
    colorIcon:               "on_surface_variant",
    colorLabel:              "on_surface_variant",
    colorLabelFocused:       "on_primary_container",
    colorWindowBg:           "surface_container_high",
    colorKeybindBg:          "surface_container_highest",
    colorDanger:             "error",
  })

  // ── Resolução de token de paleta → cor real (mesmo padrão do BarConfig) ──
  function resolve(paletteKey) {
    if (!paletteKey) return Qt.color("transparent")
    return Colors[paletteKey] !== undefined ? Colors[paletteKey] : Qt.color("transparent")
  }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — settings (get/set genérico, flat)
  // ══════════════════════════════════════════════════════════════════════
  function get(key, def) {
    var s = root._settingsCache
    if (s && s[key] !== undefined) return s[key]
    if (root.defaultSettings[key] !== undefined) return root.defaultSettings[key]
    return def
  }

  // getColor(key) → já resolvido pra Colors[token], pronto pra usar em `color:`
  function getColor(key) {
    return resolve(get(key, root.defaultSettings[key]))
  }

  function set(key, value) {
    var s = {}
    try { s = JSON.parse(JSON.stringify(root._settingsCache || {})) } catch(e) {}
    s[key] = value
    root._settingsCache = s   // atualiza cache já, não depende do round-trip do adapter
    adapter.settings = s
    file.writeAdapter()
  }

  function resetSettings() {
    root._settingsCache = {}
    adapter.settings = {}
    file.writeAdapter()
  }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — entries (CRUD)
  // ══════════════════════════════════════════════════════════════════════
  function getEntries() {
    var e = root._entriesCache
    if (!e || e.length === 0) return root.defaultEntries
    return e
  }

  function setEntries(list) {
    root._entriesCache = list   // cache primeiro — quem lê nunca vê estado velho
    adapter.entries = list
    file.writeAdapter()
    root.entriesChanged()
  }

  function addEntry(entry) {
    var list = getEntries().slice()
    if (!entry.id) entry.id = "custom_" + Date.now()
    list.push(entry)
    setEntries(list)
  }

  function removeEntry(id) {
    var list = getEntries().filter(function(e) { return e.id !== id })
    setEntries(list)
  }

  function updateEntry(id, patch) {
    var list = getEntries().slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        var merged = {}
        for (var k  in list[i]) merged[k] = list[i][k]
        for (var k2 in patch)   merged[k2] = patch[k2]
        list[i] = merged
        break
      }
    }
    setEntries(list)
  }

  function moveEntry(fromIdx, toIdx) {
    var list = getEntries().slice()
    if (fromIdx < 0 || fromIdx >= list.length) return
    if (toIdx   < 0 || toIdx   >= list.length) return
    var item = list.splice(fromIdx, 1)[0]
    list.splice(toIdx, 0, item)
    setEntries(list)
  }

  function resetEntries() {
    // Grava lista vazia — getEntries() já cai pro fallback defaultEntries
    // automaticamente, então isso restaura os defaults sem precisar
    // duplicar a lista aqui.
    setEntries([])
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILE — state/PowerMenu.json
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: file
    path:         root.jsonPath
    watchChanges: false

    JsonAdapter {
      id: adapter
      property var entries:  []
      property var settings: ({})

      // Só copia pro cache — nunca lê de volta adapter.entries/adapter.settings
      // em outro lugar, então não tem como reentrar aqui.
      onEntriesChanged:  {
        root._entriesCache = entries
        root.entriesChanged()
      }
      onSettingsChanged: {
        root._settingsCache = settings
      }
    }

    onLoaded: {
      root.configLoaded  = true
      root._entriesCache  = adapter.entries
      root._settingsCache = adapter.settings
    }
    onLoadFailed: {
      // Arquivo ainda não existe (primeira execução) — normal, os
      // defaults acima cobrem tudo até a primeira escrita.
      root.configLoaded = true
    }
  }

  // ── Startup: garante que a pasta state/ existe antes de qualquer write ──
  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
  }
  Component.onCompleted: mkdirProc.running = true
}
