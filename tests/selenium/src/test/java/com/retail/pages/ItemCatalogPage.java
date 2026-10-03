package com.retail.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.StaleElementReferenceException;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.Select;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.util.List;

public class ItemCatalogPage {
    private final WebDriver driver;
    private final WebDriverWait wait;
    private final String url;

    private final By searchInput = By.cssSelector("[data-testid='search-input']");
    private final By statusSelect = By.cssSelector("[data-testid='status-select']");
    private final By filterButton = By.cssSelector("[data-testid='filter-button']");
    private final By resetFilterButton = By.cssSelector("[data-testid='reset-filter-button']");
    private final By itemRows = By.cssSelector("[data-testid='item-row']");
    private final By noItemsMessage = By.cssSelector("[data-testid='no-items-message']");
    private final By addNewItemButton = By.cssSelector("a[href='/items/new']");

    public ItemCatalogPage(WebDriver driver, WebDriverWait wait, String baseUrl) {
        this.driver = driver;
        this.wait = wait;
        this.url = baseUrl + "/items";
    }

    public ItemCatalogPage open() {
        driver.get(url);
        wait.until(ExpectedConditions.presenceOfElementLocated(searchInput));
        return this;
    }

    public void search(String text) {
        WebElement input = wait.until(ExpectedConditions.visibilityOfElementLocated(searchInput));
        input.clear();
        input.sendKeys(text);
        WebElement btn = wait.until(ExpectedConditions.elementToBeClickable(filterButton));
        btn.click();
        wait.until(ExpectedConditions.presenceOfElementLocated(By.tagName("body")));
    }

    public void filterByStatus(String statusValue) {
        WebElement selectElem = wait.until(ExpectedConditions.visibilityOfElementLocated(statusSelect));
        Select select = new Select(selectElem);
        select.selectByValue(statusValue);
        WebElement btn = wait.until(ExpectedConditions.elementToBeClickable(filterButton));
        btn.click();
        wait.until(ExpectedConditions.presenceOfElementLocated(By.tagName("body")));
    }

    public void resetFilters() {
        wait.until(ExpectedConditions.elementToBeClickable(resetFilterButton)).click();
    }

    public void clickAddNewItem() {
        wait.until(ExpectedConditions.elementToBeClickable(addNewItemButton)).click();
    }

    public boolean hasItem(String itemName) {
        for (int i = 0; i < 3; i++) {
            try {
                List<WebElement> rows = driver.findElements(itemRows);
                for (WebElement row : rows) {
                    List<WebElement> nameElements = row.findElements(By.cssSelector("[data-testid='item-name']"));
                    if (!nameElements.isEmpty() && nameElements.get(0).getText().trim().equals(itemName)) {
                        return true;
                    }
                }
                return false;
            } catch (StaleElementReferenceException ignored) {
                // Retry if DOM reloaded during iteration
            }
        }
        return false;
    }

    public WebElement getItemRow(String itemName) {
        for (int i = 0; i < 3; i++) {
            try {
                List<WebElement> rows = driver.findElements(itemRows);
                for (WebElement row : rows) {
                    List<WebElement> nameElements = row.findElements(By.cssSelector("[data-testid='item-name']"));
                    if (!nameElements.isEmpty() && nameElements.get(0).getText().trim().equals(itemName)) {
                        return row;
                    }
                }
                return null;
            } catch (StaleElementReferenceException ignored) {
            }
        }
        return null;
    }

    public String getItemCategory(String itemName) {
        WebElement row = getItemRow(itemName);
        if (row != null) {
            return row.findElement(By.cssSelector("[data-testid='item-category']")).getText().trim();
        }
        return null;
    }

    public int getItemQuantity(String itemName) {
        for (int i = 0; i < 3; i++) {
            try {
                WebElement row = getItemRow(itemName);
                if (row != null) {
                    String text = row.findElement(By.cssSelector("[data-testid='item-quantity']")).getText().trim();
                    return Integer.parseInt(text);
                }
                return -1;
            } catch (StaleElementReferenceException ignored) {
            }
        }
        return -1;
    }

    public int getItemRowsCount() {
        return driver.findElements(itemRows).size();
    }

    public boolean isNoItemsFoundDisplayed() {
        for (int i = 0; i < 3; i++) {
            try {
                List<WebElement> messages = driver.findElements(noItemsMessage);
                return !messages.isEmpty() && messages.get(0).isDisplayed();
            } catch (StaleElementReferenceException ignored) {
            }
        }
        return false;
    }
}
