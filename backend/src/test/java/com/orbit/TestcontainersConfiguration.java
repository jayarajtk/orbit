package com.orbit;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.test.context.DynamicPropertyRegistrar;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/**
 * Real PostGIS and Redis, plus an S3-compatible store, for integration tests and for local runs via
 * {@code bootTestRun}.
 *
 * <p>The store is Adobe S3Mock: MinIO no longer publishes public images. S3Mock speaks the S3 API
 * (including presigned links) but doesn't check signatures or link expiry; those are verified
 * against real S3 in staging. It accepts any credentials, so the ones below are placeholders.
 */
@TestConfiguration(proxyBeanMethods = false)
public class TestcontainersConfiguration {

  private static final DockerImageName POSTGIS =
      DockerImageName.parse("postgis/postgis:17-3.5").asCompatibleSubstituteFor("postgres");
  private static final DockerImageName REDIS = DockerImageName.parse("redis:7.4-alpine");
  private static final int REDIS_PORT = 6379;
  private static final DockerImageName S3 = DockerImageName.parse("adobe/s3mock:5.2.3");
  private static final int S3_PORT = 9090;
  private static final String MEDIA_BUCKET = "orbit-media";

  @Bean
  @ServiceConnection
  PostgreSQLContainer postgresContainer() {
    return new PostgreSQLContainer(POSTGIS);
  }

  @Bean
  @ServiceConnection(name = "redis")
  GenericContainer<?> redisContainer() {
    return new GenericContainer<>(REDIS).withExposedPorts(REDIS_PORT);
  }

  @Bean
  GenericContainer<?> s3Container() {
    return new GenericContainer<>(S3).withExposedPorts(S3_PORT);
  }

  /** Points media storage at the S3 container; presigned links use its mapped localhost port. */
  @Bean
  DynamicPropertyRegistrar mediaStorageProperties(GenericContainer<?> s3Container) {
    return registry -> {
      registry.add(
          "orbit.media.endpoint",
          () -> "http://" + s3Container.getHost() + ":" + s3Container.getMappedPort(S3_PORT));
      registry.add("orbit.media.access-key", () -> "placeholder");
      registry.add("orbit.media.secret-key", () -> "placeholder");
      registry.add("orbit.media.bucket", () -> MEDIA_BUCKET);
      registry.add("orbit.media.path-style", () -> true);
      registry.add("orbit.media.create-bucket", () -> true);
    };
  }
}
