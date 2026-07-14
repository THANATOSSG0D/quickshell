import QtQuick

// CornerMask — desenha 1 canto arredondado: quadrado maskColor com um
// quarto de círculo "furado" (destination-out), revelando o conteúdo por
// baixo. Usado 4x por tela em ScreenCorners.qml.
Canvas {
  id: mask
  property string corner:    "topLeft"   // topLeft | topRight | bottomLeft | bottomRight
  property int    size:      24
  property color  maskColor: "black"

  width:  size
  height: size

  onCornerChanged:    requestPaint()
  onSizeChanged:       requestPaint()
  onMaskColorChanged:  requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)

    // Centro do "furo" = canto interno (diagonalmente oposto ao canto
    // físico da tela que este mask representa).
    var innerX, innerY
    switch (corner) {
      case "topLeft":     innerX = size; innerY = size; break
      case "topRight":    innerX = 0;    innerY = size; break
      case "bottomLeft":  innerX = size; innerY = 0;    break
      case "bottomRight": innerX = 0;    innerY = 0;    break
      default:            innerX = size; innerY = size
    }

    ctx.fillStyle = maskColor
    ctx.fillRect(0, 0, size, size)

    ctx.globalCompositeOperation = "destination-out"
    ctx.beginPath()
    ctx.arc(innerX, innerY, size, 0, 2 * Math.PI)
    ctx.fill()
    ctx.globalCompositeOperation = "source-over"
  }
}
