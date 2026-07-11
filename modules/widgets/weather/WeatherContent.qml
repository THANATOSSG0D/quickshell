import qs

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root
  property bool grouped: false

  WeatherConfig { id: config }

  property real   temperature: NaN
  property real   feelsLike: NaN
  property int    weatherCode: 0
  property bool   loaded: false
  property string lastError: ""

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
          root.temperature = data.current.temperature_2m
          root.feelsLike   = data.current.apparent_temperature
          root.weatherCode = data.current.weather_code
          root.loaded = true
          root.lastError = ""
        } catch (e) {
          root.lastError = "Erro ao ler dados do clima"
        }
      }
    }
    onExited: (exitCode) => {
      if (exitCode !== 0) root.lastError = "Falha ao buscar clima (curl)"
    }
  }

  Timer {
    interval: Math.max(1, config.updateIntervalMin) * 60 * 1000
    running: true; repeat: true
    onTriggered: root.refresh()
  }
  Timer {
    interval: 800; running: true; repeat: false
    onTriggered: root.refresh()
  }

  implicitWidth: layout.implicitWidth
  implicitHeight: layout.implicitHeight

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.refresh()
    ToolTip.visible: containsMouse
    ToolTip.text: "clique para atualizar"
    ToolTip.delay: 400
  }

  ColumnLayout {
    id: layout
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 2

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 8

      Text {
        visible: config.showIcon
        text: root.describeCode(root.weatherCode).icon
        font.pixelSize: config.fontSizeTemp * 0.6
      }
      Text {
        text: fetchProc.running
          ? "…"
          : (root.loaded
              ? Math.round(root.temperature) + "°" + (config.units === "fahrenheit" ? "F" : "C")
              : (root.lastError || "…"))
        color: Colors[config.colorTemp]
        font { pixelSize: config.fontSizeTemp; family: "Inter"; weight: Font.Light }
      }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      text: config.cityLabel + " · " + root.describeCode(root.weatherCode).label
      color: Colors[config.colorDesc]
      font { pixelSize: config.fontSizeDesc; family: "Inter" }
    }

    Text {
      Layout.alignment: Qt.AlignHCenter
      visible: config.showFeelsLike && root.loaded
      text: "sensação " + Math.round(root.feelsLike) + "°"
      color: Colors[config.colorDesc]
      opacity: 0.7
      font.pixelSize: config.fontSizeDesc - 2
    }
  }
}
