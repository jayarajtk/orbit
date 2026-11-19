package com.orbit.profile.application;

import com.orbit.media.MediaApi.Links;
import com.orbit.profile.domain.LookingFor;
import com.orbit.profile.domain.Profile;
import com.orbit.profile.domain.Relationship;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * The caller's own profile, including privacy switches.
 *
 * @param photos public photos in display order, with short-lived links
 */
public record MyProfile(
    UUID accountId,
    String displayName,
    int age,
    String bio,
    String pronouns,
    Integer heightCm,
    Relationship relationship,
    Set<LookingFor> lookingFor,
    List<String> tags,
    boolean showAge,
    boolean showDistance,
    List<Photo> photos) {

  /** A public photo. */
  public record Photo(UUID id, String url, String thumbUrl) {

    static Photo of(UUID id, Links links) {
      return new Photo(id, links.url(), links.thumbUrl());
    }
  }

  static MyProfile of(Profile p, int age, List<Photo> photos) {
    return new MyProfile(
        p.getAccountId(),
        p.getDisplayName(),
        age,
        p.getBio(),
        p.getPronouns(),
        p.getHeightCm(),
        p.getRelationship(),
        p.getLookingFor(),
        p.getTags(),
        p.isShowAge(),
        p.isShowDistance(),
        photos);
  }
}
