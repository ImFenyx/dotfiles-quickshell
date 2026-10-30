import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Cheatsheet (SUPER+F1): todos os atalhos do Hyprland, agrupados pelo prefixo da
// descricao (services/Binds, lido sem processo ao abrir). Grupos em colunas, cada
// um na coluna mais curta. Digitar filtra; setas rolam; Esc fecha.
PopupBase {
  id: root
  layerName: "cheatsheet"

  panelWidth: Math.min(width - 2 * (Theme.edge + Theme.frameR), 1180)
  padTop: Theme.space.lg
  padBottom: Theme.space.lg
  padX: Theme.space.lg
  spacing: Theme.space.md
  backdropFocus: false     // o foco e do campo de busca

  readonly property int ncols: 3

  readonly property var filtered: {
    const q = search.text.trim().toLowerCase();
    if (q === "")
      return Binds.groups;
    return Binds.groups.map(g => ({
          name: g.name,
          rows: g.rows.filter(r => (g.name + " " + r.text + " " + r.keys.join(" ")).toLowerCase().includes(q))
        })).filter(g => g.rows.length > 0);
  }
  // masonry: cada grupo vai para a coluna mais curta (titulo conta como 2 linhas)
  readonly property var columns: {
    const cols = [];
    for (let i = 0; i < ncols; i++)
      cols.push({ h: 0, groups: [] });
    for (const g of filtered) {
      const c = cols.reduce((a, b) => b.h < a.h ? b : a);
      c.groups.push(g);
      c.h += g.rows.length + 2;
    }
    return cols.map(c => c.groups);
  }

  function toggle() {
    if (open) {
      close();
      return;
    }
    search.text = "";
    flick.contentY = 0;
    open = true;
  }

  // cabecalho: titulo + busca
  RowLayout {
    Layout.fillWidth: true
    spacing: Theme.space.sm
    Glyph {
      font.pixelSize: Theme.icon.m
      text: Icons.keyboard
    }
    UiText {
      font.pixelSize: Theme.type.body_l
      font.weight: Font.Bold
      text: "Atalhos"
    }
    Item {
      Layout.fillWidth: true
    }
    Rectangle {
      Layout.preferredWidth: 240
      Layout.preferredHeight: 32
      radius: height / 2
      color: Theme.surfaceContainer
      border.width: 1
      border.color: search.activeFocus ? Theme.primary : Theme.surfaceContainerHighest
      Glyph {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: Theme.icon.s
        text: Icons.search
      }
      TextInput {
        id: search
        anchors.fill: parent
        anchors.leftMargin: 34
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.fgSurface
        font.family: Theme.uiFont
        font.pixelSize: Theme.type.body_m
        focus: root.open
        onTextChanged: flick.contentY = 0
        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
          const step = 60;
          if (event.key === Qt.Key_Down)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + step);
          else if (event.key === Qt.Key_Up)
            flick.contentY = Math.max(0, flick.contentY - step);
          else
            return;
          event.accepted = true;
        }
        UiText {
          anchors.fill: parent
          visible: search.text === ""
          verticalAlignment: Text.AlignVCenter
          color: Theme.outline
          font.pixelSize: Theme.type.body_m
          text: "Buscar"
        }
      }
    }
  }

  Flickable {
    id: flick
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, root.height - Theme.barH - Theme.edge - 120)
    contentHeight: cols.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Row {
      id: cols
      width: flick.width
      spacing: Theme.space.xl

      Repeater {
        model: root.columns

        Column {
          id: col
          required property var modelData
          width: (cols.width - cols.spacing * (root.ncols - 1)) / root.ncols
          spacing: Theme.space.lg

          Repeater {
            model: col.modelData

            Column {
              id: group
              required property var modelData
              width: col.width
              spacing: Theme.space.xs

              UiText {
                color: Theme.primary
                font.pixelSize: Theme.type.title_s
                font.weight: Font.Bold
                text: group.modelData.name
              }

              Repeater {
                model: group.modelData.rows

                RowLayout {
                  id: line
                  required property var modelData
                  width: group.width
                  spacing: Theme.space.xs

                  Repeater {
                    model: line.modelData.keys
                    Rectangle {
                      id: keycap
                      required property string modelData
                      implicitWidth: capText.implicitWidth + 2 * Theme.space.sm
                      implicitHeight: 22
                      radius: Theme.shape.xs
                      color: Theme.surfaceContainerHighest
                      UiText {
                        id: capText
                        anchors.centerIn: parent
                        font.pixelSize: Theme.type.label_m
                        font.weight: Font.Bold
                        text: keycap.modelData
                      }
                    }
                  }
                  UiText {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.space.xs
                    color: Theme.fgSurfaceVariant
                    font.pixelSize: Theme.type.body_m
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    text: line.modelData.text
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
