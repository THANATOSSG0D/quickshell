import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "./components" as Qs

// ── QuickSettingsContent ─────────────────────────────────────────────────────
// Estrutura:
//   A) Grid 2×2 toggles (WiFi, Bluetooth, DND, Modo Noturno visual)
//   B) Sliders: Volume (Pipewire) + Brilho (brightnessctl)
//   C) Modo Noturno: Hyprshade toggle + Hyprsunset temperatura
//   D) Perfil Térmico (thermal-profile)
//   E) Abas: Redes | Bluetooth | Sistema | Tray
//   F) Rodapé de energia
Item {
    id: root

    property color colorPanelBg:    "#1f1f1f"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    signal closeRequested()
    property bool panelOpen: false
    property string activeTab: "networks"

    // ── Bluetooth ──────────────────────────────────────────────────────────
    property bool btPowered: false
    readonly property bool btDetected: (btShowProc.stdout || "").includes("Powered: yes")
    onBtDetectedChanged: btPowered = btDetected

    Process { id: btShowProc;   command: [ "bluetoothctl", "show" ] }
    Process { id: btToggleProc }

    function _toggleBluetooth() {
        btToggleProc.command = [ "bluetoothctl", "power", root.btPowered ? "off" : "on" ]
        btToggleProc.running = true
        root.btPowered = !root.btPowered
    }

    // ── WiFi via nmcli ─────────────────────────────────────────────────────
    property bool   wifiEnabled: false
    property string wifiBadge:   ""

    Process { id: wifiStatusProc; command: [ "nmcli", "networking" ] }
    Process { id: wifiActiveProc; command: [ "nmcli", "-t", "-f", "NAME", "conn", "show", "--active" ] }
    Process { id: wifiToggleProc }

    readonly property bool wifiDetected: (wifiStatusProc.stdout || "").trim() === "enabled"
    onWifiDetectedChanged: wifiEnabled = wifiDetected

    readonly property string wifiBadgeDetected: {
        var lines = (wifiActiveProc.stdout || "").trim().split("\n")
        return (lines.length > 0 && lines[0].trim() !== "") ? lines[0].trim() : ""
    }
    onWifiBadgeDetectedChanged: wifiBadge = wifiBadgeDetected

    function _refreshWifi() { wifiStatusProc.running = true; wifiActiveProc.running = true }
    function _toggleWifi() {
        wifiToggleProc.command = [ "nmcli", "networking", root.wifiEnabled ? "off" : "on" ]
        wifiToggleProc.running = true
        root.wifiEnabled = !root.wifiEnabled
    }

    // ── Estados locais ─────────────────────────────────────────────────────
    property bool dndEnabled:       false
    property bool nightModeEnabled: false   // tile visual — controle real fica no QsNightMode

    // ── Inicialização ──────────────────────────────────────────────────────
    Component.onCompleted: { btShowProc.running = true; _refreshWifi() }
    onPanelOpenChanged: {
        if (panelOpen) { btShowProc.running = true; _refreshWifi() }
    }

    // ── Flickable principal ────────────────────────────────────────────────
    Flickable {
        anchors.fill:   parent
        clip:           true
        contentWidth:   width
        contentHeight:  mainCol.implicitHeight + 28
        boundsMovement: Flickable.StopAtBounds

        ColumnLayout {
            id: mainCol
            x: 14; y: 14
            width:   parent.width - 28
            spacing: 10

            // ── A) Grid de toggles ─────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 2; rowSpacing: 8; columnSpacing: 8

                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 64
                    icon: "\uf1eb"; label: "Wi-Fi"; badge: root.wifiBadge
                    active: root.wifiEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleWifi()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 64
                    icon: "\uf294"; label: "Bluetooth"
                    badge: root.btPowered ? "ligado" : "desligado"
                    active: root.btPowered
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root._toggleBluetooth()
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 64
                    icon: root.dndEnabled ? "\uf1f6" : "\uf0f3"; label: "Não Perturbe"
                    badge: root.dndEnabled ? "ativado" : ""; active: root.dndEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root.dndEnabled = !root.dndEnabled
                }
                Qs.QsToggleTile {
                    Layout.fillWidth: true; Layout.preferredHeight: 64
                    icon: "\uf186"; label: "Noturno"; badge: ""; active: root.nightModeEnabled
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                    onToggled: root.nightModeEnabled = !root.nightModeEnabled
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── B) Sliders ─────────────────────────────────────────────
            Qs.QsVolumeSlider {
                Layout.fillWidth: true
                colorAccent: root.colorAccent; colorText: root.colorText
                colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
                colorMuted: root.colorMuted
            }
            Qs.QsBrightnessSlider {
                Layout.fillWidth: true
                colorAccent: root.colorAccent; colorText: root.colorText
                colorTextDim: root.colorTextDim; colorProgressBg: root.colorProgressBg
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── C) Modo Noturno ────────────────────────────────────────
            Qs.QsNightMode {
                Layout.fillWidth: true
                panelOpen:       root.panelOpen
                colorAccent:     root.colorAccent
                colorText:       root.colorText
                colorTextDim:    root.colorTextDim
                colorProgressBg: root.colorProgressBg
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── D) Perfil Térmico ──────────────────────────────────────
            Qs.QsThermalSection {
                Layout.fillWidth: true
                panelOpen:    root.panelOpen
                colorAccent:  root.colorAccent
                colorText:    root.colorText
                colorTextDim: root.colorTextDim
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── E) Abas ────────────────────────────────────────────────
            Qs.QsTabBar {
                Layout.fillWidth: true
                activeTab:    root.activeTab
                colorAccent:  root.colorAccent
                colorTextDim: root.colorTextDim
                tabs: [
                    { id: "networks",   label: "\uf1eb  Redes"     },
                    { id: "bluetooth",  label: "\uf294  Bluetooth"  },
                    { id: "system",     label: "\uf108  Sistema"    },
                    { id: "tray",       label: "\uf0c9  Tray"       }
                ]
                onTabClicked: (id) => root.activeTab = id
            }

            // ── Páginas das abas ───────────────────────────────────────
            Item {
                Layout.fillWidth: true
                height: 160
                clip:   true

                Qs.QsTabNetworks {
                    anchors.fill: parent; visible: root.activeTab === "networks"
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                }
                Qs.QsTabBluetooth {
                    anchors.fill: parent; visible: root.activeTab === "bluetooth"
                    colorAccent: root.colorAccent; colorText: root.colorText
                    colorTextDim: root.colorTextDim; colorMuted: root.colorMuted
                }
                Qs.QsTabSystem {
                    anchors.fill: parent; visible: root.activeTab === "system"
                    colorAccent: root.colorAccent; colorText: root.colorText; colorTextDim: root.colorTextDim
                }
                Qs.QsTabTray {
                    anchors.fill: parent; visible: root.activeTab === "tray"
                    colorText: root.colorText; colorTextDim: root.colorTextDim
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

            // ── F) Rodapé de energia ───────────────────────────────────
            Qs.QsFooter {
                Layout.fillWidth: true
                colorText:  root.colorText
                colorMuted: root.colorMuted
            }

            Item { height: 0 }
        }
    }
}
