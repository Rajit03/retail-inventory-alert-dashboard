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
    @DisplayName("J7: Role-Based Access Journey - Unauthenticated redirect, staff permissions, and manager privileges")
    public void testRoleAccessAndPermissions() {
        LoginPage loginPage = new LoginPage(driver, wait, baseUrl);
        ItemCatalogPage catalogPage = new ItemCatalogPage(driver, wait, baseUrl);

        // 1. Unauthenticated /items redirects to /login
        driver.manage().deleteAllCookies();
        driver.get(baseUrl + "/items");
        wait.until(ExpectedConditions.urlContains("/login"));
        assertTrue(driver.getCurrentUrl().contains("/login"), "Expected unauthenticated /items to redirect to /login");

        // 2. Staff login - can add an item, but Delete button is hidden
        loginPage.open();
        loginPage.login("staff", TestConfig.getStaffPassword());
        wait.until(ExpectedConditions.urlContains("/items"));

        // Verify "+ Add Item" is visible for staff
        assertTrue(catalogPage.hasAddNewItemButton(), "Staff member should see the 'Add item' action");

        // Verify Delete button is hidden for staff
        assertFalse(driver.findElements(By.cssSelector("[data-testid='delete-item-button']")).stream().anyMatch(WebElement::isDisplayed),
                "Staff member must not see the 'Delete item' action");

        // Staff creates an item
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

        // Logout staff
        loginPage.logout();
        wait.until(ExpectedConditions.urlContains("/login"));

        // 3. Manager login - can see Delete button and delete item
        loginPage.login("manager", TestConfig.getManagerPassword());
        wait.until(ExpectedConditions.urlContains("/items"));

        // Verify Delete button is present for manager
        assertTrue(driver.findElements(By.cssSelector("[data-testid='delete-item-button']")).stream().anyMatch(WebElement::isDisplayed),
                "Manager should see the 'Delete item' action");
    }
}
