import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One event line inside a list/card: colour bar, time, title (+ location or
// date suffix), and an open-in-Calendar button. Pure function of `ev` plus
// theme — the container decides visibility, calendars, and what opening does.
Row {
  id: row

  required property var ev
  required property color foreground
  required property string fontFamily
  required property var dotColor            // function(ev) -> color
  property bool showLocation: false         // two-line variant (day card)
  property string dateSuffix: ""            // appended to the title (summary)
  property int timeWidth: Style.space(72)

  signal openRequested(var ev)

  width: parent.width
  spacing: Style.space(8)

  Rectangle { width: Style.space(3); height: Style.space(14); radius: 1; anchors.verticalCenter: parent.verticalCenter; color: row.dotColor(row.ev) }

  Text {
    width: row.timeWidth
    anchors.verticalCenter: parent.verticalCenter
    text: row.ev.allDay ? "all day" : Model.eventTimeRange(row.ev)
    color: Qt.darker(row.foreground, 1.4)
    font.family: row.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  Column {
    visible: row.showLocation
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - row.timeWidth - 3 - 8 * 4 - 28)
    spacing: 1
    Text { width: parent.width; text: row.ev.title; color: row.foreground; font.family: row.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.bold: true }
    Text { visible: (row.ev.location || "") !== ""; width: parent.width; text: row.ev.location; color: Qt.darker(row.foreground, 1.5); font.family: row.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
  }

  Text {
    visible: !row.showLocation
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(0, parent.width - row.timeWidth - 3 - 8 * 3 - 28)
    text: row.dateSuffix !== "" ? row.ev.title + " · " + row.dateSuffix : row.ev.title
    color: row.foreground
    font.family: row.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }

  PanelActionButton {
    anchors.verticalCenter: parent.verticalCenter
    iconText: "󰅂"
    tooltipText: "Open in Calendar"
    foreground: row.foreground
    fontFamily: row.fontFamily
    onClicked: row.openRequested(row.ev)
  }
}
