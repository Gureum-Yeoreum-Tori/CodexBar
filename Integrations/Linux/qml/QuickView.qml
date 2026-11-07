import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    readonly property var controller: desktop
    title: "CodexBar"
    width: 310
    height: menu.implicitHeight
    minimumWidth: 310
    minimumHeight: 180
    property alias selectedIndex: menu.selectedIndex
    onClosing: function(event) { event.accepted = false; hide(); }
    MenuContent {
        id: menu
        anchors.fill: parent
        backend: window.controller
        onActionRequested: function(page) { window.hide(); desktop.showWindow(page); }
        onDismissed: window.hide()
        onQuitRequested: Qt.quit()
    }
}
