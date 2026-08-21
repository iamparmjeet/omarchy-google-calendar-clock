import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// WEEK view: a header (W## + date range, stepping, back-to-today) over a
// vertical stack of seven full-width day cards with up to three event chips.
// The week's keys are passed in so stepping stays the container's job.
Column {
  id: view

  required property var weekKeys
  required property string todayKey
  required property string selectedKey
  required property var eventIndex
  required property var hiddenCalendars
  required property color foreground
  required property string fontFamily
  required property var dotColor           // function(ev) -> color

  readonly property real minHeight: Style.space(360)
  readonly property var headingParts: Model.weekHeadingParts(weekKeys)
  readonly property bool currentWeek: weekKeys.indexOf(todayKey) !== -1

  signal selectDay(string key)
  signal stepWeek(int delta)
  signal backToTodayRequested()
  signal openEvent(var ev)

  width: parent.width
  spacing: Style.space(10)

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.space(8)
    PanelActionButton { iconText: "󰅁"; tooltipText: "Previous week"; foreground: view.foreground; fontFamily: view.fontFamily; onClicked: view.stepWeek(-1) }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: weekHeading.implicitWidth + Style.space(22)
      height: Style.space(22)
      radius: height / 2
      color: Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.06)
      border.width: Style.spacing.hairline
      border.color: Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.10)
      Text {
        id: weekHeading
        anchors.centerIn: parent
        text: view.headingParts
          ? "W" + view.headingParts.week
            + " · " + Qt.formatDate(Model.keyToDate(view.headingParts.startKey), "MMM d")
            + " – " + Qt.formatDate(Model.keyToDate(view.headingParts.endKey), "MMM d, yyyy")
          : ""
        color: view.foreground
        font.family: view.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 0.8
        font.bold: true
      }
    }
    PanelActionButton { iconText: "󰅂"; tooltipText: "Next week"; foreground: view.foreground; fontFamily: view.fontFamily; onClicked: view.stepWeek(1) }
    PanelActionButton {
      visible: !view.currentWeek
      anchors.verticalCenter: parent.verticalCenter
      iconText: "󰥔"
      tooltipText: "Back to this week"
      foreground: view.foreground
      fontFamily: view.fontFamily
      onClicked: view.backToTodayRequested()
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: view.weekKeys
      Rectangle {
        id: dayCard
        required property string modelData
        readonly property string key: modelData
        readonly property var evs: Model.visibleEventsOn(view.eventIndex, key, view.hiddenCalendars)
        readonly property bool isToday: key === view.todayKey
        readonly property bool isSelected: key === view.selectedKey
        readonly property bool isWeekend: Model.isWeekendKey(key)
        readonly property date keyDate: Model.keyToDate(key)
        width: parent.width
        height: dayRow.implicitHeight + Style.space(14)
        radius: Style.cornerRadius + 2
        color: isSelected ? Style.selectedFillFor(view.foreground, Color.accent)
          : isToday ? Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.07)
          : isWeekend ? Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.025)
          : Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.035)
        border.width: isSelected || isToday ? Style.spacing.hairline : 0
        border.color: isSelected ? Style.selectedBorderFor(view.foreground, Color.accent) : Style.normalBorderFor(view.foreground, Color.accent)
        Rectangle { visible: dayCard.isToday || dayCard.isSelected; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Style.space(3); height: parent.height - Style.space(10); radius: 1; color: dayCard.isSelected ? Style.selectedStateColor(view.foreground, Color.accent) : Color.accent; opacity: dayCard.isSelected ? 1 : 0.9 }

        Row {
          id: dayRow
          width: parent.width - Style.space(14)
          x: Style.space(7)
          y: Style.space(7)
          spacing: Style.space(10)

          Column {
            width: Style.space(74)
            spacing: Style.space(1)
            anchors.verticalCenter: parent.verticalCenter
            Text { text: Qt.formatDate(dayCard.keyDate, "ddd").toUpperCase(); color: dayCard.isToday ? Style.selectedStateColor(view.foreground, Color.accent) : dayCard.isWeekend ? Qt.darker(view.foreground, 1.55) : Qt.darker(view.foreground, 1.3); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: dayCard.isToday || dayCard.isSelected }
            Text { text: Model.dayNum(dayCard.key) + " · " + Qt.formatDate(dayCard.keyDate, "MMM"); color: dayCard.isSelected ? Style.selectedStateColor(view.foreground, Color.accent) : view.foreground; font.family: view.fontFamily; font.pixelSize: dayCard.isToday ? 19 : 16; font.bold: dayCard.isToday || dayCard.isSelected }
            Text { text: dayCard.isToday ? "Today" : Model.relativeDayLabel(dayCard.key, view.todayKey); color: dayCard.isToday ? Color.accent : Qt.darker(view.foreground, 1.7); font.family: view.fontFamily; font.pixelSize: Style.font.caption - 1; font.italic: true; visible: text !== "" }
          }

          Rectangle { width: Style.spacing.hairline; height: dayRow.height; color: Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.10); anchors.verticalCenter: parent.verticalCenter }

          Column {
            width: parent.width - Style.space(74) - Style.space(10) - Style.spacing.hairline - Style.space(6)
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
              model: dayCard.evs.slice(0, 3)
              Rectangle {
                id: chip
                required property var modelData
                readonly property color chipColor: view.dotColor(modelData)
                width: parent.width; height: Style.space(22); radius: Style.cornerRadius
                color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.13)
                border.width: Style.spacing.hairline; border.color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.22)
                Row {
                  anchors.fill: parent; anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6); spacing: Style.space(6)
                  Rectangle { width: Style.space(2); height: Style.space(12); radius: 1; anchors.verticalCenter: parent.verticalCenter; color: chip.chipColor }
                  Text {
                    width: Style.space(44); anchors.verticalCenter: parent.verticalCenter
                    text: chip.modelData.allDay ? "all day" : Model.startTimeText(chip.modelData)
                    color: Qt.darker(view.foreground, 1.45); font.family: view.fontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - 2 - Style.space(6) - 44 - Style.space(6) - Style.space(12))
                    text: chip.modelData.title; color: view.foreground; font.family: view.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight
                  }
                  Text { anchors.verticalCenter: parent.verticalCenter; text: "↗"; color: Qt.darker(view.foreground, 1.7); font.family: view.fontFamily; font.pixelSize: Style.font.caption }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.openEvent(chip.modelData) }
              }
            }
            Rectangle {
              visible: dayCard.evs.length > 3
              width: parent.width; height: Style.space(18); radius: Style.cornerRadius
              color: Qt.rgba(view.foreground.r, view.foreground.g, view.foreground.b, 0.06)
              Text { anchors.centerIn: parent; text: "+" + (dayCard.evs.length - 3) + " more on " + Qt.formatDate(dayCard.keyDate, "ddd").toUpperCase(); color: Qt.darker(view.foreground, 1.6); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.italic: true }
            }
            Text {
              visible: dayCard.evs.length === 0
              width: parent.width
              text: "— Free —"; color: Qt.darker(view.foreground, 2.0); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.italic: true; topPadding: Style.space(2)
            }
          }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.selectDay(dayCard.key); z: -1 }
      }
    }
  }
}
