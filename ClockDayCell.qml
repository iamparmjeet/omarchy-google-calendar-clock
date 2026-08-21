import QtQuick
import qs.Commons
import qs.Ui

// One cell of the month grid: day number, selection/today chrome, up to four
// calendar-tinted dots. Sizing stays with the grid (MonthView) so rows and
// columns keep single sources of truth for cell dimensions.
Rectangle {
  id: cell

  required property var day            // {key, day, inMonth, weekend, today} from Model.monthGrid
  required property bool isSelected
  required property color foreground
  required property string fontFamily
  property var cellEvents: []          // visible events on this day
  property var dotColor                // function(ev) -> color

  signal chosen(string key)

  radius: Style.cornerRadius
  color: isSelected && !day.today
    ? Qt.rgba(cell.foreground.r, cell.foreground.g, cell.foreground.b, 0.08)
    : "transparent"
  border.width: day.today ? Style.spacing.hairline : 0
  border.color: Style.normalBorderFor(cell.foreground, Color.accent)

  Text {
    anchors.centerIn: parent
    text: cell.day.day
    color: cell.day.inMonth
      ? (cell.day.weekend ? Qt.darker(cell.foreground, 1.45) : cell.foreground)
      : Qt.darker(cell.foreground, 2.2)
    font.family: cell.fontFamily
    font.pixelSize: Style.font.body
    font.bold: cell.day.today
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(4)
    spacing: Style.space(3)
    Repeater {
      model: cell.cellEvents.slice(0, 4)
      Rectangle { required property var modelData; width: Style.space(5); height: Style.space(5); radius: width / 2; color: cell.dotColor(modelData) }
    }
  }

  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cell.chosen(cell.day.key) }
}
