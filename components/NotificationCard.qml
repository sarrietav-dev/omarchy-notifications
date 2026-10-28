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
  property int groupCount: 1
  property real remaining: -1
  property double now: Date.now()
  property var actions: []
  property string fontFamily: Style.font.family
  readonly property bool hovered: hover.hovered || snoozeMenu.opened || moreActions.opened
  readonly property string cleanBody: Logic.styledBody(entry.body || "", entry.app || "", entry.appIcon || "")
  readonly property string icon: iconSource(entry.appIcon || "")
  signal closeRequested()
  signal cardClicked()
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

  implicitWidth: Style.space(380)
  implicitHeight: content.implicitHeight + Style.spacing.popupPadding * 2 + borderTop + borderBottom
  radius: Style.cornerRadius
  color: Commons.Color.notifications.background
  borderSpec: selected ? Border.controlSpec("focus", Commons.Color.notifications.text, Commons.Color.accent)
    : Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border, Math.max(1, Style.space(2)))
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

  ColumnLayout {
    id: content
    anchors {
      top: parent.top; left: parent.left; right: parent.right
      topMargin: root.borderTop + Style.spacing.popupPadding
      leftMargin: root.borderLeft + Style.spacing.popupPadding
      rightMargin: root.borderRight + Style.spacing.popupPadding
    }
    spacing: Style.spacing.rowGap
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)
      Rectangle {
        Layout.preferredWidth: Style.space(28)
        Layout.preferredHeight: Style.space(28)
        radius: Style.cornerRadius
        color: "transparent"
        Image {
          id: iconImage
          anchors { fill: parent; margins: Style.space(3) }
          source: root.icon
          sourceSize.width: 48
          sourceSize.height: 48
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          visible: status === Image.Ready
        }
        Text {
          anchors.centerIn: parent
          visible: iconImage.status !== Image.Ready
          text: root.entry.glyph || Attention.label(root.entry).charAt(0).toUpperCase()
          font.family: Style.font.family
          font.pixelSize: Style.font.subtitle
          color: Commons.Color.notifications.text
        }
      }
      Text {
        Layout.fillWidth: true
        text: Attention.label(root.entry)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        color: Qt.alpha(Commons.Color.notifications.text, 0.65)
      }
      Rectangle {
        visible: root.unread
        Layout.preferredWidth: Style.space(6)
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
        text: "×"
        Accessible.name: "Dismiss notification"
        implicitWidth: Style.space(28)
        subtle: true
        opacity: root.hovered || activeFocus || root.selected ? 1 : 0.45
        onClicked: root.closeRequested()
      }
    }
    Text {
      Layout.fillWidth: true
      visible: root.entry.urgency === 2
      text: "!  Requires attention"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
      color: Commons.Color.urgent
    }
    Text {
      Layout.fillWidth: true
      text: root.entry.summary || "Notification"
      textFormat: Text.PlainText
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.weight: Font.DemiBold
      color: Commons.Color.notifications.text
      wrapMode: Text.Wrap
      maximumLineCount: root.expanded ? 30 : 2
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
      lineHeight: 1.25
      color: Qt.alpha(Commons.Color.notifications.text, 0.78)
      wrapMode: Text.Wrap
      maximumLineCount: root.expanded ? 100 : 3
      elide: Text.ElideRight
    }
    Image {
      Layout.fillWidth: true
      Layout.preferredHeight: visible ? Style.space(140) : 0
      visible: root.expanded && root.previewMedia && source.toString().length > 0 && status !== Image.Error
      source: root.entry.image || ""
      sourceSize.width: 760
      sourceSize.height: 280
      asynchronous: true
      fillMode: Image.PreserveAspectFit
    }
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(3)
      radius: height / 2
      visible: root.entry.progress !== undefined && Number(root.entry.progress) >= 0
      color: Qt.alpha(Commons.Color.accent, 0.15)
      Rectangle {
        width: parent.width * Math.min(100, Math.max(0, Number(root.entry.progress))) / 100
        height: parent.height
        radius: parent.radius
        color: Commons.Color.accent
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(4)
      ActionButton {
        text: "Snooze ▾"
        subtle: true
        Accessible.name: "Snooze notification"
        onClicked: snoozeMenu.open()
        SnoozeMenu {
          id: snoozeMenu
          onSelected: function(value) { root.snoozeRequested(value) }
          onCustomRequested: root.customSnoozeRequested()
        }
      }
      ActionButton {
        visible: root.groupCount > 1
        text: "+" + (root.groupCount - 1) + " more"
        onClicked: root.groupRequested()
      }
      ActionButton {
        visible: bodyText.truncated || root.expanded || !!root.entry.image
        text: root.expanded ? "Less" : "Expand"
        subtle: true
        onClicked: root.expansionRequested(!root.expanded)
      }
      Item { Layout.fillWidth: true }
    }
    RowLayout {
      Layout.fillWidth: true
      visible: root.actions.length > 0
      spacing: Style.space(4)
      Item { Layout.fillWidth: true }
      Repeater {
        model: root.actions.slice(0, 2)
        ActionButton {
          required property var modelData
          text: modelData.text
          Layout.maximumWidth: Style.space(120)
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
    }
  }
  Rectangle {
    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 1 }
    width: (parent.width - Style.space(28)) * Math.max(0, root.remaining)
    height: Style.space(2)
    radius: height
    visible: root.remaining >= 0
    color: Commons.Color.notifications.countdown
  }
}
