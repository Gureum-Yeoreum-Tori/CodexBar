import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import "menu" as Menu

PlasmoidItem {
    id: root
    property var state: ({entries: [], spending: [], settings: {
        quotaDisplay: "remaining", resetDisplay: "countdown", showCosts: false,
        showCredits: false, showPace: true, warningColors: false,
        notifyThreshold: 10, refreshOnOpen: false}, busy: false,
        stale: true, error: "Waiting for CodexBar…", costBusy: false, costError: "", updated: ""})
    property bool requesting: false
    readonly property var firstWindow: state.entries.length && state.entries[0].windows.length ? state.entries[0].windows[0] : null
    readonly property string percentage: firstWindow ? Math.round(state.settings.quotaDisplay === "used" ?
        100 - firstWindow.remaining : firstWindow.remaining) + "%" : "—"
    preferredRepresentation: compactRepresentation
    toolTipMainText: "CodexBar"
    toolTipSubText: state.error || (percentage + (state.settings.quotaDisplay === "used" ? " used" : " remaining") +
        (state.stale ? " · out of date" : ""))
    property string executable: '"$HOME/.local/bin/codexbar-linux"'

    function poll() {
        if (requesting) return;
        requesting = true;
        reader.connectSource(executable + " --menu-snapshot" + (expanded && state.settings.showCosts ? " --with-spending" : ""));
    }
    function action(command) {
        commands.connectSource(executable + " --" + command);
    }
    onExpandedChanged: function() {
        poll();
        if (root.expanded && state.settings.refreshOnOpen) action("refresh");
    }
    Component.onCompleted: poll()
    Timer { interval: root.expanded ? 1000 : 5000; running: true; repeat: true; onTriggered: root.poll() }
    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            root.requesting = false;
            try {
                if (data["exit code"] !== 0) throw new Error("CodexBar is not running. Open CodexBar from the application launcher.");
                var next = JSON.parse(data.stdout);
                if (next.schemaVersion !== 1 || !Array.isArray(next.entries) || !next.settings) throw new Error("Update CodexBar to use this menu.");
                root.state = next;
                menuBackend.changed();
            } catch (error) {
                var retained = Object.assign({}, root.state);
                retained.stale = true;
                retained.error = String(error.message || error);
                root.state = retained;
            }
        }
    }
    Plasma5Support.DataSource {
        id: commands
        engine: "executable"
        onNewData: function(sourceName, data) { disconnectSource(sourceName); root.poll(); }
    }
    QtObject {
        id: menuBackend
        readonly property var entries: root.state.entries
        readonly property var spending: root.state.spending
        readonly property var settings: root.state.settings
        readonly property bool busy: root.state.busy
        readonly property bool stale: root.state.stale
        readonly property string error: root.state.error
        readonly property bool costBusy: root.state.costBusy
        readonly property string costError: root.state.costError
        readonly property string updated: root.state.updated
        signal changed()
        function refresh() { root.action("refresh"); }
    }
    compactRepresentation: Item {
        Layout.minimumWidth: label.implicitWidth + 10
        Layout.preferredWidth: label.implicitWidth + 10
        QQC2.Label {
            id: label
            anchors.centerIn: parent
            text: root.percentage
            font: Kirigami.Theme.defaultFont
            color: Kirigami.Theme.textColor
            opacity: root.state.stale ? 0.55 : 1
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
            Accessible.role: Accessible.Button
            Accessible.name: "CodexBar " + root.percentage
            activeFocusOnTab: true
            Keys.onReturnPressed: root.expanded = !root.expanded
            Keys.onSpacePressed: root.expanded = !root.expanded
        }
    }
    fullRepresentation: Menu.MenuContent {
        id: popup
        Layout.minimumWidth: 310
        Layout.maximumWidth: 310
        Layout.preferredWidth: 310
        Layout.minimumHeight: implicitHeight
        Layout.maximumHeight: implicitHeight
        Layout.preferredHeight: implicitHeight
        backend: menuBackend
        applicationVersion: "0.1.0-arch"
        iconDirectory: Qt.resolvedUrl("icons")
        onActionRequested: function(page) { root.expanded = false; root.action(page); }
        onDismissed: root.expanded = false
        onQuitRequested: { root.expanded = false; root.action("quit"); }
    }
}
