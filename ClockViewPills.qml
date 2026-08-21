import QtQuick
import qs.Commons
import qs.Ui

// MONTH / WEEK / UPCOMING / TASKS pill switcher. Pure viewMode in, modeChosen
// out; the container persists the choice.
Item {
  id: pills

  required property string viewMode
  required property color foreground
  required property string fontFamily

  signal modeChosen(string mode)

  width: parent.width
  height: switcherRow.height + Style.space(4)

  Rectangle {
    anchors.centerIn: parent
    width: switcherRow.width + Style.space(14)
    height: switcherRow.height + Style.space(4)
    radius: Style.cornerRadius + 2
    color: Qt.rgba(pills.foreground.r, pills.foreground.g, pills.foreground.b, 0.04)
    border.width: Style.spacing.hairline
    border.color: Qt.rgba(pills.foreground.r, pills.foreground.g, pills.foreground.b, 0.10)
  }

  Row {
    id: switcherRow
    anchors.centerIn: parent
    spacing: Style.space(2)
    Repeater {
      model: [
        { mode: "month", label: "MONTH" },
        { mode: "week", label: "WEEK" },
        { mode: "upcoming", label: "UPCOMING" },
        { mode: "tasks", label: "TASKS" }
      ]
      Rectangle {
        id: viewTab
        required property var modelData
        readonly property bool active: pills.viewMode === modelData.mode
        readonly property bool hot: tabMouse.containsMouse
        width: tabLabel.implicitWidth + Style.space(20)
        height: tabLabel.implicitHeight + Style.space(10)
        radius: Style.cornerRadius
        color: active ? Style.selectedFillFor(pills.foreground, Color.accent) : hot ? Style.hoverFillFor(pills.foreground, Color.accent) : "transparent"
        border.width: active ? Style.spacing.hairline : 0
        border.color: Style.selectedBorderFor(pills.foreground, Color.accent)
        Behavior on color { ColorAnimation { duration: 100 } }
        Text {
          id: tabLabel
          anchors.centerIn: parent
          text: viewTab.modelData.label
          color: viewTab.active ? Style.selectedStateColor(pills.foreground, Color.accent) : Qt.darker(pills.foreground, 1.5)
          font.family: pills.fontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
          font.bold: viewTab.active
        }
        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pills.modeChosen(viewTab.modelData.mode) }
      }
    }
  }
}
