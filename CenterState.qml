import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Attention.js" as Attention
import "NotificationLogic.js" as Logic

Item {
  id: root
  required property var service
  property bool opened: false
  property string screenName: ""
  property var preferences: Attention.defaults({})
  property bool preferencesLoaded: false
  property bool preferencesFromDisk: false
  property var history: []
  property var live: []
  property var hiddenKeys: []
  property double lastSeen: 0
  property double seenAtOpen: 0
  property int revision: 0
  property double now: Date.now()
  property bool settingsVisible: false
  property var customSnoozeEntries: []
  readonly property bool reducedMotion: preferences.behavior.reducedMotion
  readonly property var snoozedRows: live.filter(function(e) { return e.wakeAt > 0 })
  readonly property var rows: {
    var rev = revision
    var seen = {}, out = [], all = liveRows().concat(history)
    var sleeping = snoozedRows.map(function(e) { return Attention.key(e) })
    all.sort(function(a,b) { return Attention.receivedAt(b) - Attention.receivedAt(a) })
    all.forEach(function(r) {
      var k = Attention.key(r)
      if (!seen[k] && hiddenKeys.indexOf(k) < 0 && sleeping.indexOf(k) < 0 && !r.transient) { seen[k] = true; out.push(r) }
    })
    return out
  }
  readonly property int unreadCount: rows.filter(function(r) {
    return Attention.receivedAt(r) > lastSeen && r.app !== "omarchy-action"
  }).length

  function captureLive() {
    var out = []
    for (var i = 0; i < service.popupModel.count; i++) {
      var row = service.popupModel.get(i)
      out.push(Logic.popupEntry(row, 1))
    }
    live = out
  }
  function liveRows() { return live }
  function channelMode(row) {
    var rule = preferences.channels[Attention.channel(row)]
    return rule && ["allow", "quiet", "block"].indexOf(rule.mode) >= 0 ? rule.mode : "allow"
  }
  function savePreferences() {
    if (preferencesLoaded) prefsFile.setText(JSON.stringify(preferences, null, 2) + "\n")
  }
  function behavior(name, value) {
    var p = JSON.parse(JSON.stringify(preferences)); p.behavior[name] = value
    preferences = Attention.defaults(p); savePreferences()
  }
  function setChannel(channel, mode) {
    var p = JSON.parse(JSON.stringify(preferences)); p.channels[channel] = { mode: mode }
    preferences = p; savePreferences()
  }
  function setDnd(minutes) {
    var p = JSON.parse(JSON.stringify(preferences))
    p.doNotDisturb = { enabled: minutes !== 0, until: minutes > 0 ? Date.now() + minutes * 60000 : 0 }
    preferences = p
    service.setDoNotDisturb(minutes !== 0)
    savePreferences()
  }
  function syncDnd(value) {
    if (!preferencesLoaded || preferences.doNotDisturb.enabled === value) return
    var p = JSON.parse(JSON.stringify(preferences))
    p.doNotDisturb = { enabled: value, until: 0 }; preferences = p; savePreferences()
  }
  function open() {
    screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    seenAtOpen = lastSeen
    opened = true
    markSeen(); reloadTimer.restart()
  }
  function close() { opened = false; settingsVisible = false; customSnoozeEntries = [] }
  function toggle() { if (opened) close(); else open() }
  function markSeen() { lastSeen = Date.now(); saveState() }
  function saveState() { readState.setText(JSON.stringify({ lastSeen: lastSeen }) + "\n") }
  function reload() { reloadTimer.restart() }
  function changed() {
    Qt.callLater(function() { root.captureLive(); root.revision++ })
    reload()
  }
  function findLive(entry) {
    for (var i = 0; i < service.popupModel.count; i++) {
      if (Attention.key(service.popupModel.get(i)) === Attention.key(entry)) return i
    }
    return -1
  }
  function actionsFor(entry) {
    var rev = revision
    var index = findLive(entry)
    if (index < 0 || service.isRestoredRow(entry)) return []
    var ref = service.liveRefs[entry.originalId], out = []
    try {
      if (ref && ref.actions) for (var i = 0; i < ref.actions.length; i++) {
        var a = ref.actions[i]
        if (a.identifier !== "default") out.push({ identifier: a.identifier, text: a.text })
      }
    } catch(e) {}
    return out
  }
  function activate(entry, action) {
    var index = findLive(entry)
    if (index >= 0) {
      if (action) service.invokeAction(index, action)
      else service.invokePopupDefault(index)
    } else {
      var argv = Logic.parseExecArgv(entry.execArgv)
      if (argv) Quickshell.execDetached(argv)
      else service.focusApp(entry)
    }
    close()
  }
  function snooze(entry, minutes) {
    var deadline = Attention.snoozeDeadline(minutes, Date.now())
    if (!deadline) return false
    var index = findLive(entry), snapshot = Logic.popupEntry(entry, 1)
    // Transient sender events become explicitly user-requested reminders.
    snapshot.transient = false
    snapshot.wakeAt = deadline
    if (index < 0) {
      service.restoredPopups[Logic.popupFileName(snapshot)] = true
      service.popupModel.insert(0, snapshot)
    } else {
      service.popupModel.setProperty(index, "wakeAt", deadline)
      service.popupModel.setProperty(index, "transient", false)
    }
    service.persistPopupFile(snapshot)
    if (index < 0) {
      // The live file now owns these images. Remove only the old history JSON,
      // so retention cannot evict a snoozed reminder's thumbnail by its old key.
      service.enqueuePopupFileJob(["rm", "-f", "--", service.historyDir + Logic.popupFileName(snapshot)])
      history = history.filter(function(e) { return Attention.key(e) !== Attention.key(snapshot) })
    }
    captureLive(); revision++
    return true
  }
  function pickSnooze(entries) {
    if (!opened) open()
    settingsVisible = false
    customSnoozeEntries = entries.slice()
  }
  function wake(entry) {
    var index = findLive(entry)
    if (index < 0) return
    service.popupModel.setProperty(index, "wakeAt", 0)
    service.popupModel.setProperty(index, "remindedAt", Date.now())
    var snapshot = Logic.popupEntry(service.popupModel.get(index), 1)
    service.persistPopupFile(snapshot)
    if (index > 0) service.popupModel.move(index, 0, 1)
    captureLive(); revision++
  }
  // Deferred deletion: do not tell senders the notification closed until Undo expires.
  function dismiss(entries) {
    var keys = hiddenKeys.slice()
    entries.forEach(function(e) { var k = Attention.key(e); if (keys.indexOf(k) < 0) keys.push(k) })
    hiddenKeys = keys; undoTimer.restart()
  }
  function undo() { undoTimer.stop(); hiddenKeys = [] }
  function commit() {
    var keys = hiddenKeys.slice()
    keys.forEach(function(k) {
      var live = root.liveRows().filter(function(e) { return Attention.key(e) === k })
      if (live.length) { var i = root.findLive(live[0]); if (i >= 0) service.dismissPopup(i) }
      // Ordered after archival. Only keys derived from known model rows enter argv.
      service.enqueuePopupFileJob(["rm", "-f", "--", service.historyDir + k + ".json",
        service.imagesDir + k + "-appIcon", service.imagesDir + k + "-image"])
    })
    history = history.filter(function(e) { return keys.indexOf(Attention.key(e)) < 0 })
    captureLive()
    hiddenKeys = []; revision++; reload()
  }
  Timer { id: undoTimer; interval: 5000; onTriggered: root.commit() }
  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      root.now = Date.now()
      var d = root.preferences.doNotDisturb
      if (d.enabled && d.until > 0 && root.now >= d.until) root.setDnd(0)
      // Focus and per-app Quiet postpone the interruption, not the reminder.
      root.snoozedRows.slice().forEach(function(e) {
        if (e.wakeAt <= root.now && !service.doNotDisturb && root.channelMode(e) === "allow") root.wake(e)
      })
      if (root.opened && root.unreadCount > 0) root.markSeen()
    }
  }
  Timer {
    id: reloadTimer; interval: 160
    onTriggered: {
      if (reader.running) { restart(); return }
      // A queue barrier gives us a consistent view after writes/moves/deletes.
      service.enqueuePopupFileJob(["true"], function() { reader.running = true })
    }
  }
  Process {
    id: reader
    command: ["bash", "-c", "awk 1 \"$1\"/*.json 2>/dev/null || true", "--", service.historyDir]
    stdout: StdioCollector {
      onStreamFinished: {
        root.history = Logic.parsePopupFiles(text, 1).slice(0, root.preferences.behavior.historyLimit)
        root.revision++
      }
    }
  }
  FileView {
    id: prefsFile
    path: Quickshell.env("HOME") + "/.config/omarchy/notifications.json"
    atomicWrites: true
    printErrors: false
    function hydrate(raw) {
      if (root.preferencesLoaded) return
      var value = {}
      try { value = JSON.parse(raw || "{}") } catch(e) { console.warn("notifications: invalid preferences; using defaults") }
      root.preferences = Attention.defaults(value)
      root.preferencesFromDisk = raw.trim().length > 0
      root.preferencesLoaded = true
      if (raw.trim()) service.setDoNotDisturb(root.preferences.doNotDisturb.enabled)
      else { root.syncDnd(service.doNotDisturb); root.savePreferences() }
    }
    onLoaded: hydrate(text())
    onLoadFailed: hydrate("")
  }
  FileView {
    id: readState
    path: service.stateDir + "notification-center.json"
    atomicWrites: true
    printErrors: false
    onLoaded: { try { root.lastSeen = Number(JSON.parse(text()).lastSeen) || 0 } catch(e) {} }
  }
  Connections {
    target: service
    function onSettingsLoadedChanged() {
      if (service.settingsLoaded && !root.preferencesFromDisk) root.syncDnd(service.doNotDisturb)
    }
  }
  Component.onCompleted: { captureLive(); reload() }
}
