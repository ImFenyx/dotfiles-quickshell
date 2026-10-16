import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components

// Launcher (substitui rofi drun): dockado baixo-centro, fundido na borda,
// abre p/ cima. Busca multi-termo + frecency + teclado/mouse.
PopupBase {
  id: root

  fromBottom: true
  tuck: 1                 // mesma cor da borda = sem hairline
  panelWidth: 600
  padTop: 12
  padBottom: 8
  padX: 18
  // k=18: moldura EdgeFrame (8px, mesma cor) esconde a base do scoop;
  // sobram ~10px visiveis = paridade com os menus.
  bendK: 18
  asyncShape: false
  backdropFocus: false    // o foco e do TextInput

  property int selectedIndex: 0
  property var freq: ({})

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

  function entryText(e) {
    return [e.name, e.genericName, e.comment, e.execString, (e.categories || []).join(" "), (e.keywords || []).join(" ")].join(" ");
  }
  // sem dicionario: "musica" casa "música", "navegador" ja vem localizado
  function norm(s) {
    return s.toLowerCase().replace(/[áàâã]/g, "a").replace(/[éèê]/g, "e").replace(/[íï]/g, "i").replace(/[óôõö]/g, "o").replace(/[úü]/g, "u").replace(/ç/g, "c").replace(/ñ/g, "n");
  }
  // haystacks precomputados 1x: por keystroke roda includes() puro (fzf v2
  // media 150-800ms p/ 500 entradas, medido em log; substring ~ms)
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
      hay.push({
        e: a,
        h: norm(entryText(a))
      });
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
    const out = [];
    for (const it of appHay) {
      if (alts.every(v => v.some(x => it.h.includes(x))))
        out.push(it.e);
    }
    // frecency, depois ordem alfabetica
    out.sort((a, b) => ((freq[b.id] || 0) - (freq[a.id] || 0)) || ((sortName[a.id] < sortName[b.id]) ? -1 : 1));
    return out;
  }
  property var results: filtered()

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      // preguicoso: so reindexa com menu aberto; senao marca p/ proxima abertura
      if (root.open)
        root.rebuildIndex();
      else
        root.hzBuilt = false;
    }
  }

  function launch(entry) {
    if (!entry)
      return;
    freq[entry.id] = (freq[entry.id] || 0) + 1;
    Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/frecency.sh"), "hit", entry.id]);
    close();
    if (entry.runInTerminal)
      Quickshell.execDetached(Config.terminal.concat(entry.command));
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
    command: ["sh", Quickshell.shellPath("scripts/frecency.sh")]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        for (const l of text.trim().split("\n")) {
          const p = l.split(" ");
          if (p.length >= 2 && p[0] !== "")
            m[p[0]] = parseInt(p[1], 10) || 0;
        }
        root.freq = m;
      }
    }
  }

  // lista + scrollbar fina por cima (sem QtQuick.Controls)
  Item {
    visible: root.results.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: 318

    ListView {
      id: resultsList
      anchors.fill: parent
      clip: true
      model: root.results
      spacing: 2
      delegate: Item {
        id: app
        required property var modelData
        required property int index
        property bool selected: root.selectedIndex === index

        width: ListView.view.width
        implicitHeight: 38

        Rectangle {
          anchors.fill: parent
          radius: 8
          color: app.selected ? Theme.surface1 : (rowArea.containsMouse ? Theme.surface0 : "transparent")
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
            source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            UiText {
              Layout.fillWidth: true
              elide: Text.ElideRight
              text: app.modelData.name
            }
            UiText {
              visible: text !== ""
              Layout.fillWidth: true
              color: Theme.overlay0
              font.pointSize: 9
              font.weight: Font.Normal
              elide: Text.ElideRight
              text: app.modelData.genericName || app.modelData.comment || ""
            }
          }
        }
        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = app.index
          onClicked: root.launch(app.modelData)
        }
      }
    }

    Item {
      visible: resultsList.count > 8
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.rightMargin: -6
      width: 4
      height: parent.height
      Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.surface0
      }
      Rectangle {
        width: parent.width
        y: resultsList.visibleArea.yPosition * parent.height
        height: Math.max(24, resultsList.visibleArea.heightRatio * parent.height)
        radius: 2
        color: Theme.surface1
      }
    }
  }

  Item {
    visible: root.results.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 318
    UiText {
      anchors.centerIn: parent
      color: Theme.overlay0
      font.weight: Font.Normal
      text: root.appsSeen ? "Nada encontrado" : "Procurando…"
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 42
    radius: 10
    color: Theme.surface1
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 10
      Glyph {
        font.pointSize: 13
        text: Icons.search
      }
      TextInput {
        id: searchInput
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        color: Theme.text
        font.family: Theme.uiFont
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
