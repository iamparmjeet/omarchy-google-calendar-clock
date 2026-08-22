import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Bounded reader for the synced state document.
//
// FileView is used only as a change signal: preload stays false and text()/
// data() are never called, so FileView — whose read path has no size limit —
// never materializes state.json in the long-lived shell. The actual read
// happens in a short-lived child process whose read is bounded in a single
// open: head -c stops after MAX_STATE_CHARS + 1 bytes (kept in sync with the
// writer's MAX_STATE_BYTES in sync/sync.py), so no file-replacement race
// between a size check and a read can make the child emit more; the
// StdioCollector therefore never retains more than a ceiling-plus-one read
// plus, if the read itself errors partway, a trailing sentinel line, and
// anything over the ceiling is refused on exit (measured on the raw emitted
// bytes, before any trimming). parseState's own MAX_STATE_CHARS refusal
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
      'head -c "$(( $2 + 1 ))" -- "$1" 2>/dev/null || ' +
      'printf "%s\\n" __PARMCLOCK_STATE_UNREADABLE__',
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
      var raw = String(readOut.text || "")
      var out = raw.trim()
      if (raw.length > Model.MAX_STATE_CHARS || out === "__PARMCLOCK_STATE_UNREADABLE__") {
        console.warn("parm.clock: refusing state.json (over size ceiling or unreadable):", root.path)
        root.state = Model.parseState("")
        return
      }
      root.state = Model.parseState(out)
    }
  }

  Component.onCompleted: root.refresh()
}
