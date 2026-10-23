package com.retail.pages;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.util.List;

public class LoginPage {
    private final WebDriver driver;
    private final WebDriverWait wait;
    private final String url;

    private final By usernameInput = By.cssSelector("[data-testid='login-username']");
    private final By passwordInput = By.cssSelector("[data-testid='login-password']");
    private final By submitButton = By.cssSelector("[data-testid='login-submit']");
    private final By loginError = By.cssSelector("[data-testid='login-error']");
    private final By userNameBadge = By.cssSelector("[data-testid='user-name']");
    private final By userRoleBadge = By.cssSelector("[data-testid='user-role']");
    private final By logoutButton = By.cssSelector("[data-testid='logout-button']");

    public LoginPage(WebDriver driver, WebDriverWait wait, String baseUrl) {
        this.driver = driver;
        this.wait = wait;
        this.url = baseUrl + "/login";
    }

    public LoginPage open() {
        driver.get(url);
        wait.until(ExpectedConditions.presenceOfElementLocated(usernameInput));
        return this;
    }

    public void login(String username, String password) {
        WebElement uInput = wait.until(ExpectedConditions.visibilityOfElementLocated(usernameInput));
        uInput.clear();
        uInput.sendKeys(username);

        WebElement pInput = wait.until(ExpectedConditions.visibilityOfElementLocated(passwordInput));
        pInput.clear();
        pInput.sendKeys(password);

        WebElement btn = wait.until(ExpectedConditions.elementToBeClickable(submitButton));
        btn.click();
    }

    public boolean hasError() {
        try {
            WebElement error = wait.until(ExpectedConditions.visibilityOfElementLocated(loginError));
            return error.isDisplayed();
        } catch (Exception e) {
            return false;
        }
    }

    public String getErrorMessage() {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(loginError)).getText().trim();
    }

    public String getUserName() {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(userNameBadge)).getText().trim();
    }

    public String getUserRole() {
        return wait.until(ExpectedConditions.visibilityOfElementLocated(userRoleBadge)).getText().trim();
    }

    public boolean isUserLoggedIn() {
        return !driver.findElements(userNameBadge).isEmpty();
    }

    public void logout() {
        WebElement btn = wait.until(ExpectedConditions.elementToBeClickable(logoutButton));
        btn.click();
        wait.until(ExpectedConditions.urlContains("/login"));
    }
}
