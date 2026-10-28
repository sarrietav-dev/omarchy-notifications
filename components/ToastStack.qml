import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "../Attention.js" as Attention
import "../NotificationLogic.js" as Logic

Item {
  id: root
  required property var service
  required property var center
  property var ages: ({})
  property var paused: ({})
  property int tick: 0
  readonly property var groups: {
    var revision = center.revision
    return Attention.groups(center.liveRows().filter(function(e) {
      return !e.wakeAt && center.hiddenKeys.indexOf(Attention.key(e)) < 0
    }), center.preferences.behavior.grouping)
  }
  ListModel { id: visibleGroups }
  onGroupsChanged: Qt.callLater(syncGroups)
  Connections {
    target: center
    function onPreferencesChanged() { Qt.callLater(root.syncGroups) }
    function onHiddenKeysChanged() { Qt.callLater(root.syncGroups) }
  }
  function syncGroups() {
    var next = groups.slice(0, center.preferences.behavior.maxVisibleToasts)
    var keys = next.map(function(g) { return g.groupKey })
    for (var i = visibleGroups.count - 1; i >= 0; i--) {
      if (keys.indexOf(visibleGroups.get(i).groupKey) < 0) visibleGroups.setProperty(i, "leaving", true)
    }
    for (var n = 0; n < next.length; n++) {
      var g = next[n], found = -1, payload = JSON.stringify(g)
      for (var j = 0; j < visibleGroups.count; j++) {
        if (visibleGroups.get(j).groupKey === g.groupKey) { found = j; break }
      }
      if (found < 0) visibleGroups.insert(n, { groupKey: g.groupKey, payload: payload, leaving: false })
      else {
        if (found !== n) visibleGroups.move(found, n, 1)
        if (visibleGroups.get(n).payload !== payload) visibleGroups.setProperty(n, "payload", payload)
        visibleGroups.setProperty(n, "leaving", false)
      }
    }
    cleanup.restart()
  }
  Timer {
    id: cleanup; interval: center.reducedMotion ? 0 : 170
    onTriggered: {
      for (var i = visibleGroups.count - 1; i >= 0; i--) if (visibleGroups.get(i).leaving) visibleGroups.remove(i)
    }
  }

  function dismiss(group) {
    group.rows.forEach(function(e) { var i = center.findLive(e); if (i >= 0) service.dismissPopup(i) })
  }
  function fraction(entry) {
    var t = tick, state = ages[Attention.key(entry)], age = state ? state.elapsed : 0
    var duration = service.durationForEntry(entry)
    return duration > 0 ? Math.max(0, 1 - age / duration) : -1
  }
  Timer {
    interval: 100; running: center.live.some(function(e) { return !e.wakeAt }); repeat: true
    onTriggered: {
      var next = {}, rows = center.liveRows()
      // Iterate backwards because expiration removes rows from the service model.
      for (var i = rows.length - 1; i >= 0; i--) {
        var e = rows[i], k = Attention.key(e), duration = service.durationForEntry(e)
        var old = root.ages[k], signature = e.summary + "\n" + e.body + "\n" + e.image + "\n" + e.remindedAt
        var age = old && old.signature === signature ? old.elapsed : 0
        if (e.wakeAt > 0) age = 0
        else if (!root.paused[k] && !center.opened && !(e.resident && e.progress >= 0 && e.progress < 100)) age += 100
        next[k] = { elapsed: age, signature: signature }
        if (duration > 0 && age >= duration) {
          var index = center.findLive(e)
          if (index >= 0) service.expirePopup(index)
        }
      }
      root.ages = next; root.tick++
    }
  }
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: window
      required property var modelData
      screen: modelData
      visible: visibleGroups.count > 0 && !center.opened
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "omarchy-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region { item: column }
      readonly property var placement: Logic.popupPlacement(service.barPosition, service.barClearance, Style.gapsOut)
      Column {
        id: column
        anchors { right: parent.right; top: parent.top; rightMargin: window.placement.margins.right; topMargin: window.placement.margins.top }
        width: Math.min(Style.space(380), window.width - anchors.rightMargin - Style.space(12))
        spacing: Style.spacing.rowGap
        move: Transition { NumberAnimation { properties: "y"; duration: center.reducedMotion ? 0 : 200; easing.type: Easing.OutCubic } }
        Repeater {
          model: visibleGroups
          delegate: Item {
            id: slot
            required property string payload
            required property bool leaving
            readonly property var group: JSON.parse(payload)
            width: column.width
            height: Math.min(card.implicitHeight, (window.height - column.y - Style.space(80)) / center.preferences.behavior.maxVisibleToasts)
            property bool closing: false
            property real entrance: 0
            property real swipe: 0
            opacity: closing || leaving ? 0 : entrance
            transform: Translate { x: slot.swipe + (1 - slot.entrance) * Style.space(24) }
            Behavior on opacity { NumberAnimation { duration: center.reducedMotion ? 0 : 160 } }
            Component.onCompleted: entrance = 1
            Behavior on entrance { NumberAnimation { duration: center.reducedMotion ? 0 : 220; easing.type: Easing.OutCubic } }
            Behavior on swipe { enabled: !drag.active; NumberAnimation { duration: center.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic } }
            function closeCard() { closing = true; leave.restart() }
            Timer { id: leave; interval: center.reducedMotion ? 0 : 160; onTriggered: root.dismiss(slot.group) }
            DragHandler {
              id: drag
              target: null
              xAxis.enabled: true
              yAxis.enabled: false
              onActiveTranslationChanged: if (active) slot.swipe = activeTranslation.x
              onActiveChanged: if (!active) {
                if (Math.abs(slot.swipe) > slot.width * 0.3) slot.closeCard()
                else slot.swipe = 0
              }
            }
            NotificationCard {
              id: card
              width: parent.width
              height: parent.height
              clip: true
              entry: slot.group.row
              groupCount: slot.group.rows.length
              previewMedia: center.preferences.behavior.previewMedia
              fontFamily: Style.font.family
              remaining: {
                var t = root.tick, state = root.ages[Attention.key(entry)]
                var duration = service.durationForEntry(entry)
                return duration > 0 ? Math.max(0, 1 - (state ? state.elapsed : 0) / duration) : -1
              }
              actions: center.actionsFor(entry)
              onHoveredChanged: {
                var p = root.paused
                slot.group.rows.forEach(function(e) { p[Attention.key(e)] = card.hovered })
                root.paused = p
              }
              Component.onDestruction: {
                var p = root.paused
                slot.group.rows.forEach(function(e) { delete p[Attention.key(e)] })
                root.paused = p
              }
              onCloseRequested: slot.closeCard()
              onCardClicked: center.activate(entry, "")
              onActionRequested: function(identifier) { center.activate(entry, identifier) }
              onGroupRequested: center.open()
              onExpansionRequested: function(expand) { card.expanded = expand }
              onSnoozeRequested: function(minutes) {
                slot.group.rows.forEach(function(e) { center.snooze(e, minutes) })
              }
              onCustomSnoozeRequested: center.pickSnooze(slot.group.rows)
            }
          }
        }
        ActionButton {
          visible: root.groups.length > center.preferences.behavior.maxVisibleToasts
          width: parent.width
          text: "+" + Math.max(0, root.groups.length - center.preferences.behavior.maxVisibleToasts) + " more · Open Notification Center"
          onClicked: center.open()
        }
      }
    }
  }
  Component.onCompleted: syncGroups()
}
