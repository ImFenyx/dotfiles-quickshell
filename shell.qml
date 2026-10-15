//@ pragma IconTheme MacTahoe-purple-dark
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Wayland

// Barra quickshell — replica ~/.config/waybar (style.css + config.jsonc).
// Numeros em Rubik, icones em Nerd Font (sem fallback misturado).
// Hyprland com IPC lua: dispatchs usam a forma hl.dsp.*.
// Multi-monitor: barra + moldura + exclusoes + tooltip + menus de clique sao
// per-screen (Variants model: Quickshell.screens). Estado compartilhado vive
// no ShellRoot (shRoot.*) e a UI liga via binding — sem set imperativo por id,
// que quebraria com 2 instancias. Launcher + OSDs sao instancia unica que
// segue o monitor focado (screen: focusedScreen).
ShellRoot {
  id: shRoot
  property string uiFont: "Rubik"
  property string nerdFont: "JetBrainsMono Nerd Font Propo"
  property string calText: ""
  property string wifiSig: ""
  property string updatesTip: "…"
  property bool updatesKnown: false
  property int dotTick: 0
  property bool wifiOn: true
  onWifiOnChanged: wifiProc.running = true

  // ---- estado compartilhado (bindings per-screen) ----
  property string wifiNameStr: "--"
  property string wifiIconStr: ""
  property string updNumStr: ""
  property string updIconStr: ""
  property string sinkText: "--"
  property string sinkIconStr: ""
  property string micText: ""
  property bool micVisible: false
  property string brightText: "--"
  property string brightIconStr: ""
  property string notifText: ""

  // constantes da barra (espelho de barWin.gap/barH p/ OSDs single-instance)
  property int barH: 48

  // tela do monitor focado: launcher + OSDs aparecem onde voce esta
  property var focusedScreen: {
    var f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    var ss = Quickshell.screens;
    for (var i = 0; i < ss.length; ++i) {
      if (ss[i] && ss[i].name === f)
        return ss[i];
    }
    return ss.length > 0 ? ss[0] : null;
  }

  function levelIcon(pct, icons) {
    const i = Math.max(0, Math.min(icons.length - 1, Math.floor(pct / 100 * icons.length)));
    return icons[i];
  }
  property bool micArmed: false
  property var volIcons: ["\uf026", "\uf027", "\uf028"]
  property var blIcons: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf", "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"]
  property var wifiIcons: [String.fromCodePoint(0xF091F), String.fromCodePoint(0xF0922), String.fromCodePoint(0xF0925), String.fromCodePoint(0xF0928)]

  property int wsRev: 0
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      // so reordena quando o conjunto de workspaces pode ter mudado.
      // activewindow/fullscreen/focus disparam toda hora e nao afetam a ordem.
      const n = event.name || "";
      if (n.indexOf("workspace") !== -1 || n.indexOf("special") !== -1
        || n === "openwindow" || n === "closewindow" || n === "movewindowv2")
        wsRev++;
    }
  }

  property var sortedWorkspaces: {
    wsRev; // reordena ao adicionar/remover workspace
    const ws = [...Hyprland.workspaces.values];
    const key = w => {
      if (w.name.startsWith("special:"))
        return 1e9;
      const n = parseInt(w.name, 10);
      return isNaN(n) ? 1e9 - 1 : n;
    };
    ws.sort((a, b) => (key(a) - key(b)) || ((a.name < b.name) ? -1 : 1));
    return ws;
  }

  // ---- pollers ----
  Process {
    id: wifiProc
    command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^\\*:' | head -n1"]
    // StdioCollector (e nao SplitParser): dispara mesmo com saida vazia,
    // senao ao desconectar o SSID antigo ficava preso na pill.
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.trim().match(/^\*:([^:]*):(\d+)/m);
        if (!shRoot.wifiOn || !m) {
          shRoot.wifiNameStr = shRoot.wifiOn ? "--" : "off";
          shRoot.wifiSig = "";
          shRoot.wifiIconStr = "";
          return;
        }
        const sig = parseInt(m[2], 10);
        shRoot.wifiNameStr = m[1] || "--";
        shRoot.wifiSig = isNaN(sig) ? "" : sig + "%";
        shRoot.wifiIconStr = isNaN(sig) ? "" : shRoot.levelIcon(sig, shRoot.wifiIcons);
      }
    }
  }
  Process {
    id: wifiRadioProc
    command: ["nmcli", "radio", "wifi"]
    stdout: SplitParser {
      onRead: data => {
        shRoot.wifiOn = data.trim() === "enabled";
      }
    }
  }
  // Processo unico atomico (scripts/updates.sh): 1a linha=total, resto=lista 16.
  // Unico por vez: dois checkupdates simultaneos disputam o lock de /tmp/checkup-db
  // e um morre -> badge parcial (foi o bug do "7"). Falha -> sem saida -> mantem valor.
  Timer {
    interval: 120
    running: !updatesKnown
    repeat: true
    onTriggered: dotTick++
  }
  // Parse do poll (updates.sh). Falha -> sem saida -> mantem ultimo valor.
  function parseUpdates(text) {
    const lines = text.trim().split("\n").filter(l => l.length > 0);
    if (lines.length < 1)
      return;
    const n = parseInt(lines[0], 10);
    if (isNaN(n))
      return;
    updatesKnown = true;
    updNumStr = String(n);
    updIconStr = n > 0 ? String.fromCodePoint(0xF1377) : String.fromCodePoint(0xF00AA);
    const pkgs = lines.slice(1);
    updatesTip = n === 0 ? "Sistema atualizado" : pkgs.join("\n") + (n > pkgs.length ? "\n+" + (n - pkgs.length) + " outros" : "");
  }
  Process {
    id: updatesProc
    command: ["sh", "/home/fenyx/.config/quickshell/scripts/updates.sh"]
    stdout: StdioCollector {
      onStreamFinished: shRoot.parseUpdates(text)
    }
  }
  // Estreia instantanea: le o cache do ultimo poll antes do primeiro check.
  Process {
    id: updatesCacheProc
    command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/updates-cache\" 2>/dev/null"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: shRoot.parseUpdates(text)
    }
  }
  Process {
    id: calProc
    command: ["cal"]
    stdout: StdioCollector {
      onStreamFinished: shRoot.calText = text.trim()
    }
  }
  // Via wpctl (nativo PipeWire): pamixer falha intermitente ("Connection
  // error") e quebrava o avizo. StdioCollector + ignora vazio: sem "mut"
  // fantasma em falha transitoria.
  Process {
    id: audioProc
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length < 1 || lines[0].trim() === "")
          return;
        const sm = lines[0].match(/Volume:\s+([\d.]+)(.*)/);
        if (!sm)
          return;
        const v = Math.round(parseFloat(sm[1]) * 100);
        const muted = sm[2].indexOf("MUTED") !== -1;
        const sTxt = muted ? "mut" : v + "%";
        const sIcon = (muted || isNaN(v)) ? "" : shRoot.levelIcon(v, shRoot.volIcons);
        if (shRoot.sinkText !== sTxt || shRoot.sinkIconStr !== sIcon) {
          const first = shRoot.sinkText === "--" && shRoot.sinkIconStr === "";
          shRoot.sinkText = sTxt;
          shRoot.sinkIconStr = sIcon;
          if (!first)
            {
              brightOsd.osdOpen = false;
              micOsd.osdOpen = false;
              volOsd.show(v, muted, muted ? "\uf026" : (shRoot.sinkIconStr || "\uf028"));
            }
        }
        if (lines.length > 1) {
          const mm = lines[1].match(/Volume:\s+([\d.]+)(.*)/);
          const sv = mm ? Math.round(parseFloat(mm[1]) * 100) : NaN;
          const micMuted = mm ? mm[2].indexOf("MUTED") !== -1 : false;
          const svTxt = isNaN(sv) ? "" : sv + "%";
          shRoot.micText = svTxt;
          shRoot.micVisible = svTxt !== "";
          if (!isNaN(sv) && shRoot.micArmed) {
            shRoot.micArmed = false;
            volOsd.osdOpen = false;
            brightOsd.osdOpen = false;
            micOsd.osdOpen = false;
            micOsd.show(sv, micMuted, "\uf130");
          }
        }
      }
    }
  }
  property bool brightArmed: false
  Process {
    id: brightProc
    command: ["sh", "-c", "d=$(echo /sys/class/backlight/*/ | cut -d' ' -f1); echo $((100 * $(cat ${d}brightness) / $(cat ${d}max_brightness)))"]
    stdout: SplitParser {
      onRead: data => {
        const p = parseInt(data.trim(), 10);
        shRoot.brightText = data.trim() + "%";
        shRoot.brightIconStr = isNaN(p) ? "" : shRoot.levelIcon(p, shRoot.blIcons);
        if (!isNaN(p) && shRoot.brightArmed) {
          shRoot.brightArmed = false;
          volOsd.osdOpen = false;
          micOsd.osdOpen = false;
          brightOsd.show(p, false, shRoot.brightIconStr || "\ue38d");
        }
      }
    }
  }
  Process {
    id: swayncProc
    command: ["sh", "-c", "which swaync-client >/dev/null && exec swaync-client -swb"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        try {
          const j = JSON.parse(data);
          const n = parseInt(j.text, 10);
          shRoot.notifText = isNaN(n) ? "" : String(n);
        } catch (e) {}
      }
    }
  }

  // ---- listeners event-driven ----
  Process {
    id: pactlSub
    command: ["pactl", "subscribe"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        if (data.includes("sink") || data.includes("source") || data.includes("server"))
          audioProc.running = true;
      }
    }
  }
  Process {
    id: nmMon
    command: ["nmcli", "monitor"]
    running: true
    stdout: SplitParser {
      onRead: () => {
        wifiProc.running = true;
      }
    }
  }
  // Event-driven primeiro: pactl subscribe (audio) e nmcli monitor (wifi)
  // cobrem mudancas na hora. O timer e so fallback de 30s caso um monitor
  // morra — sem respawnar os monitores nem o audio a cada tick.
  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      wifiProc.running = true;
      wifiRadioProc.running = true;
      brightProc.running = true;
    }
  }
  Timer {
    interval: 1800000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      // sem "= false" antes: se um check ainda roda, pula em vez de matar
      // (matar no meio gerava badge parcial).
      updatesProc.running = true;
      calProc.running = true;
    }
  }

  // ---- per-screen: barra + moldura + tooltip + menus + exclusoes ----
  Variants {
    model: Quickshell.screens
    delegate: Component {
      Scope {
        id: scrScope
        required property var modelData

        PanelWindow {
          id: barWin
          screen: modelData
          anchors.top: true
          anchors.left: true
          anchors.right: true
          implicitHeight: barH + scoop
          color: "transparent"

          // Barra colada no topo + scoops invertidos (ShapePath) nas pontas,
          // fluindo para as laterais da tela. Tudo dentro da propria janela.
          // Medidas derivadas do gaps_out do Hyprland (modules/look.lua).
          // Troque gap junto com o gaps_out para manter a proporcao.
          property int gap: 16
          property int barH: gap * 3
          property int scoop: gap
          property color barBg: "#ff1e1e2e"
          property color barBorder: "#ff1e1e2e"
          property int barBW: 2
          property int edgeT: gap / 2

          // fundo da barra: faixa total, topo reto colado na tela.
          // Sem tiras de borda sobrepostas: com fundo translucido elas dobram
          // o alfa e viram linha visivel.
          // Sombra (estilo caelestia ContentWindow): so nos fundos, nao no conteudo.
          Item {
            anchors.fill: parent

            Rectangle {
              id: barContent
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: barWin.barH
              color: barWin.barBg
            }

            // decoradores: curva concava da ponta da barra ate a lateral da tela.
            // Encaixe exato, sem stroke e sem sobrepor (o fundo e translucido:
            // qualquer sobreposicao dobra o alfa e vira linha).
            Item {
              anchors.top: barContent.bottom
              anchors.topMargin: 0
              anchors.left: parent.left
              anchors.right: parent.right
              height: barWin.scoop
              RoundCorner {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                implicitSize: barWin.scoop
                tail: barWin.edgeT
                color: barWin.barBg
                borderWidth: 0
                corner: RoundCorner.CornerEnum.TopLeft
              }
              RoundCorner {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                implicitSize: barWin.scoop
                tail: barWin.edgeT
                color: barWin.barBg
                borderWidth: 0
                corner: RoundCorner.CornerEnum.TopRight
              }
            }
          }

          // Tres blocos ancorados: esquerda/direita colados nas bordas,
          // centro no meio exato da tela (spacers dividiam o espaco livre
          // e o lado mais largo — SSID longo — deslocava o centro).
          Item {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: barWin.barH
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 2
            anchors.bottomMargin: 2

            // ---- esquerda: updates + tray ----
            Rectangle {
              radius: 99
              color: "transparent"
              height: 36
              width: leftRow.implicitWidth + 24
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              // pill secundaria: Number barato (spring fica so no workspace ativo)
              Behavior on width {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }
              RowLayout {
                id: leftRow
                anchors.centerIn: parent
                spacing: 8
                Rectangle {
                  radius: 99
                  color: "#cba6f7"
                  Layout.preferredWidth: updatesRow.implicitWidth + 28
                  Behavior on Layout.preferredWidth {
                    NumberAnimation {
                      duration: 150
                      easing.type: Easing.OutCubic
                    }
                  }
                  Layout.preferredHeight: 28
                  RowLayout {
                    id: updatesRow
                    anchors.centerIn: parent
                    spacing: 5
                    // onda deterministica: um relogio so (dotTick), fase por aritmetica.
                    // Cada ponto ativo 360ms exclusivo, periodo 1080ms. Sem Animation =
                    // sem risco de fases iguais.
                    Repeater {
                      model: [0, 3, 6]
                      Item {
                        required property int modelData
                        visible: !shRoot.updatesKnown
                        Layout.preferredWidth: 6
                        Layout.preferredHeight: 16
                        Text {
                          property int ph: (shRoot.dotTick + parent.modelData) % 9
                          anchors.horizontalCenter: parent.horizontalCenter
                          y: 5 - 5 * (ph < 3 ? Math.sin(Math.PI * ph / 3) : 0)
                          // interpola entre ticks (120ms): movimento fluido, sem salto
                          Behavior on y {
                            NumberAnimation {
                              duration: 120
                            }
                          }
                          color: "#1e1e2e"
                          font.family: shRoot.uiFont
                          font.pointSize: 11
                          font.weight: Font.DemiBold
                          text: "\u2022"
                        }
                      }
                    }
                    Text {
                      visible: shRoot.updatesKnown
                      color: "#1e1e2e"
                      font.family: shRoot.uiFont
                      font.pointSize: 11
                      font.weight: Font.DemiBold
                      text: shRoot.updNumStr
                    }
                    Text {
                      color: "#1e1e2e"
                      font.family: shRoot.nerdFont
                      font.pointSize: 12
                      font.weight: Font.DemiBold
                      text: shRoot.updIconStr
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: hoverTip.show(shRoot.updatesTip, mapToGlobal(width / 2, height / 2), false)
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                    onClicked: {
                      Quickshell.execDetached(["kitty", "-e", "paru"]);
                    }
                  }
                }
                Repeater {
                  // passivos escondidos (paridade noctalia); NeedsAttention sempre visivel
                  model: ScriptModel {
                    values: [...SystemTray.items.values].filter(i => i.status !== Status.Passive)
                  }
                  MouseArea {
                    required property SystemTrayItem modelData
                    implicitWidth: 22
                    implicitHeight: 22
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    hoverEnabled: true
                    onEntered: {
                      const t = modelData.tooltipTitle || modelData.title || modelData.id || "";
                      if (t !== "")
                        hoverTip.show(t, mapToGlobal(width / 2, height / 2), false);
                    }
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                    onClicked: mouse => {
                      hoverTip.hide();
                      if (mouse.button === Qt.RightButton) {
                        if (modelData.hasMenu) {
                          netMenu.close();
                          powerMenu.close();
                          trayMenu.show(modelData, mapToGlobal(width / 2, height / 2));
                        } else {
                          modelData.secondaryActivate();
                        }
                      } else {
                        if (modelData.onlyMenu && modelData.hasMenu) {
                          netMenu.close();
                          powerMenu.close();
                          trayMenu.show(modelData, mapToGlobal(width / 2, height / 2));
                        } else {
                          modelData.activate();
                        }
                      }
                    }
                    IconImage {
                      anchors.fill: parent
                      asynchronous: true
                      // SNI ja entrega image:// pronto (pixmap/tema/path); iconPath()
                      // embrulha 2x e quebra. Launcher (DesktopEntries) continua com iconPath.
                      source: modelData.icon
                    }
                  }
                }
              }
            }

            // ---- centro: clock + workspaces + audio + backlight ----
            // Ancorado no meio exato da tela (antes: spacers dividiam o
            // espaco livre e o lado mais largo deslocava o centro).
            Rectangle {
              radius: 99
              color: "transparent"
              height: 36
              width: centerRow.implicitWidth + 24
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              RowLayout {
                id: centerRow
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                Text {
                  color: "#cba6f7"
                  font.family: shRoot.uiFont
                  font.pointSize: 11
                  font.bold: true
                  text: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"][clockSource.date.getDay()] + Qt.formatDateTime(clockSource.date, " dd/MM hh:mm")
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                      calProc.running = false;
                      calProc.running = true;
                      hoverTip.show(shRoot.calText === "" ? (["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"][clockSource.date.getDay()] + Qt.formatDateTime(clockSource.date, " dd/MM/yyyy")) : shRoot.calText, mapToGlobal(width / 2, height / 2), true);
                    }
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                  }
                }
                SystemClock {
                  id: clockSource
                  precision: SystemClock.Minutes
                }
                Rectangle {
                  radius: 99
                  color: "#45475a"
                  Layout.preferredHeight: 30
                  Layout.preferredWidth: wsRow.implicitWidth + 12
                  Behavior on Layout.preferredWidth {
                    SpringAnimation {
                      spring: 9
                      damping: 3.5
                      epsilon: 0.5
                    }
                  }
                  RowLayout {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 4
                    Repeater {
                      model: shRoot.sortedWorkspaces
                      Rectangle {
                        required property var modelData
                        property bool isSpecial: String(modelData.name).startsWith("special:")
                        property bool occupied: (modelData.windows ?? 1) > 0
                        // sincronizado entre monitores: destaca o focado global
                        property bool isActive: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.name === String(modelData.name)
                        Layout.preferredWidth: isActive ? 48 : 26
                        Layout.preferredHeight: 26
                        radius: 99
                        color: isActive ? "#cba6f7" : (occupied && !isSpecial ? "#6c7086" : "#1e1e2e")
                        Behavior on Layout.preferredWidth {
                          SpringAnimation {
                            spring: 6
                            damping: 2.2
                            epsilon: 0.5
                          }
                        }
                        Behavior on color {
                          ColorAnimation {
                            duration: 150
                          }
                        }
                        Text {
                          anchors.centerIn: parent
                          text: parent.isSpecial ? "\uef3e" : modelData.name
                          color: parent.isActive ? "#1e1e2e" : "#cdd6f4"
                          font.family: parent.isSpecial ? shRoot.nerdFont : shRoot.uiFont
                          font.pointSize: 11
                          font.weight: parent.isActive ? Font.DemiBold : Font.Medium
                        }
                        MouseArea {
                          anchors.fill: parent
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (parent.isSpecial)
                              Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + String(modelData.name).slice(8) + "\")");
                            else
                              Hyprland.dispatch("hl.dsp.focus({workspace=" + modelData.name + "})");
                          }
                        }
                      }
                    }
                  }
                }
                // audio: pill unica sink + mic (formato do waybar)
                Rectangle {
                  radius: 99
                  color: "#89b4fa"
                  Layout.preferredHeight: 28
                  Layout.preferredWidth: sinkRow.implicitWidth + 28
                  Behavior on Layout.preferredWidth {
                    SpringAnimation {
                      spring: 9
                      damping: 3.5
                      epsilon: 0.5
                    }
                  }
                  RowLayout {
                    id: sinkRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                      color: "#1e1e2e"
                      font.family: shRoot.uiFont
                      font.pointSize: 11
                      font.weight: Font.DemiBold
                      text: shRoot.sinkText
                    }
                    Text {
                      visible: shRoot.sinkIconStr !== ""
                      color: "#1e1e2e"
                      font.family: shRoot.nerdFont
                      font.pointSize: 12
                      font.weight: Font.DemiBold
                      text: shRoot.sinkIconStr
                    }
                    Item {
                      visible: shRoot.micVisible
                      Layout.preferredWidth: 8
                    }
                    Text {
                      visible: shRoot.micVisible
                      color: "#1e1e2e"
                      font.family: shRoot.uiFont
                      font.pointSize: 11
                      font.weight: Font.DemiBold
                      text: shRoot.micText
                    }
                    Text {
                      visible: shRoot.micVisible
                      color: "#1e1e2e"
                      font.family: shRoot.nerdFont
                      font.pointSize: 12
                      font.weight: Font.DemiBold
                      text: "\uf130"
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: hoverTip.show("Saída " + shRoot.sinkText + (shRoot.micVisible ? " · Entrada " + shRoot.micText : ""), mapToGlobal(width / 2, height / 2), false)
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                  }
                }
                // backlight
                Rectangle {
                  radius: 99
                  color: "#f5e0dc"
                  Layout.preferredHeight: 28
                  Layout.preferredWidth: brightRow.implicitWidth + 28
                  Behavior on Layout.preferredWidth {
                    SpringAnimation {
                      spring: 9
                      damping: 3.5
                      epsilon: 0.5
                    }
                  }
                  RowLayout {
                    id: brightRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                      color: "#1e1e2e"
                      font.family: shRoot.uiFont
                      font.pointSize: 11
                      font.weight: Font.DemiBold
                      text: shRoot.brightText
                    }
                    Text {
                      visible: shRoot.brightIconStr !== ""
                      color: "#1e1e2e"
                      font.family: shRoot.nerdFont
                      font.pointSize: 12
                      text: shRoot.brightIconStr
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: hoverTip.show("Brilho " + shRoot.brightText, mapToGlobal(width / 2, height / 2), false)
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                  }
                }
              }
            }

            // ---- direita: rede + bateria + notif + lock + power ----
            Rectangle {
              radius: 99
              color: "transparent"
              height: 36
              width: rightRow.implicitWidth + 24
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              Behavior on width {
                NumberAnimation {
                  duration: 150
                  easing.type: Easing.OutCubic
                }
              }
              RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 10
                RowLayout {
                  spacing: 5
                  Text {
                    color: shRoot.wifiOn ? "#cdd6f4" : "#6c7086"
                    font.family: shRoot.uiFont
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                    text: shRoot.wifiNameStr
                    MouseArea {
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: hoverTip.show(shRoot.wifiSig === "" ? shRoot.wifiNameStr : shRoot.wifiNameStr + " · " + shRoot.wifiSig, mapToGlobal(width / 2, height / 2), false)
                      onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                      onExited: hoverTip.hide()
                      onClicked: {
                        hoverTip.hide();
                        trayMenu.close();
                        powerMenu.close();
                        netMenu.toggle();
                      }
                    }
                  }
                  Text {
                    visible: shRoot.wifiIconStr !== ""
                    color: shRoot.wifiOn ? "#cdd6f4" : "#6c7086"
                    font.family: shRoot.nerdFont
                    font.pointSize: 12
                    text: shRoot.wifiIconStr
                  }
                }
                Rectangle {
                  radius: 99
                  color: {
                    const p = UPower.displayDevice.percentage;
                    const c = p > 1 ? p : p * 100;
                    if (c <= 20)
                      return "#f38ba8";
                    if (c <= 40)
                      return "#fab387";
                    return "#a6e3a1";
                  }
                  Behavior on color {
                    ColorAnimation {
                      duration: 150
                    }
                  }
                  Layout.preferredHeight: 28
                  Layout.preferredWidth: battRow.implicitWidth + 28
                  Behavior on Layout.preferredWidth {
                    SpringAnimation {
                      spring: 9
                      damping: 3.5
                      epsilon: 0.5
                    }
                  }
                  RowLayout {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                      color: "#1e1e2e"
                      font.family: shRoot.uiFont
                      font.pointSize: 11
                      font.weight: Font.DemiBold
                      text: {
                        const p = UPower.displayDevice.percentage;
                        return Math.round(p > 1 ? p : p * 100);
                      }
                    }
                    Text {
                      visible: text !== ""
                      color: "#1e1e2e"
                      font.family: shRoot.nerdFont
                      font.pointSize: 12
                      font.weight: Font.DemiBold
                      text: {
                        const st = UPower.displayDevice.state;
                        return (st === 1 || st === 4) ? String.fromCodePoint(0xF140B) : "";
                      }
                    }
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                      const p = UPower.displayDevice.percentage;
                      const c = Math.round(p > 1 ? p : p * 100);
                      const st = UPower.displayDevice.state;
                      const s = st === 1 ? "carregando" : st === 2 ? "descarregando" : st === 4 ? "cheia" : "";
                      hoverTip.show(s === "" ? c + "%" : c + "% · " + s, mapToGlobal(width / 2, height / 2), false);
                    }
                    onPositionChanged: event => hoverTip.move(mapToGlobal(event.x, event.y))
                    onExited: hoverTip.hide()
                  }
                }
                RowLayout {
                  spacing: 4
                  Text {
                    color: "#cba6f7"
                    font.family: shRoot.uiFont
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                    text: shRoot.notifText
                  }
                  Text {
                    color: "#cba6f7"
                    font.family: shRoot.nerdFont
                    font.pointSize: 12
                    text: ""
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["sh", "-c", "swaync-client -t -sw"])
                  }
                }
                RowLayout {
                  spacing: 14
                  Text {
                    color: "#b4befe"
                    font.family: shRoot.nerdFont
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                    text: ""
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: Quickshell.execDetached(["hyprlock"])
                    }
                  }
                  Text {
                    color: "#f38ba8"
                    font.family: shRoot.nerdFont
                    font.pointSize: 11
                    font.weight: Font.DemiBold
                    text: "⏻"
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        netMenu.close();
                        trayMenu.close();
                        powerMenu.toggle();
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Moldura de janela unica: filetes + dobras inferiores num so Canvas.
        // (As 5 janelinhas separadas viraram uma superficie: sem emenda.)
        EdgeFrame {
          screen: modelData
          bg: barWin.barBg
          edge: barWin.edgeT
          topH: barWin.barH + barWin.scoop
          bendR: barWin.scoop - barWin.edgeT
        }

        // Tooltip proprio: caixa opaca que abre abaixo da barra, centralizada
        // no controle. O ToolTip do QtQuick.Controls e translucido (vaza o
        // papel de parede) e estreito (quebra o cal, corta pacotes).
        // Per-screen: converte global (mapToGlobal) p/ local subtraindo a
        // origem da tela (HDMI fica em x=-1920).
        PanelWindow {
          id: hoverTip
          screen: modelData
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
            const sx = (scrScope.modelData && scrScope.modelData.x !== undefined) ? scrScope.modelData.x : 0;
            const sy = (scrScope.modelData && scrScope.modelData.y !== undefined) ? scrScope.modelData.y : 0;
            return Qt.point(p.x - sx, p.y - sy + 18);
          }
          function show(t, p, mono) {
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
          function hide() {
            tipOpen = false;
          }

          Rectangle {
            color: "#1e1e2e"
            border.color: "#cba6f7"
            border.width: 1
            radius: 8
            width: tipLabel.implicitWidth + 20
            height: tipLabel.implicitHeight + 16
            x: Math.max(8, Math.min(hoverTip.width - width - 8, hoverTip.tipX - width / 2))
            y: Math.max(8, Math.min(hoverTip.height - height - 8, hoverTip.tipY))
            Text {
              id: tipLabel
              anchors.centerIn: parent
              color: "#cdd6f4"
              font.family: hoverTip.tipMono ? "monospace" : shRoot.uiFont
              font.pointSize: 11
              font.weight: Font.DemiBold
              text: hoverTip.tipText
            }
          }
        }

        NetMenu {
          id: netMenu
          screen: modelData
          netName: shRoot.wifiNameStr
          netSig: shRoot.wifiSig
          topY: barWin.barH
        }

        TrayMenu {
          id: trayMenu
          screen: modelData
          topY: barWin.barH
        }

        PowerMenu {
          id: powerMenu
          screen: modelData
          topY: barWin.barH
        }

        // Zonas de exclusao invisiveis (modelo caelestia Exclusions.qml): janelas
        // 1x1 com mascara vazia que so reservam espaco para o tiling. O visual
        // continua Ignore (posicao exata); a reserva vive aqui, entao baixar o
        // gaps_out abaixo de edgeT nao deixa a janela invadir o filete. O topo
        // dispensa fantasma: a propria barra ja reserva barH + scoop.
        PanelWindow {
          screen: modelData
          anchors.left: true
          implicitWidth: 1
          implicitHeight: 1
          exclusiveZone: barWin.edgeT
          mask: Region {}
          color: "transparent"
        }
        PanelWindow {
          screen: modelData
          anchors.right: true
          implicitWidth: 1
          implicitHeight: 1
          exclusiveZone: barWin.edgeT
          mask: Region {}
          color: "transparent"
        }
        PanelWindow {
          screen: modelData
          anchors.bottom: true
          implicitWidth: 1
          implicitHeight: 1
          exclusiveZone: barWin.edgeT
          mask: Region {}
          color: "transparent"
        }
      }
    }
  }

  // ---- single-instance (segue o foco): launcher + OSDs ----
  Launcher {
    id: launcherWin
    screen: shRoot.focusedScreen
  }

  Osd {
    id: volOsd
    screen: shRoot.focusedScreen
    topY: shRoot.barH
  }
  Osd {
    id: brightOsd
    screen: shRoot.focusedScreen
    topY: shRoot.barH
  }
  Osd {
    id: micOsd
    screen: shRoot.focusedScreen
    topY: shRoot.barH
  }

  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcherWin.toggle();
    }
  }

  IpcHandler {
    target: "osd"
    function showBright(): void {
      brightArmed = true;
      brightProc.running = false;
      brightProc.running = true;
    }
    function showMic(): void {
      micArmed = true;
      audioProc.running = false;
      audioProc.running = true;
    }
  }
}
