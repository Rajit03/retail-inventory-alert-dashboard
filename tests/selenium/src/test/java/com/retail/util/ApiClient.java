package com.retail.util;

import com.retail.config.TestConfig;

import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;

public class ApiClient {
    private final HttpClient httpClient;
    private final String baseUrl;
    private String csrfToken = "";

    public ApiClient() {
        CookieManager cookieManager = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
        this.httpClient = HttpClient.newBuilder()
                .cookieHandler(cookieManager)
                .connectTimeout(Duration.ofSeconds(5))
                .build();
        this.baseUrl = TestConfig.getBaseUrl();
        login("manager", TestConfig.getManagerPassword());
    }

    public void login(String username, String password) {
        String json = String.format("{\"username\":\"%s\",\"password\":\"%s\"}",
                escapeJson(username), escapeJson(password));

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/login"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                throw new RuntimeException("ApiClient login failed: HTTP " + response.statusCode() + " - " + response.body());
            }
            String body = response.body();
            int tokenIdx = body.indexOf("\"csrfToken\":\"");
            if (tokenIdx != -1) {
                int start = tokenIdx + 13;
                int end = body.indexOf("\"", start);
                if (end != -1) {
                    this.csrfToken = body.substring(start, end);
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("Error during ApiClient login", e);
        }
    }

    public int createItem(String name, String category, double price, int quantity, int reorderThreshold) {
        String json = String.format(Locale.US,
                "{\"name\":\"%s\",\"category\":\"%s\",\"price\":%.2f,\"quantity\":%d,\"reorder_threshold\":%d}",
                escapeJson(name), escapeJson(category), price, quantity, reorderThreshold
        );

        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/items"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json));

        if (csrfToken != null && !csrfToken.isEmpty()) {
            builder.header("x-csrf-token", csrfToken);
        }

        HttpRequest request = builder.build();

        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 201) {
                throw new RuntimeException("Failed to create item via API: HTTP " + response.statusCode() + " - " + response.body());
            }
            String body = response.body();
            int idIndex = body.indexOf("\"id\":");
            if (idIndex != -1) {
                int start = idIndex + 5;
                int end = body.indexOf(",", start);
                if (end == -1) {
                    end = body.indexOf("}", start);
                }
                if (end != -1) {
                    return Integer.parseInt(body.substring(start, end).trim());
                }
            }
            return 0;
        } catch (Exception e) {
            throw new RuntimeException("Error during API call to create item", e);
        }
    }

    private String escapeJson(String input) {
        if (input == null) return "";
        return input.replace("\\", "\\\\").replace("\"", "\\\"");
    }
}
