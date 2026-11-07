import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/Usage.js" as Usage

Item {
    id: window
    property url iconDirectory: ""
    property string applicationVersion: Qt.application.version
    required property var backend
    readonly property var desktop: backend
    signal actionRequested(string page)
    signal dismissed()
    signal quitRequested()
    implicitWidth: 310
    implicitHeight: Math.min(720, bodyContent.height + footer.implicitHeight +
        (switcher.visible ? 70 : 0) + 16)
    property int selectedIndex: 0 // -1 is Overview; entries may include multiple accounts.
    readonly property var selectedEntry: selectedIndex >= 0 && selectedIndex < desktop.entries.length ?
        desktop.entries[selectedIndex] : null
    readonly property var selectedCost: selectedEntry ? costFor(selectedEntry.provider) : null
    readonly property color primaryText: nativePalette.windowText
    readonly property color secondaryText: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.65)
    readonly property color accent: nativePalette.highlight
    readonly property color meterColor: "#10a37f"
    readonly property color trackColor: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.14)
    readonly property color dividerColor: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.17)
    readonly property color hoverColor: Qt.rgba(primaryText.r, primaryText.g, primaryText.b, 0.08)

    function costFor(provider) {
        for (var i = 0; i < desktop.spending.length; ++i) {
            if (desktop.spending[i].provider === provider) return desktop.spending[i];
        }
        return null;
    }
    function openPage(page) { actionRequested(page); }

    Shortcut { sequence: "Ctrl+R"; onActivated: desktop.refresh() }
    Shortcut { sequence: "Ctrl+,"; onActivated: window.openPage("settings") }
    Shortcut { sequence: "Ctrl+Q"; onActivated: window.quitRequested() }
    Shortcut { sequence: "Escape"; onActivated: window.dismissed() }
    Connections {
        target: desktop
        function onChanged() {
            if (desktop.entries.length && window.selectedIndex >= desktop.entries.length)
                window.selectedIndex = 0;
        }
    }
    SystemPalette { id: nativePalette }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flickable {
            id: switcher
            objectName: "providerSwitcher"
            visible: desktop.entries.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 69 : 0
            clip: true
            contentWidth: tabs.implicitWidth + 32
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: tabs
                x: 16
                spacing: 3
                height: parent.height - 6
                Item {
                    width: 72; height: parent.height
                    Rectangle {
                        anchors.fill: parent; anchors.bottomMargin: 4
                        radius: 9
                        color: window.selectedIndex === -1 ? window.accent : "transparent"
                    }
                    Label {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -7
                        text: "▦"
                        color: window.selectedIndex === -1 ? "white" : window.secondaryText
                        font.pixelSize: 17
                    }
                    Label {
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Overview"
                        color: window.selectedIndex === -1 ? "white" : window.secondaryText
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Overview"
                        onClicked: window.selectedIndex = -1
                        Keys.onReturnPressed: window.selectedIndex = -1
                        Keys.onSpacePressed: window.selectedIndex = -1
                    }
                }
                Repeater {
                    model: switcher.visible ? desktop.entries : []
                    Item {
                        required property var modelData
                        required property int index
                        width: 72; height: tabs.height
                        readonly property bool selected: window.selectedIndex === index
                        readonly property var firstWindow: modelData.windows.length ? modelData.windows[0] : null
                        Rectangle {
                            anchors.fill: parent; anchors.bottomMargin: 4
                            radius: 9
                            color: selected ? window.accent : "transparent"
                        }
                        Image {
                            id: providerIcon
                            source: window.iconDirectory.toString() !== "" ? window.iconDirectory + "/ProviderIcon-" + Usage.providerName(modelData.provider).replace(/ /g, "") + ".svg" : "image://provider-icon/" + modelData.provider + "?color=" +
                                (selected ? "ffffff" : window.secondaryText.toString().slice(1))
                            width: 18; height: 18
                            sourceSize.width: 36; sourceSize.height: 36
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 5
                            visible: status === Image.Ready
                        }
                        Label {
                            visible: providerIcon.status !== Image.Ready
                            text: Usage.providerName(modelData.provider).slice(0, 2).toUpperCase()
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 5
                            font.pixelSize: 12; font.bold: true
                            color: selected ? "white" : window.secondaryText
                        }
                        Label {
                            text: Usage.providerName(modelData.provider)
                            width: parent.width - 6
                            x: 3; y: 28
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: 11
                            color: selected ? "white" : window.secondaryText
                            textFormat: Text.PlainText
                        }
                        Rectangle {
                            x: 10; width: parent.width - 20; height: 3
                            y: parent.height - 10; radius: 2
                            color: selected ? Qt.rgba(1, 1, 1, 0.4) : window.trackColor
                            Rectangle {
                                width: parent.width * (firstWindow ? 100 - firstWindow.remaining : 0) / 100
                                height: parent.height; radius: parent.radius
                                color: selected ? "white" : window.meterColor
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: Usage.providerName(modelData.provider) +
                                (modelData.accountLabel ? " " + modelData.accountLabel : "")
                            onClicked: window.selectedIndex = index
                            Keys.onReturnPressed: window.selectedIndex = index
                            Keys.onSpacePressed: window.selectedIndex = index
                        }
                    }
                }
            }
        }

        Rectangle { visible: switcher.visible; Layout.fillWidth: true; height: 1; color: window.dividerColor }

        Flickable {
            id: bodyScroll
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumHeight: 0
            clip: true
            contentWidth: width
            contentHeight: bodyContent.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: bodyContent
                width: bodyScroll.width
                spacing: 14
                Item { height: 6 }

                Label {
                    visible: desktop.entries.length === 0
                    text: desktop.busy ? "Loading usage…" : desktop.error || "No providers to show. Enable one in Settings."
                    x: 20; width: parent.width - 40
                    color: window.secondaryText
                    wrapMode: Text.Wrap
                }

                ColumnLayout {
                    visible: window.selectedIndex === -1 && desktop.entries.length > 0
                    x: 20; width: parent.width - 40
                    spacing: 12
                    Label {
                        text: "Overview"
                        color: window.primaryText
                        font.pixelSize: 13; font.weight: Font.DemiBold
                    }
                    Label {
                        text: desktop.busy ? "Refreshing usage…" : desktop.stale ?
                            "Usage may be out of date" : desktop.updated ? "Updated " + desktop.updated : "Waiting for usage…"
                        color: window.secondaryText; font.pixelSize: 12
                    }
                    Repeater {
                        model: desktop.entries
                        Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            radius: 10
                            color: window.hoverColor
                            ColumnLayout {
                                id: overviewContent
                                anchors.fill: parent; anchors.margins: 11
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        text: Usage.providerName(modelData.provider)
                                        color: window.primaryText
                                        font.pixelSize: 14; font.weight: Font.DemiBold
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }
                                    Label {
                                        text: modelData.windows.length ?
                                            Usage.quotaValue(modelData.windows[0].remaining, desktop.settings.quotaDisplay) + "% " +
                                            (desktop.settings.quotaDisplay === "used" ? "used" : "left") : "—"
                                        color: window.secondaryText; font.pixelSize: 12
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 3; color: window.trackColor
                                    Rectangle {
                                        width: parent.width * (modelData.windows.length ?
                                            Usage.quotaValue(modelData.windows[0].remaining, desktop.settings.quotaDisplay) : 0) / 100
                                        height: parent.height; radius: parent.radius; color: window.meterColor
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                activeFocusOnTab: true
                                Accessible.role: Accessible.Button
                                Accessible.name: "Show " + Usage.providerName(modelData.provider)
                                onClicked: window.selectedIndex = index
                                Keys.onReturnPressed: window.selectedIndex = index
                                Keys.onSpacePressed: window.selectedIndex = index
                            }
                        }
                    }
                }

                Column {
                    visible: window.selectedEntry !== null
                    x: 20; width: parent.width - 40
                    spacing: 6
                    RowLayout {
                        width: parent.width
                        Label {
                            text: window.selectedEntry ? Usage.providerName(window.selectedEntry.provider) : ""
                            color: window.primaryText
                            font.pixelSize: 13; font.weight: Font.DemiBold
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Label {
                            text: window.selectedEntry ? window.selectedEntry.accountLabel : ""
                            visible: text !== ""
                            color: window.secondaryText
                            font.pixelSize: 12; elide: Text.ElideMiddle
                            Layout.maximumWidth: 150
                            textFormat: Text.PlainText
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Label {
                            text: desktop.busy ? "Refreshing usage…" : desktop.stale ?
                                "Usage may be out of date" : desktop.updated ? "Updated " + desktop.updated : "Waiting for usage…"
                            color: window.secondaryText; font.pixelSize: 12
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }
                        Label {
                            text: window.selectedEntry ? window.selectedEntry.plan : ""
                            visible: text !== ""
                            color: window.secondaryText; font.pixelSize: 12
                            textFormat: Text.PlainText
                        }
                    }
                    Label {
                        visible: text !== ""
                        text: window.selectedEntry ? window.selectedEntry.error || (window.selectedEntry.statusLevel !== "none" ? window.selectedEntry.status : "") : ""
                        color: window.selectedEntry && window.selectedEntry.error ? "#cf7443" : window.secondaryText
                        font.pixelSize: 12; wrapMode: Text.Wrap
                        width: parent.width; textFormat: Text.PlainText
                    }
                    Rectangle { width: parent.width; height: 1; color: window.dividerColor }
                    Repeater {
                        model: window.selectedEntry ? window.selectedEntry.windows : []
                        MenuMetric {
                            required property var modelData
                            width: parent.width
                            metric: modelData
                            quotaDisplay: desktop.settings.quotaDisplay
                            resetDisplay: desktop.settings.resetDisplay
                            showPace: desktop.settings.showPace
                            warningColors: desktop.settings.warningColors
                            notifyThreshold: desktop.settings.notifyThreshold
                            accent: window.meterColor
                            primaryText: window.primaryText
                            secondaryText: window.secondaryText
                            trackColor: window.trackColor
                        }
                    }
                    ColumnLayout {
                        visible: window.selectedEntry && window.selectedEntry.resetCredits !== null && window.selectedEntry.resetCredits !== undefined
                        width: parent.width; spacing: 6
                        Rectangle { Layout.fillWidth: true; height: 1; color: window.dividerColor }
                        Label { text: "한도 재설정 크레딧"; color: window.primaryText; font.pixelSize: 13; font.bold: true }
                        Label {
                            text: window.selectedEntry && window.selectedEntry.resetCredits ? window.selectedEntry.resetCredits.available + "회 사용 가능" : ""
                            color: window.secondaryText; font.pixelSize: 12
                        }
                    }
                    ColumnLayout {
                        visible: desktop.settings.showCredits !== false && window.selectedEntry && window.selectedEntry.credits !== null &&
                            window.selectedEntry.credits !== undefined
                        width: parent.width
                        spacing: 9
                        Rectangle { Layout.fillWidth: true; height: 1; color: window.dividerColor }
                        Label { text: "Credits"; color: window.primaryText; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Label {
                            text: window.selectedEntry ? String(window.selectedEntry.credits) + " remaining" : ""
                            color: window.secondaryText; font.pixelSize: 13
                        }
                    }
                    ColumnLayout {
                        visible: desktop.settings.showCosts && window.selectedEntry &&
                            ["codex", "claude"].indexOf(window.selectedEntry.provider) >= 0 &&
                            (window.selectedCost !== null || desktop.costBusy || desktop.costError !== "")
                        width: parent.width
                        spacing: 8
                        Rectangle { Layout.fillWidth: true; height: 1; color: window.dividerColor }
                        Label {
                            text: desktop.costBusy ? "Reading local history…" : desktop.costError
                            visible: text !== ""
                            color: window.secondaryText; font.pixelSize: 12
                            Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                        }
                        MenuCosts {
                            Layout.fillWidth: true
                            costs: desktop.spending.filter(r => window.selectedEntry && r.provider === window.selectedEntry.provider)
                            primaryText: window.primaryText
                            secondaryText: window.secondaryText
                            barColor: window.meterColor
                        }
                    }
                    Repeater {
                        model: window.selectedEntry ? window.selectedEntry.details : []
                        ColumnLayout {
                            required property var modelData
                            width: parent.width
                            spacing: 6
                            Rectangle { Layout.fillWidth: true; height: 1; color: window.dividerColor }
                            Label {
                                text: modelData.title
                                visible: text !== ""
                                color: window.primaryText
                                font.pixelSize: 14; font.weight: Font.DemiBold
                                Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                            }
                            Repeater {
                                model: modelData.rows
                                Label {
                                    required property var modelData
                                    text: modelData.label + ": " + modelData.value +
                                        (modelData.secondaryValue ? " · " + modelData.secondaryValue : "")
                                    color: window.secondaryText
                                    font.pixelSize: 12
                                    Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText
                                }
                            }
                        }
                    }
                }
                Item { height: 6 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: window.dividerColor }
        ColumnLayout {
            id: footer
            Layout.fillWidth: true
            Layout.leftMargin: 6; Layout.rightMargin: 6
            Layout.topMargin: 6; Layout.bottomMargin: 8
            spacing: 1
            ActionRow {
                text: "Dashboard"
                visible: window.selectedEntry !== null && window.selectedEntry.provider === "codex"
                onClicked: { Qt.openUrlExternally("https://chatgpt.com/settings/usage?tab=overview"); window.dismissed(); }
            }
            ActionRow { text: "Usage & Spend…"; onClicked: window.openPage("usage") }
            ActionRow { text: "Refresh"; onClicked: desktop.refresh() }
            ActionRow { text: "Settings…"; onClicked: window.openPage("settings") }
            ActionRow { text: "About CodexBar"; onClicked: about.open() }
            ActionRow { text: "Quit"; onClicked: window.quitRequested() }
        }
    }
    Dialog {
        id: about
        anchors.centerIn: parent
        modal: true
        title: "About CodexBar"
        standardButtons: Dialog.Ok
        Label { text: "CodexBar Linux " + window.applicationVersion; padding: 14 }
    }
    component ActionRow: Button {
        Layout.fillWidth: true
        implicitHeight: 25
        flat: true
        contentItem: Label {
            text: parent.text
            color: window.primaryText
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
        }
        background: Rectangle {
            radius: 6
            color: parent.hovered || parent.down ? window.hoverColor : "transparent"
        }
    }
}
