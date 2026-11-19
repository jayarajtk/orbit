package com.orbit.profile.domain;

import java.util.List;
import java.util.Set;

/**
 * Editable profile fields, already validated at the API boundary.
 *
 * @param heightCm null when not shown
 * @param relationship null when not shown
 */
public record ProfileDraft(
    String displayName,
    String bio,
    String pronouns,
    Integer heightCm,
    Relationship relationship,
    Set<LookingFor> lookingFor,
    List<String> tags,
    boolean showAge,
    boolean showDistance) {

  public ProfileDraft {
    lookingFor = Set.copyOf(lookingFor);
    tags = List.copyOf(tags);
  }
}
