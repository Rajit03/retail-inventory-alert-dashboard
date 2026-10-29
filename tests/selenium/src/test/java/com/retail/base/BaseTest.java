package com.retail.base;

import com.retail.config.TestConfig;
import com.retail.pages.LoginPage;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.extension.ExtendWith;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.chrome.ChromeOptions;
import org.openqa.selenium.support.ui.ExpectedConditions;
import org.openqa.selenium.support.ui.WebDriverWait;

import java.time.Duration;

@ExtendWith(ScreenshotOnFailureExtension.class)
public abstract class BaseTest {
    protected WebDriver driver;
    protected WebDriverWait wait;
    protected String baseUrl;

    protected boolean shouldAutoLogin() {
        return true;
    }

    @BeforeEach
    public void setUp() {
        baseUrl = TestConfig.getBaseUrl();
        ChromeOptions options = new ChromeOptions();
        if (TestConfig.isHeadless()) {
            options.addArguments("--headless=new");
        }
        options.addArguments("--window-size=1366,900");
        options.addArguments("--disable-gpu");
        options.addArguments("--no-sandbox");
        options.addArguments("--disable-dev-shm-usage");

        try {
            driver = new ChromeDriver(options);
        } catch (org.openqa.selenium.SessionNotCreatedException e) {
            // When Chrome auto-updates, the cached driver might be momentarily mismatched.
            // Retrying once allows Selenium Manager to download and bind the matching driver.
            try {
                Thread.sleep(1000);
            } catch (InterruptedException ignored) {
            }
            driver = new ChromeDriver(options);
        }
        wait = new WebDriverWait(driver, Duration.ofSeconds(10));

        if (shouldAutoLogin()) {
            loginAsManager();
        }
    }

    public void loginAsManager() {
        loginAs("manager", TestConfig.getManagerPassword());
    }

    public void loginAsStaff() {
        loginAs("staff", TestConfig.getStaffPassword());
    }

    public void loginAs(String username, String password) {
        LoginPage loginPage = new LoginPage(driver, wait, baseUrl);
        loginPage.open();
        loginPage.login(username, password);
        wait.until(ExpectedConditions.urlMatches(".*/(items|alerts).*"));
    }

    @AfterEach
    public void tearDown() {
        if (driver != null) {
            try {
                driver.quit();
            } catch (Exception ignored) {
            }
        }
    }

    public WebDriver getDriver() {
        return driver;
    }
}
