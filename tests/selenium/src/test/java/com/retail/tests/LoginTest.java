package com.retail.tests;

import com.retail.base.BaseTest;
import com.retail.config.TestConfig;
import com.retail.pages.LoginPage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.openqa.selenium.support.ui.ExpectedConditions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class LoginTest extends BaseTest {

    @Override
    protected boolean shouldAutoLogin() {
        return false;
    }

    @Test
    @DisplayName("J6: Login Journey - Invalid login, successful login with user details, and logout")
    public void testLoginAndLogoutWorkflow() {
        LoginPage loginPage = new LoginPage(driver, wait, baseUrl);
        loginPage.open();

        // 1. Invalid login shows login-error and stays on /login
        loginPage.login("manager", "wrong_invalid_password");
        assertTrue(loginPage.hasError(), "Expected login error message to be displayed on invalid credentials");
        assertTrue(driver.getCurrentUrl().contains("/login"), "Expected to remain on /login page after invalid login");

        // 2. Valid login shows user-name and user-role
        loginPage.login("manager", TestConfig.getManagerPassword());
        wait.until(ExpectedConditions.urlContains("/items"));

        assertEquals("manager", loginPage.getUserName(), "Expected logged in user name to be manager");
        assertTrue(loginPage.getUserRole().equalsIgnoreCase("manager"), "Expected user role to be manager");

        // 3. Logout returns to /login
        loginPage.logout();
        wait.until(ExpectedConditions.urlContains("/login"));
        assertTrue(driver.getCurrentUrl().contains("/login"), "Expected to return to /login after logout");
    }
}
