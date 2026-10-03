package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.pages.ItemCatalogPage;
import com.retail.pages.ItemFormPage;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.support.ui.ExpectedConditions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class AddItemTest extends BaseTest {

    @Test
    @DisplayName("J1: Add New Item Journey - Successfully add item and verify in catalogue")
    public void testAddNewItemSuccessfully() {
        ItemFormPage formPage = new ItemFormPage(driver, wait, baseUrl);
        formPage.open();

        String uniqueName = TestData.uniqueItemName("Item");
        String category = TestData.DEFAULT_CATEGORY;
        double price = 49.99;
        int quantity = 25;
        int threshold = 10;

        formPage.fillForm(uniqueName, category, price, quantity, threshold);
        formPage.submit();

        wait.until(ExpectedConditions.urlContains("/items"));
        ItemCatalogPage catalogPage = new ItemCatalogPage(driver, wait, baseUrl);

        assertTrue(catalogPage.hasItem(uniqueName), "Expected newly added item to be present in catalogue");
        assertEquals(category, catalogPage.getItemCategory(uniqueName), "Expected category to match");
        assertEquals(quantity, catalogPage.getItemQuantity(uniqueName), "Expected quantity to match");
    }
}
