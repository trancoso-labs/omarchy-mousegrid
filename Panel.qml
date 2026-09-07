import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "3v4ng3li0n00.mousegrid"
  ipcTarget: "3v4ng3li0n00.mousegrid"
  manageIpc: true

  readonly property string ctlPath: Quickshell.env("HOME") + "/.config/omarchy/plugins/3v4ng3li0n00.mousegrid/scripts/install.py"
  property var statusData: ({
    ok: true,
    hypr_lua: false,
    click_bin: false,
    bindings: false,
    uinput: false,
    daemon: false,
    ready: false
  })
  property string flash: ""
  readonly property bool busy: workProc.running
  readonly property bool wired: statusData.ready === true
  readonly property string heroMeta: {
    if (flash) return flash
    if (wired) return "SUPER+A to aim"
    return "Hyprland not wired"
  }
  readonly property var keymap: [
    { key: "SUPER+A", action: "enter / leave" },
    { key: "arrows", action: "jump cell to cell" },
    { key: "SUPER+arrows", action: "fine aim" },
    { key: "Enter", action: "click and leave" },
    { key: "Space", action: "hold left · drag" },
    { key: "Shift+Enter", action: "right-click and leave" },
    { key: "Esc", action: "leave" }
  ]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyStatus(raw) {
    var text = String(raw || "").trim()
    if (!text) return
    try {
      var parsed = JSON.parse(text)
      if (parsed && parsed.ok === false) {
        flash = parsed.error || "error"
        return
      }
      if (parsed) statusData = parsed
      if (parsed && parsed.message) flash = parsed.message
    } catch (e) {
      flash = "status failed"
    }
  }

  function runInstall() {
    if (workProc.running) return
    workProc.command = ["python3", root.ctlPath]
    workProc.running = true
  }

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) refresh()

  Timer {
    interval: 2400
    running: root.flash !== ""
    onTriggered: root.flash = ""
  }

  Process {
    id: statusProc
    command: ["python3", root.ctlPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: workProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
    onExited: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍽"
    slotSize: Style.bar.iconSlot
    tooltipText: "Mousegrid"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        PanelHero {
          width: parent.width
          title: "Mousegrid"
          meta: root.heroMeta.toUpperCase()
          iconComponent: Text {
            text: "󰍽"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
          }
        }

        PanelSeparator { width: parent.width }

        Repeater {
          model: root.keymap
          RowLayout {
            required property var modelData
            width: column.width
            spacing: Style.space(12)
            Text {
              text: modelData.key
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              textFormat: Text.PlainText
              Layout.preferredWidth: Style.space(140)
            }
            Text {
              text: modelData.action
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }
          }
        }

        PanelSeparator { width: parent.width }

        Text {
          width: parent.width
          visible: !root.wired
          text: root.statusData.uinput === false
                ? "/dev/uinput is not writable in this session"
                : "Hyprland loader is missing. Install copies the Lua file and click helper."
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          text: root.wired ? (root.busy ? "wiring…" : "wired · hyprctl reload if binds look stale") : "click to wire Hyprland"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          textFormat: Text.PlainText

          MouseArea {
            anchors.fill: parent
            enabled: !root.wired && !root.busy
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.runInstall()
          }
        }
      }
    }
  }
}
