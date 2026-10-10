package com.retail.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.util.List;

public class AlertsPage {
    private final WebDriver driver;
    private final WebDriverWait wait;
    private final String url;

    private final By alertCards = By.cssSelector("[data-testid='alert-card']");
    private final By noAlertsMessage = By.cssSelector("[data-testid='no-alerts-message']");

    public AlertsPage(WebDriver driver, WebDriverWait wait, String baseUrl) {
        this.driver = driver;
        this.wait = wait;
        this.url = baseUrl + "/alerts";
    }

    public AlertsPage open() {
        driver.get(url);
        wait.until(ExpectedConditions.presenceOfElementLocated(By.tagName("body")));
        return this;
    }

    public boolean hasAlertForItem(String itemName) {
        List<WebElement> cards = driver.findElements(alertCards);
        for (WebElement card : cards) {
            List<WebElement> names = card.findElements(By.cssSelector("[data-testid='alert-item-name']"));
            if (!names.isEmpty() && names.get(0).getText().trim().equals(itemName)) {
                return true;
            }
        }
        return false;
    }

    public String getAlertBadgeForItem(String itemName) {
        List<WebElement> cards = driver.findElements(alertCards);
        for (WebElement card : cards) {
            List<WebElement> names = card.findElements(By.cssSelector("[data-testid='alert-item-name']"));
            if (!names.isEmpty() && names.get(0).getText().trim().equals(itemName)) {
                return card.findElement(By.cssSelector("[data-testid='alert-badge']")).getText().trim();
            }
        }
        return null;
    }

    public boolean isNoAlertsDisplayed() {
        List<WebElement> messages = driver.findElements(noAlertsMessage);
        return !messages.isEmpty() && messages.get(0).isDisplayed();
    }
}
