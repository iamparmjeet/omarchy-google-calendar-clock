import QtQuick
import qs.Commons
import qs.Ui

// NEW EVENT form card. Owns its input fields and reset/focus behaviour; the
// container is told about a submit and does the gws write. open() resets the
// fields and focuses the title, replacing the container-side field poking.
Column {
  id: form

  required property color foreground
  required property string fontFamily
  property string errorText: ""

  signal submitted(string title, string date, string start, string end, string location, bool meet)
  signal cancelled()

  width: parent.width
  spacing: Style.space(8)

  function open(defaultDate, defaultStart) {
    titleField.text = ""
    dateField.text = defaultDate
    startField.text = defaultStart || ""
    endField.text = ""
    locationField.text = ""
    meetSwitch.checked = false
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function commit() {
    var title = String(titleField.text).trim()
    if (!title) { console.warn("parm.clock: empty title, abort"); return }
    form.submitted(
      title,
      String(dateField.text).trim(),
      String(startField.text).trim(),
      String(endField.text).trim(),
      String(locationField.text).trim(),
      meetSwitch.checked
    )
    form.cancelled()
  }

  PanelSeparator { width: parent.width; foreground: form.foreground }
  Text { width: parent.width; text: "NEW EVENT"; color: Qt.darker(form.foreground, 1.4); font.family: form.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
  Rectangle {
    width: parent.width
    radius: Style.cornerRadius + 4
    color: Qt.rgba(form.foreground.r, form.foreground.g, form.foreground.b, 0.04)
    border.width: Style.spacing.hairline; border.color: Qt.rgba(form.foreground.r, form.foreground.g, form.foreground.b, 0.10)
    height: cardCol.implicitHeight + Style.space(16)
    Column {
      id: cardCol
      width: parent.width - Style.space(16)
      x: Style.space(8); y: Style.space(8)
      spacing: Style.space(8)
      TextField {
        id: titleField
        width: parent.width
        placeholderText: "Title — e.g. Lunch with team"
        foreground: form.foreground
        font.family: form.fontFamily
        Keys.onPressed: function(event) { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) form.commit(); else if (event.key === Qt.Key_Escape) form.cancelled() }
      }
      Item {
        width: parent.width
        height: Math.max(dateField.implicitHeight, meetRow.implicitHeight)
        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          TextField { id: dateField; width: Style.space(118); placeholderText: "YYYY-MM-DD"; foreground: form.foreground; font.family: form.fontFamily }
          TextField { id: startField; width: Style.space(74); placeholderText: "HH:MM"; foreground: form.foreground; font.family: form.fontFamily }
          TextField { id: endField; width: Style.space(74); placeholderText: "HH:MM"; foreground: form.foreground; font.family: form.fontFamily }
        }
        Row {
          id: meetRow
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Meet"; color: meetSwitch.checked ? form.foreground : Qt.darker(form.foreground, 1.5); font.family: form.fontFamily; font.pixelSize: Style.font.caption; font.bold: meetSwitch.checked }
          ToggleSwitch { id: meetSwitch; foreground: form.foreground; trackHeight: Style.space(16); trackWidth: Math.round(Style.space(16) * 1.85) }
        }
      }
      TextField {
        id: locationField
        width: parent.width
        placeholderText: "Location (optional)"
        foreground: form.foreground
        font.family: form.fontFamily
      }
      Row {
        width: parent.width; spacing: Style.space(8)
        Button { text: "Add"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.commit() }
        Button { text: "Cancel"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.cancelled() }
        Text { visible: form.errorText !== ""; anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - Style.space(140)); text: form.errorText; textFormat: Text.PlainText; color: Color.urgent; font.family: form.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight }
      }
    }
  }
}
