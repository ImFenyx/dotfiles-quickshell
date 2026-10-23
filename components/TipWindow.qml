import QtQuick
import Quickshell
import Quickshell.Wayland

// Tooltip proprio: caixa opaca que abre abaixo da barra, centralizada
// no controle. O ToolTip do QtQuick.Controls e translucido (vaza o
// papel de parede) e estreito (quebra o cal, corta pacotes).
// Per-screen: converte global (mapToGlobal) p/ local subtraindo a
// origem da tela (HDMI fica em x=-1920).
PanelWindow {
  id: root

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}
  color: "transparent"
  visible: tipOpen

  property bool tipOpen: false
  property string tipText: ""
  property real tipX: 0
  property real tipY: 0
  property bool tipMono: false

  function toLocal(p) {
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    const sy = (root.screen && root.screen.y !== undefined) ? root.screen.y : 0;
    return Qt.point(p.x - sx, p.y - sy + 18);
  }
  function show(t, p, mono) {
    hideDelay.stop();
    tipText = t;
    const lp = toLocal(p);
    tipX = lp.x;
    tipY = lp.y;
    tipMono = mono;
    tipOpen = true;
  }
  function move(p) {
    const lp = toLocal(p);
    tipX = lp.x;
    tipY = lp.y;
  }
  // atraso: cruzar o vao entre dois widgets nao desmapeia/remapeia a janela
  // fullscreen (buffer da tela inteira)
  function hide() {
    hideDelay.restart();
  }
  Timer {
    id: hideDelay
    interval: 80
    onTriggered: root.tipOpen = false
  }

  Rectangle {
    color: Theme.base
    border.color: Theme.mauve
    border.width: 1
    radius: 8
    width: tipLabel.implicitWidth + 20
    height: tipLabel.implicitHeight + 16
    x: Math.max(8, Math.min(root.width - width - 8, root.tipX - width / 2))
    y: Math.max(8, Math.min(root.height - height - 8, root.tipY))

    UiText {
      id: tipLabel
      anchors.centerIn: parent
      font.family: root.tipMono ? "monospace" : Theme.uiFont
      font.weight: Font.DemiBold
      text: root.tipText
    }
  }
}
