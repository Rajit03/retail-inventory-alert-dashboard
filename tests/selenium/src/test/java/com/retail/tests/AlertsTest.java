package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.pages.AlertsPage;
import com.retail.pages.TransactionPage;
import com.retail.util.ApiClient;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class AlertsTest extends BaseTest {

    @Test
    @DisplayName("J5: Exception Alerts Journey - Detect low stock alert and clear alert after replenishment")
    public void testAlertLifecycle() {
        ApiClient apiClient = new ApiClient();
        String alertItem = TestData.uniqueItemName("AlertItem");

        apiClient.createItem(alertItem, TestData.DEFAULT_CATEGORY, 25.0, 3, 10);

        AlertsPage alertsPage = new AlertsPage(driver, wait, baseUrl);
        alertsPage.open();

        assertTrue(alertsPage.hasAlertForItem(alertItem), "Expected low-stock item to appear in alerts list");
        String badge = alertsPage.getAlertBadgeForItem(alertItem);
        assertTrue(badge != null && badge.toUpperCase().contains("LOW STOCK"),
                "Expected LOW STOCK badge, but got: " + badge);

        TransactionPage txPage = new TransactionPage(driver, wait, baseUrl);
        txPage.recordTransaction(alertItem, "IN", 15);

        alertsPage.open();
        assertFalse(alertsPage.hasAlertForItem(alertItem), "Expected alert to be cleared after restocking above threshold");
    }
}
