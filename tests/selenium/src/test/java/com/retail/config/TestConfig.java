package com.retail.config;

public class TestConfig {
    public static String getBaseUrl() {
        String baseUrl = System.getProperty("base.url", "http://localhost:3100");
        if (baseUrl.endsWith("/")) {
            return baseUrl.substring(0, baseUrl.length() - 1);
        }
        return baseUrl;
    }

    public static boolean isHeadless() {
        return Boolean.parseBoolean(System.getProperty("headless", "true"));
    }

    public static String getManagerPassword() {
        return System.getProperty("test.manager.password", "TestManagerPass123!");
    }

    public static String getStaffPassword() {
        return System.getProperty("test.staff.password", "TestStaffPass123!");
    }
}
