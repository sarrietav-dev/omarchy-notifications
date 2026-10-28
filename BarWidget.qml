import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

Ui.WidgetButton {
  id: root
  property string moduleName: ""
  property var settings: ({})
  readonly property var service: bar && bar.shell ? bar.shell.serviceFor("sebas.notifications") : null
  readonly property int unread: service ? service.center.unreadCount : 0
  readonly property bool dnd: service ? service.doNotDisturb : false
  text: (dnd ? "󰂛" : "󰂚") + (unread > 0 && !vertical ? " " + Math.min(unread, 99) : "")
  fontSize: Style.bar.iconFont
  foreground: unread > 0 ? Commons.Color.accent : bar ? bar.barForeground : Commons.Color.bar.text
  tooltipText: "Notifications · " + unread + " unread" + (dnd ? " · Focus on" : "")
  Accessible.role: Accessible.Button
  Accessible.name: tooltipText
  onPressed: function(button) {
    if (!service) return
    if (button === Qt.RightButton) service.center.setDnd(dnd ? 0 : -1)
    else service.center.toggle()
  }
}
