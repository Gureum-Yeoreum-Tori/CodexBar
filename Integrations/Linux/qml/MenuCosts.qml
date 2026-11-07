import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../Shared/Usage.js" as Usage

ColumnLayout {
    id: root
    objectName: "costDashboard"
    required property var costs
    required property color primaryText
    required property color secondaryText
    property color barColor: "#10a37f"
    property string selectedDevice: "mac"
    property bool tokensMode: false
    property int selectedDay: -1
    readonly property var deviceRecords: costs || []
    readonly property var sources: deviceRecords.length > 1 ? deviceRecords.concat([combined()]) : deviceRecords
    readonly property var record: sources.find(r => r.device === selectedDevice) || sources[0] || null
    readonly property var days: record && record.daily ? record.daily : []
    readonly property var currencySource: sources.find(r => r.device === "mac") || record
    readonly property string currency: currencySource ? currencySource.currency || "USD" : "USD"
    readonly property real rate: currencySource ? currencySource.exchangeRate || 1 : 1
    readonly property real maximum: Math.max(1, ...days.map(d => (tokensMode ? d.totalTokens : d.totalCost) || 0))
    spacing: 9
    function combined() {
        function sum(key, rows) {
            return rows.every(r => Usage.number(r[key]) !== null) ? rows.reduce((a, r) => a + r[key], 0) : null;
        }
        var dates = [];
        deviceRecords.forEach(r => (r.daily || []).forEach(d => { if (dates.indexOf(d.date) < 0) dates.push(d.date); }));
        dates.sort();
        var daily = dates.slice(-30).map(date => {
            var rows = deviceRecords.map(r => (r.daily || []).find(d => d.date === date) || {});
            return {date: date, totalCost: sum("totalCost", rows), totalTokens: sum("totalTokens", rows)};
        });
        return {device: "total", today: sum("today", deviceRecords), month: sum("month", deviceRecords),
            todayTokens: sum("todayTokens", deviceRecords), tokens: sum("tokens", deviceRecords), daily: daily,
            coverage: deviceRecords.every(r => r.coverage === "Local history") ? "Local history" : "일부 기록이 불완전합니다.",
            error: deviceRecords.some(r => r.error) ? "일부 기기의 기록을 갱신하지 못했습니다." : ""};
    }
    function compact(value) {
        if (Usage.number(value) === null) return "—";
        if (value >= 1000000) return (value / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
        if (value >= 1000) return (value / 1000).toFixed(1).replace(/\.0$/, "") + "K";
        return String(Math.round(value));
    }
    function money(value) {
        if (Usage.number(value) === null) return "—";
        return (currency === "KRW" ? "₩" : currency === "USD" ? "$" : currency + " ") +
            (value * rate).toFixed(currency === "KRW" ? 0 : 2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }
    function recent() {
        var result = [];
        for (var index = 0; index < 4; index++) {
            var end = days.length - index * 7;
            var group = days.slice(Math.max(0, end - 7), end);
            if (!group.length) continue;
            var known = group.every(d => Usage.number(d.totalCost) !== null);
            var knownTokens = group.every(d => Usage.number(d.totalTokens) !== null);
            result.push({label: index === 0 ? "최근 7일" : (index * 7 + 1) + "–" + ((index + 1) * 7) + "일 전",
                range: group[0].date + " – " + group[group.length - 1].date,
                cost: known ? group.reduce((a, d) => a + d.totalCost, 0) : null,
                tokens: knownTokens ? group.reduce((a, d) => a + d.totalTokens, 0) : null});
        }
        return result;
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: "사용량 기록"; color: root.primaryText; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
        Repeater {
            model: root.sources
            Button {
                required property var modelData
                objectName: "cost-device-" + modelData.device
                implicitWidth: 42
                Layout.minimumWidth: 38
                Layout.preferredWidth: 42
                font.pixelSize: 12
                text: modelData.device === "mac" ? "Mac" : modelData.device === "total" ? "합계" : "Arch"
                checkable: true
                checked: root.record === modelData
                implicitHeight: 25
                onClicked: { root.selectedDevice = modelData.device || "local"; root.selectedDay = -1; }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        visible: root.record !== null && (root.record.device === "mac" || root.record.device === "total")
        text: root.currencySource && root.currencySource.collectedAt ? "Mac 동기화 · " + new Date(root.currencySource.collectedAt).toLocaleString(Qt.locale("ko_KR"), "MM/dd HH:mm") +
            (Date.now() - Date.parse(root.currencySource.collectedAt) > 900000 ? " · 마지막 저장 기록" : "") : ""
        color: root.secondaryText; font.pixelSize: 11; wrapMode: Text.Wrap
    }
    GridLayout {
        columns: 2; columnSpacing: 20; rowSpacing: 8; Layout.fillWidth: true
        Repeater {
            model: root.record ? [
                {title: "오늘", value: root.money(root.record.today)},
                {title: "오늘 토큰", value: root.compact(root.record.todayTokens)},
                {title: "30일", value: root.money(root.record.month)},
                {title: "30일 토큰", value: root.compact(root.record.tokens)}] : []
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true; spacing: 1
                Label { text: modelData.title; color: root.secondaryText; font.pixelSize: 12 }
                Label { text: modelData.value; color: root.primaryText; font.pixelSize: 15; font.bold: true }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { text: root.tokensMode ? root.compact(root.maximum) : root.money(root.maximum); color: root.secondaryText; font.pixelSize: 11; Layout.fillWidth: true }
        Button { text: "비용"; checkable: true; checked: !root.tokensMode; implicitHeight: 24; onClicked: root.tokensMode = false }
        Button { text: "토큰"; checkable: true; checked: root.tokensMode; implicitHeight: 24; onClicked: root.tokensMode = true }
    }
    Item {
        Layout.fillWidth: true; implicitHeight: 58
        Row {
            anchors.fill: parent; spacing: 2
            Repeater {
                model: root.days
                Item {
                    required property var modelData
                    required property int index
                    width: Math.max(1, (parent.width - (root.days.length - 1) * 2) / Math.max(1, root.days.length)); height: parent.height
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width; radius: 1.5
                        property var value: root.tokensMode ? modelData.totalTokens : modelData.totalCost
                        height: value === null ? 1 : Math.max(1, parent.height * value / root.maximum)
                        color: root.barColor; opacity: root.selectedDay === index ? 1 : 0.7
                    }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.selectedDay = index; onClicked: root.selectedDay = index }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.secondaryText; font.pixelSize: 11
        text: root.selectedDay >= 0 && root.selectedDay < root.days.length ?
            root.days[root.selectedDay].date + " · " + root.money(root.days[root.selectedDay].totalCost) + " · " + root.compact(root.days[root.selectedDay].totalTokens) + " 토큰" : "일별 막대에 마우스를 올려 상세 사용량 보기"
    }
    Label { text: "최근 구간 · 일별 기록 기준"; color: root.primaryText; font.pixelSize: 12; font.bold: true }
    Repeater {
        model: root.recent()
        ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 1
            RowLayout {
                Layout.fillWidth: true
                Label { text: modelData.label; color: root.primaryText; font.pixelSize: 12; Layout.fillWidth: true }
                Label { text: root.money(modelData.cost) + " · " + root.compact(modelData.tokens); color: root.primaryText; font.pixelSize: 12 }
            }
            Label { text: modelData.range; color: root.secondaryText; font.pixelSize: 11 }
        }
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.secondaryText; font.pixelSize: 11
        text: "토큰 사용량 기반 추정 · 구독 청구서가 아닙니다.\n" +
            (root.record && root.record.device === "total" ? "기기별 합계 · 복제된 기록은 중복 포함될 수 있습니다.\n" : "") +
            "최근 구간은 한도 재설정 시각과 다를 수 있습니다."
    }
    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.secondaryText; font.pixelSize: 11
        visible: root.record !== null && (root.record.coverage !== "Local history" || root.record.error !== "")
        text: root.record ? [root.record.error, root.record.coverage].filter(Boolean).join(" · ") : ""
    }
}
