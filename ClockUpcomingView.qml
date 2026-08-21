import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// UPCOMING view: the next 14 days grouped by date, only days with at least one
// visible event. Grouping lives in Model.visibleUpcomingGroups so the view is a
// pure render of the model output.
Column {
  id: view

  required property var eventIndex
  required property string todayKey
  required property var hiddenCalendars
  required property color foreground
  required property string fontFamily
  required property var dotColor           // function(ev) -> color

  readonly property real minHeight: Style.space(360)
  readonly property var groups: Model.visibleUpcomingGroups(eventIndex, todayKey, 14, hiddenCalendars)

  signal openEvent(var ev)

  width: parent.width
  spacing: Style.space(6)

  Text { width: parent.width; text: "UPCOMING — NEXT 14 DAYS"; color: Qt.darker(view.foreground, 1.4); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }

  Repeater {
    model: view.groups
    Column {
      id: group
      required property var modelData
      readonly property date keyDate: Model.keyToDate(modelData.key)
      width: parent.width; spacing: Style.space(4)
      Text { width: parent.width; text: Qt.formatDate(group.keyDate, "dddd, MMMM d"); color: Qt.darker(view.foreground, 1.2); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
      Repeater {
        model: group.modelData.events
        ClockEventRow {
          required property var modelData
          ev: modelData
          timeWidth: Style.space(70)
          foreground: view.foreground
          fontFamily: view.fontFamily
          dotColor: view.dotColor
          onOpenRequested: view.openEvent(ev)
        }
      }
    }
  }

  Text {
    visible: view.groups.length === 0
    width: parent.width
    text: "No events in next 14 days."
    color: Qt.darker(view.foreground, 1.8)
    font.family: view.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.italic: true
  }
}
