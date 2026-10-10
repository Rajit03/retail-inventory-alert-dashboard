package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.pages.ItemFormPage;
import com.retail.util.ApiClient;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

public class InvalidItemTest extends BaseTest {

    @Test
    @DisplayName("J2: Invalid Item Validation Journey - HTML5 validation and duplicate name error")
    public void testInvalidItemValidation() {
        ItemFormPage formPage = new ItemFormPage(driver, wait, baseUrl);
        formPage.open();

        formPage.fillForm("", TestData.DEFAULT_CATEGORY, TestData.DEFAULT_PRICE, 10, 5);
        formPage.submit();

        assertTrue(driver.getCurrentUrl().contains("/items/new"), "URL should remain /items/new when validation fails");
        assertTrue(formPage.isNameValueMissing(), "Name input should have validity.valueMissing = true");

        ApiClient apiClient = new ApiClient();
        String duplicateName = TestData.uniqueItemName("Dup");
        apiClient.createItem(duplicateName, TestData.DEFAULT_CATEGORY, TestData.DEFAULT_PRICE, 15, 5);

        formPage.open();
        formPage.fillForm(duplicateName, TestData.DEFAULT_CATEGORY, TestData.DEFAULT_PRICE, 10, 5);
        formPage.submit();

        assertTrue(formPage.isErrorAlertDisplayed(), "Error alert should be displayed for duplicate name");
        String errorMsg = formPage.getErrorMessage();
        assertTrue(errorMsg.toLowerCase().contains("already exists") || errorMsg.toLowerCase().contains("error"),
                "Error message should indicate item already exists, but got: " + errorMsg);
    }
}
