import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The bottom card under the pills. Three variants keyed on viewMode:
// month/week show the selected day's events (with locations), upcoming shows a
// flat 14-day summary (first 8), tasks shows the first 10 tasks.
Rectangle {
  id: card

  required property string viewMode
  required property string selectedKey
  required property string todayKey
  required property var eventIndex
  required property var hiddenCalendars
  required property var tasks                  // pre-filtered by the container
  required property color foreground
  required property string fontFamily
  required property var dotColor               // function(ev) -> color

  signal openEvent(var ev)

  readonly property var dayEvents: viewMode === "month" || viewMode === "week"
    ? Model.visibleEventsOn(eventIndex, selectedKey, hiddenCalendars)
    : []
  readonly property var summary: Model.upcomingSummary(eventIndex, todayKey, 14, hiddenCalendars, 8)

  width: parent.width
  radius: Style.cornerRadius + 4
  color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.03)
  border.width: Style.spacing.hairline
  border.color: Qt.rgba(card.foreground.r, card.foreground.g, card.foreground.b, 0.12)
  height: inner.implicitHeight + Style.space(16)
  clip: true

  Column {
    id: inner
    width: parent.width - Style.space(16)
    x: Style.space(8)
    y: Style.space(8)
    spacing: Style.space(8)

    // Month/Week: selected-day events
    Column {
      visible: card.viewMode === "month" || card.viewMode === "week"
      width: parent.width
      spacing: Style.space(6)
      Text { width: parent.width; text: Qt.formatDate(Model.keyToDate(card.selectedKey), "dddd, MMMM d").toUpperCase(); color: Qt.darker(card.foreground, 1.3); font.family: card.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
      Repeater {
        model: card.dayEvents
        ClockEventRow {
          required property var modelData
          ev: modelData
          showLocation: true
          foreground: card.foreground
          fontFamily: card.fontFamily
          dotColor: card.dotColor
          onOpenRequested: card.openEvent(ev)
        }
      }
      Text {
        visible: card.dayEvents.length === 0
        width: parent.width; text: "No events on this day."
        color: Qt.darker(card.foreground, 1.8); font.family: card.fontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true
      }
    }

    // Upcoming: flat summary
    Column {
      visible: card.viewMode === "upcoming"
      width: parent.width
      spacing: Style.space(4)
      Text { width: parent.width; text: "NEXT 14 DAYS — SUMMARY"; color: Qt.darker(card.foreground, 1.4); font.family: card.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
      Repeater {
        model: card.summary
        ClockEventRow {
          required property var modelData
          ev: modelData
          dateSuffix: Qt.formatDate(Model.keyToDate(modelData.dateKey), "MMM d")
          foreground: card.foreground
          fontFamily: card.fontFamily
          dotColor: card.dotColor
          onOpenRequested: card.openEvent(ev)
        }
      }
    }

    // Tasks: first 10
    Column {
      visible: card.viewMode === "tasks"
      width: parent.width
      spacing: Style.space(4)
      Text { width: parent.width; text: "TASKS — " + card.tasks.length + " TOTAL"; color: Qt.darker(card.foreground, 1.4); font.family: card.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
      Repeater {
        model: card.tasks.slice(0, 10)
        Row {
          required property var modelData
          width: parent.width; spacing: Style.space(8)
          Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.status === "completed" ? "[x]" : "[ ]"; color: modelData.status === "completed" ? Qt.darker(card.foreground, 1.6) : Style.selectedStateColor(card.foreground, Color.accent); font.family: card.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          Text { anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - 32 - 70); text: modelData.title; textFormat: Text.PlainText; color: modelData.status === "completed" ? Qt.darker(card.foreground, 1.6) : card.foreground; font.family: card.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.strikeout: modelData.status === "completed" }
          Text { anchors.verticalCenter: parent.verticalCenter; text: Model.taskDueDate(modelData) || "no due"; color: Qt.darker(card.foreground, 1.4); font.family: card.fontFamily; font.pixelSize: Style.font.caption }
        }
      }
      Text { visible: card.tasks.length > 10; width: parent.width; text: "+" + (card.tasks.length - 10) + " more — switch to TASKS tab for full list"; color: Qt.darker(card.foreground, 1.6); font.family: card.fontFamily; font.pixelSize: Style.font.caption; font.italic: true }
    }
  }
}
