package com.retail.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.util.Locale;

public class ItemFormPage {
    private final WebDriver driver;
    private final WebDriverWait wait;
    private final String url;

    private final By nameInput = By.cssSelector("[data-testid='name-input']");
    private final By categoryInput = By.cssSelector("[data-testid='category-input']");
    private final By priceInput = By.cssSelector("[data-testid='price-input']");
    private final By quantityInput = By.cssSelector("[data-testid='quantity-input']");
    private final By thresholdInput = By.cssSelector("[data-testid='threshold-input']");
    private final By submitButton = By.cssSelector("[data-testid='submit-button']");
    private final By errorAlert = By.cssSelector("[data-testid='error-alert']");

    public ItemFormPage(WebDriver driver, WebDriverWait wait, String baseUrl) {
        this.driver = driver;
        this.wait = wait;
        this.url = baseUrl + "/items/new";
    }

    public ItemFormPage open() {
        driver.get(url);
        wait.until(ExpectedConditions.visibilityOfElementLocated(nameInput));
        return this;
    }

    public void fillForm(String name, String category, double price, int quantity, int threshold) {
        if (name != null) {
            WebElement nameEl = wait.until(ExpectedConditions.visibilityOfElementLocated(nameInput));
            nameEl.clear();
            nameEl.sendKeys(name);
        }
        if (category != null) {
            WebElement catEl = wait.until(ExpectedConditions.visibilityOfElementLocated(categoryInput));
            catEl.clear();
            catEl.sendKeys(category);
        }
        if (price >= 0) {
            WebElement priceEl = wait.until(ExpectedConditions.visibilityOfElementLocated(priceInput));
            priceEl.clear();
            priceEl.sendKeys(String.format(Locale.US, "%.2f", price));
        }
        if (quantity >= 0) {
            WebElement qtyEl = wait.until(ExpectedConditions.visibilityOfElementLocated(quantityInput));
            qtyEl.clear();
            qtyEl.sendKeys(String.valueOf(quantity));
        }
        if (threshold >= 0) {
            WebElement threshEl = wait.until(ExpectedConditions.visibilityOfElementLocated(thresholdInput));
            threshEl.clear();
            threshEl.sendKeys(String.valueOf(threshold));
        }
    }

    public void submit() {
        wait.until(ExpectedConditions.elementToBeClickable(submitButton)).click();
    }

    public boolean isNameValueMissing() {
        WebElement nameEl = driver.findElement(nameInput);
        Object result = ((JavascriptExecutor) driver).executeScript("return arguments[0].validity.valueMissing;", nameEl);
        return Boolean.TRUE.equals(result);
    }

    public boolean isErrorAlertDisplayed() {
        try {
            WebElement alert = wait.until(ExpectedConditions.visibilityOfElementLocated(errorAlert));
            return alert.isDisplayed();
        } catch (Exception e) {
            return false;
        }
    }

    public String getErrorMessage() {
        WebElement alert = wait.until(ExpectedConditions.visibilityOfElementLocated(errorAlert));
        return alert.getText();
    }
}
