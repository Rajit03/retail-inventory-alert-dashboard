package com.retail.base;

import org.junit.jupiter.api.extension.ExtensionContext;
import org.junit.jupiter.api.extension.TestExecutionExceptionHandler;
import org.openqa.selenium.OutputType;
import org.openqa.selenium.TakesScreenshot;
import org.openqa.selenium.WebDriver;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

public class ScreenshotOnFailureExtension implements TestExecutionExceptionHandler {
    private static final DateTimeFormatter FORMATTER = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");

    @Override
    public void handleTestExecutionException(ExtensionContext context, Throwable throwable) throws Throwable {
        Object testInstance = context.getRequiredTestInstance();
        if (testInstance instanceof BaseTest) {
            WebDriver driver = ((BaseTest) testInstance).getDriver();
            if (driver instanceof TakesScreenshot) {
                try {
                    byte[] screenshotBytes = ((TakesScreenshot) driver).getScreenshotAs(OutputType.BYTES);
                    String className = context.getRequiredTestClass().getSimpleName();
                    String methodName = context.getRequiredTestMethod().getName();
                    String timestamp = LocalDateTime.now().format(FORMATTER);
                    String fileName = String.format("%s_%s_%s.png", className, methodName, timestamp);

                    Path screenshotsDir = Paths.get("target", "screenshots");
                    if (Files.exists(Paths.get("tests", "selenium"))) {
                        screenshotsDir = Paths.get("tests", "selenium", "target", "screenshots");
                    }
                    Files.createDirectories(screenshotsDir);
                    Path screenshotPath = screenshotsDir.resolve(fileName);
                    Files.write(screenshotPath, screenshotBytes);

                    System.out.println("Screenshot captured on failure: " + screenshotPath.toAbsolutePath());
                } catch (Exception e) {
                    System.err.println("Failed to capture screenshot on failure: " + e.getMessage());
                }
            }
        }
        throw throwable;
    }
}
