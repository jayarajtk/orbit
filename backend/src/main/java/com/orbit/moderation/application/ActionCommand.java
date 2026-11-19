package com.orbit.moderation.application;

import com.orbit.moderation.domain.ActionKind;
import com.orbit.moderation.domain.Policy;
import java.util.UUID;

/**
 * An action a moderator asks for.
 *
 * @param memberMessage what the member is told; empty for none
 * @param internalNote what other moderators see; empty for none
 * @param suspendHours for {@code SUSPEND} only
 * @param mediaId for {@code REMOVE_PHOTO} only: one of the member's public photos
 */
public record ActionCommand(
    ActionKind kind,
    Policy policy,
    String memberMessage,
    String internalNote,
    Integer suspendHours,
    UUID mediaId) {}
