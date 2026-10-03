package com.retail.util;

public class TestData {
    public static final String DEFAULT_CATEGORY = "Selenium";
    public static final double DEFAULT_PRICE = 29.99;
    public static final int DEFAULT_QUANTITY = 20;
    public static final int DEFAULT_THRESHOLD = 10;

    public static String uniqueItemName(String label) {
        return "SEL-" + System.currentTimeMillis() + "-" + label;
    }
}
