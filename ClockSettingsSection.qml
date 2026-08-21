import QtQuick
import qs.Commons
import qs.Ui

// Settings block: badge toggle + badge-count dropdown + show-completed toggle
// + per-calendar visibility toggles. Emits {key: value} patches; the container
// merges them into shell.json via persistSettings.
Column {
  id: section

  required property bool showTaskBadge
  required property string badgeMode
  required property bool showCompletedTasks
  required property var calendars
  required property var hiddenCalendars
  required property color foreground
  required property string fontFamily

  signal changed(var values)

  width: parent.width
  spacing: Style.space(6)

  function isHidden(calId) { return hiddenCalendars.indexOf(calId) !== -1 }

  function toggleCalendar(calId) {
    var arr = hiddenCalendars.slice()
    var i = arr.indexOf(calId)
    if (i === -1) arr.push(calId); else arr.splice(i, 1)
    changed({ hiddenCalendars: arr })
  }

  PanelSeparator { width: parent.width; foreground: section.foreground }

  Toggle { width: parent.width; label: "Task badge  [ ] N"; description: "Show 󰄳 N count on the clock"; checked: section.showTaskBadge; foreground: section.foreground; fontFamily: section.fontFamily; onClicked: section.changed({ showTaskBadge: !section.showTaskBadge }) }

  Dropdown {
    label: "Badge count"
    value: section.badgeMode
    foreground: section.foreground
    fontFamily: section.fontFamily
    options: [
      { value: "dueToday", label: "Due today" },
      { value: "overdue", label: "Overdue + today" },
      { value: "all", label: "All incomplete" }
    ]
    onChanged: function(v) { section.changed({ badgeCount: v }) }
  }

  Toggle {
    width: parent.width
    label: "Show completed tasks [x]"
    description: "Toggle slider for closed tasks"
    checked: section.showCompletedTasks
    foreground: section.foreground
    fontFamily: section.fontFamily
    onClicked: section.changed({ showCompletedTasks: !section.showCompletedTasks })
  }

  Repeater {
    model: section.calendars
    Toggle {
      required property var modelData
      width: parent.width
      label: modelData.name || modelData.id
      checked: !section.isHidden(modelData.id)
      foreground: section.foreground
      fontFamily: section.fontFamily
      onClicked: section.toggleCalendar(modelData.id)
    }
  }
}
