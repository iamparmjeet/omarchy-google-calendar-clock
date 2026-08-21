import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One task line in the TASKS view: checkbox, [x]/[ ] marker, title, due date,
// delete. The container decides whether a click completes or re-opens.
Rectangle {
  id: row

  required property var task
  required property color foreground
  required property string fontFamily

  readonly property bool done: task.status === "completed"

  signal toggled(var task)
  signal deleted(var task)

  width: parent.width
  height: Style.space(32)
  radius: Style.cornerRadius
  color: row.done ? Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.04) : "transparent"
  border.width: Style.spacing.hairline
  border.color: Qt.rgba(row.foreground.r, row.foreground.g, row.foreground.b, 0.08)

  Row {
    anchors.fill: parent
    anchors.margins: Style.space(6)
    spacing: Style.space(8)

    PanelActionButton {
      anchors.verticalCenter: parent.verticalCenter
      iconText: row.done ? "󰄳" : "󰄰"
      tooltipText: row.done ? "Mark open [ ]" : "Complete [x]"
      foreground: row.done ? Qt.darker(row.foreground, 1.4) : Style.selectedStateColor(row.foreground, Color.accent)
      fontFamily: row.fontFamily
      onClicked: row.toggled(row.task)
    }

    Text { anchors.verticalCenter: parent.verticalCenter; text: row.done ? "[x]" : "[ ]"; color: row.done ? Qt.darker(row.foreground, 1.6) : Style.selectedStateColor(row.foreground, Color.accent); font.family: row.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

    Text { anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - 120); text: row.task.title; color: row.done ? Qt.darker(row.foreground, 1.6) : row.foreground; font.family: row.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.strikeout: row.done }

    Text { anchors.verticalCenter: parent.verticalCenter; text: Model.taskDueDate(row.task) || "no due"; color: Qt.darker(row.foreground, 1.5); font.family: row.fontFamily; font.pixelSize: Style.font.caption }

    Item { width: Math.max(0, parent.width - (24 + 8 * 3 + 24 + 60) - (row.task.title.length * 6)); height: 1 }

    PanelActionButton { anchors.verticalCenter: parent.verticalCenter; iconText: "󰆴"; tooltipText: "Delete task"; hoverColor: Color.urgent; foreground: row.foreground; fontFamily: row.fontFamily; onClicked: row.deleted(row.task) }
  }
}
