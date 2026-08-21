import QtQuick
import qs.Commons
import qs.Ui

// TASKS view: header with the open/closed legend and the show-completed
// switch, then one row per (already filtered) task. Completion and deletion
// are emitted; the container owns gws writes and re-sync.
Column {
  id: view

  required property var tasks              // pre-filtered by the container
  required property bool showCompleted
  required property color foreground
  required property string fontFamily

  readonly property real minHeight: Style.space(360)

  signal showCompletedToggled()
  signal taskToggled(var task)
  signal taskDeleted(var task)

  width: parent.width
  spacing: Style.space(6)

  Item {
    width: parent.width
    height: Style.space(22)
    Row {
      id: tasksHeaderLeft
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(10)
      Text { text: "TASKS"; color: Qt.darker(view.foreground, 1.4); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
      Rectangle { width: Style.spacing.hairline; height: Style.space(10); color: Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.18); anchors.verticalCenter: parent.verticalCenter }
      Text { text: "[ ] open  ·  [×] closed"; color: Qt.darker(view.foreground, 1.7); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 0.4 }
    }
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(7)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "closed"
        color: view.showCompleted ? view.foreground : Qt.darker(view.foreground, 1.6)
        font.family: view.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.6
      }
      ToggleSwitch {
        anchors.verticalCenter: parent.verticalCenter
        checked: view.showCompleted
        foreground: view.foreground
        trackHeight: Style.space(16)
        trackWidth: Math.round(Style.space(16) * 1.85)
        onToggled: view.showCompletedToggled()
      }
    }
  }

  Repeater {
    model: view.tasks
    ClockTaskRow {
      required property var modelData
      task: modelData
      foreground: view.foreground
      fontFamily: view.fontFamily
      onToggled: view.taskToggled(task)
      onDeleted: view.taskDeleted(task)
    }
  }

  Text {
    visible: view.tasks.length === 0
    width: parent.width
    text: "No tasks."
    color: Qt.darker(view.foreground, 1.8)
    font.family: view.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.italic: true
  }
}
