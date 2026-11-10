/**
 * Cross-cutting infrastructure shared by every module: error mapping, security configuration and
 * common configuration. Contains no business logic.
 */
@ApplicationModule(displayName = "Shared", type = ApplicationModule.Type.OPEN)
package com.orbit.shared;

import org.springframework.modulith.ApplicationModule;
