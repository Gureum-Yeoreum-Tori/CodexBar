import QtQuick
import QtTest
import "../../Shared/Usage.js" as Usage
TestCase {
    name: "CostModel"
    function test_missingHistoryStaysUnknown() {
        var row = Usage.costs(JSON.stringify([{provider: "codex", daily: [], historyCoverageIsEstablished: false}]), "2030-01-30")[0];
        compare(row.daily.length, 30);
        compare(row.daily[0].totalCost, null);
        compare(row.todayTokens, null);
    }
    function test_macTotalsRemainSeparate() {
        var rows = Usage.costs(JSON.stringify([
            {provider: "codex", last30DaysCostUSD: 8, daily: []},
            {provider: "codex", device: "mac", last30DaysCostUSD: 12, currency: "KRW", exchangeRate: 1400,
                daily: [{date: "2030-01-30", totalCost: 3, totalTokens: 100}], historyCoverageIsEstablished: true}
        ]), "2030-01-30");
        compare(rows[0].device, "local"); compare(rows[0].month, 8);
        compare(rows[1].device, "mac"); compare(rows[1].month, 12);
        compare(rows[1].todayTokens, 100); compare(rows[1].currency, "KRW");
        compare(rows[1].daily[0].totalCost, 0); compare(rows[1].daily[29].totalCost, 3);
    }
}
