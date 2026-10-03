package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.pages.ItemCatalogPage;
import com.retail.util.ApiClient;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class SearchFilterTest extends BaseTest {

    @Test
    @DisplayName("J4: Search & Filter Journey - Search prefix, filter by low stock, empty state")
    public void testSearchAndFilter() {
        ApiClient apiClient = new ApiClient();
        String prefix = "SF-" + System.currentTimeMillis();

        String inStockItem = prefix + "-InStock";
        String lowStockItem = prefix + "-LowStock";
        String outOfStockItem = prefix + "-OutOfStock";

        apiClient.createItem(inStockItem, TestData.DEFAULT_CATEGORY, 10.0, 20, 5);
        apiClient.createItem(lowStockItem, TestData.DEFAULT_CATEGORY, 10.0, 3, 5);
        apiClient.createItem(outOfStockItem, TestData.DEFAULT_CATEGORY, 10.0, 0, 5);

        ItemCatalogPage catalogPage = new ItemCatalogPage(driver, wait, baseUrl);
        catalogPage.open();

        catalogPage.search(prefix);
        assertTrue(catalogPage.hasItem(inStockItem), "In-stock item should appear in search results");
        assertTrue(catalogPage.hasItem(lowStockItem), "Low-stock item should appear in search results");
        assertTrue(catalogPage.hasItem(outOfStockItem), "Out-of-stock item should appear in search results");

        catalogPage.filterByStatus("LOW_STOCK");
        assertTrue(catalogPage.hasItem(lowStockItem), "Low-stock item should appear when filtering by LOW_STOCK");
        assertFalse(catalogPage.hasItem(inStockItem), "In-stock item should not appear when filtering by LOW_STOCK");
        assertFalse(catalogPage.hasItem(outOfStockItem), "Out-of-stock item should not appear when filtering by LOW_STOCK");

        catalogPage.search("NON_EXISTING_" + System.currentTimeMillis());
        assertTrue(catalogPage.isNoItemsFoundDisplayed(), "Should display 'No items found.' for non-existing search");
    }
}
