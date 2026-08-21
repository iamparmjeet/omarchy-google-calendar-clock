import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// MONTH view: week-number column + weekday header + the fixed 6x7 grid +
// month stepping. Everything stateful (selected day, today, view month) is
// passed in; the view only renders and emits navigation.
Column {
  id: view

  required property var weeks              // Model.monthGrid output
  required property var weekdays           // Model.weekdayOrder output
  required property date viewDate
  required property string selectedKey
  required property string todayKey
  required property var eventIndex
  required property var hiddenCalendars
  required property color foreground
  required property string fontFamily
  required property string nextWeekStartLabel
  required property var dotColor           // function(ev) -> color

  readonly property real minHeight: Style.space(285)
  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)
  property var labelLocale: Qt.locale("en_US")

  signal selectDay(string key)
  signal stepMonth(int delta)
  signal toggleWeekStartRequested()

  width: parent.width
  spacing: Style.space(2)

  function weekdayLabel(weekday) { return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase() }

  Item {
    id: gridWrap
    width: gridColumn.width
    height: gridColumn.y + gridColumn.height
    anchors.horizontalCenter: parent.horizontalCenter

    WheelHandler { onWheel: function(event) { if (event.angleDelta.y === 0) return; view.stepMonth(event.angleDelta.y > 0 ? -1 : 1) } }

    Column {
      id: gridColumn
      y: Style.space(10)
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: Style.space(3)

      Row {
        id: headerRow
        spacing: view.cellSpacing
        Rectangle {
          width: view.weekColumnWidth; height: Style.space(16); radius: Style.cornerRadius
          color: weekStartMouse.containsMouse ? Style.hoverFillFor(view.foreground, Color.accent) : "transparent"
          Text { anchors.centerIn: parent; text: "W"; color: weekStartMouse.containsMouse ? Style.hoverStateColor(view.foreground, Color.accent) : Qt.darker(view.foreground, 1.9); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
          MouseArea { id: weekStartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: view.toggleWeekStartRequested() }
          PanelToolTip { visible: weekStartMouse.containsMouse; text: "Start weeks on " + view.nextWeekStartLabel; fontFamily: view.fontFamily }
        }
        Item { width: view.gutterWidth; height: Style.space(16) }
        Repeater {
          model: view.weekdays
          Text { required property var modelData; width: view.cellWidth; height: Style.space(16); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: view.weekdayLabel(modelData); color: Qt.darker(view.foreground, 1.5); font.family: view.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
        }
      }

      Repeater {
        model: view.weeks
        Row {
          required property var modelData
          spacing: view.cellSpacing
          Text { width: view.weekColumnWidth; height: view.cellHeight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: modelData.week; color: Qt.darker(view.foreground, 1.9); font.family: view.fontFamily; font.pixelSize: Style.font.caption }
          Item { width: view.gutterWidth; height: view.cellHeight }
          Repeater {
            model: modelData.days
            ClockDayCell {
              required property var modelData
              width: view.cellWidth; height: view.cellHeight
              day: modelData
              isSelected: modelData.key === view.selectedKey
              cellEvents: Model.visibleEventsOn(view.eventIndex, modelData.key, view.hiddenCalendars)
              foreground: view.foreground
              fontFamily: view.fontFamily
              dotColor: view.dotColor
              onChosen: view.selectDay(key)
            }
          }
        }
      }
    }

    Rectangle { x: gridColumn.x + view.weekColumnWidth + view.cellSpacing + Math.round((view.gutterWidth - width) / 2); y: gridColumn.y + headerRow.height + gridColumn.spacing; width: Style.spacing.hairline; height: gridColumn.height - headerRow.height - gridColumn.spacing; color: view.foreground; opacity: 0.1 }
  }

  Item {
    width: parent.width; height: monthNav.height + Style.space(2)
    Item {
      id: monthNav
      anchors.horizontalCenter: parent.horizontalCenter; y: Style.space(2)
      width: gridColumn.width; height: monthLabel.implicitHeight + Style.space(8)
      Text { id: monthLabel; anchors.centerIn: parent; width: Style.space(150); horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(view.viewDate, "MMMM yyyy").toUpperCase(); color: Qt.darker(view.foreground, 1.4); font.family: view.fontFamily; font.pixelSize: Style.font.body; font.letterSpacing: 1 }
      PanelActionButton { anchors.left: parent.left; anchors.leftMargin: -Style.space(8); anchors.verticalCenter: parent.verticalCenter; iconText: "󰅁"; tooltipText: "Previous month"; foreground: view.foreground; fontFamily: view.fontFamily; onClicked: view.stepMonth(-1) }
      PanelActionButton { anchors.right: parent.right; anchors.rightMargin: -Style.space(8); anchors.verticalCenter: parent.verticalCenter; iconText: "󰅂"; tooltipText: "Next month"; foreground: view.foreground; fontFamily: view.fontFamily; onClicked: view.stepMonth(1) }
    }
  }
}
