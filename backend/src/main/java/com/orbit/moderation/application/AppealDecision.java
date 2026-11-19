package com.orbit.moderation.application;

/**
 * A moderator's decision on an appeal.
 *
 * @param reverse true to undo the action and reinstate the account; false to uphold it
 * @param memberMessage what the member is told
 */
public record AppealDecision(boolean reverse, String memberMessage) {}
