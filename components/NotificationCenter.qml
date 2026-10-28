import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "../Attention.js" as Attention

Item {
  id: root
  required property var service
  required property var center
  readonly property color foreground: Commons.Color.popups.text
  property string query: ""
  property var collapsed: ({})
  property var expanded: ({})
  readonly property double sectionClock: Math.floor(center.now / 60000) * 60000
  readonly property var filtered: center.rows.filter(function(r) {
    return (Attention.label(r) + " " + r.summary + " " + Attention.plain(r.body)).toLowerCase().indexOf(root.query.toLowerCase()) >= 0
  })
  readonly property var sections: {
    var result = [], map = {}
    root.filtered.forEach(function(r) {
      var section = Attention.bucket(Attention.receivedAt(r), root.sectionClock) + " · " + Attention.label(r)
      if (!map[section]) { map[section] = []; result.push({ title: section, rows: map[section] }) }
      map[section].push(r)
    })
    return result
  }
  readonly property var displayRows: {
    var out = []
    sections.forEach(function(s) {
      out.push({ header: true, title: s.title, entry: s.rows[0], count: s.rows.length, members: s.rows })
      if (!root.collapsed[s.title]) s.rows.forEach(function(r) {
        out.push({ header: false, title: s.title, entry: r, count: 0, members: [] })
      })
    })
    return out
  }
  readonly property var channels: {
    var map = {}, out = []
    center.rows.forEach(function(r) { var c = Attention.channel(r); if (!map[c]) { map[c] = true; out.push({ key: c, label: Attention.label(r) }) } })
    Object.keys(center.preferences.channels).forEach(function(c) { if (!map[c]) out.push({ key: c, label: c }) })
    return out
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: window
      required property var modelData
      screen: modelData
      readonly property bool here: center.screenName === "" ? Quickshell.screens[0] === modelData : center.screenName === modelData.name
      property real reveal: center.opened && here ? 1 : 0
      visible: here && (center.opened || reveal > 0)
      Behavior on reveal { NumberAnimation { duration: center.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic } }
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "sebas-notification-center"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: center.opened && here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      Rectangle { anchors.fill: parent; color: Commons.Color.menu.scrim; opacity: window.reveal }
      MouseArea { anchors.fill: parent; onClicked: center.close() }

      Ui.BorderSurface {
        id: sheet
        width: Math.min(Style.space(420), window.width - Style.space(24))
        readonly property real edgeMargin: service.barPosition === "right" ? service.barClearance : Style.gapsOut
        x: window.width - width - edgeMargin + (1 - window.reveal) * (width + edgeMargin)
        y: service.barPosition === "top" ? service.barClearance : Style.gapsOut
        height: window.height - y - (service.barPosition === "bottom" ? service.barClearance : Style.gapsOut)
        radius: Style.cornerRadius
        color: Commons.Color.popups.background
        borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
        clip: true
        // Prevent clicks on the sheet background from falling through to the scrim.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
          anchors {
            fill: parent
            topMargin: sheet.borderTop + Style.spacing.panelPadding
            bottomMargin: sheet.borderBottom + Style.spacing.panelPadding
            leftMargin: sheet.borderLeft + Style.spacing.panelPadding
            rightMargin: sheet.borderRight + Style.spacing.panelPadding
          }
          spacing: Style.spacing.panelGap
          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: center.settingsVisible ? "Preferences" : "Notifications"
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.weight: Font.DemiBold
              color: root.foreground
            }
            ActionButton {
              text: center.settingsVisible ? "Back" : "Settings"
              subtle: true
              onClicked: center.settingsVisible = !center.settingsVisible
            }
            ActionButton { text: "×"; Accessible.name: "Close Notification Center"; subtle: true; onClicked: center.close() }
          }
          Text {
            Layout.fillWidth: true
            text: service.doNotDisturb ? "Focus on · Silent delivery" : center.rows.length + " notifications"
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            color: Qt.alpha(root.foreground, 0.6)
          }
          RowLayout {
            Layout.fillWidth: true
            ActionButton {
              text: service.doNotDisturb ? "Focus: On ▾" : "Focus: Off ▾"
              onClicked: focusMenu.open()
              NotificationMenu {
                id: focusMenu
                NotificationMenuItem { text: "Allow notifications"; onTriggered: center.setDnd(0) }
                NotificationMenuItem { text: "For 15 minutes"; onTriggered: center.setDnd(15) }
                NotificationMenuItem { text: "For 1 hour"; onTriggered: center.setDnd(60) }
                NotificationMenuItem {
                  text: "Until tomorrow at 08:00"
                  onTriggered: { var d = new Date(); d.setDate(d.getDate() + 1); d.setHours(8,0,0,0); center.setDnd((d.getTime() - Date.now()) / 60000) }
                }
                NotificationMenuItem { text: "Until I turn it off"; onTriggered: center.setDnd(-1) }
              }
            }
            Item { Layout.fillWidth: true }
            ActionButton {
              visible: center.snoozedRows.length > 0
              text: "Snoozed · " + center.snoozedRows.length + " ▾"
              onClicked: sleepingMenu.open()
              NotificationMenu {
                id: sleepingMenu
                Instantiator {
                  model: center.snoozedRows
                  delegate: NotificationMenuItem {
                    required property var modelData
                    text: (modelData.summary || Attention.label(modelData)) + " · " + new Date(modelData.wakeAt).toLocaleString() + " · Show now"
                    onTriggered: center.wake(modelData)
                  }
                  onObjectAdded: function(index, object) { sleepingMenu.insertItem(index, object) }
                  onObjectRemoved: function(index, object) { sleepingMenu.removeItem(object) }
                }
              }
            }
            ActionButton {
              text: "Clear all"
              enabled: center.rows.length > 0
              subtle: true
              visible: !center.settingsVisible
              onClicked: center.dismiss(center.rows)
            }
          }
          Ui.TextField {
            id: search
            Layout.fillWidth: true
            visible: !center.settingsVisible
            placeholderText: "Search notifications…"
            Accessible.name: "Search notifications"
            text: root.query
            onTextEdited: root.query = text
            foreground: root.foreground
            Keys.onDownPressed: { list.forceActiveFocus(); list.currentIndex = Math.min(1, list.count - 1) }
            Keys.onEscapePressed: center.close()
          }

          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !center.settingsVisible
            clip: true
            spacing: Style.spacing.rowGap
            model: root.displayRows
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: NotificationScrollBar {}
            Keys.onEscapePressed: center.close()
            Keys.onPressed: function(event) {
              var row = currentIndex >= 0 && currentIndex < root.displayRows.length ? root.displayRows[currentIndex] : null
              if (event.key === Qt.Key_Slash) { search.forceActiveFocus(); event.accepted = true }
              else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) { currentIndex = Math.min(count - 1, currentIndex + 1); event.accepted = true }
              else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) { currentIndex = Math.max(0, currentIndex - 1); event.accepted = true }
              else if (row && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                if (row.header) root.toggleSection(row.title)
                else center.activate(row.entry, "")
                event.accepted = true
              } else if (row && event.key === Qt.Key_Delete) {
                var group = root.sections.filter(function(s) { return s.title === row.title })[0]
                center.dismiss(row.header || (event.modifiers & Qt.ShiftModifier) ? group.rows : [row.entry])
                event.accepted = true
              } else if (row && !row.header && event.key === Qt.Key_Space) {
                root.toggleExpanded(Attention.key(row.entry)); event.accepted = true
              }
            }
            delegate: Item {
              id: cell
              required property var modelData
              required property int index
              width: list.width
              height: modelData.header ? Style.space(36) : notification.implicitHeight
              RowLayout {
                anchors.fill: parent
                visible: cell.modelData.header
                ActionButton {
                  Layout.fillWidth: true
                  text: (root.collapsed[cell.modelData.title] ? "▸ " : "▾ ") + cell.modelData.title + "  · " + cell.modelData.count
                  subtle: true
                  onClicked: root.toggleSection(cell.modelData.title)
                }
                ActionButton {
                  text: "×"; subtle: true
                  Accessible.name: "Dismiss group"
                  onClicked: center.dismiss(cell.modelData.members)
                }
              }
              NotificationCard {
                id: notification
                width: parent.width
                visible: !cell.modelData.header
                entry: cell.modelData.entry
                now: center.now
                expanded: !!root.expanded[Attention.key(entry)]
                selected: list.activeFocus && list.currentIndex === cell.index
                unread: Attention.receivedAt(entry) > center.seenAtOpen && entry.app !== "omarchy-action"
                previewMedia: center.preferences.behavior.previewMedia
                fontFamily: Style.font.family
                actions: center.actionsFor(entry)
                showOpenAction: true
                onOpenRequested: center.activate(entry, "")
                onCloseRequested: center.dismiss([entry])
                onCardClicked: { list.currentIndex = cell.index; root.toggleExpanded(Attention.key(entry)) }
                onExpansionRequested: root.toggleExpanded(Attention.key(entry))
                onSnoozeRequested: function(minutes) { center.snooze(entry, minutes) }
                onCustomSnoozeRequested: center.pickSnooze([entry])
                onActionRequested: function(identifier) { center.activate(entry, identifier) }
              }
            }
            Text {
              anchors.centerIn: parent
              width: parent.width - Style.space(32)
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              visible: list.count === 0
              text: root.query ? "No matching notifications\nTry a different search." : "All caught up\n\nNew notifications will appear here,\neven while Focus is on."
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              lineHeight: 1.6
              color: Qt.alpha(Commons.Color.foreground, 0.55)
            }
          }
          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: center.settingsVisible
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical: NotificationScrollBar {}
            ColumnLayout {
              width: parent.width
              spacing: Style.spacing.panelGap
              Repeater {
                model: [ { key: "grouping", label: "Group notifications by app" }, { key: "previewMedia", label: "Show image previews" }, { key: "reducedMotion", label: "Reduce motion" } ]
                ActionButton {
                  required property var modelData
                  Layout.fillWidth: true
                  text: (center.preferences.behavior[modelData.key] ? "✓  " : "○  ") + modelData.label
                  onClicked: center.behavior(modelData.key, !center.preferences.behavior[modelData.key])
                }
              }
              ActionButton {
                Layout.fillWidth: true
                text: "Visible toasts: " + center.preferences.behavior.maxVisibleToasts + " · Change"
                onClicked: center.behavior("maxVisibleToasts", center.preferences.behavior.maxVisibleToasts % 5 + 1)
              }
              ActionButton {
                Layout.fillWidth: true
                text: "History: " + center.preferences.behavior.historyLimit + " notifications · Change"
                onClicked: {
                  var sizes = [50, 100, 200, 500], i = sizes.indexOf(center.preferences.behavior.historyLimit)
                  center.behavior("historyLimit", sizes[(i + 1) % sizes.length])
                }
              }
              Text { text: "Application delivery"; color: Commons.Color.foreground; font.family: Style.font.family; font.bold: true }
              Text {
                Layout.fillWidth: true
                text: "Allow: toasts + history · Quiet: history only\nBlock: discard new notifications"
                font.family: Style.font.family; font.pixelSize: Style.font.caption
                color: Qt.alpha(Commons.Color.foreground, 0.6); wrapMode: Text.Wrap
              }
              Repeater {
                model: root.channels
                RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  Text {
                    Layout.fillWidth: true
                    text: modelData.label; elide: Text.ElideRight; textFormat: Text.PlainText
                    color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body
                  }
                  ActionButton {
                    readonly property string mode: center.preferences.channels[parent.modelData.key] ? center.preferences.channels[parent.modelData.key].mode : "allow"
                    text: mode === "allow" ? "Allow" : mode === "quiet" ? "Quiet" : "Blocked"
                    onClicked: center.setChannel(parent.modelData.key, mode === "allow" ? "quiet" : mode === "quiet" ? "block" : "allow")
                  }
                }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            visible: center.hiddenKeys.length > 0
            Text {
              Layout.fillWidth: true
              text: center.hiddenKeys.length + " dismissed"
              color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
            }
            ActionButton { text: "Undo"; onClicked: center.undo() }
          }
          Text {
            text: "↑↓ Navigate   Space Expand   Enter Open   Del Dismiss"
            font.family: Style.font.family; font.pixelSize: Style.font.caption
            color: Qt.alpha(Commons.Color.foreground, 0.4)
            Layout.fillWidth: true; elide: Text.ElideRight
          }
        }
        Keys.onEscapePressed: center.close()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            center.undo(); event.accepted = true
          }
        }
        SnoozePicker {
          id: snoozePicker
          parent: sheet
          onChosen: function(timestamp) {
            center.customSnoozeEntries.slice().forEach(function(entry) { center.snooze(entry, "at:" + timestamp) })
          }
          onClosed: center.customSnoozeEntries = []
        }
      }
      Connections {
        target: center
        function onOpenedChanged() {
          if (center.opened && window.here) Qt.callLater(function() { search.forceActiveFocus() })
          else snoozePicker.close()
        }
        function onCustomSnoozeEntriesChanged() {
          if (window.here && center.opened && center.customSnoozeEntries.length > 0) Qt.callLater(function() { snoozePicker.show() })
        }
      }
    }
  }
  function toggleSection(title) { var c = Object.assign({}, collapsed); c[title] = !c[title]; collapsed = c }
  function toggleExpanded(key) { var e = Object.assign({}, expanded); e[key] = !e[key]; expanded = e }
}
