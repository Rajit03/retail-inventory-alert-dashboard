package com.retail.util;

import com.retail.config.TestConfig;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;

public class ApiClient {
    private final HttpClient httpClient;
    private final String baseUrl;

    public ApiClient() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
        this.baseUrl = TestConfig.getBaseUrl();
    }

    public int createItem(String name, String category, double price, int quantity, int reorderThreshold) {
        String json = String.format(Locale.US,
                "{\"name\":\"%s\",\"category\":\"%s\",\"price\":%.2f,\"quantity\":%d,\"reorder_threshold\":%d}",
                escapeJson(name), escapeJson(category), price, quantity, reorderThreshold
        );

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/api/items"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(json))
                .build();

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
