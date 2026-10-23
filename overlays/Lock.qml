import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.components
import qs.services

// Tela de bloqueio nativa (ext-session-lock), no lugar do hyprlock. PAM pelo
// mesmo /etc/pam.d/hyprlock (login -> system-auth, com faillock: erros demais
// travam a conta por um tempo, igual ao hyprlock). Uma superficie por monitor,
// fundo = captura borrada da propria tela. Reload da shell com a tela travada
// mantem o lock (WlSessionLock e Reloadable).
//   qs ipc call lock lock | isLocked
Scope {
  id: root

  property string status: ""       // mensagem do PAM ou do resultado ("" = nada)
  property bool failed: false      // borda vermelha no campo
  property string pending: ""      // senha esperando o PAM pedir

  function lock() {
    if (sessionLock.locked)
      return;
    status = "";
    failed = false;
    sessionLock.locked = true;
  }
  function submit(pw) {
    if (pw === "" || pam.active)
      return;
    pending = pw;
    status = "";
    pam.start();
  }

  // A 1a captura de tela carrega o backend de forma assincrona; se fosse a do
  // lock (sessao ja travada) o compositor recusaria. Aquece uma vez (caelestia).
  Loader {
    active: true
    asynchronous: true
    onLoaded: active = false
    sourceComponent: ScreencopyView {
      captureSource: Quickshell.screens[0]
    }
  }

  PamContext {
    id: pam
    config: "hyprlock"
    configDirectory: "/etc/pam.d"

    onResponseRequiredChanged: {
      if (!responseRequired)
        return;
      respond(root.pending);
      root.pending = "";
    }
    // faillock ("The account is locked ...") e outros avisos do PAM
    onMessageChanged: {
      if (messageIsError || message.startsWith("The account is locked"))
        root.status = message;
    }
    onCompleted: result => {
      root.pending = "";
      if (result === PamResult.Success) {
        sessionLock.locked = false;
        return;
      }
      root.failed = true;
      if (root.status === "")
        root.status = result === PamResult.MaxTries ? "Tentativas demais" : (result === PamResult.Error ? "Erro no PAM" : "Senha incorreta");
    }
  }

  WlSessionLock {
    id: sessionLock

    WlSessionLockSurface {
      id: surface
      color: Theme.base

      ScreencopyView {
        id: shot
        anchors.fill: parent
        captureSource: surface.screen
        visible: false             // so a versao borrada aparece
      }
      MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.hasContent   // sem captura: fica o Theme.base
        blurEnabled: true
        blur: 1
        blurMax: 64
        brightness: -0.25
      }

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        UiText {
          Layout.alignment: Qt.AlignHCenter
          font.pointSize: 64
          font.weight: Font.DemiBold
          text: Time.clockText
        }
        UiText {
          Layout.alignment: Qt.AlignHCenter
          color: Theme.subtext0
          font.pointSize: 13
          text: Time.longDate
        }

        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 28
          Layout.preferredWidth: 320
          Layout.preferredHeight: 46
          radius: height / 2
          color: Theme.surface0
          border.width: 1
          border.color: root.failed ? Theme.red : (input.activeFocus ? Theme.mauve : Theme.surface1)

          Glyph {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            color: root.failed ? Theme.red : Theme.mauve
            text: Icons.lock
          }
          TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 44
            anchors.rightMargin: 18
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.text
            font.family: Theme.uiFont
            font.pointSize: 13
            echoMode: TextInput.Password
            passwordCharacter: "•"
            focus: true
            readOnly: pam.active         // readOnly (nao enabled): mantem o foco
            onTextChanged: {
              if (text !== "")
                root.failed = false;
            }
            onAccepted: {
              root.submit(text);
              text = "";
            }
            Keys.onEscapePressed: text = ""
          }
          UiText {
            anchors.fill: input
            visible: input.text === ""
            verticalAlignment: Text.AlignVCenter
            color: Theme.overlay0
            font.pointSize: 13
            text: pam.active ? "Verificando…" : "Senha"
          }
        }

        UiText {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: 6
          Layout.maximumWidth: 420
          visible: root.status !== ""
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          color: Theme.red
          font.pointSize: 10
          text: root.status
        }
      }
    }
  }

  IpcHandler {
    target: "lock"
    function lock(): void {
      root.lock();
    }
    function isLocked(): bool {
      return sessionLock.locked;
    }
  }
}
