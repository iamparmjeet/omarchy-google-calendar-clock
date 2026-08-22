import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Bounded reader for the synced state document.
//
// FileView is used only as a change signal: preload stays false and text()/
// data() are never called, so FileView — whose read path has no size limit —
// never materializes state.json in the long-lived shell. The actual read
// happens in a short-lived child process that sizes the file first and cats
// it only when under Model.MAX_STATE_CHARS (kept in sync with the writer's
// MAX_STATE_BYTES in sync/sync.py); the StdioCollector therefore retains at
// most a ceiling-sized document. parseState's own MAX_STATE_CHARS refusal
// remains as defense in depth.
QtObject {
  id: root

  property string path: ""
  property var state: Model.parseState("")

  // Bumped by every refresh; a reader that exits for an older generation
  // discards its output and reads again, so rapid successive writes (atomic
  // rename + directory watch can both fire) always settle on the newest file.
  property int generation: 0
  property int startedGeneration: 0

  function reload() {
    root.refresh()
  }

  function refresh() {
    root.generation += 1
    if (reader.running) return // re-read from onExited when this one settles
    reader.command = [
      "sh", "-c",
      'n=$(wc -c < "$1" 2>/dev/null) || { printf "%s\\n" __PARMCLOCK_STATE_UNREADABLE__; exit 0; }; ' +
      'if [ "$n" -gt "$2" ]; then printf "%s\\n" __PARMCLOCK_STATE_TOO_LARGE__; ' +
      'else cat -- "$1"; fi',
      "parm.clock", root.path, String(Model.MAX_STATE_CHARS)
    ]
    root.startedGeneration = root.generation
    reader.running = true
  }

  property FileView watcher: FileView {
    path: root.path
    watchChanges: true
    preload: false
    printErrors: false
    onPathChanged: root.refresh()
    onFileChanged: root.refresh()
  }

  property Process reader: Process {
    id: reader
    command: []
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: {
      if (root.startedGeneration !== root.generation) {
        root.refresh()
        return
      }
      var out = String(readOut.text || "").trim()
      if (out === "__PARMCLOCK_STATE_TOO_LARGE__" || out === "__PARMCLOCK_STATE_UNREADABLE__") {
        console.warn("parm.clock: refusing state.json (over size ceiling or unreadable):", root.path)
        root.state = Model.parseState("")
        return
      }
      root.state = Model.parseState(out)
    }
  }

  Component.onCompleted: root.refresh()
}
