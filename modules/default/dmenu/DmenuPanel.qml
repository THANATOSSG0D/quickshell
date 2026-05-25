import Quickshell
import Quickshell.Hyprland
import QtQuick
import "../bar" as Bar

Bar.BarPopup {
  id: panel

  property string mode:       "drun"   // drun | run | window | script — controlado por DmenuIpc._showTop()
  property string launchCmd:  "uwsm app -- {exec}"
  property bool   showIcons:  true
  property int    maxVisible: 12

  property var    scriptEntries:  []
  property string scriptPreview:  ""
  property string scriptPrompt:   ">"
  property string scriptLabel:    "SCRIPT"
  property string scriptSep:      ""
  property var    scriptCallback: null
  property var    backCallback:    null   // chamado quando usuário pressiona Backspace com query vazia

  popupW: barRef ? barRef.parent.themePanelWidth : 320
  popupH: barRef ? barRef.parent.popupHDmenu     : 460

  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#1f1f1f"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#1f1f1f"

  // ── Garante que o callback é chamado exatamente uma vez ──────────────────
  property bool _callbackFired: false

  function open() {
    _callbackFired = false
    panelOpen = true
  }
  function close() { panelOpen = false }

  onPanelOpenChanged: {
    if (panelOpen) content.activate()
  }

  // ── FocusGrab.onCleared → BarPopup emite closeRequested() ────────────────
  // Só chama callback se DmenuContent ainda não o chamou (seleção com Enter/click).
  // _callbackFired já estará true se o usuário selecionou algo — guarda re-entrada.
  onCloseRequested: {
    if (!_callbackFired) {
      _callbackFired = true
      if (scriptCallback) scriptCallback(null)
    }
  }

  property alias dmenuContent: content

  DmenuContent {
    id: content
    anchors.fill: parent

    mode:       panel.mode
    launchCmd:  panel.launchCmd
    showIcons:  panel.showIcons
    maxVisible: panel.maxVisible

    scriptEntries: panel.scriptEntries
    scriptPreview: panel.scriptPreview
    scriptPrompt:  panel.scriptPrompt
    scriptLabel:   panel.scriptLabel
    scriptSep:     panel.scriptSep

    colorPanelBg:  panel.colorPanelBg
    colorText:     panel.colorText
    colorTextDim:  panel.colorTextDim
    colorAccent:   panel.colorAccent
    colorSelected: panel.colorSelected
    colorDivider:  panel.colorDivider
    colorInputBg:  panel.colorInputBg

    // ── FIX: duplo-callback ───────────────────────────────────────────────
    //
    // BUG ORIGINAL (ordem errada):
    //   panel.panelOpen = false        ← dispara BarPopup.closeRequested() SYNC
    //   if (!panel._callbackFired) {   ← _callbackFired ainda é false aqui!
    //     panel._callbackFired = true  ← nunca chega aqui: o onCloseRequested acima
    //     panel.scriptCallback(selected)  já chamou scriptCallback(null) antes.
    //   }
    //
    // Como acontecia:
    //   HyprlandFocusGrab.onCleared é emitido sincronamente quando panelOpen
    //   muda para false → BarPopup.closeRequested() dispara → DmenuPanel.
    //   onCloseRequested executa → scriptCallback(null) enviado ao cliente.
    //   O handler original continuava, mas _callbackFired já estava true,
    //   então scriptCallback(selected) NUNCA era chamado.
    //   Resultado: o cliente sempre recebia null, main_choice ficava vazio,
    //   e os submenus nunca eram abertos.
    //
    // FIX: marcar _callbackFired = true PRIMEIRO, antes de fechar o painel.
    //   Assim, quando BarPopup.closeRequested() disparar (dentro de panelOpen=false),
    //   o guard já está ativo e o segundo callback(null) é descartado.
    onBackRequested: {
      if (panel.backCallback) panel.backCallback()
    }

    onCloseRequested: (selected) => {
      if (!panel._callbackFired) {
        panel._callbackFired = true           // ← guarda PRIMEIRO
        panel.panelOpen = false               // ← fecha painel (pode emitir closeRequested)
        if (panel.scriptCallback) panel.scriptCallback(selected)
      }
    }
  }
}
