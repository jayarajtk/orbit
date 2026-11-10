package com.orbit;

import java.util.List;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;
import org.testcontainers.utility.MountableFile;

/**
 * Local-only OIDC issuer for {@code bootTestRun}: a throwaway Keycloak with the {@code orbit} realm
 * from {@code keycloak/orbit-realm.json} (public client {@code orbit-mobile}, user {@code
 * dev-user}). Never used in automated tests, which mock the {@code JwtDecoder}.
 *
 * <p>Bound to fixed host port 8180 so the token's {@code iss} claim matches the issuer URI in
 * {@code application-local.yml}. That URI is static on purpose: the resource-server
 * auto-configuration evaluates it before dynamic properties are registered.
 */
@TestConfiguration(proxyBeanMethods = false)
class LocalOidcConfiguration {

  private static final DockerImageName KEYCLOAK =
      DockerImageName.parse("quay.io/keycloak/keycloak:26.4.0");
  private static final int HOST_PORT = 8180;
  private static final int KEYCLOAK_PORT = 8080;

  @Bean
  GenericContainer<?> keycloakContainer() {
    GenericContainer<?> keycloak =
        new GenericContainer<>(KEYCLOAK)
            .withCommand("start-dev", "--import-realm")
            .withCopyFileToContainer(
                MountableFile.forClasspathResource("keycloak/orbit-realm.json"),
                "/opt/keycloak/data/import/orbit-realm.json")
            .withExposedPorts(KEYCLOAK_PORT)
            .waitingFor(
                Wait.forHttp("/realms/orbit/.well-known/openid-configuration")
                    .forPort(KEYCLOAK_PORT));
    keycloak.setPortBindings(List.of(HOST_PORT + ":" + KEYCLOAK_PORT));
    return keycloak;
  }
}
