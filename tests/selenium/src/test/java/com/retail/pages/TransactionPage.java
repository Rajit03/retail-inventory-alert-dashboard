package com.retail.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.Select;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.util.List;

public class TransactionPage {
    private final WebDriver driver;
    private final WebDriverWait wait;
    private final String baseUrl;

    private final By itemSelect = By.cssSelector("[data-testid='item-select']");
    private final By typeSelect = By.cssSelector("[data-testid='type-select']");
    private final By quantityInput = By.cssSelector("[data-testid='quantity-input']");
    private final By submitButton = By.cssSelector("[data-testid='submit-button']");
    private final By errorAlert = By.cssSelector("[data-testid='error-alert']");
    private final By transactionRows = By.cssSelector("[data-testid='transaction-row']");

    public TransactionPage(WebDriver driver, WebDriverWait wait, String baseUrl) {
        this.driver = driver;
        this.wait = wait;
        this.baseUrl = baseUrl;
    }

    public TransactionPage openNew() {
        driver.get(baseUrl + "/transactions/new");
        wait.until(ExpectedConditions.visibilityOfElementLocated(itemSelect));
        return this;
    }

    public TransactionPage openIndex() {
        driver.get(baseUrl + "/transactions");
        wait.until(ExpectedConditions.presenceOfElementLocated(By.tagName("body")));
        return this;
    }

    public void selectItemByVisibleTextContaining(String itemName) {
        WebElement selectEl = wait.until(ExpectedConditions.visibilityOfElementLocated(itemSelect));
        Select select = new Select(selectEl);
        for (WebElement option : select.getOptions()) {
            if (option.getText().contains(itemName)) {
                select.selectByVisibleText(option.getText());
                return;
            }
        }
        throw new RuntimeException("Item with name containing '" + itemName + "' not found in select dropdown");
    }

    public void recordTransaction(String itemName, String type, int quantity) {
        openNew();
        selectItemByVisibleTextContaining(itemName);

        WebElement typeEl = wait.until(ExpectedConditions.visibilityOfElementLocated(typeSelect));
        Select typeDropdown = new Select(typeEl);
        typeDropdown.selectByValue(type);

        WebElement qtyEl = wait.until(ExpectedConditions.visibilityOfElementLocated(quantityInput));
        qtyEl.clear();
        qtyEl.sendKeys(String.valueOf(quantity));

        driver.findElement(submitButton).click();
    }

    public boolean isErrorAlertDisplayed() {
        List<WebElement> alerts = driver.findElements(errorAlert);
        return !alerts.isEmpty() && alerts.get(0).isDisplayed();
    }

    public String getErrorMessage() {
        WebElement alert = wait.until(ExpectedConditions.visibilityOfElementLocated(errorAlert));
        return alert.getText();
    }

    public boolean hasTransaction(String itemName, String type, int quantity) {
        List<WebElement> rows = driver.findElements(transactionRows);
        for (WebElement row : rows) {
            String nameText = row.findElement(By.cssSelector("[data-testid='tx-item-name']")).getText().trim();
            String typeText = row.findElement(By.cssSelector("[data-testid='tx-type']")).getText().trim();
            String qtyText = row.findElement(By.cssSelector("[data-testid='tx-quantity']")).getText().trim();

            if (nameText.equals(itemName) && typeText.equalsIgnoreCase(type) && qtyText.equals(String.valueOf(quantity))) {
                return true;
            }
        }
        return false;
    }
}
