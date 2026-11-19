package com.orbit.shared;

import static org.assertj.core.api.Assertions.assertThat;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import javax.imageio.ImageIO;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.client.RestTestClient;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** Uploads and completes a small JPEG through the real media endpoints, for integration tests. */
public final class PhotoUploads {

  private static final HttpClient HTTP = HttpClient.newHttpClient();
  private static final JsonMapper JSON = JsonMapper.builder().build();

  private PhotoUploads() {}

  /**
   * Uploads and completes a photo for {@code purpose} as the bearer token {@code who}.
   *
   * @return the media id
   */
  public static String upload(RestTestClient client, String who, String purpose)
      throws IOException, InterruptedException {
    byte[] bytes = jpeg();
    String ticketJson =
        client
            .post()
            .uri("/api/v1/media/uploads")
            .header("Authorization", "Bearer " + who)
            .contentType(MediaType.APPLICATION_JSON)
            .body(
                "{\"purpose\":\"%s\",\"contentType\":\"image/jpeg\",\"sizeBytes\":%d}"
                    .formatted(purpose, bytes.length))
            .exchange()
            .expectStatus()
            .isCreated()
            .expectBody(String.class)
            .returnResult()
            .getResponseBody();
    JsonNode ticket = JSON.readTree(ticketJson);
    HttpResponse<String> stored =
        HTTP.send(
            HttpRequest.newBuilder(URI.create(ticket.get("uploadUrl").asString()))
                .header("Content-Type", "image/jpeg")
                .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                .build(),
            HttpResponse.BodyHandlers.ofString());
    assertThat(stored.statusCode()).isEqualTo(200);
    String id = ticket.get("id").asString();
    client
        .post()
        .uri("/api/v1/media/uploads/" + id + "/complete")
        .header("Authorization", "Bearer " + who)
        .contentType(MediaType.APPLICATION_JSON)
        .body("{}")
        .exchange()
        .expectStatus()
        .isOk();
    return id;
  }

  private static byte[] jpeg() throws IOException {
    BufferedImage image = new BufferedImage(64, 48, BufferedImage.TYPE_INT_RGB);
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "jpeg", out);
    return out.toByteArray();
  }
}
