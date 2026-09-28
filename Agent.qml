import QtQuick
import Quickshell.Io

// One agent's usage record from omarchy-agent-usage-update (or any writer
// that drops a contract JSON into the usage directory).
Item {
  id: root
  visible: false

  property string agentId: ""
  property string path: ""
  property var record: null

  FileView {
    path: root.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.record = null
  }

  function parse(content) {
    try {
      var parsed = JSON.parse(String(content || ""))
      root.record = parsed && typeof parsed === "object" ? parsed : null
    } catch (e) {
      console.warn("token-gauge", "Ignoring bad usage record", root.path, e)
      root.record = null
    }
  }
}
