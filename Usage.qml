import QtQuick
import Quickshell
import Quickshell.Io

// Discovers agent usage records and keeps them fresh. Display-only:
// Plugin bin/usage-update (plus optional cursor collector) owns the JSON.
Item {
  id: root
  visible: false

  property var settings: ({})
  property int refreshIntervalSec: Math.max(30, Number(setting("refreshIntervalSec", 300)) || 300)

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state")
    + "/omarchy/agents/usage"
  readonly property string pluginBin: home + "/.config/omarchy/plugins/wszaq.token-gauge/bin"
  readonly property string updateBin: pluginBin + "/usage-update"
  readonly property string cursorCollector: home
    + "/.config/omarchy/plugins/wszaq.cursor-agent/bin/collect-cursor"

  property var agentIds: []
  property var agents: []
  property int dataRevision: 0
  property string pendingUpdateKind: ""
  // Codex (and others) sometimes rewrite the usage file with empty limits when
  // the app-server RPC blips. Hold the last good limits so the dial does not
  // snap 93% → 0% → 93% on every refresh.
  property var lastGoodLimits: ({})
  property var lastGoodTier: ({})
  // Snapshots read by providers — never mutate these inside a binding.
  property var holdSnapshot: ({})
  property var tierSnapshot: ({})
  readonly property int limitsHoldMs: 30 * 60 * 1000

  property var providers: {
    var rev = dataRevision
    var held = holdSnapshot
    var tiers = tierSnapshot
    var result = []
    for (var i = 0; i < agents.length; i++) {
      var record = agents[i] ? agents[i].record : null
      if (!record || !record.id) continue
      var id = String(record.id)
      if (!providerEnabled(id)) continue
      var display = displayProvider(record, held, tiers)
      if (providerHasData(display)) result.push(display)
    }
    result.sort(function (a, b) {
      return String(a.providerName).localeCompare(String(b.providerName))
    })
    return result
  }

  Process {
    id: listProcess
    running: false
    command: ["find", root.usageDir, "-maxdepth", "1", "-name", "*.json", "-printf", "%f\n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyAgentListing(text)
    }
  }

  Instantiator {
    id: agentInstantiator
    model: root.agentIds
    delegate: Agent {
      required property var modelData
      agentId: modelData
      path: root.usageDir + "/" + modelData + ".json"
      onRecordChanged: root.recordsChanged()
    }
    onObjectAdded: (index, object) => root.rebuildAgents()
    onObjectRemoved: (index, object) => root.rebuildAgents()
  }

  Process {
    id: updateProcess
    running: false
    onExited: {
      root.rescanAgents()
      root.maybeRunCursor()
      if (root.pendingUpdateKind !== "") {
        var kind = root.pendingUpdateKind
        root.pendingUpdateKind = ""
        root.runUpdate(kind)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("token-gauge", text.trim())
    }
  }

  Process {
    id: cursorProcess
    running: false
    command: [root.cursorCollector]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("token-gauge", "cursor", text.trim())
    }
    onExited: root.rescanAgents()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshAll(false)
  }

  // Stock omarchy.agents also writes the shared usage JSON with the flaky
  // system Codex collector. When it blanks limits[], re-run our collector.
  Timer {
    id: healTimer
    interval: 8000
    running: true
    repeat: true
    onTriggered: root.healBlankLimits()
  }

  Process {
    id: healProcess
    running: false
    onExited: root.rescanAgents()
  }

  Component.onCompleted: {
    rescanAgents()
  }

  function setting(name, fallback) {
    if (!settings || settings[name] === undefined || settings[name] === null) return fallback
    return settings[name]
  }

  function providerEnabled(id) {
    if (!settings || !settings.providers || !settings.providers[id]) return true
    return settings.providers[id].enabled !== false
  }

  function numberValue(v) {
    var n = Number(v)
    return isFinite(n) ? n : 0
  }

  function providerHasData(p) {
    var funded = p.balance && numberValue(p.balance.funded) > 0
    var hasLimits = p.limits && p.limits.length > 0
    var hasToday = numberValue(p.todayTotalTokens) > 0
    // Spec: show when ready, or when there is a limit / today burn / funded balance.
    if (p.ready === true) return true
    if (!p.ready && !hasLimits && !hasToday && !funded) return false
    return hasLimits || hasToday || funded
  }

  function balanceValue(raw) {
    if (!raw || typeof raw !== "object") return null
    var remaining = Number(raw.remaining)
    var funded = Number(raw.funded)
    if (!isFinite(remaining) || remaining < 0) return null
    return {
      remaining: remaining,
      funded: isFinite(funded) && funded > 0 ? funded : 0,
      spent: Math.max(0, Number(raw.spent) || 0),
      currency: String(raw.currency || "USD"),
      estimated: raw.estimated === true
    }
  }

  // Collectors store daily token totals in recentDays[].messageCount (legacy name).
  function cloneRecentDays(list) {
    var out = []
    if (!Array.isArray(list)) return out
    for (var i = 0; i < list.length; i++) {
      var day = list[i]
      if (!day || typeof day !== "object") continue
      var date = String(day.date || "")
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue
      var tokens = Number(day.messageCount)
      if (!isFinite(tokens) || tokens < 0) continue
      out.push({ date: date, messageCount: tokens })
    }
    return out
  }

  function cloneLimits(list) {
    var out = []
    if (!Array.isArray(list)) return out
    for (var i = 0; i < list.length; i++) {
      var lim = list[i]
      if (!lim || typeof lim !== "object") continue
      out.push({
        label: String(lim.label || ""),
        title: lim.title !== undefined ? String(lim.title) : undefined,
        percent: Number(lim.percent),
        resetsAt: String(lim.resetsAt || "")
      })
    }
    return out
  }

  function rememberLimits(id, limits, tierLabel) {
    if (!id || !limits || limits.length === 0) return
    var next = Object.assign({}, root.lastGoodLimits)
    next[id] = { limits: cloneLimits(limits), at: Date.now() }
    root.lastGoodLimits = next
    if (tierLabel) {
      var tiers = Object.assign({}, root.lastGoodTier)
      tiers[id] = String(tierLabel)
      root.lastGoodTier = tiers
    }
  }

  function heldFromSnapshot(snapshot, id) {
    var held = snapshot ? snapshot[id] : null
    if (!held || !held.limits || held.limits.length === 0) return null
    if (Date.now() - Number(held.at || 0) > root.limitsHoldMs) return null
    return held.limits
  }

  function heldLimits(id) {
    return heldFromSnapshot(root.lastGoodLimits, id)
  }

  // Pure w.r.t. root mutable state: snapshots are passed in from the binding.
  function displayProvider(record, heldMap, tierMap) {
    var id = String(record.id)
    var limits = Array.isArray(record.limits) ? record.limits : []
    var tierLabel = String(record.tierLabel || "")
    var limitsHeld = false
    var heldSrc = heldMap || root.holdSnapshot
    var tierSrc = tierMap || root.tierSnapshot

    if (limits.length === 0) {
      var held = heldFromSnapshot(heldSrc, id)
      if (held && held.length > 0) {
        limits = held
        limitsHeld = true
        if (!tierLabel && tierSrc && tierSrc[id]) tierLabel = String(tierSrc[id])
      }
    }

    var status = String(record.usageStatusText || "")
    // Don't surface "limits unavailable" while we still show held limits.
    if (limitsHeld && status.toLowerCase().indexOf("limit") >= 0) status = ""

    return {
      providerId: id,
      providerName: String(record.name || record.id),
      tierLabel: tierLabel,
      ready: record.ready !== false,
      usageStatusText: status,
      authHelpText: String(record.authHelpText || ""),
      todayTotalTokens: numberValue(record.todayTotalTokens),
      todayPrompts: numberValue(record.todayPrompts),
      todaySessions: numberValue(record.todaySessions),
      totalPrompts: numberValue(record.totalPrompts),
      totalSessions: numberValue(record.totalSessions),
      activeDays: numberValue(record.activeDays),
      hasPromptStats: record.hasPromptStats !== false,
      recentDays: cloneRecentDays(record.recentDays),
      limits: limits,
      limitsHeld: limitsHeld,
      balance: balanceValue(record.balance),
      updatedAt: String(record.updatedAt || "")
    }
  }

  function catchUpHeldLimits() {
    var next = null
    var nextTiers = null
    for (var i = 0; i < agents.length; i++) {
      var record = agents[i] ? agents[i].record : null
      if (!record || !record.id) continue
      var id = String(record.id)
      var limits = Array.isArray(record.limits) ? record.limits : []
      if (limits.length === 0) continue
      if (!next) next = Object.assign({}, root.lastGoodLimits)
      next[id] = { limits: cloneLimits(limits), at: Date.now() }
      var tierLabel = String(record.tierLabel || "")
      if (tierLabel) {
        if (!nextTiers) nextTiers = Object.assign({}, root.lastGoodTier)
        nextTiers[id] = tierLabel
      }
    }
    if (next) root.lastGoodLimits = next
    if (nextTiers) root.lastGoodTier = nextTiers
  }

  function publishHoldSnapshots() {
    root.holdSnapshot = root.lastGoodLimits
    root.tierSnapshot = root.lastGoodTier
  }

  function rescanAgents() {
    if (!listProcess.running) listProcess.running = true
  }

  function applyAgentListing(output) {
    var ids = []
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var name = lines[i].trim()
      if (name.slice(-5) === ".json") ids.push(name.slice(0, -5))
    }
    ids.sort()
    if (JSON.stringify(ids) !== JSON.stringify(agentIds)) agentIds = ids
  }

  function rebuildAgents() {
    var result = []
    for (var i = 0; i < agentInstantiator.count; i++) {
      var agent = agentInstantiator.objectAt(i)
      if (agent) result.push(agent)
    }
    agents = result
    recordsChanged()
  }

  function recordsChanged() {
    catchUpHeldLimits()
    publishHoldSnapshots()
    dataRevision++
  }

  function updateCommand(kind) {
    var command = [root.updateBin]
    if (kind === "force") command.push("--force")
    if (kind === "limits") command.push("--limits-only")
    var providers = settings && settings.providers ? settings.providers : {}
    for (var id in providers) {
      if (providers[id] && providers[id].enabled === false) command.push("--except", id)
    }
    return command
  }

  function runUpdate(kind) {
    if (updateProcess.running) {
      if (kind === "force" || root.pendingUpdateKind === "") root.pendingUpdateKind = kind
      return
    }
    updateProcess.command = updateCommand(kind)
    updateProcess.running = true
  }

  function maybeRunCursor() {
    if (!providerEnabled("cursor")) return
    if (cursorProcess.running) return
    cursorProcess.running = true
  }

  function refreshAll(force) {
    runUpdate(force === true ? "force" : "normal")
  }

  function healBlankLimits() {
    if (healProcess.running || updateProcess.running) return
    var blank = []
    for (var i = 0; i < agents.length; i++) {
      var record = agents[i] ? agents[i].record : null
      if (!record || !record.id) continue
      var id = String(record.id)
      if (!providerEnabled(id)) continue
      var limits = Array.isArray(record.limits) ? record.limits : []
      if (limits.length > 0) continue
      // Only heal agents we have a last-good for, or known flaky codex.
      if (id === "codex" || heldLimits(id)) blank.push(id)
    }
    if (blank.length === 0) return
    var command = [root.updateBin, "--limits-only"]
    for (var j = 0; j < blank.length; j++) command.push(blank[j])
    healProcess.command = command
    healProcess.running = true
  }

  function formatTokenCount(n) {
    if (n === undefined || n === null) return "0"
    if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(Math.round(n))
  }
}
