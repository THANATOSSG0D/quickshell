import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Scope {
  id: weatherWidget

  WeatherConfig { id: config }

  property real   temperature: NaN
  property real   feelsLike: NaN
  property int    weatherCode: 0
  property bool   loaded: false
  property string lastError: ""

  // Código WMO → { icon, label }. https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  function describeCode(code) {
    const map = {
      0:  { icon: "☀️", label: "Céu limpo" },
      1:  { icon: "🌤️", label: "Poucas nuvens" },
      2:  { icon: "⛅",  label: "Parcialmente nublado" },
      3:  { icon: "☁️",  label: "Nublado" },
      45: { icon: "🌫️", label: "Neblina" },
      48: { icon: "🌫️", label: "Neblina" },
      51: { icon: "🌦️", label: "Garoa fraca" },
      53: { icon: "🌦️", label: "Garoa" },
      55: { icon: "🌦️", label: "Garoa forte" },
      61: { icon: "🌧️", label: "Chuva fraca" },
      63: { icon: "🌧️", label: "Chuva" },
      65: { icon: "🌧️", label: "Chuva forte" },
      71: { icon: "🌨️", label: "Neve fraca" },
      73: { icon: "🌨️", label: "Neve" },
      75: { icon: "🌨️", label: "Neve forte" },
      80: { icon: "🌦️", label: "Pancadas de chuva" },
      81: { icon: "🌦️", label: "Pancadas de chuva" },
      82: { icon: "⛈️", label: "Pancadas fortes" },
      95: { icon: "⛈️", label: "Trovoada" },
      96: { icon: "⛈️", label: "Trovoada c/ granizo" },
      99: { icon: "⛈️", label: "Trovoada forte c/ granizo" },
    }
    return map[code] || { icon: "🌡️", label: "—" }
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  Process {
    id: fetchProc
    command: [
      "curl", "-s", "--max-time", "8",
      "https://api.open-meteo.com/v1/forecast" +
        "?latitude=" + config.latitude +
        "&longitude=" + config.longitude +
        "&current=temperature_2m,apparent_temperature,weather_code" +
        "&temperature_unit=" + (config.units === "fahrenheit" ? "fahrenheit" : "celsius") +
        "&timezone=auto"
    ]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(text)
          weatherWidget.temperature = data.current.temperature_2m
          weatherWidget.feelsLike   = data.current.apparent_temperature
          weatherWidget.weatherCode = data.current.weather_code
          weatherWidget.loaded = true
          weatherWidget.lastError = ""
        } catch (e) {
          weatherWidget.lastError = "Erro ao ler dados do clima"
        }
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) weatherWidget.lastError = "Falha ao buscar clima (curl)"
    }
  }

  // busca periódica
  Timer {
    interval: Math.max(1, config.updateIntervalMin) * 60 * 1000
    running: true; repeat: true
    onTriggered: weatherWidget.refresh()
  }

  // primeira busca, com um pequeno atraso pra garantir que o config
  // (latitude/longitude salvos) já carregou do JSON antes de disparar
  Timer {
    interval: 800; running: true; repeat: false
    onTriggered: weatherWidget.refresh()
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        Component.onCompleted: {
          if (this.WlrLayershell != null)
            this.WlrLayershell.layer = WlrLayer.Bottom
        }

        mask: Region { item: content }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
          { h: Qt.AlignRight,   v: Qt.AlignBottom  },
        ]

        Item {
          id: content
          x: {
            if (positions[config.position].h === Qt.AlignLeft)  return config.edgeMargin
            if (positions[config.position].h === Qt.AlignRight) return parent.width - width - config.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[config.position].v === Qt.AlignTop)    return config.edgeMargin
            if (positions[config.position].v === Qt.AlignBottom) return parent.height - height - config.edgeMargin
            return (parent.height - height) / 2
          }
          width: layout.implicitWidth
          height: layout.implicitHeight

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: weatherWidget.refresh()

            ToolTip.visible: containsMouse
            ToolTip.text: "clique para atualizar"
            ToolTip.delay: 400
          }

          ColumnLayout {
            id: layout
            spacing: 2

            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: 8

              Text {
                visible: config.showIcon
                text: weatherWidget.describeCode(weatherWidget.weatherCode).icon
                font.pixelSize: config.fontSizeTemp * 0.6
              }

              Text {
                text: fetchProc.running
                  ? "…"
                  : (weatherWidget.loaded
                      ? Math.round(weatherWidget.temperature) + "°" + (config.units === "fahrenheit" ? "F" : "C")
                      : (weatherWidget.lastError || "…"))
                color: Colors[config.colorTemp]
                font { pixelSize: config.fontSizeTemp; family: "Inter"; weight: Font.Light }
              }
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: config.cityLabel + " · " + weatherWidget.describeCode(weatherWidget.weatherCode).label
              color: Colors[config.colorDesc]
              font { pixelSize: config.fontSizeDesc; family: "Inter" }
            }

            Text {
              Layout.alignment: Qt.AlignHCenter
              visible: config.showFeelsLike && weatherWidget.loaded
              text: "sensação " + Math.round(weatherWidget.feelsLike) + "°"
              color: Colors[config.colorDesc]
              opacity: 0.7
              font.pixelSize: config.fontSizeDesc - 2
            }
          }
        }
      }
    }
  }
}
