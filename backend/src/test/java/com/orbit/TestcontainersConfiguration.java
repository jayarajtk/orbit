package com.orbit;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

/** Real PostGIS and Redis for integration tests and for local runs via {@code bootTestRun}. */
@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

  private static final DockerImageName POSTGIS =
      DockerImageName.parse("postgis/postgis:17-3.5").asCompatibleSubstituteFor("postgres");
  private static final DockerImageName REDIS = DockerImageName.parse("redis:7.4-alpine");
  private static final int REDIS_PORT = 6379;

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
}
