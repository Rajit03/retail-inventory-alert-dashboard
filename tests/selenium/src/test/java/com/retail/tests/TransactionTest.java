package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.pages.ItemCatalogPage;
import com.retail.pages.TransactionPage;
import com.retail.util.ApiClient;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class TransactionTest extends BaseTest {

    @Test
    @DisplayName("J3: Stock Transaction Journey - Deduct stock and prevent overdraft")
    public void testStockTransactions() {
        ApiClient apiClient = new ApiClient();
        String itemName = TestData.uniqueItemName("TxItem");
        apiClient.createItem(itemName, TestData.DEFAULT_CATEGORY, TestData.DEFAULT_PRICE, 20, 10);

        TransactionPage txPage = new TransactionPage(driver, wait, baseUrl);
        ItemCatalogPage catalogPage = new ItemCatalogPage(driver, wait, baseUrl);

        txPage.recordTransaction(itemName, "OUT", 5);

        catalogPage.open();
        assertEquals(15, catalogPage.getItemQuantity(itemName), "Catalogue quantity should be 15 after OUT of 5");

        txPage.openIndex();
        assertTrue(txPage.hasTransaction(itemName, "OUT", 5), "Transaction history should record OUT of 5");

        txPage.recordTransaction(itemName, "OUT", 100);

        assertTrue(txPage.isErrorAlertDisplayed(), "Error alert should appear when deducting more than current stock");

        catalogPage.open();
        assertEquals(15, catalogPage.getItemQuantity(itemName), "Catalogue quantity should remain 15 after failed transaction");
    }
}
