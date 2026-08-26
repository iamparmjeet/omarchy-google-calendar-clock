import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// NEW EVENT form card. Owns its input fields and reset/focus behaviour; the
// container is told about a submit and does the gws write. open() resets the
// fields and focuses the title, replacing the container-side field poking.
Column {
  id: form

  required property color foreground
  required property string fontFamily
  property string errorText: ""

  signal submitted(string title, string date, string start, string end, string endDate, string location, bool meet)
  signal cancelled()

  // Non-null while editing an existing event; the container reads it to decide
  // between an insert and a patch. Meet creation is add-only: a patch cannot
  // meaningfully re-issue a conference createRequest.
  property var editingEvent: null
  property string todayKey: ""
  property int weekStart: 0
  // 30-minute slots; "" is the all-day choice and the reason a plain dropdown
  // works here — a free-text time field cannot express "no time at all".
  readonly property var timeOptions: {
    var out = [{ label: "All day", value: "" }]
    for (var i = 0; i < 48; i++) {
      var hh = Math.floor(i / 2), mm = (i % 2) * 30
      var v = (hh < 10 ? "0" : "") + hh + ":" + (mm === 0 ? "00" : "30")
      out.push({ label: v, value: v })
    }
    return out
  }
  readonly property bool editing: !!form.editingEvent
  readonly property string heading: form.editing ? "EDIT EVENT" : "NEW EVENT"

  width: parent.width
  spacing: Style.space(8)

  // "2026-08-26T14:00:00-03:00" -> "14:00"; all-day values carry no time.
  function _hhmm(value) {
    var m = /T(\d{2}:\d{2})/.exec(String(value || ""))
    return m ? m[1] : ""
  }

  // "2026-08-26T14:00:00-03:00" or "2026-08-26" -> "2026-08-26"
  function _dayOf(value) {
    var m = /^(\d{4}-\d{2}-\d{2})/.exec(String(value || ""))
    return m ? m[1] : ""
  }

  // Google stores all-day ends exclusively; show the user the last day they
  // actually mean, which is the day before.
  function _inclusiveEndDay(ev) {
    var raw = form._dayOf(ev.end)
    if (raw === "" || !ev.allDay) return raw
    var d = Model.keyToDate(raw)
    d.setDate(d.getDate() - 1)
    return Model.keyForDate(d)
  }

  function openForEdit(ev) {
    form.editingEvent = ev
    titleField.text = ev.title || ""
    startDate.setValue(ev.dateKey || "")
    var endDay = form._inclusiveEndDay(ev)
    endDate.setValue(endDay === (ev.dateKey || "") ? "" : endDay)
    startTime.value = ev.allDay ? "" : form._hhmm(ev.start)
    endTime.value = ev.allDay ? "" : form._hhmm(ev.end)
    locationField.text = ev.location || ""
    meetSwitch.checked = false
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function open(defaultDate, defaultStart) {
    form.editingEvent = null
    titleField.text = ""
    startDate.setValue(defaultDate)
    endDate.clear()
    startTime.value = defaultStart || ""
    endTime.value = ""
    locationField.text = ""
    meetSwitch.checked = false
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function commit() {
    var title = String(titleField.text).trim()
    if (!title) { console.warn("parm.clock: empty title, abort"); return }
    form.submitted(
      title,
      startDate.value,
      startTime.value,
      endTime.value,
      endDate.value,
      String(locationField.text).trim(),
      meetSwitch.checked
    )
    form.cancelled()
  }

  PanelSeparator { width: parent.width; foreground: form.foreground }
  Text { width: parent.width; text: form.heading; color: Qt.darker(form.foreground, 1.4); font.family: form.fontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
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
      // ---- Starts
      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          anchors.top: parent.top; topPadding: Style.space(6)
          width: Style.space(52); text: "STARTS"
          color: Qt.darker(form.foreground, 1.6); font.family: form.fontFamily
          font.pixelSize: Style.font.caption; font.letterSpacing: 1
        }
        ClockDateField {
          id: startDate
          foreground: form.foreground; fontFamily: form.fontFamily
          todayKey: form.todayKey; weekStart: form.weekStart
          placeholder: "Pick a day"
          onPicked: if (endDate.value !== "" && endDate.value < startDate.value) endDate.setValue(startDate.value)
        }
        Dropdown {
          id: startTime
          anchors.top: parent.top
          width: Style.space(104)
          showLabel: false
          fontFamily: form.fontFamily
          options: form.timeOptions
          value: ""
          onChanged: function(v) {
            startTime.value = v
            // All-day is a property of the event, not of one end of it.
            if (v === "") endTime.value = ""
          }
        }
      }

      // ---- Ends
      Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
          anchors.top: parent.top; topPadding: Style.space(6)
          width: Style.space(52); text: "ENDS"
          color: Qt.darker(form.foreground, 1.6); font.family: form.fontFamily
          font.pixelSize: Style.font.caption; font.letterSpacing: 1
        }
        ClockDateField {
          id: endDate
          foreground: form.foreground; fontFamily: form.fontFamily
          todayKey: form.todayKey; weekStart: form.weekStart
          placeholder: "Same day"
          minKey: startDate.value
        }
        Dropdown {
          id: endTime
          anchors.top: parent.top
          width: Style.space(104)
          showLabel: false
          enabled: startTime.value !== ""
          opacity: enabled ? 1 : 0.45
          fontFamily: form.fontFamily
          options: form.timeOptions
          value: ""
          onChanged: function(v) { endTime.value = v }
        }
      }

      // ---- Meet (creation only)
      Row {
        id: meetRow
        visible: !form.editing
        width: parent.width
        spacing: Style.space(8)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(52); text: "MEET"
          color: Qt.darker(form.foreground, 1.6); font.family: form.fontFamily
          font.pixelSize: Style.font.caption; font.letterSpacing: 1
        }
        ToggleSwitch { id: meetSwitch; anchors.verticalCenter: parent.verticalCenter; foreground: form.foreground; trackHeight: Style.space(16); trackWidth: Math.round(Style.space(16) * 1.85) }
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
        Button { text: form.editing ? "Save" : "Add"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.commit() }
        Button { text: "Cancel"; foreground: form.foreground; fontFamily: form.fontFamily; onClicked: form.cancelled() }
        Text { visible: form.errorText !== ""; anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - Style.space(140)); text: form.errorText; textFormat: Text.PlainText; color: Color.urgent; font.family: form.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight }
      }
    }
  }
}
