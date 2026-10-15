import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland

// Launcher (substitui rofi drun): dockado baixo-centro, fundido na borda,
// abre p/ cima. Busca multi-termo + frecency + teclado/mouse.
PanelWindow {
  id: root
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: open ? fullMask : emptyMask
  color: "transparent"
  // Desmapeada quando fechada (menos RAM): layerrule noanim p/ namespace
  // quickshell evita o fadeLayersIn do Hyprland, o slide continua 100% QML.
  // offsetScale<1 mantem mapeada durante a animacao de saida.
  visible: open || offsetScale < 0.999

  property bool open: false
  property real offsetScale: open ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }
  property int selectedIndex: 0
  property var freq: ({})
  property int freqRev: 0
  property color menuBg: "#ff1e1e2e"

  function toggle() {
    if (open) {
      close();
      return;
    }
    if (!hzBuilt)
      rebuildIndex();
    searchInput.text = "";
    selectedIndex = 0;
    freqLoadProc.running = false;
    freqLoadProc.running = true;
    open = true;
  }
  // modelo OSD: close direto, spring resolve o colapso (sem estado closing)
  function close() {
    open = false;
  }

  function entryText(e) {
    return [e.name, e.genericName, e.comment, e.execString, (e.categories || []).join(" "), (e.keywords || []).join(" ")].join(" ");
  }
  // sem dicionario: "musica" casa "música", "navegador" ja vem localizado
  function norm(s) {
    return s.toLowerCase().replace(/[áàâã]/g, "a").replace(/[éèê]/g, "e").replace(/[íï]/g, "i").replace(/[óôõö]/g, "o").replace(/[úü]/g, "u").replace(/ç/g, "c").replace(/ñ/g, "n");
  }
  // haystacks precomputados 1x: por keystroke roda includes() puro (fzf v2
  // media 150-800ms p/ 500 entradas — medido em log; substring ~ms)
  property var appHay: []
  property var sortName: ({})
  property bool hzBuilt: false
  property bool appsSeen: false
  function rebuildIndex() {
    const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay && a.execString !== "");
    const sn = {};
    const hay = [];
    for (const a of apps) {
      sn[a.id] = a.name.toLowerCase();
      hay.push({ e: a, h: norm(entryText(a)) });
    }
    sortName = sn;
    appHay = hay;
    hzBuilt = true;
    if (hay.length > 0)
      appsSeen = true;
  }
  function filtered() {
    if (!hzBuilt || appHay.length === 0)
      return [];
    // stemming leve p/ categorias: "gaming"->"gam" casa "Game", "games"->"game".
    // So tenta base >=3 letras (nao esvazia "os"->"o").
    const toks = norm(searchInput.text.trim()).split(/\s+/).filter(x => x !== "");
    const alts = toks.map(x => {
      const v = [x];
      for (const sfx of ["ing", "ed", "es", "s"]) {
        if (x.length > 3 && x.endsWith(sfx) && x.length - sfx.length >= 3)
          v.push(x.slice(0, -sfx.length));
      }
      return v;
    });
    const t00 = Date.now();
    const scored = [];
    for (const it of appHay) {
      let ok = true;
      for (const v of alts) {
        let hit = false;
        for (const x of v) {
          if (it.h.includes(x)) {
            hit = true;
            break;
          }
        }
        if (!hit) {
          ok = false;
          break;
        }
      }
      if (ok)
        scored.push({ e: it.e, s: 0 });
    }
    const dtFind = Date.now() - t00;
    const t0 = Date.now();
    scored.sort((a, b) => (b.s - a.s) || ((freq[b.e.id] || 0) - (freq[a.e.id] || 0)) || ((sortName[a.e.id] < sortName[b.e.id]) ? -1 : 1));
    const dt = Date.now() - t0;
    if (dt + dtFind > 15)
      console.log("launcher find=" + dtFind + "ms sort=" + dt + "ms q=" + q + " matches=" + scored.length);


    return scored.map(r => r.e);
  }
  property var results: filtered()

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      // preguicoso: so reindexa com menu aberto; senao marca p/ proxima abertura
      if (open)
        rebuildIndex();
      else
        hzBuilt = false;
    }
  }

  function launch(entry) {
    if (!entry)
      return;
    freq[entry.id] = (freq[entry.id] || 0) + 1;
    freqRev++;
    Quickshell.execDetached(["sh", "/home/fenyx/.config/quickshell/scripts/frecency.sh", "hit", entry.id]);
    close();
    if (entry.runInTerminal)
      Quickshell.execDetached(["kitty", "-e"].concat(entry.command));
    else
      entry.execute();
  }

  function moveSel(d) {
    if (results.length === 0)
      return;
    selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + d));
    resultsList.positionViewAtIndex(selectedIndex, ListView.Contain);
  }

  Process {
    id: freqLoadProc
    command: ["sh", "/home/fenyx/.config/quickshell/scripts/frecency.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        for (const l of text.trim().split("\n")) {
          const p = l.split(" ");
          if (p.length >= 2 && p[0] !== "")
            m[p[0]] = parseInt(p[1], 10) || 0;
        }
        freq = m;
        freqRev++;
      }
    }
  }

  HyprlandFocusGrab {
    active: root.open
    windows: [QsWindow.window]
    onCleared: root.close()
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.close()
  }

  Region {
    id: emptyMask
  }
  Region {
    id: fullMask
    x: 0
    y: 0
    width: root.width
    height: root.height
  }

  // Caixa fundida na borda inferior (espelho do OSD): mascara fixa + conteudo
  // rigido que desliza p/ cima dentro dela. Tuck 1px (mesma cor = sem hairline).
  Item {
    width: 600
    height: contentCol.implicitHeight + 20
    clip: true
    x: (root.width - width) / 2
    y: root.height - height + 1
    visible: root.offsetScale < 1

    Item {
      width: parent.width
      height: parent.height
      y: height * root.offsetScale

      Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.menuBg
          PathSvg {
            path: {
              // k=18: moldura EdgeFrame (8px, mesma cor) esconde a base do scoop;
              // sobram ~10px visiveis = paridade com os menus.
              const w = bgShape.width, h = bgShape.height, r = 16, f = 8, k = 18;
              const bx = w - f;
              return `M0,${h} L${w},${h} C${w - 2},${h} ${bx},${h - k * 0.25} ${bx},${h - k} L${bx},${r} Q${bx},0 ${bx - r},0 L${f + r},0 Q${f},0 ${f},${r} L${f},${h - k} C${f},${h - k * 0.25} 2,${h} 0,${h} Z`;
            }
          }
        }
      }

      ColumnLayout {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 12
        spacing: 2

      ListView {
        id: resultsList
        visible: root.results.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: 318
        implicitHeight: 318
        clip: true
        model: root.results
        spacing: 2
        delegate: Item {
          required property var modelData
          required property int index
          property bool selected: root.selectedIndex === index
          width: ListView.view.width
          implicitHeight: 38
          Rectangle {
            anchors.fill: parent
            radius: 8
            color: selected ? "#45475a" : (rowArea.containsMouse ? "#313244" : "transparent")
          }
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            IconImage {
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26
              Layout.alignment: Qt.AlignVCenter
              asynchronous: true
              // IconImage nao resolve nome de tema sozinho (vira path relativo);
              // iconPath() gera image:// com fallback (vale p/ pixmaps tbm)
              source: Quickshell.iconPath(modelData.icon, "application-x-executable")
            }
            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 0
              Text {
                Layout.fillWidth: true
                color: "#cdd6f4"
                font.family: "Rubik"
                font.pointSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                text: modelData.name
              }
              Text {
                visible: text !== ""
                Layout.fillWidth: true
                color: "#6c7086"
                font.family: "Rubik"
                font.pointSize: 9
                elide: Text.ElideRight
                text: modelData.genericName || modelData.comment || ""
              }
            }
          }
          MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.selectedIndex = index
            onClicked: root.launch(modelData)
          }
        }
      }

      Item {
        visible: root.results.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: 318
        implicitHeight: 318
        Text {
          anchors.centerIn: parent
          color: "#6c7086"
          font.family: "Rubik"
          font.pointSize: 11
          text: root.appsSeen ? "Nada encontrado" : "Procurando…"
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 10
        color: "#45475a"
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10
          Text {
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font Propo"
            font.pointSize: 13
            text: ""
          }
          TextInput {
            id: searchInput
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            color: "#cdd6f4"
            font.family: "Rubik"
            font.pointSize: 12
            focus: root.open
            Keys.onEscapePressed: root.close()
            Keys.onPressed: event => {
              if (event.key === Qt.Key_Up) {
                root.moveSel(-1);
                event.accepted = true;
              } else if (event.key === Qt.Key_Down) {
                root.moveSel(1);
                event.accepted = true;
              } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                const r = root.results;
                if (r.length > 0)
                  root.launch(r[Math.min(root.selectedIndex, r.length - 1)]);
                event.accepted = true;
              }
            }
            onTextChanged: root.selectedIndex = 0
          }
        }
      }
    }

      // scrollbar fina sobre a lista (sem QtQuick.Controls)
      Item {
        visible: resultsList.count > 8
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        width: 4
        height: 318
        Rectangle {
          anchors.fill: parent
          radius: 2
          color: "#313244"
        }
        Rectangle {
          width: parent.width
          y: resultsList.visibleArea.yPosition * parent.height
          height: Math.max(24, resultsList.visibleArea.heightRatio * parent.height)
          radius: 2
          color: "#45475a"
        }
      }
    }
  }
}
