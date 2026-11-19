/**
 * Reviewing reports and acting on them: the moderation queue, actions (warn, suspend, ban, remove
 * photo, dismiss, reinstate), appeals, evidence copied at report time, and the audit log
 * (ADR-0007).
 *
 * <p>Depends on identity, profile, media, safety and chat through their public APIs; nothing
 * depends on this module.
 */
@ApplicationModule(displayName = "Moderation")
package com.orbit.moderation;

import org.springframework.modulith.ApplicationModule;
