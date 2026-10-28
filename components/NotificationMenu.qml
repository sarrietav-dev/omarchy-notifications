import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Menu {
  id: root
  readonly property var surfaceBorder: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
  width: Style.spacing.searchableDropdownWidth
  font.family: Style.font.family
  font.pixelSize: Style.font.body
  leftPadding: Border.left(surfaceBorder) + Style.spacing.xxs
  rightPadding: Border.right(surfaceBorder) + Style.spacing.xxs
  topPadding: Border.top(surfaceBorder) + Style.spacing.xxs
  bottomPadding: Border.bottom(surfaceBorder) + Style.spacing.xxs
  spacing: Style.spacing.xxs
  background: Ui.BorderSurface {
    color: Commons.Color.popups.background
    borderSpec: root.surfaceBorder
    radius: Style.cornerRadius
  }
  delegate: NotificationMenuItem {}
}
