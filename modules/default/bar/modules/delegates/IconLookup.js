// ── IconLookup.js ─────────────────────────────────────────────────────────────
// Lógica de resolução de ícone de aplicativo, extraída do Icons.qml para ser
// compartilhada entre o módulo de ícones da barra e o WsTooltip (que mostra
// a lista de janelas de um workspace com ícone + título).
//
// Uso (de dentro de um arquivo QML):
//   import "IconLookup.js" as IconLookup
//   var entry     = IconLookup.findDesktopEntry(appId, DesktopEntries)
//   var iconName  = IconLookup.resolveIconName(entry)
//   var iconPaths = IconLookup.buildIconPaths(iconName, homeDir)

function findDesktopEntry(appId, DesktopEntries) {
    if (!appId) return null
    if (DesktopEntries.applications.values.length === 0) return null

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
                var appName       = (app.name || "").toLowerCase().replace(/\s+/g, "")
                var appNameSpaced = (app.name || "").toLowerCase()
                var appIdLower    = (app.id   || "").toLowerCase().replace(/\s+/g, "")

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

function resolveIconName(entry) {
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

function buildIconPaths(iconName, homeDir) {
    if (!iconName) return []
    if (iconName.startsWith("/")) return [toFileUri(iconName)]

    var n = iconName
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
        "file://" + homeDir + "/.local/share/icons/hicolor/scalable/apps/" + n + ".svg",
        "file://" + homeDir + "/.local/share/icons/hicolor/256x256/apps/"  + n + ".png",
        "file://" + homeDir + "/.local/share/icons/hicolor/128x128/apps/"  + n + ".png",
        "file://" + homeDir + "/.local/share/icons/hicolor/96x96/apps/"    + n + ".png",
        "file://" + homeDir + "/.local/share/icons/hicolor/64x64/apps/"    + n + ".png",
        "file://" + homeDir + "/.local/share/icons/hicolor/48x48/apps/"    + n + ".png",
        "file://" + homeDir + "/.local/share/pixmaps/" + n + ".png",
        "file://" + homeDir + "/.local/share/pixmaps/" + n + ".svg",
    ]
}

// Conveniência: appId → primeiro caminho de ícone candidato (sem fallback
// progressivo de Image.onStatusChanged — para uso simples em tooltips onde
// não vale a pena tentar N caminhos, só o mais provável).
function firstIconPath(appId, DesktopEntries, homeDir) {
    var entry = findDesktopEntry(appId, DesktopEntries)
    var name  = resolveIconName(entry)
    var paths = buildIconPaths(name, homeDir)
    return paths.length > 0 ? paths[0] : ""
}
