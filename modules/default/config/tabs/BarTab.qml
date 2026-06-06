import QtQuick
import './bar' as Bar

// BarTab — router das subabas da Barra.
// Recebe todo o estado do ConfigWindow e emite onChanged(opts)
// para que o ConfigWindow aplique e salve.

Item {
  id: root

  // ── Cores ─────────────────────────────────────────────────────────────
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorProgressBg
  required property color colorSidebar
  required property color colorDivider
  required property color colorError
  required property var   colors        // Colors singleton
  required property var   overlay       // Item fora do layer para popups

  // ── Subaba ativa ──────────────────────────────────────────────────────
  required property int activeSubtab    // 0-6

  // ── Geral ─────────────────────────────────────────────────────────────
  required property string localTheme
  required property int    localPosition
  required property bool   localAutoHide
  required property bool   localSilence
  required property int    localBarSize
  required property int    localBarMargin
  required property int    localPillWidth
  required property int    localPillMinSpacing

  // ── Módulos ───────────────────────────────────────────────────────────
  required property var    slotLeft
  required property var    slotCenter
  required property var    slotRight
  required property var    slotTop
  required property var    slotMiddle
  required property var    slotBottom

  // ── Workspaces ────────────────────────────────────────────────────────
  required property string localWsStyle
  required property string localWsSort
  required property bool   localWsMono
  required property int    localWsSpacing
  required property bool   localWsAddBtn

  // ── Clock ─────────────────────────────────────────────────────────────
  required property string pkClkText
  required property string pkClkDim
  required property string pkClkAccent
  required property int    localClkDismiss

  // ── Volume ────────────────────────────────────────────────────────────
  required property bool   localShowSink
  required property bool   localShowSource
  required property string pkVolMuted

  // ── Mídia ─────────────────────────────────────────────────────────────
  required property string localMpTextMode
  required property int    localMpScrollSpeed
  required property int    localMpScrollWidth
  required property bool   localMpBgEnabled
  required property string pkMpBgColor
  required property string pkMpBgActive
  required property string pkMpText
  required property string pkMpDim
  required property string pkMpTextActive
  required property string pkMpDimActive

  // ── Paleta ────────────────────────────────────────────────────────────
  required property string pkBarBg
  required property string pkBarBgPill
  required property string pkText
  required property string pkTextDim
  required property string pkAccent
  required property string pkAccentBg
  required property string pkPanelBg
  required property string pkProgressBg
  required property string pkProgressFg
  required property string pkDivider

  signal changed(var opts)

  // ── Loaders ───────────────────────────────────────────────────────────
  Loader {
    anchors.fill: parent; active: root.activeSubtab === 0
    sourceComponent: Bar.BarTabGeral {
      localTheme: root.localTheme; localPosition: root.localPosition
      localAutoHide: root.localAutoHide; localSilence: root.localSilence
      localBarSize: root.localBarSize; localBarMargin: root.localBarMargin
      localPillWidth: root.localPillWidth; localPillMinSpacing: root.localPillMinSpacing
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onChanged: (opts) => root.changed(opts)
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 1
    sourceComponent: Bar.BarTabModulos {
      isH: root.localPosition === 1 || root.localPosition === 3
      slotLeft: root.slotLeft; slotCenter: root.slotCenter; slotRight: root.slotRight
      slotTop: root.slotTop; slotMiddle: root.slotMiddle; slotBottom: root.slotBottom
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      onSlotChanged: (slot, arr) => {
        var opts = {}
        var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
        opts[key] = arr
        root.changed(opts)
      }
      onModuleAdded: (slot, id) => {
        var key = "modules" + slot.charAt(0).toUpperCase() + slot.slice(1)
        var opts = {}
        opts[key] = root["slot" + slot.charAt(0).toUpperCase() + slot.slice(1)].concat([id])
        root.changed(opts)
      }
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 2
    sourceComponent: Bar.BarTabWorkspaces {
      localWsStyle: root.localWsStyle; localWsSort: root.localWsSort
      localWsMono: root.localWsMono; localWsSpacing: root.localWsSpacing
      localWsAddBtn: root.localWsAddBtn
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onChanged: (opts) => root.changed(opts)
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 3
    sourceComponent: Bar.BarTabClock {
      pkClkText: root.pkClkText; pkClkDim: root.pkClkDim; pkClkAccent: root.pkClkAccent
      localClkDismiss: root.localClkDismiss; colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
      onChanged: (opts) => root.changed(opts)
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 4
    sourceComponent: Bar.BarTabVolume {
      localShowSink: root.localShowSink; localShowSource: root.localShowSource
      pkVolMuted: root.pkVolMuted; colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorError: root.colorError
      colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
      colorProgressBg: root.colorProgressBg
      onChanged: (opts) => root.changed(opts)
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 5
    sourceComponent: Bar.BarTabMidia {
      localMpTextMode: root.localMpTextMode; localMpScrollSpeed: root.localMpScrollSpeed
      localMpScrollWidth: root.localMpScrollWidth; localMpBgEnabled: root.localMpBgEnabled
      pkMpBgColor: root.pkMpBgColor; pkMpBgActive: root.pkMpBgActive
      pkMpText: root.pkMpText; pkMpDim: root.pkMpDim
      pkMpTextActive: root.pkMpTextActive; pkMpDimActive: root.pkMpDimActive
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
      onChanged: (opts) => root.changed(opts)
    }
  }

  Loader {
    anchors.fill: parent; active: root.activeSubtab === 6
    sourceComponent: Bar.BarTabPaleta {
      pkBarBg: root.pkBarBg; pkBarBgPill: root.pkBarBgPill
      pkText: root.pkText; pkTextDim: root.pkTextDim
      pkAccent: root.pkAccent; pkAccentBg: root.pkAccentBg
      pkPanelBg: root.pkPanelBg; pkProgressBg: root.pkProgressBg
      pkProgressFg: root.pkProgressFg; pkDivider: root.pkDivider
      colors: root.colors; overlay: root.overlay
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
      onChanged: (opts) => root.changed(opts)
    }
  }
}
