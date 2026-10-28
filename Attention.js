// Pure attention policy. Rows never retain QObjects.
function key(row) { return String(row.timestamp) + "-" + String(row.originalId) }
function receivedAt(row) { return Number(row.remindedAt) || Number(row.timestamp) || 0 }
function iconCandidates(entry) {
  var e = entry || {}, out = [], values = [e.image, e.appIcon]
  values.forEach(function(value) {
    if (typeof value !== "string" || !value || out.indexOf(value) >= 0) return
    // Only sender-supplied local/provider images or themed icon names. Never
    // resolve a website or fetch a remote icon as a side effect of delivery.
    if (/^[a-z][a-z0-9+.-]*:/i.test(value) && !/^(file|image):\/\//i.test(value)) return
    out.push(value)
  })
  return out
}
function snoozeDeadline(minutes, now) {
  if (typeof minutes === "string" && /^at:\d+$/.test(minutes)) {
    var absolute = Number(minutes.slice(3))
    return isFinite(absolute) && absolute > now && !isNaN(new Date(absolute).getTime()) ? absolute : 0
  }
  if (minutes === "tomorrow") {
    var d = new Date(now); d.setDate(d.getDate() + 1); d.setHours(8, 0, 0, 0)
    return d.getTime()
  }
  var n = Number(minutes)
  return isFinite(n) && n > 0 && n <= 10080 ? now + n * 60000 : 0
}
function snoozeOptions(now) {
  var today = new Date(now)
  function day(offset, hour) {
    var d = new Date(today)
    d.setDate(d.getDate() + offset); d.setHours(hour, 0, 0, 0)
    return d.getTime()
  }
  var mondayOffset = -((today.getDay() + 6) % 7)
  return [
    { label: "Later today", timestamp: day(0, 18) },
    { label: "Tomorrow", timestamp: day(1, 8) },
    { label: "Later this week", timestamp: day(mondayOffset + 4, 8) },
    { label: "This weekend", timestamp: day(mondayOffset + 6, 8) },
    { label: "Next week", timestamp: day(mondayOffset + 7, 8) }
  ].filter(function(option) { return option.timestamp > now })
}
function parseLocalDateTime(dateText, timeText, now) {
  var date = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateText))
  var time = /^(\d{2}):(\d{2})$/.exec(String(timeText))
  if (!date || !time) return 0
  var y = Number(date[1]), m = Number(date[2]) - 1, d = Number(date[3])
  var h = Number(time[1]), minute = Number(time[2])
  if (y < 1970 || m < 0 || m > 11 || d < 1 || d > 31 || h > 23 || minute > 59) return 0
  var value = new Date(0)
  value.setFullYear(y, m, d); value.setHours(h, minute, 0, 0)
  // Reject rolled-over dates and nonexistent local times during DST changes.
  if (value.getFullYear() !== y || value.getMonth() !== m || value.getDate() !== d ||
      value.getHours() !== h || value.getMinutes() !== minute) return 0
  return value.getTime() > now ? value.getTime() : 0
}
function channel(row) {
  return String(row.desktopEntry || row.app || row.appIcon || "System")
    .replace(/^.*\//, "").replace(/\.desktop$/, "").toLowerCase()
}
function label(row) {
  if (row.app === "omarchy-action") return "Omarchy"
  if (row.app || row.desktopEntry) return String(row.app || row.desktopEntry).replace(/\.desktop$/, "")
  var icon = String(row.appIcon || "")
  if (icon && icon.indexOf("/") < 0) return icon.replace(/^com\.[^.]+\./, "").replace(/[-_]/g, " ")
  return "System"
}
function plain(text) { return String(text || "").replace(/<[^>]*>/g, " ") }
function relative(timestamp, now) {
  var minutes = Math.max(0, Math.floor((now - timestamp) / 60000))
  if (minutes < 1) return "now"
  if (minutes < 60) return minutes + "m"
  if (minutes < 1440) return Math.floor(minutes / 60) + "h"
  return Math.floor(minutes / 1440) + "d"
}
function bucket(timestamp, now) {
  var today = new Date(now); today.setHours(0, 0, 0, 0)
  var yesterday = new Date(today); yesterday.setDate(yesterday.getDate() - 1)
  if (timestamp >= now - 3600000 && timestamp >= today.getTime()) return "Recent"
  if (timestamp >= today.getTime()) return "Earlier today"
  if (timestamp >= yesterday.getTime()) return "Yesterday"
  return "Older"
}
function groups(rows, enabled) {
  var out = []
  rows.forEach(function(row) {
    var found = null
    if (enabled && row.urgency !== 2) {
      for (var i = 0; i < out.length; i++) {
        if (out[i].row.urgency !== 2 && channel(out[i].row) === channel(row) &&
            Math.abs(receivedAt(out[i].row) - receivedAt(row)) < 90000) { found = out[i]; break }
      }
    }
    if (found) found.rows.push(row)
    else {
      var c = channel(row), used = out.some(function(g) { return g.groupKey === c })
      out.push({ row: row, rows: [row], groupKey: row.urgency === 2 || !enabled || used ? key(row) : c })
    }
  })
  // Never merge separate emergencies.
  out.sort(function(a, b) { return (b.row.urgency === 2 ? 1 : 0) - (a.row.urgency === 2 ? 1 : 0) })
  return out
}
function defaults(value) {
  var v = value || {}, b = v.behavior || {}, d = v.doNotDisturb || {}
  return { version: 1, doNotDisturb: { enabled: !!d.enabled, until: Number(d.until) || 0 },
    behavior: { maxVisibleToasts: Math.max(1, Math.min(5, Number(b.maxVisibleToasts) || 3)),
      historyLimit: Math.max(10, Math.min(500, Number(b.historyLimit) || 100)),
      reducedMotion: !!b.reducedMotion, grouping: b.grouping !== false, previewMedia: b.previewMedia !== false },
    channels: v.channels && typeof v.channels === "object" ? v.channels : {} }
}
if (typeof module !== "undefined") module.exports = { key: key, receivedAt: receivedAt, iconCandidates: iconCandidates, snoozeDeadline: snoozeDeadline,
  snoozeOptions: snoozeOptions, parseLocalDateTime: parseLocalDateTime, channel: channel, label: label,
  plain: plain, relative: relative, bucket: bucket, groups: groups, defaults: defaults }
