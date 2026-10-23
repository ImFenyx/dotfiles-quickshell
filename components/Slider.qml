import QtQuick

// Slider proprio (a shell nao usa QtQuick.Controls): trilho + preenchimento +
// bolinha no hover/arrasto. `value` (0..1) vem de fora por binding; clicar,
// arrastar ou rolar emite `moved(v)` e quem usa aplica (ex.: audio.volume = v).
// Acima de 1 (volume amplificado) o preenchimento fica cheio e a roda nao sobe.
Item {
  id: root

  property real value: 0
  property bool muted: false        // preenchimento apagado
  property color fill: Theme.blue
  signal moved(real value)

  readonly property real frac: Math.max(0, Math.min(1, value))

  implicitWidth: 160
  implicitHeight: 18

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: 3
    color: Theme.surface1
    Rectangle {
      width: parent.width * root.frac
      height: parent.height
      radius: 3
      color: root.muted ? Theme.overlay0 : root.fill
    }
  }
  Rectangle {
    anchors.verticalCenter: parent.verticalCenter
    x: track.width * root.frac - width / 2
    width: 14
    height: 14
    radius: 7
    color: Theme.text
    visible: area.containsMouse || area.pressed
  }

  MouseArea {
    id: area
    anchors.fill: parent
    anchors.topMargin: -4          // alvo maior que o trilho
    anchors.bottomMargin: -4
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    function at(x) {
      root.moved(Math.max(0, Math.min(1, x / width)));
    }
    onPressed: mouse => at(mouse.x)
    onPositionChanged: mouse => {
      if (pressed)
        at(mouse.x);
    }
    onWheel: wheel => {
      const d = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
      if (d > 0 && root.value >= 1)
        return;
      root.moved(Math.max(0, Math.min(1, root.value + d)));
    }
  }
}
