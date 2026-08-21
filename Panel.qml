import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Calendar popup — single-column, pill-driven.
// Order: hero → year/life rails → calendar area (Month/Week/Upcoming/Tasks)
//        → pills [Month/Week/Upcoming/Tasks] → divider → events card
//        → bottom actions [Sync/Add event/Add task/Settings] → forms → settings → footer
// Keeps yearProgress/lifeDone rails. Expand/two-pane removed (single 620 width).
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
  readonly property var dayEvents: Model.eventsForDate(eventIdx, selectedKey)
  readonly property var dayTasks: Model.tasksForDate(state.tasks, selectedKey)

  // Tasks toggle — [] open vs [x] closed, slider style
  readonly property bool showCompletedTasks: setting("showCompletedTasks", false)
  readonly property var filteredTasks: {
    if (root.showCompletedTasks) return state.tasks || []
    var out = []
    var list = state.tasks || []
    for (var i = 0; i < list.length; i++) if (list[i].status !== "completed") out.push(list[i])
    return out
  }
  readonly property var filteredDayTasks: {
    if (root.showCompletedTasks) {
      var all = state.tasks || []
      var res = []
      for (var j = 0; j < all.length; j++) if (Model.taskDueDate(all[j]) === root.selectedKey) res.push(all[j])
      return res
    }
    return root.dayTasks
  }

  readonly property bool showTaskBadge: setting("showTaskBadge", true)
  readonly property string badgeMode: setting("badgeCount", "dueToday")
  // kept for compat, always false now — single column
  readonly property bool expanded: false
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

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int cellWidth: Style.space(52)
  readonly property int cellHeight: Style.space(34)
  readonly property int cellSpacing: Style.space(2)
  readonly property int weekColumnWidth: Style.space(32)
  readonly property int gutterWidth: Style.space(14)

  // Week keys for Week view — delegates to Model.weekKeysFor for test parity
  readonly property var weekKeys: Model.weekKeysFor(root.selectedKey || root.todayKey, root.weekStart)

  function isHidden(calId) { return root.hiddenCalendars.indexOf(calId) !== -1 }
  function toggleCalendar(calId) {
    var arr = root.hiddenCalendars.slice()
    var i = arr.indexOf(calId)
    if (i === -1) arr.push(calId); else arr.splice(i,1)
    persistSettings({ hiddenCalendars: arr })
  }
  function visibleEventsOn(key) {
    var list = Model.eventsForDate(root.eventIdx, key)
    return list.filter(function(ev){ return !root.isHidden(ev.calendarId) })
  }
  function dotColor(ev) {
    var c = Model.calendarColor(root.state.calendars, ev.calendarId)
    return c !== "" ? c : Style.selectedStateColor(root.contentForeground, Color.accent)
  }
  function selectDay(key) { root.selectedKey = key }

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function(){ if (root.opened) setCenterHoverRevealSuppressed(true) })
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
  function moveYear(delta) { moveMonth(delta*12) }

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
  function setViewMode(mode) {
    if (mode === root.viewMode) return
    persistSettings({ panelView: mode })
  }
  function toggleSettings() { root.settingsVisible = !root.settingsVisible }
  function toggleShowCompleted() { persistSettings({ showCompletedTasks: !root.showCompletedTasks }) }

  function startEditingLife() {
    root.editingLife = true
    Qt.callLater(function(){
      bornField.text = root.birthYear > 0 ? String(root.birthYear) : ""
      expectancyField.text = String(root.lifeExpectancy)
      bornField.selectAll(); bornField.forceActiveFocus()
    })
  }
  function cancelEditingLife() {
    root.editingLife = false
    Qt.callLater(function(){ if (keyCatcher) keyCatcher.forceActiveFocus() })
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
  function toggleWeekStart() { setWeekStart(Model.toggledWeekStart(root.weekStart)) }
  function weekdayLabel(weekday) { return String(labelLocale.dayName(weekday, Locale.ShortFormat)).toUpperCase() }

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
    for (var i=0;i<list.length;i++){ var c=list[i]; if(c.primary===true) return c.id; if(fallback==="" && c.id.indexOf("@")!==-1 && c.id.indexOf("#")===-1) fallback=c.id }
    if (fallback!=="") return fallback
    return list.length>0 ? list[0].id : "primary"
  }
  property string primaryTasklistId: root.state.tasklists.length>0 ? root.state.tasklists[0].id : "@default"
  property string mutateOutput: ""
  property bool editingNewEvent: false
  property bool editingNewTask: false

  // Enhanced add-event fields
  property string eventTitleText: ""
  property string eventDateText: ""
  property string eventStartText: ""
  property string eventEndText: ""
  property string eventLocationText: ""
  property bool eventMeet: false

  function toggleNewEvent() {
    root.editingNewEvent = !root.editingNewEvent
    if (root.editingNewEvent) {
      root.editingNewTask = false
      root.eventDateText = root.selectedKey
      var now = new Date()
      var hh = String(now.getHours()).padStart(2,"0")
      var mm = String(Math.ceil(now.getMinutes()/30)*30 % 60).padStart(2,"0")
      var h2 = String(now.getHours()).padStart(2,"0")
      // default to next half hour
      if (root.eventStartText === "") root.eventStartText = hh + ":" + mm
      Qt.callLater(function(){ if (eventTitleField) eventTitleField.forceActiveFocus() })
    }
  }
  function toggleNewTask() {
    root.editingNewTask = !root.editingNewTask
    if (root.editingNewTask) {
      root.editingNewEvent = false
      Qt.callLater(function(){ if (taskTitleField) taskTitleField.forceActiveFocus() })
    }
  }
  function commitNewEventForm() {
    var title = String(eventTitleField.text).trim()
    if (!title) { console.warn("parm.clock: empty title, abort"); return }
    var date = String(eventDateField.text).trim() || root.selectedKey
    var start = String(eventStartField.text).trim()
    var end = String(eventEndField.text).trim()
    var loc = String(eventLocationField.text).trim()
    console.log("parm.clock commitNewEventForm", JSON.stringify({title:title, date:date, start:start, end:end, loc:loc, meet:root.eventMeet, cal:root.primaryCalendarId}))
    root.newEventForm(title, date, start, end, loc, root.eventMeet)
    root.editingNewEvent = false
    eventTitleField.text = ""; eventDateField.text=""; eventStartField.text=""; eventEndField.text=""; eventLocationField.text=""
    root.eventMeet = false
  }
  function commitNewTask() {
    var t = String(taskTitleField.text).trim()
    var d = String(taskDueField.text).trim()
    console.log("parm.clock commitNewTask", JSON.stringify({title:t, due:d, list:root.primaryTasklistId}))
    if (!t) { console.warn("parm.clock: empty task title"); return }
    root.newTask(t, d)
    root.editingNewTask = false
    taskTitleField.text = ""; taskDueField.text = ""
  }
  function runMutate(args) {
    if (mutateProc.running) { console.warn("parm.clock runMutate blocked, already running", JSON.stringify(args)); return }
    mutateOutput = ""
    var cmd = ["python3", root.mutatePath].concat(args)
    console.log("parm.clock runMutate", JSON.stringify(cmd))
    mutateProc.command = cmd
    mutateProc.running = true
  }
  function refreshAfterMutate() { if (root.bar) root.bar.run("omarchy-shell -q parm.clock refresh") }
  function newEventQuick(text) { if (!text) return; runMutate(["event-quickadd","--calendar",root.primaryCalendarId,"--text",text]) }
  function newEventForm(title, date, start, end, location, meet) {
    var args = ["event-add","--calendar",root.primaryCalendarId,"--title",title,"--date",date]
    if (start) args = args.concat(["--start",start])
    if (end) args = args.concat(["--end",end])
    if (location) args = args.concat(["--location",location])
    if (meet) args.push("--meet")
    runMutate(args)
  }
  function deleteEvent(ev) { if (!ev||!ev.id) return; runMutate(["event-delete","--calendar",ev.calendarId||root.primaryCalendarId,"--event",ev.id]) }
  function newTask(title, due) { var args=["task-add","--list",root.primaryTasklistId,"--title",title]; if(due) args=args.concat(["--due",due]); runMutate(args) }
  function completeTask(task) { if (!task||!task.id) return; runMutate(["task-complete","--list",task.listId||root.primaryTasklistId,"--task",task.id]) }
  function uncompleteTask(task){ if(!task||!task.id) return; runMutate(["task-complete","--list",task.listId||root.primaryTasklistId,"--task",task.id,"--undo"]) }
  function deleteTask(task){ if(!task||!task.id) return; runMutate(["task-delete","--list",task.listId||root.primaryTasklistId,"--task",task.id]) }

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
    onExited: function(exitCode){
      if (exitCode!==0){
        if (root.mutateOutput==="") root.mutateOutput = String(mutateErr.text||"").trim() || String(mutateOut.text||"").trim() || "mutate exited "+exitCode
        console.warn("parm.clock mutate failed:", root.mutateOutput)
      } else root.mutateOutput=""
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
      onMoveRequested: function(dx,dy){ if(dx!==0) root.moveMonth(dx); if(dy!==0) root.moveYear(dy) }
      onActivateRequested: root.goToToday()
      onCloseRequested: root.close()
      onTabRequested: function(direction){ root.switchPanel(direction) }
      onTextKey: function(t){
        if(t==="[") root.moveMonth(-1)
        else if(t==="]") root.moveMonth(1)
        else if(t==="{") root.moveYear(-1)
        else if(t==="}") root.moveYear(1)
        else if(t==="t"||t==="T") root.goToToday()
        else if(t==="w"||t==="W") root.toggleWeekStart()
        else if(t==="m"||t==="M") root.setViewMode("month")
        else if(t==="e"||t==="E") root.setViewMode("week")
        else if(t==="u"||t==="U") root.setViewMode("upcoming")
        else if(t==="a"||t==="A") root.toggleNewEvent()
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

          // ---- Hero: today, centered. (kept as default calendar heading)
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

          // ---- Year progress
          Item {
            width: parent.width
            height: yearBlock.y + yearBlock.height
            Item {
              id: yearBlock
              y: Style.space(6)
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.max(Style.space(480), gridColumn.width)
              height: Math.max(yearLabel.implicitHeight, Style.space(10))
              TapHandler { enabled: !root.editingLife; onDoubleTapped: root.startEditingLife() }
              Row {
                visible: root.editingLife
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)
                Text { anchors.verticalCenter: parent.verticalCenter; text: "BORN"; color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
                TextField { id: bornField; width: Style.space(70); anchors.verticalCenter: parent.verticalCenter; placeholderText: "year"; foreground: root.contentForeground; font.family: root.contentFontFamily; inputMethodHints: Qt.ImhDigitsOnly; Keys.onPressed: function(event){ root.handleLifeKey(event, expectancyField) } }
                Text { anchors.verticalCenter: parent.verticalCenter; leftPadding: Style.space(6); text: "LIVE TO"; color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
                TextField { id: expectancyField; width: Style.space(60); anchors.verticalCenter: parent.verticalCenter; placeholderText: "90"; foreground: root.contentForeground; font.family: root.contentFontFamily; inputMethodHints: Qt.ImhDigitsOnly; Keys.onPressed: function(event){ root.handleLifeKey(event, bornField) } }
              }
              Text { id: yearLabel; visible: !root.editingLife; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: root.today.getFullYear(); color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
              Text { id: yearPercent; visible: !root.editingLife; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.yearDonePercent + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Rectangle {
                id: yearTrack; visible: !root.editingLife; anchors.left: yearLabel.right; anchors.right: yearPercent.left; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; height: Style.space(6); radius: Style.cornerRadius>0 ? height/2 : 0; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
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
              width: Math.max(Style.space(480), gridColumn.width)
              height: Math.max(lifeLabel.implicitHeight, Style.space(10))
              Text { id: lifeLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "LIFE"; color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.letterSpacing: 1 }
              Text { id: lifePercent; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: root.lifeDonePercent + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Rectangle { anchors.left: lifeLabel.right; anchors.right: lifePercent.left; anchors.leftMargin: Style.space(12); anchors.rightMargin: Style.space(12); anchors.verticalCenter: parent.verticalCenter; height: Style.space(6); radius: Style.cornerRadius>0 ? height/2 : 0; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                Rectangle { width: Math.round(parent.width * root.lifeDone); height: parent.height; radius: parent.radius; color: Style.selectedStateColor(root.contentForeground, Color.accent); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } } }
              }
              TapHandler { onDoubleTapped: root.clearLife() }
              MouseArea { id: lifeMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton; PanelToolTip { visible: lifeMouse.containsMouse; text: "Memento Mori"; fontFamily: root.contentFontFamily } }
            }
          }

          // ---- Calendar area (switches by viewMode) — single column
          Item {
            width: parent.width
            height: calArea.height
            Column {
              id: calArea
              width: parent.width
              spacing: Style.space(6)

              // Month grid
              Item {
                visible: root.viewMode === "month"
                width: parent.width
                height: visible ? monthGridWrap.height : 0
                Item {
                  id: monthGridWrap
                  width: gridColumn.width
                  height: gridColumn.y + gridColumn.height
                  anchors.horizontalCenter: parent.horizontalCenter
                  WheelHandler { onWheel: function(event){ if(event.angleDelta.y===0) return; root.moveMonth(event.angleDelta.y>0 ? -1:1) } }
                  Column {
                    id: gridColumn
                    y: Style.space(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(3)
                    Row {
                      id: headerRow
                      spacing: root.cellSpacing
                      Rectangle {
                        width: root.weekColumnWidth; height: Style.space(16); radius: Style.cornerRadius
                        color: weekStartMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
                        Text { anchors.centerIn: parent; text: "W"; color: weekStartMouse.containsMouse ? Style.hoverStateColor(root.contentForeground, Color.accent) : Qt.darker(root.contentForeground,1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                        MouseArea { id: weekStartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleWeekStart() }
                        PanelToolTip { visible: weekStartMouse.containsMouse; text: "Start weeks on " + root.nextWeekStartLabel; fontFamily: root.contentFontFamily }
                      }
                      Item { width: root.gutterWidth; height: Style.space(16) }
                      Repeater {
                        model: root.weekdays
                        Text { required property var modelData; width: root.cellWidth; height: Style.space(16); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: root.weekdayLabel(modelData); color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                      }
                    }
                    Repeater {
                      model: root.weeks
                      Row {
                        required property var modelData
                        spacing: root.cellSpacing
                        Text { width: root.weekColumnWidth; height: root.cellHeight; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: modelData.week; color: Qt.darker(root.contentForeground,1.9); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                        Item { width: root.gutterWidth; height: root.cellHeight }
                        Repeater {
                          model: modelData.days
                          Rectangle {
                            required property var modelData
                            readonly property bool isSelected: modelData.key === root.selectedKey
                            readonly property var cellEvents: root.visibleEventsOn(modelData.key)
                            width: root.cellWidth; height: root.cellHeight; radius: Style.cornerRadius
                            color: isSelected && !modelData.today ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08) : "transparent"
                            border.width: modelData.today ? Style.spacing.hairline : 0
                            border.color: Style.normalBorderFor(root.contentForeground, Color.accent)
                            Text { anchors.centerIn: parent; text: modelData.day; color: modelData.inMonth ? (modelData.weekend ? Qt.darker(root.contentForeground,1.45) : root.contentForeground) : Qt.darker(root.contentForeground,2.2); font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: modelData.today }
                            Row {
                              anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(4); spacing: Style.space(3)
                              Repeater { model: cellEvents.slice(0,4); Rectangle { required property var modelData; width: Style.space(5); height: Style.space(5); radius: width/2; color: root.dotColor(modelData) } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectDay(modelData.key) }
                          }
                        }
                      }
                    }
                  }
                  Rectangle { x: gridColumn.x + root.weekColumnWidth + root.cellSpacing + Math.round((root.gutterWidth - width)/2); y: gridColumn.y + headerRow.height + gridColumn.spacing; width: Style.spacing.hairline; height: gridColumn.height - headerRow.height - gridColumn.spacing; color: root.contentForeground; opacity: 0.1 }
                }
                // Month stepping under grid
                Item {
                  width: parent.width; height: monthNav.height + Style.space(6)
                  Item {
                    id: monthNav; anchors.horizontalCenter: parent.horizontalCenter; y: Style.space(6); width: gridColumn.width; height: monthLabel.implicitHeight + Style.space(8)
                    Text { id: monthLabel; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; width: Style.space(150); horizontalAlignment: Text.AlignHCenter; text: Qt.formatDate(root.viewDate, "MMMM yyyy").toUpperCase(); color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.letterSpacing: 1 }
                    PanelActionButton { anchors.left: parent.left; anchors.leftMargin: -Style.space(8); anchors.verticalCenter: parent.verticalCenter; iconText: "󰅁"; tooltipText: "Previous month"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.moveMonth(-1) }
                    PanelActionButton { anchors.right: parent.right; anchors.rightMargin: -Style.space(8); anchors.verticalCenter: parent.verticalCenter; iconText: "󰅂"; tooltipText: "Next month"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.moveMonth(1) }
                  }
                }
              }

              // Week view — redesigned: pill header + balanced 7 cards with subtle weekend tint + chips
              Item {
                visible: root.viewMode === "week"
                width: parent.width
                height: Math.max(Style.space(300), weekCol.implicitHeight)
                Column {
                  id: weekCol
                  width: parent.width
                  spacing: Style.space(10)
                  // Header: prev | pill (Wk + range) | next  — own aesthetic, not github clone
                  Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(8)
                    PanelActionButton { iconText: "󰅁"; tooltipText: "Previous week"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: moveWeek(-1) }
                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: weekHeading.implicitWidth + Style.space(22)
                      height: Style.space(22)
                      radius: height / 2
                      color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                      border.width: Style.spacing.hairline
                      border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
                      Text {
                        id: weekHeading
                        anchors.centerIn: parent
                        text: weekHeadingText()
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.letterSpacing: 0.8
                        font.bold: true
                      }
                    }
                    PanelActionButton { iconText: "󰅂"; tooltipText: "Next week"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: moveWeek(1) }
                    PanelActionButton {
                      visible: !isCurrentWeek()
                      anchors.verticalCenter: parent.verticalCenter
                      iconText: "󰥔"
                      tooltipText: "Back to this week"
                      foreground: root.contentForeground
                      fontFamily: root.contentFontFamily
                      onClicked: goToToday()
                    }
                  }
                  // Vertical stack — each day is a full-width row, easier scanning than 7 cramped cards
                  Column {
                    width: parent.width
                    spacing: Style.space(6)
                    Repeater {
                      model: root.weekKeys
                      Rectangle {
                        required property var modelData
                        readonly property string key: modelData
                        readonly property var evs: root.visibleEventsOn(key)
                        readonly property bool isToday: key === root.todayKey
                        readonly property bool isSelected: key === root.selectedKey
                        readonly property bool isWeekend: { var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key)); if(!m) return false; var d=new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10)); var wd=d.getDay(); return wd===0||wd===6 }
                        width: parent.width
                        height: dayRow.implicitHeight + Style.space(14)
                        radius: Style.cornerRadius + 2
                        color: isSelected ? Style.selectedFillFor(root.contentForeground, Color.accent)
                          : isToday ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.07)
                          : isWeekend ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025)
                          : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.035)
                        border.width: isSelected || isToday ? Style.spacing.hairline : 0
                        border.color: isSelected ? Style.selectedBorderFor(root.contentForeground, Color.accent) : Style.normalBorderFor(root.contentForeground, Color.accent)
                        // Left accent for today/selected
                        Rectangle { visible: isToday || isSelected; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: Style.space(3); height: parent.height - Style.space(10); radius: 1; color: isSelected ? Style.selectedStateColor(root.contentForeground, Color.accent) : Color.accent; opacity: isSelected ? 1 : 0.9 }
                        Row {
                          id: dayRow
                          width: parent.width - Style.space(14)
                          x: Style.space(7)
                          y: Style.space(7)
                          spacing: Style.space(10)
                          // Date rail — compact, left-aligned
                          Column {
                            width: Style.space(74)
                            spacing: Style.space(1)
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: weekDayShort(key); color: isToday ? Style.selectedStateColor(root.contentForeground, Color.accent) : isWeekend ? Qt.darker(root.contentForeground,1.55) : Qt.darker(root.contentForeground,1.3); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: isToday || isSelected }
                            Text { text: weekDayNum(key) + " · " + weekMonthShort(key); color: isSelected ? Style.selectedStateColor(root.contentForeground, Color.accent) : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: isToday ? 19 : 16; font.bold: isToday || isSelected }
                            Text { text: isToday ? "Today" : (relativeLabel(key) || ""); color: isToday ? Color.accent : Qt.darker(root.contentForeground,1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption - 1; font.italic: true; visible: text !== "" }
                          }
                          Rectangle { width: Style.spacing.hairline; height: dayRow.height; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10); anchors.verticalCenter: parent.verticalCenter }
                          // Events — vertical stack, chips grow to fill
                          Column {
                            width: parent.width - Style.space(74) - Style.space(10) - Style.spacing.hairline - Style.space(6)
                            spacing: Style.space(4)
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                              model: evs.slice(0,3)
                              Rectangle {
                                required property var modelData
                                readonly property color chipColor: root.dotColor(modelData)
                                width: parent.width; height: Style.space(22); radius: Style.cornerRadius
                                color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.13)
                                border.width: Style.spacing.hairline; border.color: Qt.rgba(chipColor.r, chipColor.g, chipColor.b, 0.22)
                                Row {
                                  anchors.fill: parent; anchors.leftMargin: Style.space(6); anchors.rightMargin: Style.space(6); spacing: Style.space(6)
                                  Rectangle { width: Style.space(2); height: Style.space(12); radius: 1; anchors.verticalCenter: parent.verticalCenter; color: chipColor }
                                  Text {
                                    width: Style.space(44); anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.allDay ? "all day" : timeStart(modelData)
                                    color: Qt.darker(root.contentForeground,1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight
                                  }
                                  Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, parent.width - 2 - Style.space(6) - 44 - Style.space(6) - Style.space(12))
                                    text: modelData.title; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight
                                  }
                                  Text { anchors.verticalCenter: parent.verticalCenter; text: "↗"; color: Qt.darker(root.contentForeground,1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: openEventLink(modelData) }
                              }
                            }
                            Rectangle {
                              visible: evs.length > 3
                              width: parent.width; height: Style.space(18); radius: Style.cornerRadius
                              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                              Text { anchors.centerIn: parent; text: "+" + (evs.length-3) + " more on " + weekDayShort(key); color: Qt.darker(root.contentForeground,1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.italic: true }
                            }
                            Text {
                              visible: evs.length === 0
                              width: parent.width
                              text: "— Free —"; color: Qt.darker(root.contentForeground,2.0); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.italic: true; topPadding: Style.space(2)
                            }
                          }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectDay(key); z: -1 }
                      }
                    }
                  }
                }
              }

              // Upcoming — next 14 days grouped — min-height keeps panel stable
              Item {
                visible: root.viewMode === "upcoming"
                width: parent.width
                height: Math.max(Style.space(280), upcomingCol.implicitHeight)
                Column {
                  id: upcomingCol
                  width: parent.width
                  spacing: Style.space(6)
                  Text { width: parent.width; text: "UPCOMING — NEXT 14 DAYS"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                  Repeater {
                    model: {
                      var out=[]; var base=new Date(today.getFullYear(), today.getMonth(), today.getDate())
                      for(var d=0;d<14;d++){ var dt=new Date(base.getFullYear(), base.getMonth(), base.getDate()+d); var k=Model.dateKey(dt.getFullYear(), dt.getMonth(), dt.getDate()); var evs=Model.eventsForDate(eventIdx,k).filter(function(ev){return !isHidden(ev.calendarId)}); if(evs.length>0) out.push({key:k, events:evs}) }
                      return out
                    }
                    Column {
                      required property var modelData
                      width: parent.width; spacing: Style.space(4)
                      Text { width: parent.width; text: upcomingLabel(modelData.key); color: Qt.darker(root.contentForeground,1.2); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                      Repeater {
                        model: modelData.events
                        Row {
                          required property var modelData
                          width: parent.width; spacing: Style.space(8)
                          Rectangle { width: Style.space(3); height: Style.space(14); radius:1; anchors.verticalCenter: parent.verticalCenter; color: dotColor(modelData) }
                          Text { width: Style.space(70); anchors.verticalCenter: parent.verticalCenter; text: modelData.allDay ? "all day" : timeText(modelData); color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                          Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.title; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; width: Math.max(0, parent.width - 70 - 3 - 8*3 - 28) }
                          PanelActionButton { anchors.verticalCenter: parent.verticalCenter; iconText: "󰅂"; tooltipText: "Open in Calendar"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: openEventLink(modelData) }
                        }
                      }
                    }
                  }
                  Text {
                    visible: { var c=0; var base=new Date(today.getFullYear(), today.getMonth(), today.getDate()); for(var d=0;d<14;d++){ var dt=new Date(base.getFullYear(), base.getMonth(), base.getDate()+d); var k=Model.dateKey(dt.getFullYear(), dt.getMonth(), dt.getDate()); if(Model.eventsForDate(eventIdx,k).filter(function(ev){return !isHidden(ev.calendarId)}).length>0) c++ } return c===0 }
                    width: parent.width; text: "No events in next 14 days."; color: Qt.darker(root.contentForeground,1.8); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true
                  }
                }
              }

              // Tasks — min-height anchored to month grid (~280) so 0/1 task doesn't collapse the panel
              Item {
                visible: root.viewMode === "tasks"
                width: parent.width
                height: Math.max(Style.space(280), tasksCol.implicitHeight)
                Column {
                  id: tasksCol
                  width: parent.width
                  spacing: Style.space(6)
                // Creative compact header — legend + tiny pill switch (ToggleSwitch, not the 54px settings Toggle)
                Item {
                  width: parent.width
                  height: Style.space(22)
                  Row {
                    id: tasksHeaderLeft
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(10)
                    Text { text: "TASKS"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                    Rectangle { width: Style.spacing.hairline; height: Style.space(10); color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "[ ] open  ·  [×] closed"; color: Qt.darker(root.contentForeground,1.7); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 0.4 }
                  }
                  Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(7)
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "closed"
                      color: root.showCompletedTasks ? root.contentForeground : Qt.darker(root.contentForeground,1.6)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.letterSpacing: 0.6
                    }
                    ToggleSwitch {
                      id: showClosedToggle
                      anchors.verticalCenter: parent.verticalCenter
                      checked: root.showCompletedTasks
                      foreground: root.contentForeground
                      trackHeight: Style.space(16)
                      trackWidth: Math.round(Style.space(16) * 1.85)
                      onToggled: root.toggleShowCompleted()
                    }
                  }
                }
                Repeater {
                  model: root.viewMode === "tasks" ? (root.showCompletedTasks ? filteredTasks : filteredTasks.filter(function(t){return true})) : []
                  // filteredTasks already respects toggle; for tasks view show all tasks not just due today
                  Rectangle {
                    required property var modelData
                    width: parent.width; height: Style.space(32); radius: Style.cornerRadius
                    color: modelData.status === "completed" ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04) : "transparent"
                    border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)
                    Row {
                      anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                      PanelActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: modelData.status === "completed" ? "󰄳" : "󰄰"
                        tooltipText: modelData.status === "completed" ? "Mark open [ ]" : "Complete [x]"
                        foreground: modelData.status === "completed" ? Qt.darker(root.contentForeground,1.4) : Style.selectedStateColor(root.contentForeground, Color.accent)
                        fontFamily: root.contentFontFamily
                        onClicked: modelData.status === "completed" ? root.uncompleteTask(modelData) : root.completeTask(modelData)
                      }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.status === "completed" ? "[x]" : "[ ]"; color: modelData.status==="completed" ? Qt.darker(root.contentForeground,1.6) : Style.selectedStateColor(root.contentForeground, Color.accent); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                      Text { anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - 120); text: modelData.title; color: modelData.status==="completed" ? Qt.darker(root.contentForeground,1.6) : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.strikeout: modelData.status==="completed" }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: Model.taskDueDate(modelData) || "no due"; color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                      Item { width: Math.max(0, parent.width - (24+8*3+24+60) - (modelData.title.length*6)); height: 1 }
                      PanelActionButton { anchors.verticalCenter: parent.verticalCenter; iconText: "󰆴"; tooltipText: "Delete task"; hoverColor: Color.urgent; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.deleteTask(modelData) }
                    }
                  }
                }
                Text { visible: filteredTasks.length===0; width: parent.width; text: "No tasks."; color: Qt.darker(root.contentForeground,1.8); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true }
                }
              }

            }
          }

          // ---- Pills: Month / Week / Upcoming / Tasks (directly under calendar)
          Item {
            width: parent.width
            height: switcherRow.height + Style.space(10)
            Rectangle {
              anchors.centerIn: parent
              width: switcherRow.width + Style.space(14)
              height: switcherRow.height + Style.space(8)
              radius: Style.cornerRadius + 2
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
            }
            Row {
              id: switcherRow
              anchors.centerIn: parent
              spacing: Style.space(2)
              Repeater {
                model: [
                  { mode: "month", label: "MONTH" },
                  { mode: "week", label: "WEEK" },
                  { mode: "upcoming", label: "UPCOMING" },
                  { mode: "tasks", label: "TASKS" }
                ]
                Rectangle {
                  id: viewTab
                  required property var modelData
                  readonly property bool active: root.viewMode === modelData.mode
                  readonly property bool hot: tabMouse.containsMouse
                  width: tabLabel.implicitWidth + Style.space(20)
                  height: tabLabel.implicitHeight + Style.space(10)
                  radius: Style.cornerRadius
                  color: active ? Style.selectedFillFor(root.contentForeground, Color.accent) : hot ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
                  border.width: active ? Style.spacing.hairline : 0
                  border.color: Style.selectedBorderFor(root.contentForeground, Color.accent)
                  Behavior on color { ColorAnimation { duration: 100 } }
                  Text {
                    id: tabLabel
                    anchors.centerIn: parent
                    text: viewTab.modelData.label
                    color: viewTab.active ? Style.selectedStateColor(root.contentForeground, Color.accent) : Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1
                    font.bold: viewTab.active
                  }
                  MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setViewMode(viewTab.modelData.mode) }
                }
              }
            }
          }

          // ---- Divider + Events card (below pills, before bottom actions)
          Column {
            width: parent.width
            spacing: Style.space(8)
            PanelSeparator { width: parent.width; foreground: root.contentForeground }
            Rectangle {
              width: parent.width
              radius: Style.cornerRadius + 4
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
              border.width: Style.spacing.hairline
              border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
              height: eventsInner.implicitHeight + Style.space(16)
              clip: true
              Column {
                id: eventsInner
                width: parent.width - Style.space(16)
                x: Style.space(8)
                y: Style.space(8)
                spacing: Style.space(8)
                // Month/Week selected-day events
                Column {
                  visible: root.viewMode === "month" || root.viewMode === "week"
                  width: parent.width
                  spacing: Style.space(6)
                  Text { width: parent.width; text: selectedDateLabel().toUpperCase(); color: Qt.darker(root.contentForeground,1.3); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                  Repeater {
                    model: root.viewMode === "month" || root.viewMode === "week" ? filteredDayEvents() : []
                    Row {
                      required property var modelData
                      width: parent.width; spacing: Style.space(8)
                      Rectangle { width: Style.space(3); height: Style.space(16); radius: 1; anchors.verticalCenter: parent.verticalCenter; color: dotColor(modelData) }
                      Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; text: modelData.allDay ? "all day" : timeText(modelData); color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                      Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, parent.width - 72 - 3 - 8*4 - 28)
                        spacing: 1
                        Text { width: parent.width; text: modelData.title; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.bold: true }
                        Text { visible: (modelData.location||"") !== ""; width: parent.width; text: modelData.location; color: Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                      }
                      PanelActionButton { anchors.verticalCenter: parent.verticalCenter; iconText: "󰅂"; tooltipText: "Open in Calendar"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: openEventLink(modelData) }
                    }
                  }
                  Text {
                    visible: filteredDayEvents().length === 0
                    width: parent.width; text: "No events on this day."; color: Qt.darker(root.contentForeground,1.8); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true
                  }
                }
                // Upcoming handled inside calendar area; duplicate compact list here for card when upcoming
                Column {
                  visible: root.viewMode === "upcoming"
                  width: parent.width
                  spacing: Style.space(4)
                  Text { width: parent.width; text: "NEXT 14 DAYS — SUMMARY"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                  Repeater {
                    model: upcomingSummary()
                    Row {
                      required property var modelData
                      width: parent.width; spacing: Style.space(8)
                      Rectangle { width: Style.space(3); height: Style.space(14); radius:1; anchors.verticalCenter: parent.verticalCenter; color: dotColor(modelData) }
                      Text { width: Style.space(72); anchors.verticalCenter: parent.verticalCenter; text: modelData.allDay ? "all day" : timeText(modelData); color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.title + " · " + shortDate(modelData.dateKey); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; width: Math.max(0, parent.width - 72 - 3 - 8*3 - 28) }
                      PanelActionButton { anchors.verticalCenter: parent.verticalCenter; iconText: "󰅂"; tooltipText: "Open in Calendar"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: openEventLink(modelData) }
                    }
                  }
                }
                // Tasks card view
                Column {
                  visible: root.viewMode === "tasks"
                  width: parent.width
                  spacing: Style.space(4)
                  Text { width: parent.width; text: "TASKS — " + filteredTasks.length + " TOTAL"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
                  Repeater {
                    model: filteredTasks.slice(0, 10)
                    Row {
                      required property var modelData
                      width: parent.width; spacing: Style.space(8)
                      Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.status==="completed" ? "[x]" : "[ ]"; color: modelData.status==="completed" ? Qt.darker(root.contentForeground,1.6) : Style.selectedStateColor(root.contentForeground, Color.accent); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                      Text { anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - 32 - 70); text: modelData.title; color: modelData.status==="completed" ? Qt.darker(root.contentForeground,1.6) : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight; font.strikeout: modelData.status==="completed" }
                      Text { anchors.verticalCenter: parent.verticalCenter; text: Model.taskDueDate(modelData) || "no due"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    }
                  }
                  Text { visible: filteredTasks.length > 10; width: parent.width; text: "+" + (filteredTasks.length-10) + " more — switch to TASKS tab for full list"; color: Qt.darker(root.contentForeground,1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.italic: true }
                }
              }
            }
          }

          // ---- Bottom action row: Sync / Add event / Add task / Settings
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)
            Button { iconText: "󰓦"; tooltipText: "Sync now"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.runSync() }
            Button { iconText: "󰐕"; tooltipText: "New event"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.editingNewEvent; onClicked: root.toggleNewEvent() }
            Button { iconText: "󰄳"; tooltipText: "New task [ ]"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.editingNewTask; onClicked: root.toggleNewTask() }
            Button { iconText: "󰒓"; tooltipText: "Settings"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; selected: root.settingsVisible; onClicked: root.toggleSettings() }
          }

          // ---- New event form — card design, compact Meet switch (no 240px Toggle overflow)
          Column {
            visible: root.editingNewEvent
            width: parent.width
            spacing: Style.space(8)
            PanelSeparator { width: parent.width; foreground: root.contentForeground }
            Text { width: parent.width; text: "NEW EVENT"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
            Rectangle {
              width: parent.width
              radius: Style.cornerRadius + 4
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
              height: eventCardCol.implicitHeight + Style.space(16)
              Column {
                id: eventCardCol
                width: parent.width - Style.space(16)
                x: Style.space(8); y: Style.space(8)
                spacing: Style.space(8)
                TextField {
                  id: eventTitleField
                  width: parent.width
                  placeholderText: "Title — e.g. Lunch with team"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  Keys.onPressed: function(event){ if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter) commitNewEventForm(); else if(event.key===Qt.Key_Escape) root.editingNewEvent=false }
                }
                Item {
                  width: parent.width
                  height: Math.max(eventDateField.implicitHeight, meetRow.implicitHeight)
                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    TextField { id: eventDateField; width: Style.space(118); placeholderText: "YYYY-MM-DD"; text: root.eventDateText; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.eventDateText = text }
                    TextField { id: eventStartField; width: Style.space(74); placeholderText: "HH:MM"; text: root.eventStartText; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.eventStartText = text }
                    TextField { id: eventEndField; width: Style.space(74); placeholderText: "HH:MM"; text: root.eventEndText; foreground: root.contentForeground; font.family: root.contentFontFamily; onTextChanged: root.eventEndText = text }
                  }
                  Row {
                    id: meetRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Meet"; color: root.eventMeet ? root.contentForeground : Qt.darker(root.contentForeground,1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: root.eventMeet }
                    ToggleSwitch { checked: root.eventMeet; foreground: root.contentForeground; trackHeight: Style.space(16); trackWidth: Math.round(Style.space(16)*1.85); onToggled: root.eventMeet = !root.eventMeet }
                  }
                }
                TextField {
                  id: eventLocationField
                  width: parent.width
                  placeholderText: "Location (optional)"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  onTextChanged: root.eventLocationText = text
                }
                Row {
                  width: parent.width; spacing: Style.space(8)
                  Button { text: "Add"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: commitNewEventForm() }
                  Button { text: "Cancel"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.editingNewEvent = false }
                  Text { visible: root.mutateOutput !== ""; anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - Style.space(140)); text: root.mutateOutput; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight }
                }
              }
            }
          }

          // ---- New task form — card, no overflow (flex title + fixed due + actions)
          Column {
            visible: root.editingNewTask
            width: parent.width
            spacing: Style.space(8)
            PanelSeparator { width: parent.width; foreground: root.contentForeground }
            Text { width: parent.width; text: "NEW TASK  [ ]"; color: Qt.darker(root.contentForeground,1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.letterSpacing: 1; font.bold: true }
            Rectangle {
              width: parent.width
              radius: Style.cornerRadius + 4
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
              border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.10)
              height: taskCardCol.implicitHeight + Style.space(16)
              Column {
                id: taskCardCol
                width: parent.width - Style.space(16)
                x: Style.space(8); y: Style.space(8)
                spacing: Style.space(8)
                TextField {
                  id: taskTitleField
                  width: parent.width
                  placeholderText: "What needs doing?  [ ]"
                  foreground: root.contentForeground
                  font.family: root.contentFontFamily
                  Keys.onPressed: function(event){ if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter) root.commitNewTask(); else if(event.key===Qt.Key_Escape) root.editingNewTask=false }
                }
                Item {
                  width: parent.width
                  height: Math.max(taskDueField.implicitHeight, taskAddButton.implicitHeight)
                  TextField {
                    id: taskDueField
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(128)
                    placeholderText: "due  YYYY-MM-DD"
                    foreground: root.contentForeground
                    font.family: root.contentFontFamily
                    Keys.onPressed: function(event){ if(event.key===Qt.Key_Return||event.key===Qt.Key_Enter) root.commitNewTask(); else if(event.key===Qt.Key_Escape) root.editingNewTask=false }
                  }
                  Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Button { text: "Cancel"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.editingNewTask = false }
                    Button { id: taskAddButton; text: "Add"; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.commitNewTask() }
                  }
                }
                Text { visible: root.mutateOutput !== ""; width: parent.width; text: root.mutateOutput; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; elide: Text.ElideRight }
              }
            }
          }

          // ---- Settings
          Column {
            visible: root.settingsVisible
            width: parent.width
            spacing: Style.space(6)
            PanelSeparator { width: parent.width; foreground: root.contentForeground }
            Toggle { width: parent.width; label: "Task badge  [ ] N"; description: "Show 󰄳 N count on the clock"; checked: root.showTaskBadge; foreground: root.contentForeground; fontFamily: root.contentFontFamily; onClicked: root.persistSettings({ showTaskBadge: !root.showTaskBadge }) }
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
              onChanged: function(v){ root.persistSettings({ badgeCount: v }) }
            }
            Toggle {
              width: parent.width
              label: "Show completed tasks [x]"
              description: "Toggle slider for closed tasks"
              checked: root.showCompletedTasks
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleShowCompleted()
            }
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

          // ---- Sync status footer
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.syncStale ? "⚠ " + root.syncLabel : "✓ " + root.syncLabel
            color: root.syncStale ? Color.urgent : Qt.darker(root.contentForeground,1.8)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  function selectedDateLabel(){
    var key=String(root.selectedKey)
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(key)
    if(!m) return ""
    return Qt.formatDate(new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10)), "dddd, MMMM d")
  }
  function timeText(ev){
    var s=ev.start||""; var e=ev.end||""
    var sm=/T(\d{2}:\d{2})/.exec(s)
    var em=/T(\d{2}:\d{2})/.exec(e)
    var st=sm?sm[1]:""
    var et=em?em[1]:""
    return et!=="" ? st+"–"+et : st
  }
  function weekDayShort(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    if(!m) return String(key)
    var d=new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10))
    return Qt.formatDate(d, "ddd").toUpperCase()
  }
  function weekMonthShort(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    if(!m) return ""
    var d=new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10))
    return Qt.formatDate(d, "MMM")
  }
  function relativeLabel(key){ return Model.relativeDayLabel(key, root.todayKey) }
  function weekDayLabel(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    if(!m) return key
    var d=new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10))
    return Qt.formatDate(d, "ddd").toUpperCase() + " " + m[3]
  }
  function weekDayNum(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    return m ? m[3] : ""
  }
  function timeStart(ev){
    var s=ev.start||""; var m=/T(\d{2}:\d{2})/.exec(s); return m?m[1]:""
  }
  function isCurrentWeek(){ return root.weekKeys.indexOf(root.todayKey) !== -1 }
  function weekHeadingText(){
    if(root.weekKeys.length===0) return ""
    var a=root.weekKeys[0], b=root.weekKeys[6]
    var ma=/^(\d{4})-(\d{2})-(\d{2})$/.exec(a), mb=/^(\d{4})-(\d{2})-(\d{2})$/.exec(b)
    if(!ma||!mb) return a+" – "+b
    var da=new Date(parseInt(ma[1],10), parseInt(ma[2],10)-1, parseInt(ma[3],10))
    var db=new Date(parseInt(mb[1],10), parseInt(mb[2],10)-1, parseInt(mb[3],10))
    var wk = Model.isoWeek(da.getFullYear(), da.getMonth(), da.getDate())
    return "W" + wk + " · " + Qt.formatDate(da,"MMM d") + " – " + Qt.formatDate(db,"MMM d, yyyy")
  }
  function upcomingLabel(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    return m ? Qt.formatDate(new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10)), "dddd, MMMM d") : key
  }
  function shortDate(key){
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(key))
    return m ? Qt.formatDate(new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10)), "MMM d") : key
  }
  function filteredDayEvents(){
    var list = root.visibleEventsOn(root.selectedKey)
    return list
  }
  function upcomingSummary(){
    var out=[]; var base=new Date(today.getFullYear(), today.getMonth(), today.getDate())
    for(var d=0;d<14;d++){ var dt=new Date(base.getFullYear(), base.getMonth(), base.getDate()+d); var k=Model.dateKey(dt.getFullYear(), dt.getMonth(), dt.getDate()); var evs=Model.eventsForDate(eventIdx,k).filter(function(ev){return !isHidden(ev.calendarId)}); for(var j=0;j<evs.length;j++) out.push(evs[j]) }
    return out.slice(0,8)
  }
  function openEventLink(ev){
    var url = ev.htmlLink || ev.meetUrl || ""
    if(url!=="" && root.bar) root.bar.run("xdg-open '" + url.replace(/'/g, "'\\''") + "'")
    else if(url!=="") Qt.openUrlExternally(url)
  }
  function moveWeek(delta){
    var cur = root.weekKeys[3] || root.selectedKey
    var m=/^(\d{4})-(\d{2})-(\d{2})$/.exec(String(cur))
    if(!m) return
    var d=new Date(parseInt(m[1],10), parseInt(m[2],10)-1, parseInt(m[3],10)+delta*7)
    var key=Model.dateKey(d.getFullYear(), d.getMonth(), d.getDate())
    root.selectedKey = key
    // keep month view in sync if user switches back
    root.viewYear = d.getFullYear(); root.viewMonth = d.getMonth()
  }
}
