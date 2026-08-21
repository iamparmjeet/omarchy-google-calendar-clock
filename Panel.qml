import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Calendar popup — single-column, pill-driven. This file is the container:
// it owns state (synced state.json, view mode, selected day, settings
// persistence) and the gws plumbing, and delegates rendering to the Clock*
// components. Order: hero → year/life rails → view area (Month/Week/Upcoming/
// Tasks) → pills → events card → actions → forms → settings → footer.
Panel {
  id: root
  moduleName: "parm.clock"
  ipcTarget: "parm.clock"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property date today: new Date()
  readonly property string todayKey: Model.keyForDate(today)

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property bool viewingCurrentMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

  property var state: Model.parseState("")
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/parm.clock/state.json"
  readonly property var eventIdx: Model.eventIndex(state.events)

  property string selectedKey: todayKey

  readonly property bool showCompletedTasks: setting("showCompletedTasks", false)
  readonly property var filteredTasks: {
    if (root.showCompletedTasks) return state.tasks || []
    var out = []
    var list = state.tasks || []
    for (var i = 0; i < list.length; i++) if (list[i].status !== "completed") out.push(list[i])
    return out
  }

  readonly property bool showTaskBadge: setting("showTaskBadge", true)
  readonly property string badgeMode: setting("badgeCount", "dueToday")
  property bool settingsVisible: false
  readonly property var hiddenCalendars: setting("hiddenCalendars", [])
  readonly property string viewMode: {
    var v = String(setting("panelView", "month"))
    return v === "week" || v === "upcoming" || v === "tasks" ? v : "month"
  }

  readonly property real yearDone: Model.yearProgress(today.getFullYear(), today.getMonth(), today.getDate())
  readonly property int yearDonePercent: Model.yearProgressPercent(today.getFullYear(), today.getMonth(), today.getDate())

  readonly property int birthYear: Model.parseBirthYear(setting("birthYear", 0), today.getFullYear())
  readonly property int age: Model.ageFromBirthYear(birthYear, today.getFullYear())
  readonly property int lifeExpectancy: Model.parseLifeExpectancy(setting("lifeExpectancy", 0))
  readonly property real lifeDone: Model.lifeProgress(age, lifeExpectancy)
  readonly property int lifeDonePercent: Model.lifeProgressPercent(age, lifeExpectancy)
  property bool editingLife: false

  readonly property int weekStart: Model.normalizedWeekStart(setting("weekStartDay", null), Qt.locale().firstDayOfWeek)
  readonly property var labelLocale: Qt.locale("en_US")
  readonly property string nextWeekStartLabel: labelLocale.dayName(Model.toggledWeekStart(weekStart), Locale.LongFormat)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, todayKey)
  readonly property var weekKeys: Model.weekKeysFor(root.selectedKey || root.todayKey, root.weekStart)

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- navigation / selection

  function selectDay(key) { root.selectedKey = key }
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
  function moveYear(delta) { moveMonth(delta * 12) }
  function moveWeek(delta) {
    var cur = root.weekKeys[3] || root.selectedKey || root.todayKey
    var key = Model.stepWeek(cur, delta)
    root.selectedKey = key
    var d = Model.keyToDate(key)
    if (d) { root.viewYear = d.getFullYear(); root.viewMonth = d.getMonth() }
  }

  // ---- panel chrome

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }
  function close() {
    setCenterHoverRevealSuppressed(false)
    if (root.editingLife) root.cancelEditingLife()
    root.controller.hide()
  }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = value
  }
  function refresh() { root.today = new Date(); root.goToToday() }

  // ---- settings persistence

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
  function toggleWeekStart() { setWeekStart(Model.toggledWeekStart(root.weekStart)) }
  function setViewMode(mode) {
    if (mode === root.viewMode) return
    persistSettings({ panelView: mode })
  }
  function toggleSettings() { root.settingsVisible = !root.settingsVisible }
  function toggleShowCompleted() { persistSettings({ showCompletedTasks: !root.showCompletedTasks }) }

  // ---- life rails editing

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function() {
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll(); bornField.forceActiveFocus()
    })
  }
  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }
  function handleLifeKey(event, other) {
    if (event.key === Qt.Key_Escape) { root.cancelEditingLife(); event.accepted = true }
    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.commitLife(); event.accepted = true }
    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { other.selectAll(); other.forceActiveFocus(); event.accepted = true }
  }
  function clearLife() { if (root.birthYear <= 0) return; persistSettings({ birthYear: 0 }) }
  function commitLife() {
    var born = Model.parseBirthYear(bornField.text, today.getFullYear())
    var span = Model.parseLifeExpectancy(expectancyField.text)
    if (born !== root.birthYear || span !== root.lifeExpectancy) persistSettings({ birthYear: born, lifeExpectancy: span })
    cancelEditingLife()
  }

  // ---- sync + gws plumbing

  readonly property string syncLabel: Model.syncStatusLabel(root.state.syncStatus, new Date())
  readonly property bool syncStale: Model.isStale(root.state.syncStatus, new Date(), 30)
  function runSync() {
    if (root.bar) root.bar.run("python3 " + syncPath + " && omarchy-shell -q parm.clock refresh")
  }
  readonly property string syncPath: {
    var u = Qt.resolvedUrl("sync/sync.py").toString()
    return u.startsWith("file://") ? u.slice(7) : u
  }
  readonly property string mutatePath: {
    var u = Qt.resolvedUrl("sync/mutate.py").toString()
    return u.startsWith("file://") ? u.slice(7) : u
  }
  readonly property string primaryCalendarId: {
    var list = root.state.calendars
    var fallback = ""
    for (var i = 0; i < list.length; i++) { var c = list[i]; if (c.primary === true) return c.id; if (fallback === "" && c.id.indexOf("@") !== -1 && c.id.indexOf("#") === -1) fallback = c.id }
    if (fallback !== "") return fallback
    return list.length > 0 ? list[0].id : "primary"
  }
  property string primaryTasklistId: root.state.tasklists.length > 0 ? root.state.tasklists[0].id : "@default"
  property string mutateOutput: ""
  property bool editingNewEvent: false
  property bool editingNewTask: false

  function toggleNewEvent() {
    root.editingNewEvent = !root.editingNewEvent
    if (root.editingNewEvent) {
      root.editingNewTask = false
      Qt.callLater(function() { eventForm.open(root.selectedKey, Model.nextHalfHourHHMM(new Date())) })
    }
  }
  function toggleNewTask() {
    root.editingNewTask = !root.editingNewTask
    if (root.editingNewTask) {
      root.editingNewEvent = false
      Qt.callLater(function() { taskForm.open() })
    }
  }
  function runMutate(args) {
    if (mutateProc.running) { console.warn("parm.clock runMutate blocked, already running", JSON.stringify(args)); return }
    mutateOutput = ""
    var cmd = ["python3", root.mutatePath].concat(args)
    mutateProc.command = cmd
    mutateProc.running = true
  }
  function newEventQuick(text) { if (!text) return; runMutate(["event-quickadd", "--calendar", root.primaryCalendarId, "--text", text]) }
  function newEventForm(title, date, start, end, location, meet) {
    var args = ["event-add", "--calendar", root.primaryCalendarId, "--title", title, "--date", date]
    if (start) args = args.concat(["--start", start])
    if (end) args = args.concat(["--end", end])
    if (location) args = args.concat(["--location", location])
    if (meet) args.push("--meet")
    runMutate(args)
  }
  function newTask(title, due) { var args = ["task-add", "--list", root.primaryTasklistId, "--title", title]; if (due) args = args.concat(["--due", due]); runMutate(args) }
  function completeTask(task) { if (!task || !task.id) return; runMutate(["task-complete", "--list", task.listId || root.primaryTasklistId, "--task", task.id]) }
  function uncompleteTask(task) { if (!task || !task.id) return; runMutate(["task-complete", "--list", task.listId || root.primaryTasklistId, "--task", task.id, "--undo"]) }
  function deleteTask(task) { if (!task || !task.id) return; runMutate(["task-delete", "--list", task.listId || root.primaryTasklistId, "--task", task.id]) }

  function dotColor(ev) {
    var c = Model.calendarColor(root.state.calendars, ev.calendarId)
    return c !== "" ? c : Style.selectedStateColor(root.contentForeground, Color.accent)
  }
  function openEventLink(ev) {
    var url = ev.htmlLink || ev.meetUrl || ""
    if (url !== "" && root.bar) root.bar.run("xdg-open '" + url.replace(/'/g, "'\\''") + "'")
    else if (url !== "") Qt.openUrlExternally(url)
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
  Process {
    id: mutateProc
    command: []
    stdout: StdioCollector { id: mutateOut; waitForEnd: true }
    stderr: StdioCollector { id: mutateErr; waitForEnd: true; onStreamFinished: root.mutateOutput = String(text || "").trim() }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root.mutateOutput === "") root.mutateOutput = String(mutateErr.text || "").trim() || String(mutateOut.text || "").trim() || "mutate exited " + exitCode
        console.warn("parm.clock mutate failed:", root.mutateOutput)
      } else root.mutateOutput = ""
      if (stateFile) stateFile.reload()
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
    contentWidth: panel.fittedContentWidth(Style.space(620))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editingLife
      onMoveRequested: function(dx, dy) { if (dx !== 0) root.moveMonth(dx); if (dy !== 0) root.moveYear(dy) }
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
        else if (t === "m" || t === "M") root.setViewMode("month")
        else if (t === "e" || t === "E") root.setViewMode("week")
        else if (t === "u" || t === "U") root.setViewMode("upcoming")
        else if (t === "a" || t === "A") root.toggleNewEvent()
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
          width: Math.max(calendarScroll.width, Style.space(560))
          spacing: Style.space(8)

          // ---- Hero: today, centered. Click returns when browsing other months.
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
                color: heroMouse.containsMouse ? Style.hoverStateColor(root.contentForeground, Color.accent) : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 48
              }
              Text {
                id: heroDate
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(root.today, "MMMM d")
                color: heroMouse.containsMouse ? Style.hoverStateColor(root.contentForeground, Color.accent) : root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 52
                font.bold: true
              }
            }
            MouseArea {
              id: heroMouse
              x: heroRow.x; y: heroRow.y; width: heroRow.width; height: heroRow.height
              enabled: !root.viewingCurrentMonth
              hoverEnabled: enabled
              cursorShape: Qt.PointingHandCursor
              onClicked: root.goToToday()
              PanelToolTip { visible: heroMouse.containsMouse; text: "Back to today"; fontFamily: root.contentFontFamily }
            }
          }

          // ---- Year progress (double-click to edit life figures)
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height
            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.max(Style.space(480), contentColumn.width - Style.space(80))
              height: Math.max(yearLabel.implicitHeight, Style.space(10))
              TapHandler { enabled: !root.editingLife; onDoubleTapped: root.startEditingLife() }
              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "BORN"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
                TextField { id: bornField; width: Style.space(70); anchors.verticalCenter: parent.verticalCenter; placeholderText: "year"; foreground: root.contentForeground; font.family: root.contentFontFamily; inputMethodHints: Qt.ImhDigitsOnly; Keys.onPressed: function(event) { root.handleLifeKey(event, expectancyField) } }
                Text { anchors.verticalCenter: parent.verticalCenter; leftPadding: Style.space(6); text: "LIVE TO"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
                TextField { id: expectancyField; width: Style.space(60); anchors.verticalCenter: parent.verticalCenter; placeholderText: "90"; foreground: root.contentForeground; font.family: root.contentFontFamily; inputMethodHints: Qt.ImhDigitsOnly; Keys.onPressed: function(event) { root.handleLifeKey(event, bornField) } }
              }
              Text { id: yearLabel; visible: !root.editingLife; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.today.getFullYear(); color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
              Text { id: yearPercent; visible: !root.editingLife; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.yearDonePercent + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Rectangle {
                id: yearTrack; visible: !root.editingLife; anchors.left: yearLabel.right; anchors.right: yearPercent.left; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; height: Style.space(6); radius: Style.cornerRadius > 0 ? height / 2 : 0; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                Rectangle { width: Math.round(parent.width * root.yearDone); height: parent.height; radius: parent.radius; color: Style.selectedStateColor(root.contentForeground, Color.accent); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
              }
            }
          }

          // ---- Memento mori
          Item {
            visible: root.birthYear > 0
            width: parent.width
            height: visible ? lifeBlock.height : 0
            Item {
              id: lifeBlock
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.max(Style.space(480), contentColumn.width - Style.space(80))
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))
              Text { id: lifeLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "LIFE"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
              Text { id: lifePercent; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.lifeDonePercent + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Rectangle { anchors.left: lifeLabel.right; anchors.right: lifePercent.left; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; height: Style.space(6); radius: Style.cornerRadius > 0 ? height / 2 : 0; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                Rectangle { width: Math.round(parent.width * root.lifeDone); height: parent.height; radius: parent.radius; color: Style.selectedStateColor(root.contentForeground, Color.accent); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
              }
              TapHandler { onDoubleTapped: root.clearLife() }
              MouseArea { id: lifeMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; PanelToolTip { visible: lifeMouse.containsMouse; text: "Memento Mori"; fontFamily: root.contentFontFamily } }
            }
          }

          // ---- Calendar area: only the active view is instantiated; switching
          //      pills destroys the old view and creates the new one.
          Item {
            width: parent.width
            height: viewLoader.item ? Math.max(viewLoader.item.minHeight, viewLoader.item.implicitHeight) : 0
            Loader {
              id: viewLoader
              width: parent.width
              sourceComponent: root.viewMode === "month" ? monthComponent
                : root.viewMode === "week" ? weekComponent
                : root.viewMode === "upcoming" ? upcomingComponent
                : tasksComponent

              Component {
                id: monthComponent
                ClockMonthView {
                  width: parent.width
                  weeks: root.weeks
                  weekdays: root.weekdays
                  viewDate: root.viewDate
                  selectedKey: root.selectedKey
                  todayKey: root.todayKey
                  eventIndex: root.eventIdx
                  hiddenCalendars: root.hiddenCalendars
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  nextWeekStartLabel: root.nextWeekStartLabel
                  dotColor: root.dotColor
                  onSelectDay: root.selectDay(key)
                  onStepMonth: root.moveMonth(delta)
                  onToggleWeekStartRequested: root.toggleWeekStart()
                }
              }
              Component {
                id: weekComponent
                ClockWeekView {
                  width: parent.width
                  weekKeys: root.weekKeys
                  todayKey: root.todayKey
                  selectedKey: root.selectedKey
                  eventIndex: root.eventIdx
                  hiddenCalendars: root.hiddenCalendars
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  dotColor: root.dotColor
                  onSelectDay: root.selectDay(key)
                  onStepWeek: root.moveWeek(delta)
                  onBackToTodayRequested: root.goToToday()
                  onOpenEvent: root.openEventLink(ev)
                }
              }
              Component {
                id: upcomingComponent
                ClockUpcomingView {
                  width: parent.width
                  eventIndex: root.eventIdx
                  todayKey: root.todayKey
                  hiddenCalendars: root.hiddenCalendars
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  dotColor: root.dotColor
                  onOpenEvent: root.openEventLink(ev)
                }
              }
              Component {
                id: tasksComponent
                ClockTasksView {
                  width: parent.width
                  tasks: root.filteredTasks
                  showCompleted: root.showCompletedTasks
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                  onShowCompletedToggled: root.toggleShowCompleted()
                  onTaskToggled: (task && task.status === "completed") ? root.uncompleteTask(task) : root.completeTask(task)
                  onTaskDeleted: root.deleteTask(task)
                }
              }
            }
          }

          // ---- Pills: Month / Week / Upcoming / Tasks
          ClockViewPills {
            width: parent.width
            viewMode: root.viewMode
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onModeChosen: root.setViewMode(mode)
          }

          Item { width: parent.width; height: Style.space(10) } // extra gap pills → events

          // ---- Events card
          ClockEventsCard {
            width: parent.width
            viewMode: root.viewMode
            selectedKey: root.selectedKey
            todayKey: root.todayKey
            eventIndex: root.eventIdx
            hiddenCalendars: root.hiddenCalendars
            tasks: root.filteredTasks
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            dotColor: root.dotColor
            onOpenEvent: root.openEventLink(ev)
          }

          Item { width: parent.width; height: Style.space(40) } // breathing room events → actions

          // ---- Bottom action row: Sync / Add event / Add task / Settings
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)
            Button { iconText: "󰓦"; tooltipText: "Sync now"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.runSync() }
            Button { iconText: "󰐕"; tooltipText: "New event"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.editingNewEvent; onClicked: root.toggleNewEvent() }
            Button { iconText: "󰄳"; tooltipText: "New task [ ]"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.editingNewTask; onClicked: root.toggleNewTask() }
            Button { iconText: "󰒓"; tooltipText: "Settings"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.settingsVisible; onClicked: root.toggleSettings() }
          }

          // ---- New event form
          ClockEventForm {
            id: eventForm
            visible: root.editingNewEvent
            width: parent.width
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            errorText: root.mutateOutput
            onSubmitted: root.newEventForm(title, date, start, end, location, meet)
            onCancelled: root.editingNewEvent = false
          }

          // ---- New task form
          ClockTaskForm {
            id: taskForm
            visible: root.editingNewTask
            width: parent.width
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            errorText: root.mutateOutput
            onSubmitted: root.newTask(title, due)
            onCancelled: root.editingNewTask = false
          }

          // ---- Settings
          ClockSettingsSection {
            visible: root.settingsVisible
            width: parent.width
            showTaskBadge: root.showTaskBadge
            badgeMode: root.badgeMode
            showCompletedTasks: root.showCompletedTasks
            calendars: root.state.calendars
            hiddenCalendars: root.hiddenCalendars
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: root.persistSettings(values)
          }

          // ---- Sync status footer (message can carry gws/Google error text)
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.syncStale ? "⚠ " + root.syncLabel : "✓ " + root.syncLabel
            textFormat: Text.PlainText
            color: root.syncStale ? Color.urgent : Qt.darker(root.contentForeground, 1.8)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
