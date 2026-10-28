import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui
import "../Attention.js" as Attention

Popup {
  id: root
  property string dateText: ""
  property string timeText: "08:00"
  property date pageDate: new Date()
  property double now: Date.now()
  readonly property double deadline: Attention.parseLocalDateTime(dateText, timeText, now)
  readonly property var surfaceBorder: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Math.max(1, Style.space(2)))
  signal chosen(double timestamp)
  width: Math.min(Style.space(340), parent.width - Style.gapsOut * 2)
  implicitHeight: form.implicitHeight + topPadding + bottomPadding
  x: (parent.width - width) / 2
  y: Math.max(Style.gapsOut, (parent.height - height) / 2)
  modal: true
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  leftPadding: Border.left(surfaceBorder) + Style.spacing.popupPadding
  rightPadding: Border.right(surfaceBorder) + Style.spacing.popupPadding
  topPadding: Border.top(surfaceBorder) + Style.spacing.popupPadding
  bottomPadding: Border.bottom(surfaceBorder) + Style.spacing.popupPadding
  Overlay.modal: Rectangle { color: Commons.Color.menu.scrim }
  background: Ui.BorderSurface {
    color: Commons.Color.popups.background
    borderSpec: root.surfaceBorder
    radius: Style.cornerRadius
  }
  function show() {
    now = Date.now()
    var initial = new Date(now + 3600000)
    dateText = Qt.formatDate(initial, "yyyy-MM-dd")
    timeText = Qt.formatTime(initial, "HH:mm")
    pageDate = new Date(initial.getFullYear(), initial.getMonth(), 1, 12)
    open()
    Qt.callLater(function() { dateField.forceActiveFocus() })
  }
  function turnMonth(offset) { pageDate = new Date(pageDate.getFullYear(), pageDate.getMonth() + offset, 1, 12) }
  Timer { interval: 1000; repeat: true; running: root.opened; onTriggered: root.now = Date.now() }
  contentItem: ColumnLayout {
    id: form
    spacing: Style.spacing.rowGap
    Text {
      text: "Pick date & time"
      font.family: Style.font.family
      font.pixelSize: Style.font.title
      font.bold: true
      color: Commons.Color.popups.text
    }
    RowLayout {
      Layout.fillWidth: true
      ActionButton { text: "‹"; Accessible.name: "Previous month"; subtle: true; onClicked: root.turnMonth(-1) }
      Text {
        Layout.fillWidth: true
        text: Qt.formatDate(root.pageDate, "MMMM yyyy")
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: Commons.Color.popups.text
      }
      ActionButton { text: "›"; Accessible.name: "Next month"; subtle: true; onClicked: root.turnMonth(1) }
    }
    DayOfWeekRow {
      Layout.fillWidth: true
      locale: grid.locale
      delegate: Text {
        required property var model
        text: model.shortName
        horizontalAlignment: Text.AlignHCenter
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: Qt.alpha(Commons.Color.popups.text, 0.65)
      }
    }
    MonthGrid {
      id: grid
      Layout.fillWidth: true
      Layout.preferredHeight: Style.spacing.controlHeight * 6
      month: root.pageDate.getMonth()
      year: root.pageDate.getFullYear()
      locale: Qt.locale()
      delegate: Ui.Button {
        required property var model
        text: String(model.day)
        fontSize: Style.font.body
        horizontalPadding: 0
        verticalPadding: 0
        focusable: true
        selected: root.dateText === Qt.formatDate(model.date, "yyyy-MM-dd")
        foreground: Qt.alpha(Commons.Color.popups.text, model.month === grid.month ? 1 : 0.35)
        Accessible.name: Qt.formatDate(model.date, "dddd, MMMM d, yyyy")
        onClicked: root.dateText = Qt.formatDate(model.date, "yyyy-MM-dd")
      }
    }
    RowLayout {
      Layout.fillWidth: true
      Ui.TextField {
        id: dateField
        Layout.fillWidth: true
        Accessible.name: "Snooze date, year-month-day"
        placeholderText: "YYYY-MM-DD"
        text: root.dateText
        onTextEdited: root.dateText = text
      }
      Ui.TextField {
        Layout.preferredWidth: Style.space(85)
        Accessible.name: "Snooze time, 24-hour clock"
        placeholderText: "HH:MM"
        text: root.timeText
        onTextEdited: root.timeText = text
      }
    }
    Text {
      Layout.fillWidth: true
      text: root.deadline > 0 ? "Your local time · " + Qt.formatDateTime(new Date(root.deadline), "ddd, d MMM h:mm AP") : "Enter a valid future date and time."
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: root.deadline > 0 ? Qt.alpha(Commons.Color.popups.text, 0.65) : Commons.Color.urgent
      wrapMode: Text.Wrap
    }
    RowLayout {
      Layout.fillWidth: true
      Item { Layout.fillWidth: true }
      ActionButton { text: "Cancel"; subtle: true; onClicked: root.close() }
      ActionButton {
        text: "Snooze"
        enabled: root.deadline > 0
        onClicked: { var timestamp = root.deadline; if (timestamp > Date.now()) { root.chosen(timestamp); root.close() } }
      }
    }
  }
}
