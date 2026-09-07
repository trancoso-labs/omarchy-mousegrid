import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string focusRow: "coarse"
  property int coarseIndex: 2
  property int fineIndex: 1
  property int cols: 6
  property int rows: 4
  property int fine: 12

  readonly property string pluginId: (manifest && manifest.id) || "3v4ng3li0n00.mousegrid"
  readonly property string ctlPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/3v4ng3li0n00.mousegrid/scripts/install.py"
  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/mousegrid.json"

  property color foreground: Color.imagePicker ? Color.imagePicker.text : Color.menu.text
  property color scrim: Color.imagePicker ? Color.imagePicker.scrim : Color.menu.scrim
  property color selectedBorder: Color.imagePicker ? Color.imagePicker.selectedBorder : Color.accent
  property color unselectedBorder: Color.imagePicker ? Color.imagePicker.unselectedBorder : Color.menu.border

  readonly property var coarsePresets: [
    { cols: 3, rows: 2 },
    { cols: 4, rows: 3 },
    { cols: 6, rows: 4 },
    { cols: 8, rows: 5 },
    { cols: 10, rows: 6 },
    { cols: 12, rows: 8 }
  ]
  readonly property var finePresets: [8, 12, 16, 24, 36]

  function open(payload) {
    root.opened = true
    root.applyFromConfig()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function indexOfCoarse(c, r) {
    for (var i = 0; i < coarsePresets.length; i++)
      if (coarsePresets[i].cols === c && coarsePresets[i].rows === r) return i
    return 2
  }

  function indexOfFine(px) {
    for (var i = 0; i < finePresets.length; i++)
      if (finePresets[i] === px) return i
    return 1
  }

  function applyFromConfig() {
    root.coarseIndex = indexOfCoarse(root.cols, root.rows)
    root.fineIndex = indexOfFine(root.fine)
  }

  function applyStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || "").trim())
      if (!parsed) return
      if (parsed.cols) root.cols = parsed.cols
      if (parsed.rows) root.rows = parsed.rows
      if (parsed.fine) root.fine = parsed.fine
      root.applyFromConfig()
    } catch (e) {}
  }

  function save() {
    var preset = coarsePresets[coarseIndex]
    root.cols = preset.cols
    root.rows = preset.rows
    root.fine = finePresets[fineIndex]
    if (saveProc.running) return
    saveProc.command = ["python3", root.ctlPath, "set", String(root.cols), String(root.rows), String(root.fine)]
    saveProc.running = true
  }

  function move(delta) {
    if (focusRow === "coarse") {
      var next = coarseIndex + delta
      if (next < 0) next = 0
      if (next >= coarsePresets.length) next = coarsePresets.length - 1
      if (next !== coarseIndex) {
        coarseIndex = next
        save()
      }
    } else {
      var n = fineIndex + delta
      if (n < 0) n = 0
      if (n >= finePresets.length) n = finePresets.length - 1
      if (n !== fineIndex) {
        fineIndex = n
        save()
      }
    }
  }

  FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyStatus(text())
    onFileChanged: reload()
  }

  Process {
    id: saveProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-mousegrid"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
          root.save()
          root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.move(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.move(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) {
          root.focusRow = "coarse"
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
          root.focusRow = "fine"
          event.accepted = true
        }
      }

      Column {
        anchors.centerIn: parent
        spacing: Style.space(28)
        width: Math.min(parent.width - 80, 920)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "MOUSEGRID"
          color: root.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.letterSpacing: 4
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          text: "ARROWS"
          color: root.focusRow === "coarse" ? root.selectedBorder : Qt.darker(root.foreground, 1.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 2
          textFormat: Text.PlainText
        }

        Row {
          spacing: Style.space(16)
          Repeater {
            model: root.coarsePresets
            GridCard {
              required property var modelData
              required property int index
              cols: modelData.cols
              rows: modelData.rows
              selected: index === root.coarseIndex
              focused: root.focusRow === "coarse" && selected
              label: modelData.cols + "×" + modelData.rows
              cardWidth: 132
              cardHeight: 84
              onPicked: {
                root.focusRow = "coarse"
                root.coarseIndex = index
                root.save()
              }
            }
          }
        }

        Text {
          width: parent.width
          text: "SUPER + ARROWS"
          color: root.focusRow === "fine" ? root.selectedBorder : Qt.darker(root.foreground, 1.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.letterSpacing: 2
          textFormat: Text.PlainText
        }

        Row {
          spacing: Style.space(16)
          Repeater {
            model: root.finePresets
            GridCard {
              required property var modelData
              required property int index
              cols: Math.max(2, Math.round(48 / modelData))
              rows: Math.max(2, Math.round(48 / modelData))
              selected: index === root.fineIndex
              focused: root.focusRow === "fine" && selected
              label: modelData + " px"
              cardWidth: 100
              cardHeight: 84
              onPicked: {
                root.focusRow = "fine"
                root.fineIndex = index
                root.save()
              }
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "← → choose   ·   ↑ ↓ row   ·   Enter keep   ·   Esc"
          color: Qt.darker(root.foreground, 1.6)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          textFormat: Text.PlainText
        }
      }
    }
  }

  component GridCard: Item {
    id: card
    property int cols: 6
    property int rows: 4
    property bool selected: false
    property bool focused: false
    property string label: ""
    property int cardWidth: 132
    property int cardHeight: 84
    signal picked()

    width: cardWidth
    height: cardHeight + Style.space(22)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.picked()
    }

    Rectangle {
      id: frame
      width: card.cardWidth
      height: card.cardHeight
      color: Qt.rgba(0, 0, 0, 0.35)
      border.width: card.focused ? 3 : (card.selected ? 2 : 1)
      border.color: card.selected ? root.selectedBorder : root.unselectedBorder
      radius: 4
      scale: card.selected ? 1.06 : 1.0
      Behavior on scale { NumberAnimation { duration: 120 } }

      Grid {
        anchors.fill: parent
        anchors.margins: 6
        columns: Math.max(1, card.cols)
        columnSpacing: 1
        rowSpacing: 1
        Repeater {
          model: Math.max(1, card.cols * card.rows)
          Rectangle {
            width: Math.max(1, (frame.width - 12 - (card.cols - 1)) / card.cols)
            height: Math.max(1, (frame.height - 12 - (card.rows - 1)) / card.rows)
            color: Qt.rgba(1, 1, 1, card.selected ? 0.18 : 0.08)
          }
        }
      }
    }

    Text {
      anchors.top: frame.bottom
      anchors.topMargin: Style.space(6)
      anchors.horizontalCenter: frame.horizontalCenter
      text: card.label
      color: card.selected ? root.foreground : Qt.darker(root.foreground, 1.4)
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      textFormat: Text.PlainText
    }
  }
}
