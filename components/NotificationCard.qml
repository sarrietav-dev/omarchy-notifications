import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "../NotificationLogic.js" as Logic
import "../Attention.js" as Attention

Ui.BorderSurface {
  id: root
  property var entry: ({})
  property bool expanded: false
  property bool unread: false
  property bool reducedMotion: false
  property bool previewMedia: true
  property bool selected: false
  property bool showOpenAction: false
  property int groupCount: 1
  property real remaining: -1
  property double now: Date.now()
  property var actions: []
  property string fontFamily: Style.font.family
  readonly property bool hovered: hover.hovered || snoozeMenu.opened || moreActions.opened
  readonly property bool showControls: hovered || expanded || selected
  readonly property string cleanBody: Logic.styledBody(entry.body || "", entry.app || "", entry.appIcon || "")
  readonly property var iconCandidates: Attention.iconCandidates(entry).map(iconSource).filter(function(source) { return source.length > 0 })
  property int iconIndex: 0
  readonly property string icon: iconIndex < iconCandidates.length ? iconCandidates[iconIndex] : ""
  onIconCandidatesChanged: iconIndex = 0
  readonly property string mediaSource: {
    var candidates = Attention.iconCandidates({ image: entry.image })
    return candidates.length > 0 ? iconSource(candidates[0]) : ""
  }
  readonly property bool canExpand: titleText.truncated || bodyText.truncated || !!mediaSource || actions.length > 0 || showOpenAction
  // Keep theme colors, gradients and intentionally absent border sides, but
  // cap the frame at a hairline rather than outlining every card heavily.
  readonly property var cardBorder: {
    var spec = Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border, Style.spacing.hairline)
    return Object.assign({}, spec, { widths: {
      top: Math.min(Style.spacing.hairline, Border.top(spec)),
      right: Math.min(Style.spacing.hairline, Border.right(spec)),
      bottom: Math.min(Style.spacing.hairline, Border.bottom(spec)),
      left: Math.min(Style.spacing.hairline, Border.left(spec))
    } })
  }
  signal closeRequested()
  signal cardClicked()
  signal openRequested()
  signal actionRequested(string identifier)
  signal groupRequested()
  signal expansionRequested(bool expand)
  signal snoozeRequested(string minutes)
  signal customSnoozeRequested()

  function iconSource(value) {
    if (!value) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: Style.space(360)
  implicitHeight: content.implicitHeight + Style.spacing.controlPaddingY * 2 + borderTop + borderBottom
  radius: Style.cornerRadius
  color: Commons.Color.notifications.background
  borderSpec: selected ? Border.controlSpec("focus", Commons.Color.notifications.text, Commons.Color.accent) : cardBorder
  Accessible.role: Accessible.Button
  Accessible.name: Attention.label(entry) + ": " + (entry.summary || "")
  HoverHandler { id: hover }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button !== Qt.LeftButton) root.closeRequested()
      else root.cardClicked()
    }
  }

  RowLayout {
    id: content
    anchors {
      top: parent.top; left: parent.left; right: parent.right
      topMargin: root.borderTop + Style.spacing.controlPaddingY
      leftMargin: root.borderLeft + Style.spacing.controlPaddingX
      rightMargin: root.borderRight + Style.spacing.controlPaddingX
    }
    spacing: Style.spacing.controlGap
    Item {
      Layout.preferredWidth: Style.space(32)
      Layout.preferredHeight: Style.space(32)
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: Style.spacing.xxs
      Image {
        id: iconImage
        anchors.fill: parent
        source: root.icon
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
        onStatusChanged: {
          if (status === Image.Error && root.iconIndex + 1 < root.iconCandidates.length)
            root.iconIndex++
        }
      }
      Text {
        anchors.centerIn: parent
        visible: iconImage.status !== Image.Ready
        text: root.entry.glyph || Attention.label(root.entry).charAt(0).toUpperCase()
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconLarge
        color: Commons.Color.notifications.text
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.xxs
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xxs
        Text {
          Layout.fillWidth: true
          text: root.entry.urgency === 2 ? "! " + Attention.label(root.entry) : Attention.label(root.entry)
          textFormat: Text.PlainText
          elide: Text.ElideRight
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          color: root.entry.urgency === 2 ? Commons.Color.urgent : Qt.alpha(Commons.Color.notifications.text, 0.65)
          Accessible.name: root.entry.urgency === 2 ? "Requires attention: " + Attention.label(root.entry) : text
        }
        Rectangle {
          visible: root.unread
          Layout.preferredWidth: Style.space(4)
          Layout.preferredHeight: width
          radius: width / 2
          color: Commons.Color.accent
        }
        Text {
          text: Attention.relative(Attention.receivedAt(root.entry) || root.now, root.now)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: Qt.alpha(Commons.Color.notifications.text, 0.5)
        }
        ActionButton {
          visible: root.groupCount > 1
          text: "+" + (root.groupCount - 1)
          tooltipText: "Show grouped notifications"
          Accessible.name: (root.groupCount - 1) + " more notifications"
          subtle: true
          fontSize: Style.font.caption
          verticalPadding: Style.spacing.xxs
          horizontalPadding: Style.spacing.xxs
          implicitHeight: Style.space(18)
          onClicked: root.groupRequested()
        }
        ActionButton {
          text: "󰒲"
          tooltipText: "Snooze"
          Accessible.name: "Snooze notification"
          subtle: true
          fontSize: Style.font.bodySmall
          verticalPadding: Style.spacing.xxs
          horizontalPadding: Style.spacing.xxs
          implicitWidth: Style.space(20)
          implicitHeight: Style.space(18)
          opacity: root.showControls || activeFocus ? 1 : 0
          onClicked: snoozeMenu.open()
          SnoozeMenu {
            id: snoozeMenu
            onSelected: function(value) { root.snoozeRequested(value) }
            onCustomRequested: root.customSnoozeRequested()
          }
        }
        ActionButton {
          visible: root.canExpand || root.expanded
          text: root.expanded ? "󰅃" : "󰅀"
          tooltipText: root.expanded ? "Collapse" : "Expand"
          Accessible.name: tooltipText
          subtle: true
          fontSize: Style.font.bodySmall
          verticalPadding: Style.spacing.xxs
          horizontalPadding: Style.spacing.xxs
          implicitWidth: Style.space(20)
          implicitHeight: Style.space(18)
          opacity: root.showControls || activeFocus ? 1 : 0
          onClicked: root.expansionRequested(!root.expanded)
        }
        ActionButton {
          text: "×"
          Accessible.name: "Dismiss notification"
          tooltipText: Accessible.name
          subtle: true
          fontSize: Style.font.bodySmall
          verticalPadding: Style.spacing.xxs
          horizontalPadding: Style.spacing.xxs
          implicitWidth: Style.space(20)
          implicitHeight: Style.space(18)
          opacity: root.showControls || activeFocus ? 1 : 0
          onClicked: root.closeRequested()
        }
      }
      Text {
        id: titleText
        Layout.fillWidth: true
        text: root.entry.summary || "Notification"
        textFormat: Text.PlainText
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.weight: Font.DemiBold
        color: Commons.Color.notifications.text
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? 30 : 1
        elide: Text.ElideRight
      }
      Text {
        id: bodyText
        Layout.fillWidth: true
        visible: root.cleanBody.length > 0
        text: root.cleanBody
        textFormat: Text.StyledText
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        lineHeight: 1.1
        color: Qt.alpha(Commons.Color.notifications.text, 0.78)
        wrapMode: Text.Wrap
        maximumLineCount: root.expanded ? 100 : 2
        elide: Text.ElideRight
      }
      Image {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Style.space(120) : 0
        visible: root.expanded && root.previewMedia && source.toString().length > 0 && status !== Image.Error
        source: root.expanded && root.previewMedia ? root.mediaSource : ""
        sourceSize.width: 720
        sourceSize.height: 240
        asynchronous: true
        fillMode: Image.PreserveAspectFit
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Style.spacing.hairline
        visible: root.entry.progress !== undefined && Number(root.entry.progress) >= 0
        color: Qt.alpha(Commons.Color.accent, 0.15)
        Rectangle {
          width: parent.width * Math.min(100, Math.max(0, Number(root.entry.progress))) / 100
          height: parent.height
          color: Commons.Color.accent
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.spacing.sm
        visible: root.expanded && (root.actions.length > 0 || root.showOpenAction)
        spacing: Style.spacing.sm
        Item { Layout.fillWidth: true }
        Repeater {
          model: root.actions.slice(0, 2)
          ActionButton {
            required property var modelData
            text: modelData.text
            Layout.maximumWidth: Style.space(100)
            onClicked: root.actionRequested(modelData.identifier)
          }
        }
        ActionButton {
          visible: root.actions.length > 2
          text: "…"
          Accessible.name: "More actions"
          onClicked: moreActions.open()
          NotificationMenu {
            id: moreActions
            Instantiator {
              model: root.actions.slice(2)
              delegate: NotificationMenuItem {
                required property var modelData
                text: modelData.text
                onTriggered: root.actionRequested(modelData.identifier)
              }
              onObjectAdded: function(index, object) { moreActions.insertItem(index, object) }
              onObjectRemoved: function(index, object) { moreActions.removeItem(object) }
            }
          }
        }
        ActionButton { visible: root.showOpenAction; text: "Open ↗"; onClicked: root.openRequested() }
      }
    }
  }
  Rectangle {
    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 1 }
    width: (parent.width - Style.spacing.controlPaddingX * 2) * Math.max(0, root.remaining)
    height: Style.spacing.hairline
    visible: root.remaining >= 0
    color: Qt.alpha(Commons.Color.notifications.countdown, 0.5)
  }
}
