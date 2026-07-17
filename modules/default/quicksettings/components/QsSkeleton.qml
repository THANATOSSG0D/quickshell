import QtQuick

// ── QsSkeleton ────────────────────────────────────────────────────────────────
// Barra "shimmer" pra estados de carregamento (ex.: resumo do perfil de
// energia/shader enquanto o Process ainda não respondeu, no lugar do texto
// "Carregando…"). Só anima enquanto `active` for true — parada, não gasta
// ciclo de CPU à toa quando a subpágina não está visível.
//
// USO:
//   Qs.QsSkeleton { width: 90; active: root.shaderSummary === "Carregando…" }
Item {
    id: root

    property color baseColor: "#474747"
    property bool   active:   true

    implicitWidth:  64
    implicitHeight: 8

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.baseColor.r, root.baseColor.g, root.baseColor.b, 0.35)
        clip: true

        Rectangle {
            id: sweep
            width:  track.width * 0.45
            height: track.height
            radius: track.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0)    }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.28) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0)    }
            }

            SequentialAnimation {
                running: root.active
                loops: Animation.Infinite
                NumberAnimation {
                    target: sweep; property: "x"
                    from: -sweep.width; to: track.width
                    duration: 1100; easing.type: Easing.InOutQuad
                }
                PauseAnimation { duration: 300 }
            }
        }
    }
}
