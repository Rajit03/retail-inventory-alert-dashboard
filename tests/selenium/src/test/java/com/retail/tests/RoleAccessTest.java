package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.config.TestConfig;
import com.retail.pages.ItemCatalogPage;
import com.retail.pages.ItemFormPage;
import com.retail.pages.LoginPage;
import com.retail.util.TestData;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class RoleAccessTest extends BaseTest {

    @Override
    protected boolean shouldAutoLogin() {
        return false;
    }

    @Test
    @DisplayName("J7: Role-Based Access Journey - Unauthenticated redirect, purchasing restrictions, staff capabilities")
    public void testRoleAccessAndPermissions() {
        LoginPage loginPage = new LoginPage(driver, wait, baseUrl);
        ItemCatalogPage catalogPage = new ItemCatalogPage(driver, wait, baseUrl);

        // 1. Unauthenticated /items redirects to /login
        driver.manage().deleteAllCookies();
        driver.get(baseUrl + "/items");
        wait.until(ExpectedConditions.urlContains("/login"));
        assertTrue(driver.getCurrentUrl().contains("/login"), "Expected unauthenticated /items to redirect to /login");

        // 2. Purchasing does not see the "Add item" action and gets forbidden-message on /items/new
        loginPage.open();
        loginPage.login("purchasing", TestConfig.getPurchasingPassword());
        wait.until(ExpectedConditions.urlMatches(".*/(items|alerts).*"));

        // Navigate to /items and verify "Add item" is hidden
        driver.get(baseUrl + "/items");
        wait.until(ExpectedConditions.presenceOfElementLocated(By.cssSelector("[data-testid='search-input']")));
        assertFalse(catalogPage.hasAddNewItemButton(), "Purchasing officer must not see the 'Add item' action");

        // Attempt direct access to /items/new -> forbidden-message
        driver.get(baseUrl + "/items/new");
        WebElement forbidden = wait.until(ExpectedConditions.visibilityOfElementLocated(By.cssSelector("[data-testid='forbidden-message']")));
        assertTrue(forbidden.isDisplayed(), "Expected forbidden-message on direct navigation to /items/new for purchasing role");

        // Logout
        loginPage.logout();

        // 3. Staff can add an item
        loginPage.open();
        loginPage.login("staff", TestConfig.getStaffPassword());
        wait.until(ExpectedConditions.urlContains("/items"));

        ItemFormPage formPage = new ItemFormPage(driver, wait, baseUrl);
        formPage.open();

        String uniqueName = TestData.uniqueItemName("StaffItem");
        String category = TestData.DEFAULT_CATEGORY;
        double price = 29.99;
        int quantity = 15;
        int threshold = 5;

        formPage.fillForm(uniqueName, category, price, quantity, threshold);
        formPage.submit();

        wait.until(ExpectedConditions.not(ExpectedConditions.urlContains("/items/new")));
        wait.until(ExpectedConditions.urlContains("/items"));
        wait.until(d -> catalogPage.hasItem(uniqueName));
        assertTrue(catalogPage.hasItem(uniqueName), "Expected staff member to successfully add an item to the catalogue");
    }
}
