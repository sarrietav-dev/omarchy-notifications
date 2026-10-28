import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

MenuItem {
  id: root
  implicitHeight: Math.max(Style.spacing.popupRowHeight, label.implicitHeight + topPadding + bottomPadding)
  leftPadding: Style.spacing.controlPaddingX
  rightPadding: Style.spacing.controlPaddingX
  topPadding: Style.spacing.controlPaddingY
  bottomPadding: Style.spacing.controlPaddingY
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  contentItem: Text {
    id: label
    text: root.text
    textFormat: Text.PlainText
    font: root.font
    color: Qt.alpha(Commons.Color.popups.text, root.enabled ? 1 : 0.45)
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }
  background: Ui.BorderSurface {
    readonly property bool hot: root.highlighted || root.hovered || root.activeFocus
    radius: Style.cornerRadius
    color: root.down ? Style.pressedFill : hot ? Style.hoverFill : "transparent"
    borderSpec: hot ? Border.controlSpec("hover-cursor", Commons.Color.popups.text, Commons.Color.accent) : Border.none()
  }
}
