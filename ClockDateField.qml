import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// A date field that is picked, not typed: the button shows the chosen day and
// toggles a compact month grid below it. Typing a date is still possible for
// anyone who prefers it — the button doubles as a text field once focused —
// but the grid is the default path.
//
// Built on Model.monthGrid, the same six-row builder the month view uses, so a
// month never changes the picker's height and the panel does not jump.
Column {
  id: field

  required property color foreground
  required property string fontFamily
  property string value: ""                 // "YYYY-MM-DD", "" when unset
  property string placeholder: "Pick a date"
  property int weekStart: 0
  property string todayKey: ""
  property string minKey: ""                // days before this render disabled
  property bool expanded: false
  property real fieldWidth: Style.space(150)

  signal picked(string key)

  readonly property date _cursorDate: {
    var base = field.value !== "" ? field.value : (field.todayKey !== "" ? field.todayKey : Model.keyForDate(new Date()))
    return Model.keyToDate(base)
  }
  property int viewYear: -1
  property int viewMonth: -1
  readonly property int shownYear: field.viewYear >= 0 ? field.viewYear : field._cursorDate.getFullYear()
  readonly property int shownMonth: field.viewMonth >= 0 ? field.viewMonth : field._cursorDate.getMonth()
  readonly property var grid: Model.monthGrid(field.shownYear, field.shownMonth, field.weekStart, field.todayKey)

  function clear() { field.value = ""; field.expanded = false; field.viewYear = -1; field.viewMonth = -1 }
  function setValue(key) { field.value = String(key || ""); field.viewYear = -1; field.viewMonth = -1 }
  function stepMonth(delta) {
    var d = new Date(field.shownYear, field.shownMonth + delta, 1)
    field.viewYear = d.getFullYear()
    field.viewMonth = d.getMonth()
  }

  spacing: Style.space(6)

  // ---- The closed field
  Rectangle {
    id: button
    width: field.fieldWidth
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    color: Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, mouse.containsMouse || field.expanded ? 0.10 : 0.05)
    border.width: Style.spacing.hairline
    border.color: field.expanded
      ? Style.selectedBorderFor(field.foreground, Color.accent)
      : Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.14)

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(6)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰃭"
        color: Qt.darker(field.foreground, 1.4)
        font.family: field.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(30)
        text: field.value !== "" ? Qt.formatDate(Model.keyToDate(field.value), "ddd, d MMM yyyy") : field.placeholder
        color: field.value !== "" ? field.foreground : Qt.darker(field.foreground, 1.8)
        font.family: field.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: field.expanded = !field.expanded
    }
  }

  // ---- The grid
  Rectangle {
    visible: field.expanded
    width: field.fieldWidth
    height: visible ? gridCol.implicitHeight + Style.space(16) : 0
    radius: Style.cornerRadius + 2
    color: Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.05)
    border.width: Style.spacing.hairline
    border.color: Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.14)

    Column {
      id: gridCol
      x: Style.space(8); y: Style.space(8)
      width: parent.width - Style.space(16)
      spacing: Style.space(4)

      // Month stepper
      Item {
        width: parent.width
        height: Style.space(20)
        Text {
          anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
          text: "‹"; color: field.foreground; font.family: field.fontFamily; font.pixelSize: Style.font.body
          MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor; onClicked: field.stepMonth(-1) }
        }
        Text {
          anchors.centerIn: parent
          text: Qt.formatDate(new Date(field.shownYear, field.shownMonth, 1), "MMMM yyyy").toUpperCase()
          color: Qt.darker(field.foreground, 1.2); font.family: field.fontFamily
          font.pixelSize: Style.font.caption; font.letterSpacing: 1
        }
        Text {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          text: "›"; color: field.foreground; font.family: field.fontFamily; font.pixelSize: Style.font.body
          MouseArea { anchors.fill: parent; anchors.margins: -Style.space(6); cursorShape: Qt.PointingHandCursor; onClicked: field.stepMonth(1) }
        }
      }

      // Weekday header
      Row {
        width: parent.width
        Repeater {
          model: 7
          Text {
            required property int index
            width: gridCol.width / 7
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDate(new Date(2026, 1, 1 + ((index + field.weekStart) % 7)), "ddd").charAt(0)
            color: Qt.darker(field.foreground, 1.7)
            font.family: field.fontFamily
            font.pixelSize: Style.font.caption - 1
          }
        }
      }

      // Six week rows, always
      Repeater {
        model: field.grid
        Row {
          required property var modelData
          width: parent.width
          Repeater {
            model: modelData.days
            Rectangle {
              required property var modelData
              readonly property bool isChosen: modelData.key === field.value
              readonly property bool isToday: modelData.key === field.todayKey
              readonly property bool disabled: field.minKey !== "" && modelData.key < field.minKey
              width: gridCol.width / 7
              height: Style.space(22)
              radius: Style.cornerRadius
              color: isChosen ? Style.selectedFillFor(field.foreground, Color.accent) : "transparent"
              border.width: (!isChosen && isToday) ? Style.spacing.hairline : 0
              border.color: Qt.rgba(field.foreground.r, field.foreground.g, field.foreground.b, 0.35)
              opacity: disabled ? 0.3 : (modelData.inMonth ? 1 : 0.45)
              Text {
                anchors.centerIn: parent
                text: Model.dayNum(modelData.key)
                color: isChosen ? Style.selectedStateColor(field.foreground, Color.accent) : field.foreground
                font.family: field.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: isChosen || isToday
              }
              MouseArea {
                anchors.fill: parent
                enabled: !parent.disabled
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  field.value = parent.modelData.key
                  field.expanded = false
                  field.picked(field.value)
                }
              }
            }
          }
        }
      }
    }
  }
}
