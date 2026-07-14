import QtQuick

// ── Sparkline ────────────────────────────────────────────────────────────
// Mini gráfico de linha (histórico recente) usado pelos widgets de
// monitoramento (CPU/RAM/GPU/Rede). Espera valores já normalizados em
// 0..100 — quem alimenta `history` decide a escala (% direto pra CPU/RAM,
// max-scaling pra taxas de rede que não têm teto natural).

Canvas {
  id: root

  property var   history: []   // array de números 0..100
  property color lineColor: "white"
  property color fillColor: Qt.rgba(1, 1, 1, 0.08)
  property real  strokeWidth: 1.5

  onHistoryChanged: requestPaint()
  onWidthChanged:  requestPaint()
  onHeightChanged: requestPaint()
  onLineColorChanged: requestPaint()

  onPaint: {
    const ctx = getContext("2d")
    ctx.reset()
    if (history.length < 2 || width <= 0 || height <= 0) return

    const n = history.length
    const stepX = width / (n - 1)
    const yFor = (v) => height - (Math.max(0, Math.min(100, v)) / 100) * height

    // preenchimento sob a linha
    ctx.beginPath()
    ctx.moveTo(0, height)
    for (let i = 0; i < n; i++) ctx.lineTo(i * stepX, yFor(history[i]))
    ctx.lineTo(width, height)
    ctx.closePath()
    ctx.fillStyle = fillColor
    ctx.fill()

    // linha
    ctx.beginPath()
    for (let i = 0; i < n; i++) {
      const x = i * stepX, y = yFor(history[i])
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.strokeStyle = lineColor
    ctx.lineWidth = strokeWidth
    ctx.lineJoin = "round"
    ctx.stroke()
  }
}
