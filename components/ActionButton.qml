import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

// Use the same control implementation as Omarchy's native shell panels.
Ui.Button {
  property bool subtle: false
  property bool danger: false
  focusable: true
  bordered: !subtle
  foreground: danger ? Commons.Color.urgent : Commons.Color.foreground
  background: subtle ? "transparent" : Style.normalFill
  fontFamily: Style.font.family
  fontSize: Style.font.body
  Accessible.role: Accessible.Button
  Accessible.name: text
}
