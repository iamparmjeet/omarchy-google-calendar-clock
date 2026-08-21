import QtQuick
import qs.Commons
import qs.Ui

// NEW TASK form card. Owns its fields; emits submitted(title, due) and lets
// the container perform the write and close the form.
Column {
  id: form

  required property color foreground
  required property string fontFamily
  property string errorText: ""

  signal submitted(string title, string due)
  signal cancelled()

  width: parent.width
  spacing: Style.space(8)

  function open() {
    titleField.text = ""
    dueField.text = ""
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function commit() {
    var title = String(titleField.text).trim()
    if (!title) { console.warn("parm.clock: empty task title"); return }
    form.submitted(title, String(dueField.text).trim())
    form.cancelled()
  }

  PanelSeparator { width: parent.width; foreground: form.foreground }
  Text { width: parent.width; text: "NEW TASK  [ ]"; color: Qt.darker(form.foreground, 1.4); font.family: form.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
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
        placeholderText: "What needs doing?  [ ]"
        foreground: form.foreground
        font.family: form.fontFamily
        Keys.onPressed: function(event) { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) form.commit(); else if (event.key === Qt.Key_Escape) form.cancelled() }
      }
      Item {
        width: parent.width
        height: Math.max(dueField.implicitHeight, addButton.implicitHeight)
        TextField {
          id: dueField
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(128)
          placeholderText: "due  YYYY-MM-DD"
          foreground: form.foreground
          font.family: form.fontFamily
          Keys.onPressed: function(event) { if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) form.commit(); else if (event.key === Qt.Key_Escape) form.cancelled() }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          Button { text: "Cancel"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.cancelled() }
          Button { id: addButton; text: "Add"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.commit() }
        }
      }
      Text { visible: form.errorText !== ""; width: parent.width; text: form.errorText; textFormat: Text.PlainText; color: Color.urgent; font.family: form.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight }
    }
  }
}
