import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "3v4ng3li0n00.mousegrid"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰍽"
    slotSize: Style.bar.iconSlot
    tooltipText: "Mousegrid"
    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle 3v4ng3li0n00.mousegrid '{}'")
    }
  }
}
