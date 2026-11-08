import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components

// Tela de sessao (SUPER+CTRL+P e o botao de energia da barra): camada escura na tela
// toda e seis acoes. Bloquear e imediato; as outras armam no 1o Enter/clique (e checam
// o que se perderia: scripts/power-check.sh) e confirmam no 2o. Setas escolhem, Esc
// desarma e depois fecha, clique no fundo fecha. Botao em foco vira circulo (morph M3E).
PanelWindow {
  id: root

  WlrLayershell.namespace: "quickshell:session"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  color: "transparent"
  visible: open || fade > 0.001

  property bool open: false
  property int sel: 0
  property string armed: ""
  property var warns: []
  property real fade: open ? 1 : 0
  Behavior on fade {
    NumberAnimation {
      duration: Theme.animNormal
      easing.type: Easing.OutCubic
    }
  }

  readonly property var actions: [
    { id: "lock", label: "Bloquear", icon: Icons.lock, cmd: null },
    { id: "suspend", label: "Dormir", icon: Icons.suspend, cmd: ["systemctl", "suspend"] },
    { id: "hibernate", label: "Hibernar", icon: Icons.hibernate, cmd: ["systemctl", "hibernate"] },
    { id: "logout", label: "Sair", icon: Icons.logout, cmd: ["sh", "-c", "uwsm check is-active >/dev/null 2>&1 && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
    { id: "reboot", label: "Reiniciar", icon: Icons.reboot, cmd: ["systemctl", "reboot"] },
    { id: "shutdown", label: "Desligar", icon: Icons.shutdown, cmd: ["systemctl", "poweroff"] }
  ]

  function toggle() {
    if (open) {
      close();
      return;
    }
    armed = "";
    warns = [];
    sel = 0;
    open = true;
  }
  function close() {
    open = false;
    armed = "";
  }
  function fire(i) {
    const a = actions[i];
    sel = i;
    if (a.id === "lock") {
      close();
      Hyprland.dispatch('hl.dsp.global("quickshell:lock")');
      return;
    }
    if (armed !== a.id) {
      armed = a.id;
      warns = [];
      check.running = true;
      return;
    }
    close();
    Quickshell.execDetached(a.cmd);
  }

  Process {
    id: check
    command: ["sh", Quickshell.shellPath("scripts/power-check.sh")]
    stdout: StdioCollector {
      onStreamFinished: root.warns = text.split("\n").filter(l => l !== "")
    }
  }

  // fundo: escurece a tela; clique fora dos botoes fecha
  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Theme.scrim, 0.7)
    opacity: root.fade
    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  Item {
    anchors.fill: parent
    focus: root.open
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape) {
        if (root.armed !== "")
          root.armed = "";
        else
          root.close();
      } else if (event.key === Qt.Key_Left) {
        root.sel = Math.max(0, root.sel - 1);
        root.armed = "";
      } else if (event.key === Qt.Key_Right) {
        root.sel = Math.min(root.actions.length - 1, root.sel + 1);
        root.armed = "";
      } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
        root.fire(root.sel);
      } else {
        return;
      }
      event.accepted = true;
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    spacing: Theme.space.xl
    opacity: root.fade
    scale: 0.94 + 0.06 * root.fade

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Theme.space.lg

      Repeater {
        model: root.actions

        ColumnLayout {
          id: item
          required property var modelData
          required property int index
          readonly property bool focused: root.sel === index
          readonly property bool isArmed: root.armed === modelData.id
          spacing: Theme.space.sm

          Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            // morph M3E: em foco vira circulo
            // fallback: os tokens chegam depois do 1o frame no reload, e o spring nao anda
            // com a janela escondida (o raio ficava preso em 0)
            radius: item.focused || area.containsMouse ? width / 2 : (Theme.shape.dialog || 28)
            Behavior on radius {
              enabled: !Theme.reduceMotion
              SpringPill {}
            }
            color: item.isArmed ? (item.modelData.id === "shutdown" || item.modelData.id === "reboot" ? Theme.error : Theme.primary) : (item.focused ? Theme.primaryContainer : Theme.surfaceContainer)
            Behavior on color {
              ColorAnimation {
                duration: Theme.animFast
              }
            }
            Glyph {
              anchors.centerIn: parent
              font.pixelSize: Theme.icon.xl
              color: item.isArmed ? Theme.fgPrimary : (item.focused ? Theme.fgPrimaryContainer : Theme.fgSurface)
              text: item.modelData.icon
            }
            MouseArea {
              id: area
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: {
                if (root.sel !== item.index)
                  root.armed = "";
                root.sel = item.index;
              }
              onClicked: root.fire(item.index)
            }
          }
          UiText {
            Layout.alignment: Qt.AlignHCenter
            color: item.focused ? Theme.fgSurface : Theme.fgSurfaceVariant
            font.pixelSize: Theme.type.body_l
            text: item.modelData.label
          }
        }
      }
    }

    // armado: o aviso mais importante (power-check) ou a confirmacao
    UiText {
      Layout.alignment: Qt.AlignHCenter
      Layout.maximumWidth: 600
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: root.warns.length > 0 ? Theme.warning : Theme.fgSurface
      font.pixelSize: Theme.type.body_l
      text: {
        if (root.armed === "")
          return "Enter escolhe · Esc fecha";
        const a = root.actions.find(x => x.id === root.armed);
        const w = root.warns;
        if (w.length === 0)
          return "Enter de novo para " + a.label.toLowerCase();
        return w[0] + (w.length > 1 ? ` (+${w.length - 1})` : "") + " — Enter de novo para " + a.label.toLowerCase() + " mesmo assim";
      }
    }
  }
}
