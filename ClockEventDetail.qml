import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// DETAIL view: everything the synced state knows about one event, shown in
// place of the calendar area. Reached by clicking an event body; the row's
// own ↗ button still goes straight to Google and never lands here.
//
// Google-controlled strings (title, location, description) render as
// PlainText: AutoText would let an organizer's event carry rich-text markup
// into the shell, and a description is the longest attacker-controlled string
// the panel ever displays.
Column {
  id: detail

  required property var ev
  required property var calendars
  required property color foreground
  required property string fontFamily
  required property var dotColor            // function(ev) -> color

  readonly property real minHeight: Style.space(360)
  readonly property color accentColor: detail.ev ? detail.dotColor(detail.ev) : detail.foreground

  // The card breathes on its own rather than sitting flush against the panel
  // edges, which is what made the detail area read as undefined next to the
  // bordered cards the rest of the panel uses.
  readonly property int cardInset: Style.space(10)
  readonly property int cardPadding: Style.space(18)
  readonly property int labelWidth: Style.space(96)

  readonly property string calendarName: {
    var list = detail.calendars || []
    for (var i = 0; i < list.length; i++)
      if (list[i].id === (detail.ev ? detail.ev.calendarId : "")) return list[i].name || list[i].summary || list[i].id
    return detail.ev ? detail.ev.calendarId : ""
  }
  readonly property string whenText: {
    if (!detail.ev) return ""
    // Same phrasing the agenda card uses for its day heading.
    var day = Qt.formatDate(Model.keyToDate(detail.ev.dateKey), "dddd, MMMM d")
    if (!Model.eventSpansDays(detail.ev))
      return detail.ev.allDay ? day + " · all day" : day + " · " + Model.eventTimeRange(detail.ev)
    // Multi-day: name both ends, or the reader has to guess which day the
    // closing time belongs to.
    var endDay = Qt.formatDate(Model.keyToDate(detail.ev.endDateKey), "dddd, MMMM d")
    if (detail.ev.allDay) return day + "  →  " + endDay + " · all day"
    return day + " · " + Model.startTimeText(detail.ev) + "  →  " + endDay + " · " + Model.eventEndTimeText(detail.ev)
  }

  signal back()
  signal editRequested(var ev)
  signal deleteRequested(var ev)
  signal openExternally(var ev)
  signal openUrl(string url)
  signal openLocation(string location)

  width: parent.width
  spacing: Style.space(12)

  // ---- Header: back + calendar chip + actions
  Item {
    width: parent.width
    height: Math.max(backRow.implicitHeight, actionRow.implicitHeight)

    Row {
      id: backRow
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)
      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰅁"
        tooltipText: "Back"
        foreground: detail.foreground
        fontFamily: detail.fontFamily
        onClicked: detail.back()
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(3); height: Style.space(14); radius: 1
        color: detail.accentColor
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: detail.calendarName
        textFormat: Text.PlainText
        color: Qt.darker(detail.foreground, 1.4)
        font.family: detail.fontFamily
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1
        elide: Text.ElideRight
        width: Math.min(implicitWidth, Style.space(220))
      }
    }

    Row {
      id: actionRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      PanelActionButton {
        iconText: "󰏫"; tooltipText: "Edit"
        foreground: detail.foreground; fontFamily: detail.fontFamily
        onClicked: detail.editRequested(detail.ev)
      }
      PanelActionButton {
        iconText: "󰩹"; tooltipText: "Delete"
        foreground: detail.foreground; fontFamily: detail.fontFamily
        hoverColor: Color.urgent
        onClicked: detail.deleteRequested(detail.ev)
      }
      PanelActionButton {
        iconText: "󰅂"; tooltipText: "Open in Calendar"
        foreground: detail.foreground; fontFamily: detail.fontFamily
        onClicked: detail.openExternally(detail.ev)
      }
    }
  }

  // ---- The card: inset from the panel edges, bordered, generously padded
  Item {
    width: parent.width
    height: card.height + detail.cardInset

    Rectangle {
      id: card
      x: detail.cardInset
      width: parent.width - detail.cardInset * 2
      height: cardCol.implicitHeight + detail.cardPadding * 2
      radius: Style.cornerRadius + 4
      color: Qt.rgba(detail.foreground.r, detail.foreground.g, detail.foreground.b, 0.04)
      border.width: Style.spacing.hairline
      border.color: Qt.rgba(detail.foreground.r, detail.foreground.g, detail.foreground.b, 0.14)

      // A tinted rail in the calendar's colour, so the card is anchored to the
      // event rather than floating as a generic container.
      Rectangle {
        x: 0; y: detail.cardPadding
        width: Style.space(3)
        height: parent.height - detail.cardPadding * 2
        radius: 1
        color: detail.accentColor
        opacity: 0.85
      }

      Column {
        id: cardCol
        x: detail.cardPadding
        y: detail.cardPadding
        width: parent.width - detail.cardPadding * 2
        spacing: Style.space(14)

        Text {
          width: parent.width
          text: detail.ev ? (detail.ev.title || "(untitled)") : ""
          textFormat: Text.PlainText
          color: detail.foreground
          font.family: detail.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: Text.WordWrap
        }

        PanelSeparator { width: parent.width; foreground: detail.foreground }

        // One labelled row, optionally with a trailing action button.
        component Field: Item {
          required property string label
          required property string value
          property bool wrap: false
          property string actionIcon: ""
          property string actionTooltip: ""
          signal actionTriggered()

          visible: value !== ""
          width: parent.width
          height: visible ? Math.max(valueText.implicitHeight, actionSlot.height) : 0

          Text {
            id: labelText
            anchors.left: parent.left
            anchors.top: parent.top
            width: detail.labelWidth
            text: parent.label
            color: Qt.darker(detail.foreground, 1.6)
            font.family: detail.fontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
          Text {
            id: valueText
            anchors.left: labelText.right
            anchors.leftMargin: Style.space(12)
            anchors.right: actionSlot.left
            anchors.rightMargin: Style.space(8)
            anchors.top: parent.top
            text: parent.value
            textFormat: Text.PlainText
            color: detail.foreground
            font.family: detail.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: parent.wrap ? Text.WordWrap : Text.NoWrap
            elide: parent.wrap ? Text.ElideNone : Text.ElideRight
          }
          Item {
            id: actionSlot
            anchors.right: parent.right
            anchors.top: parent.top
            width: parent.actionIcon !== "" ? actionButton.width : 0
            height: parent.actionIcon !== "" ? actionButton.height : Style.space(1)
            PanelActionButton {
              id: actionButton
              visible: parent.parent.actionIcon !== ""
              iconText: parent.parent.actionIcon
              tooltipText: parent.parent.actionTooltip
              foreground: detail.foreground
              fontFamily: detail.fontFamily
              onClicked: parent.parent.actionTriggered()
            }
          }
        }

        Field { label: "WHEN"; value: detail.whenText }

        Field {
          label: "WHERE"
          value: detail.ev ? (detail.ev.location || "") : ""
          wrap: true
          actionIcon: "󰍎"
          actionTooltip: "Open in Maps"
          onActionTriggered: detail.openLocation(detail.ev.location)
        }

        Field {
          label: "MEET"
          value: detail.ev ? (detail.ev.meetUrl || "") : ""
          wrap: true
          actionIcon: "󰕧"
          actionTooltip: "Join meeting"
          onActionTriggered: detail.openUrl(detail.ev.meetUrl)
        }

        Field {
          label: "LINK"
          value: detail.ev ? (detail.ev.htmlLink || "") : ""
          actionIcon: "󰏌"
          actionTooltip: "Open in Google Calendar"
          onActionTriggered: detail.openUrl(detail.ev.htmlLink)
        }

        Field { label: "REPEATS"; value: (detail.ev && detail.ev.recurring) ? "Recurring event" : "" }

        PanelSeparator {
          width: parent.width
          foreground: detail.foreground
          visible: detail.ev && (detail.ev.description || "") !== ""
        }

        Text {
          width: parent.width
          visible: text !== ""
          text: detail.ev ? (detail.ev.description || "") : ""
          textFormat: Text.PlainText
          color: Qt.darker(detail.foreground, 1.25)
          font.family: detail.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
