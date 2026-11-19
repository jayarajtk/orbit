/**
 * Blocks and reports. Reports are reviewed and acted on by the {@code moderation} module
 * (ADR-0007).
 *
 * <p>See docs/design/design-doc.md §5 for this module's responsibilities and allowed dependencies.
 */
@ApplicationModule(displayName = "Safety")
package com.orbit.safety;

import org.springframework.modulith.ApplicationModule;
