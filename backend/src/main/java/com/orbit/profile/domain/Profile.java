package com.orbit.profile.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Instant;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/** A member's public profile, keyed by their account id. */
@Entity
@Table(name = "profile")
public class Profile {

  /** Maximum number of interest tags. */
  public static final int MAX_TAGS = 10;

  @Id
  @Column(name = "account_id")
  private UUID accountId;

  @Column(name = "display_name", nullable = false, length = 30)
  private String displayName;

  @Column(nullable = false, length = 280)
  private String bio;

  @Column(nullable = false, length = 20)
  private String pronouns;

  @Column(name = "height_cm")
  private Short heightCm;

  @Enumerated(EnumType.STRING)
  @Column(length = 16)
  private Relationship relationship;

  @JdbcTypeCode(SqlTypes.ARRAY)
  @Column(name = "looking_for", nullable = false, columnDefinition = "text[]")
  private String[] lookingFor;

  @JdbcTypeCode(SqlTypes.ARRAY)
  @Column(nullable = false, columnDefinition = "text[]")
  private String[] tags;

  @Column(name = "show_age", nullable = false)
  private boolean showAge;

  @Column(name = "show_distance", nullable = false)
  private boolean showDistance;

  @Column(name = "last_active_at", nullable = false)
  private Instant lastActiveAt;

  @Version private Long version;

  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  /** For JPA only. */
  protected Profile() {}

  /** Creates the profile for {@code accountId} from {@code draft}. */
  public static Profile create(UUID accountId, ProfileDraft draft, Instant now) {
    Profile profile = new Profile();
    profile.accountId = Objects.requireNonNull(accountId);
    profile.createdAt = now;
    profile.apply(draft, now);
    return profile;
  }

  /** Replaces every editable field with {@code draft}. */
  public void apply(ProfileDraft draft, Instant now) {
    displayName = draft.displayName().strip();
    bio = draft.bio().strip();
    pronouns = draft.pronouns().strip();
    heightCm = draft.heightCm() == null ? null : draft.heightCm().shortValue();
    relationship = draft.relationship();
    lookingFor = draft.lookingFor().stream().map(Enum::name).sorted().toArray(String[]::new);
    tags = normalizeTags(draft.tags());
    showAge = draft.showAge();
    showDistance = draft.showDistance();
    lastActiveAt = now;
    updatedAt = now;
  }

  /** Marks the member as active now (drives "online"). */
  public void touch(Instant now) {
    lastActiveAt = now;
  }

  private static String[] normalizeTags(List<String> raw) {
    return raw.stream()
        .map(t -> t.strip().replace("#", "").toLowerCase(Locale.ROOT))
        .filter(t -> !t.isEmpty())
        .distinct()
        .limit(MAX_TAGS)
        .toArray(String[]::new);
  }

  public UUID getAccountId() {
    return accountId;
  }

  public String getDisplayName() {
    return displayName;
  }

  public String getBio() {
    return bio;
  }

  public String getPronouns() {
    return pronouns;
  }

  public Integer getHeightCm() {
    return heightCm == null ? null : heightCm.intValue();
  }

  public Relationship getRelationship() {
    return relationship;
  }

  public Set<LookingFor> getLookingFor() {
    return Arrays.stream(lookingFor)
        .map(LookingFor::valueOf)
        .collect(Collectors.toCollection(() -> EnumSet.noneOf(LookingFor.class)));
  }

  public List<String> getTags() {
    return List.of(tags);
  }

  public boolean isShowAge() {
    return showAge;
  }

  public boolean isShowDistance() {
    return showDistance;
  }

  public Instant getLastActiveAt() {
    return lastActiveAt;
  }

  @Override
  public boolean equals(Object other) {
    return this == other || (other instanceof Profile p && accountId.equals(p.accountId));
  }

  @Override
  public int hashCode() {
    return accountId.hashCode();
  }
}
