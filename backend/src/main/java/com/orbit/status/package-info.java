/**
 * 24-hour photo statuses: posting, who may see them, views and early deletion.
 *
 * <p>See docs/superpowers/specs/2026-11-18-polish-waves-status-design.md §8.1. Uses only the
 * published APIs of media, safety (blocks), identity (restriction) and profile (visibility).
 */
@ApplicationModule(
    displayName = "Status",
    allowedDependencies = {"media", "safety", "identity", "profile"})
package com.orbit.status;

import org.springframework.modulith.ApplicationModule;
