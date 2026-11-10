package com.orbit;

import org.springframework.boot.SpringApplication;

/**
 * Runs the API locally ({@code ./gradlew bootTestRun}) against throwaway PostGIS, Redis and
 * Keycloak containers. No environment variables needed.
 */
public class TestOrbitApiApplication {

  public static void main(String[] args) {
    SpringApplication.from(OrbitApiApplication::main)
        .with(TestcontainersConfiguration.class, LocalOidcConfiguration.class)
        .withAdditionalProfiles("local")
        .run(args);
  }
}
