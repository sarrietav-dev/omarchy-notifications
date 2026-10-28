import QtQuick
import QtQuick.Controls
import QtQml.Models
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import "../Attention.js" as Attention

NotificationMenu {
  id: root
  property double now: Date.now()
  signal selected(string value)
  signal customRequested()
  width: Style.space(340)
  onAboutToShow: now = Date.now()
  Instantiator {
    model: Attention.snoozeOptions(root.now)
    delegate: NotificationMenuItem {
      id: option
      required property var modelData
      text: modelData.label
      contentItem: RowLayout {
        spacing: Style.spacing.controlGap
        Text {
          Layout.fillWidth: true
          text: option.text
          textFormat: Text.PlainText
          font: option.font
          color: Commons.Color.popups.text
          elide: Text.ElideRight
        }
        Text {
          text: Qt.formatDateTime(new Date(option.modelData.timestamp), "ddd, h:mm AP")
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          color: Qt.alpha(Commons.Color.popups.text, 0.65)
        }
      }
      onTriggered: root.selected("at:" + modelData.timestamp)
    }
    onObjectAdded: function(index, object) { root.insertItem(index, object) }
    onObjectRemoved: function(index, object) { root.removeItem(object) }
  }
  MenuSeparator {
    contentItem: Rectangle {
      implicitWidth: Style.space(300)
      implicitHeight: Style.spacing.hairline
      color: Qt.alpha(Commons.Color.popups.text, 0.15)
    }
  }
  NotificationMenuItem {
    text: "󰃭  Pick date & time"
    onTriggered: root.customRequested()
  }
}
