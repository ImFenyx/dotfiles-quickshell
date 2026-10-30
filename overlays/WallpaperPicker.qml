import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Seletor de wallpaper (Super+Shift+W): desce da barra com a grade de miniaturas
// de Config.wallpaperDir (imagens e videos, estes com selo ▶). Busca pelo nome,
// setas navegam, Enter/clique aplica e fecha (a transicao do awww aparece logo
// depois), Esc sai. O atual fica marcado e ja vem selecionado.
PopupBase {
  id: root

  panelWidth: 760
  padTop: Theme.space.lg
  padBottom: Theme.space.lg
  padX: Theme.space.lg
  spacing: 10
  backdropFocus: false     // o foco e do campo de busca

  readonly property int cols: 4
  property int sel: 0

  readonly property var results: {
    const q = search.text.trim().toLowerCase();
    return q === "" ? Wallpapers.items : Wallpapers.items.filter(it => it.name.toLowerCase().includes(q));
  }

  function toggle() {
    if (open) {
      close();
      return;
    }
    search.text = "";
    Wallpapers.refresh();
    sel = Math.max(0, results.findIndex(it => it.path === Wallpapers.current));
    open = true;
    // o modelo so enche com a janela visivel: rola ate o atual no proximo ciclo
    Qt.callLater(() => grid.positionViewAtIndex(root.sel, GridView.Contain));
  }
  function apply(it) {
    close();
    Wallpapers.apply(it);
  }
  function move(d) {
    if (results.length === 0)
      return;
    sel = Math.max(0, Math.min(results.length - 1, sel + d));
    grid.positionViewAtIndex(sel, GridView.Contain);
  }

  // cabecalho: titulo + quantidade + busca
  RowLayout {
    Layout.fillWidth: true
    spacing: 10
    Glyph {
      font.pixelSize: Theme.icon.m
      text: Icons.image
    }
    UiText {
      font.pixelSize: Theme.type.body_l
      font.weight: Font.Bold
      text: "Wallpapers"
    }
    UiText {
      color: Theme.fgSurfaceVariant
      font.pixelSize: Theme.type.body_m
      text: Wallpapers.items.length > 0 ? String(Wallpapers.items.length) : ""
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
        onTextChanged: root.sel = 0
        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
          if (event.key === Qt.Key_Left)
            root.move(-1);
          else if (event.key === Qt.Key_Right)
            root.move(1);
          else if (event.key === Qt.Key_Up)
            root.move(-root.cols);
          else if (event.key === Qt.Key_Down)
            root.move(root.cols);
          else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (root.results.length > 0)
              root.apply(root.results[Math.min(root.sel, root.results.length - 1)]);
          } else
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

  // grade (3 linhas visiveis) + scrollbar fina
  Item {
    Layout.fillWidth: true
    Layout.preferredHeight: grid.cellHeight * 3

    GridView {
      id: grid
      anchors.fill: parent
      clip: true
      cellWidth: width / root.cols
      cellHeight: Math.round(cellWidth * 0.6)
      boundsBehavior: Flickable.StopAtBounds
      // fechado (fim da animacao de saida), os delegates saem
      model: ScriptModel {
        values: root.visible ? root.results : []
      }
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool selected: root.sel === index
        readonly property bool isCurrent: modelData.path === Wallpapers.current

        width: GridView.view.cellWidth
        height: GridView.view.cellHeight

        Rectangle {
          anchors.fill: parent
          anchors.margins: 4
          radius: Theme.shape.md
          color: Theme.surfaceContainer
          border.width: 2
          border.color: cell.selected ? Theme.primary : (cellArea.containsMouse ? Theme.surfaceContainerHighest : "transparent")

          ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 3
            radius: Theme.shape.sm
            color: "transparent"
            Image {
              anchors.fill: parent
              source: cell.modelData.thumb
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              sourceSize.width: 320
              sourceSize.height: 180
            }
            // nome: so na selecionada / com o mouse
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: 22
              visible: cell.selected || cellArea.containsMouse
              color: Theme.surface
              opacity: 0.85
              UiText {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.type.label_s
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                text: cell.modelData.name
              }
            }
          }
          // video (gslapper/mpvpaper)
          Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8
            width: 22
            height: 20
            radius: height / 2
            visible: cell.modelData.video
            color: Theme.surface
            opacity: 0.85
            Glyph {
              anchors.centerIn: parent
              font.pixelSize: Theme.icon.xs
              text: Icons.play
            }
          }
          // o que esta aplicado
          Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            width: 20
            height: 20
            radius: height / 2
            visible: cell.isCurrent
            color: Theme.primary
            Glyph {
              anchors.centerIn: parent
              color: Theme.fgPrimary
              font.pixelSize: Theme.icon.xs
              text: Icons.check
            }
          }
        }
        MouseArea {
          id: cellArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.sel = cell.index
          onClicked: root.apply(cell.modelData)
        }
      }
    }

    Item {
      visible: grid.contentHeight > grid.height
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.rightMargin: -8
      width: 4
      height: parent.height
      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceContainer
      }
      Rectangle {
        width: parent.width
        y: grid.visibleArea.yPosition * parent.height
        height: Math.max(24, grid.visibleArea.heightRatio * parent.height)
        radius: height / 2
        color: Theme.surfaceContainerHighest
      }
    }

    UiText {
      anchors.centerIn: parent
      visible: root.results.length === 0
      color: Theme.outline
      textFormat: Text.PlainText
      text: Wallpapers.loading && Wallpapers.items.length === 0 ? "Gerando miniaturas…" : (search.text !== "" ? "Nada encontrado" : "Nenhuma imagem em " + Config.wallpaperDir)
    }
  }

  UiText {
    Layout.fillWidth: true
    color: Theme.outline
    font.pixelSize: Theme.type.label_m
    font.weight: Font.Medium
    text: "← → ↑ ↓  navegar     Enter  aplicar     Esc  sair"
  }
}
