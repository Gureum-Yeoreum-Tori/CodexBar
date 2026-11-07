import QtQuick
import QtTest
import "../../qml" as Desktop

TestCase {
    id: testCase
    name: "QuickView"
    when: windowShown
    QtObject {
        id: desktop
        property var settings: ({showCosts: true, quotaDisplay: "remaining", resetDisplay: "countdown",
            showPace: true, warningColors: true, notifyThreshold: 10})
        property var entries: [{provider: "codex", accountLabel: "", plan: "Synthetic plan",
            windows: [{label: "Session", remaining: 60, resetsAt: "2030-01-01T00:00:00Z", pace: ""}],
            credits: null, error: "", status: "", details: []}]
        property var spending: []
        property bool busy: false
        property bool stale: false
        property string updated: "just now"
        property string error: ""
        property bool costBusy: false
        property string costError: ""
        signal changed()
        function refresh() {}
        function showWindow(page) {}
    }
    property var view: null
    Component { id: viewComponent; Desktop.QuickView {} }

    function textItem(item, text) {
        if (item.text === text && item.visible) return item;
        for (var i = 0; i < item.children.length; ++i) {
            var found = textItem(item.children[i], text);
            if (found) return found;
        }
        return null;
    }
    function shown(text) { return textItem(view.contentItem, text) !== null; }
    function init() {
        desktop.settings = {showCosts: true, quotaDisplay: "remaining", resetDisplay: "countdown",
            showPace: true, warningColors: true, notifyThreshold: 10};
        desktop.spending = [{provider: "codex", today: 3, month: 12, tokens: 100, provenance: "local",
            device: "local", todayTokens: 12500, daily: [{date: "2030-01-01", totalCost: 3, totalTokens: 12500}], coverage: "History may be incomplete", error: "Synthetic provider cost error"}];
        desktop.costError = "Local spending could not be refreshed. Previous data may be stale.";
        desktop.costBusy = false;
        view = createTemporaryObject(viewComponent, testCase, {visible: true});
        verify(view);
    }
    function test_retainedCostShowsRefreshError() {
        tryVerify(function() { return shown(desktop.costError); });
        verify(shown("오늘"));
        verify(shown("$3.00"));
    }
    function test_partialCostShowsCoverageAndProviderError() {
        tryVerify(function() { return shown("Synthetic provider cost error · History may be incomplete"); });
        verify(shown("Synthetic provider cost error · History may be incomplete"));
    }
    function test_firstFailureIsVisibleWithoutCachedTotals() {
        desktop.spending = [];
        tryVerify(function() { return shown(desktop.costError); });
    }
    function test_refreshingRetainedCostIsVisible() {
        desktop.costError = "";
        desktop.costBusy = true;
        tryVerify(function() { return shown("Reading local history…"); });
    }
    function test_disabledCostsHideErrorsAndTotals() {
        desktop.settings = {showCosts: false, quotaDisplay: "remaining", resetDisplay: "countdown",
            showPace: true, warningColors: true, notifyThreshold: 10};
        tryVerify(function() { return !shown("사용량 기록"); });
        verify(!shown(desktop.costError));
    }
    function test_singleProviderUsesCompactMacLayout() {
        compare(view.width, 310);
        var switcher = findChild(view.contentItem, "providerSwitcher");
        verify(switcher);
        verify(!switcher.visible);
        verify(view.height <= 720);
        verify(shown("Refresh"));
        verify(shown("Dashboard"));
    }
    function test_macSourceAndArchSwitch() {
        desktop.spending = desktop.spending.concat([{provider: "codex", device: "mac", today: 5, month: 20,
            todayTokens: 800, tokens: 4000, currency: "KRW", exchangeRate: 1400, collectedAt: "2030-01-01T00:00:00Z",
            daily: [], error: "", coverage: "Local history"}]);
        tryVerify(function() { return shown("₩7,000"); });
        var arch = findChild(view.contentItem, "cost-device-local");
        verify(arch);
        waitForRendering(arch);
        mouseClick(arch, arch.width / 2, arch.height / 2);
        compare(findChild(view.contentItem, "costDashboard").selectedDevice, "local");
        tryVerify(function() { return shown("₩4,200"); });
        var total = findChild(view.contentItem, "cost-device-total");
        verify(total); mouseClick(total, total.width / 2, total.height / 2);
        tryVerify(function() { return shown("₩11,200"); });
        verify(shown("₩44,800"));
    }
    function test_syntheticRender() {
        tryVerify(function() { return shown("사용량 기록"); });
        grabImage(view.contentItem).save(".local/quick-view-synthetic.png");
    }
}
