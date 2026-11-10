package com.orbit;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModule;
import org.springframework.modulith.core.ApplicationModules;

/** Fails the build when a module reaches into another module's internals or a cycle appears. */
class ModularityTests {

  private static final ApplicationModules MODULES =
      ApplicationModules.of(OrbitApiApplication.class);

  @Test
  void moduleBoundariesAreRespected() {
    MODULES.verify();
  }

  @Test
  void declaresTheModulesFromTheDesignDoc() {
    assertThat(MODULES.stream().map(ApplicationModule::getDisplayName))
        .contains(
            "Identity",
            "Profile",
            "Discovery",
            "Chat",
            "Media",
            "Safety",
            "Notification",
            "Billing",
            "Shared");
  }
}
