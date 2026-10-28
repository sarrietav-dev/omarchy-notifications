import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons

ScrollBar {
  id: root
  policy: ScrollBar.AsNeeded
  padding: Style.spacing.xxs
  contentItem: Rectangle {
    implicitWidth: Style.space(4)
    implicitHeight: Style.space(36)
    radius: Style.cornerRadius
    color: Qt.alpha(Commons.Color.popups.text, root.pressed ? 0.7 : 0.3)
    opacity: root.active || root.pressed ? 1 : 0
  }
  background: Item {}
}
