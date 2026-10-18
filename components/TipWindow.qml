import QtQuick
import Quickshell
import Quickshell.Wayland

// Tooltip proprio: caixa opaca que abre abaixo da barra, centralizada
// no controle. O ToolTip do QtQuick.Controls e translucido (vaza o
// papel de parede) e estreito (quebra o cal, corta pacotes).
//
// A janela tem o TAMANHO DO TOOLTIP (layer-shell ancorada em top+left, posicao
// por margens). Antes era uma janela de tela cheia mapeada a cada hover: buffer
// de ~8MB por tooltip, damage de tela inteira e GL alocando/liberando toda hora.
// Per-screen: converte global (mapToGlobal) p/ local subtraindo a origem da
// tela (HDMI fica em x=-1920).
PanelWindow {
  id: root

  property bool tipOpen: false
  property string tipText: ""
  property real tipX: 0       // centro do controle, coordenadas da tela
  property real tipY: 0       // topo do tooltip
  property bool tipMono: false

  readonly property real screenW: root.screen ? root.screen.width : 1920
  readonly property real screenH: root.screen ? root.screen.height : 1080

  anchors.top: true
  anchors.left: true
  margins.left: Math.max(8, Math.min(screenW - box.width - 8, tipX - box.width / 2))
  margins.top: Math.max(8, Math.min(screenH - box.height - 8, tipY))
  implicitWidth: box.width
  implicitHeight: box.height
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}
  color: "transparent"
  visible: tipOpen

  function toLocal(p) {
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    const sy = (root.screen && root.screen.y !== undefined) ? root.screen.y : 0;
    return Qt.point(p.x - sx, p.y - sy + 18);
  }
  function show(t, p, mono) {
    tipText = t;
    tipMono = mono;
    const lp = toLocal(p);
    tipX = lp.x;
    tipY = lp.y;
    tipOpen = true;
  }
  function move(p) {
    const lp = toLocal(p);
    tipX = lp.x;
    tipY = lp.y;
  }
  function hide() {
    tipOpen = false;
  }

  Rectangle {
    id: box
    color: Theme.base
    border.color: Theme.mauve
    border.width: 1
    radius: 8
    width: tipLabel.implicitWidth + 20
    height: tipLabel.implicitHeight + 16

    UiText {
      id: tipLabel
      anchors.centerIn: parent
      font.family: root.tipMono ? "monospace" : Theme.uiFont
      font.weight: Font.DemiBold
      text: root.tipText
    }
  }
}
