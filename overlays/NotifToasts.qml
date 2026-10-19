import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// Toasts: uma aba unica colada no filete direito (EdgeTab), com os cartoes
// dentro. Entra deslizando pela borda e sai do mesmo jeito; a altura acompanha
// a quantidade de toasts. Instancia unica que segue o monitor focado (como o OSD).
//
// Janela estreita (so a largura da aba) e click-through fora dela: a mascara e
// a propria aba. Fica desmapeada quando nao ha toast.
PanelWindow {
  id: root

  property bool suppress: false          // centro aberto: toasts somem

  readonly property int pad: 14
  readonly property int ear: Theme.scoop
  readonly property int tabW: Theme.sideTabW + Theme.edge
  readonly property int maxVisible: 4

  readonly property var live: Notifs.popups.slice(0, maxVisible)
  readonly property bool want: !suppress && live.length > 0

  // O que a lista exibe. Congela ao sumir: durante o slide de saida o conteudo
  // precisa continuar la (senao a aba colapsa antes de sair).
  property var shown: []
  onLiveChanged: {
    if (want)
      shown = live;
  }
  onWantChanged: {
    if (want)
      shown = live;
  }

  // Altura do conteudo, congelada enquanto a aba sai: se o conteudo mudasse no
  // meio do slide (item destruido, lista esvaziando) a aba encolheria vazia.
  property real stackH: 0

  // 0 = aberto, 1 = fechado (mesmo spring do PopupBase)
  property real offsetScale: want ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }

  anchors.top: true
  anchors.bottom: true
  anchors.right: true
  implicitWidth: tabW
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  visible: want || offsetScale < 0.999
  mask: Region {
    item: tab
  }

  onVisibleChanged: {
    if (!visible)
      shown = [];
  }

  Item {
    id: tab
    x: 0
    y: Theme.sideTabTop
    width: root.tabW
    height: root.stackH + 2 * root.pad + 2 * root.ear
    clip: true

    // so anima com a aba ja na tela (ao entrar ela nasce no tamanho certo)
    Behavior on height {
      enabled: root.want && root.offsetScale < 0.3
      NumberAnimation {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    // conteudo rigido que desliza para a direita dentro do clip
    Item {
      width: parent.width
      height: parent.height
      x: width * root.offsetScale

      EdgeTab {
        anchors.fill: parent
        color: Theme.base
      }

      Column {
        id: stack
        x: root.pad
        y: root.ear + root.pad
        width: Theme.sideTabW - 2 * root.pad
        spacing: 8

        onImplicitHeightChanged: {
          if (root.want)
            root.stackH = implicitHeight;
        }

        add: Transition {
          NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 160
          }
        }
        move: Transition {
          NumberAnimation {
            property: "y"
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        Repeater {
          model: ScriptModel {
            values: root.shown
          }
          delegate: NotifCard {
            required property var modelData
            width: stack.width
            item: modelData
            toast: true
            onBodyClicked: modelData.hidePopup()
          }
        }
      }
    }
  }
}
