import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Widgets
import qs.components

// Agente polkit da sessao (no lugar do hyprpolkitagent: so um agente registra por
// sessao). Pedido de senha do sistema (pkexec, systemctl, apps) desce da barra
// como os menus; mostra o id da acao p/ saber o que esta sendo autorizado. Esc,
// Cancelar ou clique fora cancelam o pedido (nao so escondem).
PopupBase {
  id: root

  panelWidth: 420
  padTop: 16
  padBottom: 14
  padX: 22
  spacing: 10
  backdropFocus: false     // o foco e do campo de senha

  readonly property var flow: agent.flow
  // pedido respondido e esperando o PAM: campo travado ate o proximo pedido ou o fim
  property bool waiting: false
  property string error: ""

  function submit() {
    if (!flow || waiting || !flow.isResponseRequired)
      return;
    waiting = true;
    error = "";
    flow.submit(input.text);
    input.text = "";
  }
  function cancel() {
    if (agent.isActive && flow)
      flow.cancelAuthenticationRequest();
  }

  // fechou por Esc/clique fora com o pedido aberto = cancelar
  onOpenChanged: {
    if (!open)
      cancel();
  }

  PolkitAgent {
    id: agent
    onIsActiveChanged: {
      root.waiting = false;
      root.error = "";
      root.open = isActive;
    }
  }

  Connections {
    target: root.flow
    function onAuthenticationFailed() {
      root.waiting = false;
      root.error = "Senha incorreta";
    }
    function onIsResponseRequiredChanged() {
      if (root.flow.isResponseRequired)
        root.waiting = false;
    }
  }

  // cabecalho: icone do app + titulo
  RowLayout {
    Layout.fillWidth: true
    spacing: 12
    Item {
      Layout.preferredWidth: 36
      Layout.preferredHeight: 36
      IconImage {
        id: appIcon
        anchors.fill: parent
        source: root.flow && root.flow.iconName !== "" ? Quickshell.iconPath(root.flow.iconName, true) : ""
        visible: source !== "" && status === Image.Ready
      }
      Glyph {
        anchors.centerIn: parent
        visible: !appIcon.visible
        font.pixelSize: Theme.icon.l
        text: Icons.lock
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 0
      UiText {
        font.pixelSize: Theme.type.body_l
        font.weight: Font.DemiBold
        text: "Autenticação necessária"
      }
      UiText {
        Layout.fillWidth: true
        visible: text !== ""
        color: Theme.outline
        font.pixelSize: Theme.type.label_s
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
        text: root.flow ? root.flow.actionId : ""
      }
    }
  }

  UiText {
    Layout.fillWidth: true
    color: Theme.onSurfaceVariant
    font.pixelSize: Theme.type.body_m
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: root.flow ? root.flow.message : ""
  }

  // campo de senha (pill, como o lock)
  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 4
    Layout.preferredHeight: 42
    radius: height / 2
    color: Theme.surfaceContainer
    border.width: 1
    border.color: root.error !== "" ? Theme.error : (input.activeFocus ? Theme.primary : Theme.surfaceContainerHighest)

    Glyph {
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      color: root.error !== "" ? Theme.error : Theme.primary
      text: Icons.lock
    }
    TextInput {
      id: input
      anchors.fill: parent
      anchors.leftMargin: 40
      anchors.rightMargin: 16
      verticalAlignment: TextInput.AlignVCenter
      color: Theme.onSurface
      font.family: Theme.uiFont
      font.pixelSize: Theme.type.body_l
      echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
      passwordCharacter: "•"
      focus: root.open
      readOnly: root.waiting       // readOnly (nao enabled): mantem o foco
      onTextChanged: {
        if (text !== "")
          root.error = "";
      }
      onAccepted: root.submit()
      Keys.onEscapePressed: root.close()
    }
    UiText {
      anchors.fill: input
      visible: input.text === ""
      verticalAlignment: Text.AlignVCenter
      color: Theme.outline
      font.pixelSize: Theme.type.body_l
      elide: Text.ElideRight
      textFormat: Text.PlainText
      // "Password:" do PAM sem os dois pontos; sem prompt = "Senha"
      text: root.waiting ? "Verificando…" : (root.flow && root.flow.inputPrompt.trim().replace(/:$/, "") !== "" ? root.flow.inputPrompt.trim().replace(/:$/, "") : "Senha")
    }
  }

  // erro da tentativa ou aviso do PAM (ex.: faillock)
  UiText {
    Layout.fillWidth: true
    visible: text !== ""
    color: root.error !== "" || (root.flow && root.flow.supplementaryIsError) ? Theme.error : Theme.onSurfaceVariant
    font.pixelSize: Theme.type.label_m
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: root.error !== "" ? root.error : (root.flow ? root.flow.supplementaryMessage : "")
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 2
    spacing: 8
    Item {
      Layout.fillWidth: true
    }
    Repeater {
      model: [
        {
          label: "Cancelar",
          main: false
        },
        {
          label: "Autenticar",
          main: true
        }
      ]
      delegate: Rectangle {
        id: btn
        required property var modelData
        implicitWidth: btnLabel.implicitWidth + 32
        implicitHeight: 32
        radius: 16
        color: btn.modelData.main ? (btnArea.containsMouse ? Theme.secondary : Theme.primary) : (btnArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
        opacity: btn.modelData.main && root.waiting ? 0.5 : 1
        UiText {
          id: btnLabel
          anchors.centerIn: parent
          color: btn.modelData.main ? Theme.onPrimary : Theme.onSurface
          font.pixelSize: Theme.type.body_m
          font.weight: Font.DemiBold
          text: btn.modelData.label
        }
        MouseArea {
          id: btnArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (btn.modelData.main)
              root.submit();
            else
              root.close();
          }
        }
      }
    }
  }
}
