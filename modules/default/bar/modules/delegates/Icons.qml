import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property var modelData: null

  readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + Quickshell.env("USER"))

  property bool  isHorizontal:    true
  property int   iconSize:        18
  property bool  monochrome:      false
  property color monoColor:       "white"
  property color monoColorActive: "red"
  property real  monoOpacity:     0.95
  property int   iconSpacing:     3
  property string sortOrder:      "position"
  property string fallbackIcon:   ""

  implicitWidth:  isHorizontal ? layout.implicitWidth  : iconSize + 4
  implicitHeight: isHorizontal ? iconSize + 4          : layout.implicitHeight
  width:  implicitWidth
  height: implicitHeight

  property var sortedToplevels: {
    if (!root.modelData) return []
    var list = root.modelData.toplevels.values.slice()
    if (sortOrder === "alphabetical") {
      list.sort(function(a, b) {
        var nameA = a.wayland ? a.wayland.appId : a.title
        var nameB = b.wayland ? b.wayland.appId : b.title
        return nameA.localeCompare(nameB)
      })
    } else {
      list.sort(function(a, b) {
        var ax = a.lastIpcObject ? (a.lastIpcObject.at ? a.lastIpcObject.at[0] : 0) : 0
        var bx = b.lastIpcObject ? (b.lastIpcObject.at ? b.lastIpcObject.at[0] : 0) : 0
        return ax - bx
      })
    }
    return list
  }

  GridLayout {
    id: layout
    anchors.centerIn: parent
    columns:       root.isHorizontal ? -1 : 1
    rows:          root.isHorizontal ? 1  : -1
    columnSpacing: root.isHorizontal ? root.iconSpacing : 0
    rowSpacing:    root.isHorizontal ? 0 : root.iconSpacing

    Repeater {
      model: root.sortedToplevels

      delegate: Item {
        id: appItem
        required property var modelData

        Layout.preferredWidth:  root.iconSize
        Layout.preferredHeight: root.iconSize

        // ── Lookup do DesktopEntry ─────────────────────────────────────────
        property var entry: {
          var _loaded = DesktopEntries.applications.values.length
          if (_loaded === 0) return null
          if (!modelData.wayland) return null
          var appId = modelData.wayland.appId

          var result = DesktopEntries.byId(appId)
                    || DesktopEntries.byId(appId.toLowerCase())
                    || null

          if (!result) result = DesktopEntries.heuristicLookup(appId) || null

          if (!result) {
            var ignoreParts = ["www", "com", "org", "net", "io", "app", "web",
                               "default", "stable", "beta", "dev", "nightly"]

            var cleaned = appId
                            .replace(/-[Dd]efault$/, "")
                            .replace(/^vivaldi-/,    "")
                            .replace(/^brave-/,      "")
                            .replace(/^chrome-/,     "")
                            .replace(/^chromium-/,   "")
                            .replace(/^msedge-/,     "")
                            .replace(/^firefox-/,    "")
                            .replace(/__+/g,         "")
                            .replace(/[0-9a-f]{8,}/gi, "")
                            .toLowerCase()

            var hostCandidates = []
            var domainParts = cleaned.split(".")
            for (var d = 0; d < domainParts.length; d++) {
              var dp = domainParts[d].replace(/[-_\s]+/g, "").trim()
              if (dp.length >= 3 && ignoreParts.indexOf(dp) === -1) {
                hostCandidates.push(dp)
                hostCandidates.push(dp.charAt(0).toUpperCase() + dp.slice(1))
              }
            }

            for (var c = 0; c < hostCandidates.length; c++) {
              result = DesktopEntries.byId(hostCandidates[c]) || null
              if (result) break
            }

            if (!result) {
              var parts = cleaned
                            .replace(/\./g, " ")
                            .split(/[-_\s]+/)
                            .filter(function(p) {
                              return p.length >= 3 && ignoreParts.indexOf(p) === -1
                            })

              for (var i = 0; i < DesktopEntries.applications.values.length; i++) {
                var app = DesktopEntries.applications.values[i]
                var appName        = (app.name || "").toLowerCase().replace(/\s+/g, "")
                var appNameSpaced  = (app.name || "").toLowerCase()
                var appIdLower     = (app.id   || "").toLowerCase().replace(/\s+/g, "")

                for (var j = 0; j < parts.length; j++) {
                  var p = parts[j]
                  if (appName.includes(p) || appNameSpaced.includes(p) || appIdLower.includes(p)) {
                    result = app
                    break
                  }
                  if (p.length >= 6 && (p.includes(appName) || appName.includes(p.slice(0, -1)))) {
                    result = app
                    break
                  }
                }
                if (result) break
              }
            }
          }

          return result
        }

        property string iconName: {
          if (!entry) return ""
          var icon = entry.icon || ""
          if (!icon) return ""
          if (icon.startsWith("/")) return icon
          return icon.replace(/-launcher$/, "").replace(/-client$/, "")
        }

        function toFileUri(path) {
          if (!path) return ""
          return "file://" + path.split("/").map(function(seg) {
            return seg.replace(/ /g, "%20")
          }).join("/")
        }

        readonly property var iconPaths: {
          if (!iconName) return []
          if (iconName.startsWith("/")) return [toFileUri(iconName)]

          var home = root.homeDir
          var n    = iconName
          return [
            "file:///usr/share/icons/Papirus/48x48/apps/" + n + ".svg",
            "file:///usr/share/icons/Papirus/32x32/apps/" + n + ".svg",
            "file:///usr/share/icons/Papirus/64x64/apps/" + n + ".svg",
            "file:///usr/share/icons/hicolor/scalable/apps/"  + n + ".svg",
            "file:///usr/share/icons/hicolor/256x256/apps/"   + n + ".png",
            "file:///usr/share/icons/hicolor/128x128/apps/"   + n + ".png",
            "file:///usr/share/icons/hicolor/48x48/apps/"     + n + ".png",
            "file:///usr/share/pixmaps/" + n + ".png",
            "file:///usr/share/pixmaps/" + n + ".svg",
            "file://" + home + "/.local/share/icons/hicolor/scalable/apps/" + n + ".svg",
            "file://" + home + "/.local/share/icons/hicolor/256x256/apps/"  + n + ".png",
            "file://" + home + "/.local/share/icons/hicolor/128x128/apps/"  + n + ".png",
            "file://" + home + "/.local/share/icons/hicolor/96x96/apps/"    + n + ".png",
            "file://" + home + "/.local/share/icons/hicolor/64x64/apps/"    + n + ".png",
            "file://" + home + "/.local/share/icons/hicolor/48x48/apps/"    + n + ".png",
            "file://" + home + "/.local/share/pixmaps/" + n + ".png",
            "file://" + home + "/.local/share/pixmaps/" + n + ".svg",
          ]
        }

        property int  attempt:   0
        property bool exhausted: false

        readonly property string currentSource: {
          if (exhausted) return ""
          if (iconPaths.length === 0) return ""
          return iconPaths[Math.min(attempt, iconPaths.length - 1)]
        }

        onIconPathsChanged: {
          appItem.attempt   = 0
          appItem.exhausted = false
        }

        // ── Ícone colorido ───────────────────────────────────────────────
        Image {
          id: iconImg
          anchors.fill: parent
          fillMode: Image.PreserveAspectFit
          visible:  !root.monochrome
          // Ativo = opacidade total; inativo = 55% (mais sutil que o original 0.6)
          opacity:  modelData.activated ? 1.0 : 0.55
          source:   appItem.currentSource

          Behavior on opacity { NumberAnimation { duration: 150 } }

          onStatusChanged: {
            if (status === Image.Error) {
              if (appItem.attempt < appItem.iconPaths.length - 1) {
                appItem.attempt++
              } else {
                appItem.exhausted = true
              }
            }
          }
        }

        // ── Fallback genérico ────────────────────────────────────────────
        Image {
          id: fallbackImg
          anchors.fill: parent
          fillMode: Image.PreserveAspectFit
          visible:  !root.monochrome && appItem.exhausted && fallbackAttempt < fallbackPaths.length
          opacity:  modelData.activated ? 1.0 : 0.55

          property int fallbackAttempt: 0

          readonly property var fallbackPaths: {
            var fb = root.fallbackIcon
            if (!fb) return []
            if (fb.startsWith("/")) return ["file://" + fb]
            return [
              "file:///usr/share/icons/Papirus/48x48/apps/"    + fb + ".svg",
              "file:///usr/share/icons/Papirus/32x32/apps/"    + fb + ".svg",
              "file:///usr/share/icons/hicolor/48x48/apps/"    + fb + ".png",
              "file:///usr/share/icons/hicolor/48x48/apps/"    + fb + ".svg",
              "file:///usr/share/icons/hicolor/scalable/apps/" + fb + ".svg",
              "file:///usr/share/pixmaps/"                     + fb + ".png",
              "file:///usr/share/pixmaps/"                     + fb + ".svg",
            ]
          }

          source: fallbackPaths.length > 0
            ? fallbackPaths[Math.min(fallbackAttempt, fallbackPaths.length - 1)]
            : ""

          onStatusChanged: {
            if (status === Image.Error) {
              if (fallbackAttempt < fallbackPaths.length - 1)
                fallbackAttempt++
              else
                fallbackAttempt = fallbackPaths.length
            }
          }

          onFallbackPathsChanged: fallbackAttempt = 0
        }

        // ── Ícone monocromático ──────────────────────────────────────────
        Item {
          id: monoContainer
          anchors.fill: parent
          visible:  root.monochrome
          opacity:  modelData.activated ? root.monoOpacity : root.monoOpacity * 0.45

          Behavior on opacity { NumberAnimation { duration: 150 } }

          Image {
            id: iconImgMono
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: appItem.exhausted ? fallbackImg.source : iconImg.source

            layer.enabled: true
            layer.effect: BrightnessContrast {
              brightness: 0.4
              contrast:  -0.3
            }
          }

          layer.enabled: true
          layer.effect: Colorize {
            hue: modelData.activated
              ? root.monoColorActive.hslHue
              : root.monoColor.hslHue
            saturation: modelData.activated
              ? root.monoColorActive.hslSaturation * 0.55
              : root.monoColor.hslSaturation * 0.55
            lightness: 0.0
          }
        }

        // ── Indicador de janela ativa ────────────────────────────────────
        // Usa monoColorActive quando monocromo, senão branco — corrige hardcode original
        Rectangle {
          anchors.bottom:           root.isHorizontal ? parent.bottom : undefined
          anchors.right:            root.isHorizontal ? undefined     : parent.right
          anchors.horizontalCenter: root.isHorizontal ? parent.horizontalCenter : undefined
          anchors.verticalCenter:   root.isHorizontal ? undefined     : parent.verticalCenter
          width:   root.isHorizontal ? 4 : 3
          height:  root.isHorizontal ? 3 : 4
          radius:  2
          visible: modelData.activated
          color:   root.monochrome ? root.monoColorActive : "white"
          opacity: modelData.activated ? 0.85 : 0.0

          Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: Hyprland.dispatch("hl.dsp.focus({ window = 'address:0x" + modelData.address + "'})")
        }
      }
    }
  }
}
