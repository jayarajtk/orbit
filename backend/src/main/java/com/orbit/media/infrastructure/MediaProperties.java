package com.orbit.media.infrastructure;

import jakarta.validation.constraints.NotBlank;
import java.net.URI;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Media storage settings ({@code orbit.media.*}). In the cloud only {@code bucket} and {@code
 * region} are set and credentials come from the environment (IAM role or {@code AWS_*} variables).
 * Locally, {@code endpoint}, the access keys and {@code path-style} point at MinIO.
 *
 * @param endpoint S3-compatible endpoint; null for AWS S3. Presigned links use this host, so it
 *     must be reachable by the apps.
 * @param accessKey only for local MinIO; never set in shared environments
 * @param secretKey only for local MinIO; never set in shared environments
 * @param createBucket create the bucket at startup (local and test only)
 * @param uploadTtl how long an upload link works
 * @param viewTtl how long a download link works
 */
@Validated
@ConfigurationProperties("orbit.media")
public record MediaProperties(
    @NotBlank String bucket,
    @NotBlank String region,
    URI endpoint,
    String accessKey,
    String secretKey,
    boolean pathStyle,
    boolean createBucket,
    Duration uploadTtl,
    Duration viewTtl) {

  public MediaProperties {
    uploadTtl = uploadTtl == null ? Duration.ofMinutes(5) : uploadTtl;
    viewTtl = viewTtl == null ? Duration.ofMinutes(10) : viewTtl;
  }

  boolean hasStaticCredentials() {
    return accessKey != null && !accessKey.isBlank() && secretKey != null && !secretKey.isBlank();
  }
}
