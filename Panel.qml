import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The clock's calendar popup: a month grid with ISO week numbers and Google
// Calendar event/task dots, plus a selected-day agenda and tasks list. The
// panel reads ~/.local/state/parm.clock/state.json (written by sync/sync.py)
// and never touches gws or Google directly.
//
// Compact by default: hero + year/life rails + month grid + today's agenda.
// The expand toggle widens to two panes — month grid left, selected-day agenda
// and tasks right.
//
// BarWidget.qml owns the bar label (and the task badge) and hands this panel
// the button to anchor against.
Panel {
  id: root
  moduleName: "parm.clock"
  ipcTarget: "parm.clock"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against `slot.activeItem`, and switchPanelFrom looks the
  // slot up the same way.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // ---- Today. SystemClock keeps this honest across midnight so the
  //      highlight rolls over without the panel being reopened.
  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  // The month on screen. Stepping moves this and nothing else.
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()

  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  // ---- Synced state. Read from state.json; updated by the FileView watcher.
  property var state: Model.parseState("")
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/parm.clock/state.json"
  readonly property var eventIdx: Model.eventIndex(state.events)

  // The selected day drives the agenda. Defaults to today; clicking a grid
  // cell selects that day. Opening the panel resets it to today.
  property string selectedKey: todayKey
  readonly property var dayEvents: Model.eventsForDate(eventIdx, selectedKey)
  readonly property var dayTasks: Model.tasksForDate(state.tasks, selectedKey)

  // ---- Settings (persisted to shell.json via persistSettings).
  readonly property bool showTaskBadge: setting("showTaskBadge", true)
  readonly property string badgeMode: setting("badgeCount", "dueToday")
  readonly property bool expanded: setting("defaultView", "compact") === "expanded"
  property bool settingsVisible: false
  readonly property var hiddenCalendars: setting("hiddenCalendars", [])

  // Pinned to today, not to the month being browsed — stepping through the
  // calendar does not change how much of the year is gone.
  readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  // Memento mori (stock behavior).
  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  // Unset falls through to the locale's own first day (stock behavior).
  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
  readonly property var labelLocale: Qt.locale("en_US")
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)

  // Guarded so the widget renders before the bar is injected.
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  // ---- Agenda / badge helpers ------------------------------------------

  function isHidden(calId) {
    return root.hiddenCalendars.indexOf(calId) !== -1
  }

  function toggleCalendar(calId) {
    var arr = root.hiddenCalendars.slice()
    var i = arr.indexOf(calId)
    if (i === -1) arr.push(calId)
    else arr.splice(i, 1)
    persistSettings({ hiddenCalendars: arr })
  }

  function visibleEventsOn(key) {
    var list = Model.eventsForDate(root.eventIdx, key)
    return list.filter(function(ev) { return !root.isHidden(ev.calendarId) })
  }

  function dotColor(ev) {
    var c = Model.calendarColor(root.state.calendars, ev.calendarId)
    return c !== "" ? c : Style.selectedStateColor(root.contentForeground, Color.accent)
  }

  function selectDay(key) {
    root.selectedKey = key
  }

  // ---- Panel lifecycle (stock) -----------------------------------------

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.editingLife) root.cancelEditingLife()
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    root.today = new Date()
    root.goToToday()
  }

  function goToToday() {
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    root.selectedKey = todayKey
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }

  function moveYear(delta) {
    moveMonth(delta * 12)
  }

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setWeekStart(day) {
    var next = Model.normalizedWeekStart(day, root.weekStart)
    if (next === root.weekStart) return
    persistSettings({ weekStartDay: Model.weekStartSettingName(next) })
  }

  function toggleExpand() {
    persistSettings({ defaultView: root.expanded ? "compact" : "expanded" })
  }

  function toggleSettings() {
    root.settingsVisible = !root.settingsVisible
  }

  // ---- Memento mori (stock) --------------------------------------------

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll()
      bornField.forceActiveFocus()
    })
  }

  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) {
      root.cancelEditingLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.commitLife()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      other.selectAll()
      other.forceActiveFocus()
      event.accepted = true
    }
  }

  function clearLife() {
    if (root.birthYear <= 0) return
    persistSettings({ birthYear: 0 })
  }

  function commitLife() {
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy)
      persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  function toggleWeekStart() {
    setWeekStart(Model.toggledWeekStart(root.weekStart))
  }

  function weekdayLabel(weekday) {
    return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase()
  }

  // ---- Sync footer ------------------------------------------------------

  readonly property string syncLabel: Model.syncStatusLabel(root.state.syncStatus, new Date())
  readonly property bool syncStale: Model.isStale(root.state.syncStatus, new Date(), 30)

  function runSync() {
    if (root.bar) root.bar.run("python3 " + syncPath + " && omarchy-shell -q parm.clock refresh")
  }

  readonly property string syncPath: {
    var u = Qt.resolvedUrl("sync/sync.py").toString()
    return u.startsWith("file://") ? u.slice(7) : u
  }

  // ---- CRUD (Phase 7). Writes go through sync/mutate.py, which calls gws
  //      then re-syncs state.json. QML never talks to gws or Google directly.
  readonly property string mutatePath: {
    var u = Qt.resolvedUrl("sync/mutate.py").toString()
    return u.startsWith("file://") ? u.slice(7) : u
  }

  property string primaryCalendarId: root.state.calendars.length > 0 ? root.state.calendars[0].id : "primary"
  property string primaryTasklistId: root.state.tasklists.length > 0 ? root.state.tasklists[0].id : "@default"

  property string mutateOutput: ""

  property bool editingNewEvent: false
  property bool editingNewTask: false

  function toggleNewEvent() {
    root.editingNewEvent = !root.editingNewEvent
    if (root.editingNewEvent) root.editingNewTask = false
    if (root.editingNewEvent) Qt.callLater(function() { if (quickAddField) quickAddField.forceActiveFocus() })
  }

  function toggleNewTask() {
    root.editingNewTask = !root.editingNewTask
    if (root.editingNewTask) root.editingNewEvent = false
    if (root.editingNewTask) Qt.callLater(function() { if (taskTitleField) taskTitleField.forceActiveFocus() })
  }

  function commitQuickAdd() {
    root.newEventQuick(String(quickAddField.text).trim())
    root.editingNewEvent = false
    quickAddField.text = ""
  }

  function commitNewTask() {
    root.newTask(String(taskTitleField.text).trim(), String(taskDueField.text).trim())
    root.editingNewTask = false
    taskTitleField.text = ""
    taskDueField.text = ""
  }

  function runMutate(args) {
    if (mutateProc.running) return
    mutateOutput = ""
    var cmd = ["python3", root.mutatePath].concat(args)
    mutateProc.command = cmd
    mutateProc.running = true
  }

  function refreshAfterMutate() {
    if (root.bar) root.bar.run("omarchy-shell -q parm.clock refresh")
  }

  function newEventQuick(text) {
    if (!text) return
    runMutate(["event-quickadd", "--calendar", root.primaryCalendarId, "--text", text])
  }

  function newEventForm(title, date, start, end, location, meet) {
    var args = ["event-add", "--calendar", root.primaryCalendarId, "--title", title, "--date", date]
    if (start) args = args.concat(["--start", start])
    if (end) args = args.concat(["--end", end])
    if (location) args = args.concat(["--location", location])
    if (meet) args.push("--meet")
    runMutate(args)
  }

  function deleteEvent(ev) {
    if (!ev || !ev.id) return
    runMutate(["event-delete", "--calendar", ev.calendarId || root.primaryCalendarId, "--event", ev.id])
  }

  function newTask(title, due) {
    var args = ["task-add", "--list", root.primaryTasklistId, "--title", title]
    if (due) args = args.concat(["--due", due])
    runMutate(args)
  }

  function completeTask(task) {
    if (!task || !task.id) return
    runMutate(["task-complete", "--list", task.listId || root.primaryTasklistId, "--task", task.id])
  }

  function deleteTask(task) {
    if (!task || !task.id) return
    runMutate(["task-delete", "--list", task.listId || root.primaryTasklistId, "--task", task.id])
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      if (Model.keyForDate(clock.date) === String(root.todayKey)) return
      var followToday = root.viewingCurrentMonth
      root.today = clock.date
      if (followToday) root.goToToday()
    }
  }

  // Watches the synced state file so the panel refreshes after every sync.
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.state = Model.parseState(text())
    onLoadFailed: root.state = Model.parseState("")
    onFileChanged: reload()
  }

  // Runs sync/mutate.py for CRUD writes.
  Process {
    id: mutateProc
    command: []
    stdout: StdioCollector {
      id: mutateOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.mutateOutput = mutateOut.text
        console.warn("parm.clock mutate failed:", mutateOut.text)
      } else {
        root.mutateOutput = ""
      }
      // Always refresh: a successful write re-syncs; a failed one leaves
      // state.json untouched (preserve-last-good).
      root.refreshAfterMutate()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.expanded ? Style.space(880) : Style.space(560))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLife
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) root.moveMonth(dx)
        if (dy !== 0) root.moveYear(dy)
      }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "[") root.moveMonth(-1)
        else if (t === "]") root.moveMonth(1)
        else if (t === "{") root.moveYear(-1)
        else if (t === "}") root.moveYear(1)
        else if (t === "t" || t === "T") root.goToToday()
        else if (t === "w" || t === "W") root.toggleWeekStart()
        else if (t === "e" || t === "E") root.toggleExpand()
      }

      Flickable {
        id: calendarScroll
        anchors.fill: parent
        contentWidth: contentColumn.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: contentColumn
          width: Math.max(calendarScroll.width, mainRow.width)
          spacing: Style.space(8)

          // ---- Hero: today, centered.
          Item {
            width: parent.width
            height: heroRow.height

            Row {
              id: heroRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(22)

              Text {
                anchors.baseline: heroDate.baseline
                text: "󰃭"
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 48
              }

              Text {
                id: heroDate
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.today, "MMMM d")
                color: heroMouse.containsMouse
                  ? Style.hoverStateColor(root.contentForeground, Color.accent)
                  : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 52
                font.bold: true
              }
            }

            MouseArea {
              id: heroMouse
              x: heroRow.x
              y: heroRow.y
              width: heroRow.width
              height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()

              PanelToolTip {
                visible: heroMouse.containsMouse
                text: "Back to today"
                fontFamily: root.contentFontFamily
              }
            }
          }

          // ---- Year progress (stock).
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height

            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(yearLabel.implicitHeight, Style.space(10))

              TapHandler {
                enabled: !root.editingLife
                onDoubleTapped: root.startEditingLife()
              }

              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "BORN"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: bornField
                  width: Style.space(70)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "year"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly
                  Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  leftPadding: Style.space(6)
                  text: "LIVE TO"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                TextField {
                  id: expectancyField
                  width: Style.space(60)
                  anchors.verticalCenter: parent.verticalCenter
                  placeholderText: "90"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  inputMethodHints: Qt.ImhDigitsOnly
                  Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) }
                }
              }

              Text {
                id: yearLabel
                visible: !root.editingLife
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.today.getFullYear()
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: yearPercent
                visible: !root.editingLife
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.yearDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                id: yearTrack
                visible: !root.editingLife
                anchors.left: yearLabel.right
                anchors.right: yearPercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.yearDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)
                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }
            }
          }

          // ---- Memento mori (stock).
          Item {
            visible: root.birthYear > 0
            width: parent.width
            height: visible ? lifeBlock.height : 0

            Item {
              id: lifeBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: gridColumn.width
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))

              Text {
                id: lifeLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "LIFE"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: 1
              }

              Text {
                id: lifePercent
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.lifeDonePercent + "%"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Rectangle {
                anchors.left: lifeLabel.right
                anchors.right: lifePercent.left
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.round(parent.width * root.lifeDone)
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)
                  Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
              }

              TapHandler { onDoubleTapped: root.clearLife() }

              MouseArea {
                id: lifeMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                PanelToolTip {
                  visible: lifeMouse.containsMouse
                  text: "Memento Mori"
                  fontFamily: root.contentFontFamily
                }
              }
            }
          }

          // ---- Two-pane body: month grid (left) | agenda + tasks (right).
          Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.expanded ? Style.space(20) : 0

            // LEFT: month grid + stepping.
            Column {
              id: gridPane
              spacing: Style.space(3)

              Item {
                width: gridColumn.width
                height: gridColumn.y + gridColumn.height

                WheelHandler {
                  onWheel: function(event) {
                    if (event.angleDelta.y === 0) return
                    root.moveMonth(event.angleDelta.y > 0 ? -1 : 1)
                  }
                }

                Column {
                  id: gridColumn
                  y: Style.space(18)
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: Style.space(3)

                  Row {
                    id: headerRow
                    spacing: root.cellSpacing

                    Rectangle {
                      width: root.weekColumnWidth
                      height: Style.space(16)
                      radius: Style.cornerRadius
                      color: weekStartMouse.containsMouse
                        ? Style.hoverFillFor(root.contentForeground, Color.accent)
                        : "transparent"

                      Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: weekStartMouse.containsMouse
                          ? Style.hoverStateColor(root.contentForeground, Color.accent)
                          : Qt.darker(root.contentForeground, 1.9)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                        font.bold: true
                      }

                      MouseArea {
                        id: weekStartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleWeekStart()
                      }

                      PanelToolTip {
                        visible: weekStartMouse.containsMouse
                        text: "Start weeks on " + root.nextWeekStartLabel
                        fontFamily: root.contentFontFamily
                      }
                    }

                    Item { width: root.gutterWidth; height: Style.space(16) }

                    Repeater {
                      model: root.weekdays

                      Text {
                        required property var modelData
                        width: root.cellWidth
                        height: Style.space(16)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: root.weekdayLabel(modelData)
                        color: Qt.darker(root.contentForeground, 1.5)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 1
                        font.bold: true
                      }
                    }
                  }

                  Repeater {
                    model: root.weeks

                    Row {
                      required property var modelData
                      spacing: root.cellSpacing

                      Text {
                        width: root.weekColumnWidth
                        height: root.cellHeight
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.week
                        color: Qt.darker(root.contentForeground, 1.9)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Item { width: root.gutterWidth; height: root.cellHeight }

                      Repeater {
                        model: modelData.days

                        Rectangle {
                          required property var modelData
                          readonly property bool isSelected: modelData.key === root.selectedKey
                          readonly property var cellEvents: root.visibleEventsOn(modelData.key)

                          width: root.cellWidth
                          height: root.cellHeight
                          radius: Style.cornerRadius
                          color: isSelected && !modelData.today
                            ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                            : "transparent"
                          border.width: modelData.today ? Style.spacing.hairline : 0
                          border.color: Style.normalBorderFor(root.contentForeground, Color.accent)

                          Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.inMonth
                              ? (modelData.weekend ? Qt.darker(root.contentForeground, 1.45) : root.contentForeground)
                              : Qt.darker(root.contentForeground, 2.2)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.body
                            font.bold: modelData.today
                          }

                          // Event/task dots, tucked under the day number.
                          Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Style.space(4)
                            spacing: Style.space(3)

                            Repeater {
                              model: cellEvents.slice(0, 4)

                              Rectangle {
                                required property var modelData
                                width: Style.space(5)
                                height: Style.space(5)
                                radius: width / 2
                                color: root.dotColor(modelData)
                              }
                            }
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectDay(modelData.key)
                          }
                        }
                      }
                    }
                  }
                }

                // Hairline down the week-number gutter.
                Rectangle {
                  x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width) / 2)
                  y: gridColumn.y + headerRow.height + gridColumn.spacing
                  width: Style.spacing.hairline
                  height: gridColumn.height - headerRow.height - gridColumn.spacing
                  color: root.contentForeground
                  opacity: 0.1
                }
              }

              // Month stepping.
              Item {
                width: gridColumn.width
                height: monthNav.height

                Item {
                  id: monthNav
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: gridColumn.width
                  height: monthLabel.implicitHeight + Style.space(10)

                  Text {
                    id: monthLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(130)
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase()
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.letterSpacing: 1
                  }

                  PanelActionButton {
                    anchors.left: parent.left
                    anchors.leftMargin: -Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "󰅁"
                    tooltipText: "Previous month"
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    onClicked: root.moveMonth(-1)
                  }

                  PanelActionButton {
                    anchors.right: parent.right
                    anchors.rightMargin: -Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    iconText: "󰅂"
                    tooltipText: "Next month"
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    onClicked: root.moveMonth(1)
                  }
                }
              }
            }

            // RIGHT: selected-day agenda + tasks (expanded view only).
            Column {
              id: detailPane
              visible: root.expanded
              width: visible ? Style.space(300) : 0
              spacing: Style.space(8)

              PanelSeparator { width: parent.width; foreground: root.contentForeground }

              Text {
                width: parent.width
                text: selectedDateLabel()
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              AgendaList { width: parent.width; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

              PanelSeparator { width: parent.width; foreground: root.contentForeground }

              Text {
                width: parent.width
                text: "TASKS"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              TasksList { width: parent.width; foreground: root.contentForeground; fontFamily: root.contentFontFamily }
            }
          }

          // ---- Compact agenda strip (today's events), visible when not expanded.
          Column {
            id: compactStrip
            visible: !root.expanded
            width: parent.width
            spacing: Style.space(8)

            PanelSeparator { width: parent.width; foreground: root.contentForeground }

            Text {
              width: parent.width
              text: "TODAY"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            AgendaList { width: parent.width; foreground: root.contentForeground; fontFamily: root.contentFontFamily }
          }

          // ---- Header actions.
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            Button {
              iconText: "󰓦"
              tooltipText: "Sync now"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.runSync()
            }

            Button {
              iconText: "󰐕"
              tooltipText: "New event"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              selected: root.editingNewEvent
              onClicked: root.toggleNewEvent()
            }

            Button {
              iconText: "󰊱"
              tooltipText: "New task"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              selected: root.editingNewTask
              onClicked: root.toggleNewTask()
            }

            Button {
              iconText: "󰒓"
              tooltipText: "Settings"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              selected: root.settingsVisible
              onClicked: root.toggleSettings()
            }

            Button {
              iconText: root.expanded ? "󰝤" : "󰝧"
              tooltipText: root.expanded ? "Compact view" : "Expand view"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleExpand()
            }
          }

          // ---- New event (quick add).
          Column {
            visible: root.editingNewEvent
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { width: parent.width; foreground: root.contentForeground }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: quickAddField
                width: parent.width - quickAddButton.implicitWidth - Style.space(8)
                placeholderText: "New event — e.g. Lunch tomorrow 1pm"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commitQuickAdd()
                  else if (event.key === Qt.Key_Escape) root.editingNewEvent = false
                }
              }

              Button {
                id: quickAddButton
                text: "Add"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.commitQuickAdd()
              }
            }

            Text {
              visible: root.mutateOutput !== ""
              width: parent.width
              text: root.mutateOutput
              color: Color.urgent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          // ---- New task.
          Column {
            visible: root.editingNewTask
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { width: parent.width; foreground: root.contentForeground }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: taskTitleField
                width: parent.width - taskDueField.width - taskAddButton.implicitWidth - Style.space(16)
                placeholderText: "New task"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commitNewTask()
                  else if (event.key === Qt.Key_Escape) root.editingNewTask = false
                }
              }

              TextField {
                id: taskDueField
                width: Style.space(120)
                placeholderText: "due (YYYY-MM-DD)"
                foreground: root.contentForeground
                font.family: root.contentFontFamily
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.commitNewTask()
                  else if (event.key === Qt.Key_Escape) root.editingNewTask = false
                }
              }

              Button {
                id: taskAddButton
                text: "Add"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.commitNewTask()
              }
            }
          }

          // ---- Settings.
          Column {
            visible: root.settingsVisible
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { width: parent.width; foreground: root.contentForeground }

            Toggle {
              width: parent.width
              label: "Task badge"
              description: "Show the ☑ N task count on the clock"
              checked: root.showTaskBadge
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.persistSettings({ showTaskBadge: !root.showTaskBadge })
            }

            Dropdown {
              label: "Badge count"
              value: root.badgeMode
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              options: [
                { value: "dueToday", label: "Due today" },
                { value: "overdue", label: "Overdue + today" },
                { value: "all", label: "All incomplete" }
              ]
              onChanged: function(v) { root.persistSettings({ badgeCount: v }) }
            }

            Dropdown {
              label: "Default view"
              value: root.expanded ? "expanded" : "compact"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              options: [
                { value: "compact", label: "Compact" },
                { value: "expanded", label: "Expanded" }
              ]
              onChanged: function(v) { root.persistSettings({ defaultView: v }) }
            }

            // Calendar visibility.
            Repeater {
              model: root.state.calendars

              Toggle {
                required property var modelData
                width: parent.width
                label: modelData.name || modelData.id
                checked: !root.isHidden(modelData.id)
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.toggleCalendar(modelData.id)
              }
            }
          }

          // ---- Sync status footer.
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.syncStale ? "⚠ " + root.syncLabel : "✓ " + root.syncLabel
            color: root.syncStale
              ? Color.urgent
              : Qt.darker(root.contentForeground, 1.8)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // ---- Shared agenda + tasks renderers ----------------------------------

  component AgendaList: Column {
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family

    spacing: Style.space(4)

    Repeater {
      model: root.dayEvents

      Row {
        required property var modelData
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(6)
          height: Style.space(6)
          radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.dotColor(modelData)
        }

        Text {
          width: Style.space(66)
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.allDay ? "all day" : timeText(modelData)
          color: Qt.darker(foreground, 1.4)
          font.family: fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.title
          color: foreground
          font.family: fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Item { width: Math.max(0, parent.width - (66 + 6 + 8*4) - 24); height: 1 }

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰆴"
          tooltipText: "Delete event"
          hoverColor: Color.urgent
          foreground: foreground
          fontFamily: fontFamily
          onClicked: root.deleteEvent(modelData)
        }
      }
    }

    Text {
      visible: root.dayEvents.length === 0
      width: parent.width
      text: "No events."
      color: Qt.darker(foreground, 1.8)
      font.family: fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component TasksList: Column {
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family

    spacing: Style.space(4)

    Repeater {
      model: root.dayTasks

      Row {
        required property var modelData
        width: parent.width
        spacing: Style.space(8)

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: modelData.status === "completed" ? "󰄲" : "󰘳"
          tooltipText: modelData.status === "completed" ? "Mark incomplete" : "Complete task"
          foreground: foreground
          fontFamily: fontFamily
          onClicked: root.completeTask(modelData)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.title
          color: foreground
          font.family: fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Item { width: Math.max(0, parent.width - (24 + 8*4) - 24); height: 1 }

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰆴"
          tooltipText: "Delete task"
          hoverColor: Color.urgent
          foreground: foreground
          fontFamily: fontFamily
          onClicked: root.deleteTask(modelData)
        }
      }
    }

    Text {
      visible: root.dayTasks.length === 0
      width: parent.width
      text: "No tasks."
      color: Qt.darker(foreground, 1.8)
      font.family: fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  function selectedDateLabel() {
    var key = String(root.selectedKey)
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(key)
    if (!m) return ""
    return Qt.formatDate(new Date(parseInt(m[1], 10), parseInt(m[2], 10) - 1, parseInt(m[3], 10)), "dddd, MMMM d")
  }

  function timeText(ev) {
    var s = ev.start || ""
    var e = ev.end || ""
    var sm = /T(\d{2}:\d{2})/.exec(s)
    var em = /T(\d{2}:\d{2})/.exec(e)
    var st = sm ? sm[1] : ""
    var et = em ? em[1] : ""
    return et !== "" ? st + "–" + et : st
  }
}
