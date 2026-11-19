package com.orbit.profile.application;

import com.orbit.identity.IdentityApi;
import com.orbit.identity.IdentityApi.AccountSummary;
import com.orbit.media.MediaApi;
import com.orbit.media.MediaApi.Kind;
import com.orbit.media.MediaApi.Links;
import com.orbit.profile.ProfileApi;
import com.orbit.profile.domain.Profile;
import com.orbit.profile.domain.ProfileDraft;
import com.orbit.profile.infrastructure.PhotoStore;
import com.orbit.profile.infrastructure.ProfileRepository;
import com.orbit.profile.infrastructure.ProfileSearch;
import com.orbit.safety.SafetyApi;
import java.time.Clock;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** The member's own profile. Other members' profiles are served by discovery. */
@Service
public class ProfileService implements ProfileApi {

  /** Public photos per member. */
  public static final int MAX_PHOTOS = 6;

  private final ProfileRepository profiles;
  private final PhotoStore photos;
  private final ProfileSearch search;
  private final IdentityApi identity;
  private final SafetyApi safety;
  private final MediaApi media;
  private final Clock clock;

  public ProfileService(
      ProfileRepository profiles,
      PhotoStore photos,
      ProfileSearch search,
      IdentityApi identity,
      SafetyApi safety,
      MediaApi media,
      Clock clock) {
    this.profiles = profiles;
    this.photos = photos;
    this.search = search;
    this.identity = identity;
    this.safety = safety;
    this.media = media;
    this.clock = clock;
  }

  /**
   * The caller's own profile.
   *
   * @throws ProfileNotFoundException if they have not created one yet
   */
  @Transactional
  public MyProfile mine(String callerSubject) {
    AccountSummary account = identity.require(callerSubject);
    Profile profile = profiles.findById(account.id()).orElseThrow(ProfileNotFoundException::new);
    profile.touch(clock.instant());
    return MyProfile.of(profile, account.age(), photosOf(account.id()));
  }

  /**
   * Replaces the caller's public photos with {@code mediaIds}, in that order. Each must be one of
   * the caller's processed photos that the scanner allows in public.
   *
   * @throws ProfileNotFoundException if they have not created a profile yet
   * @throws TooManyPhotosException above {@link #MAX_PHOTOS}
   * @throws MediaApi.MediaUnavailableException if any photo can't be used
   */
  @Transactional
  public MyProfile setPhotos(String callerSubject, List<UUID> mediaIds) {
    AccountSummary account = identity.require(callerSubject);
    Profile profile = profiles.findById(account.id()).orElseThrow(ProfileNotFoundException::new);
    List<UUID> ordered = List.copyOf(new LinkedHashSet<>(mediaIds));
    if (ordered.size() > MAX_PHOTOS) {
      throw new TooManyPhotosException();
    }
    for (UUID id : ordered) {
      media.requireAttachable(account.id(), id, Kind.PHOTO, true);
    }
    photos.replace(account.id(), ordered, clock.instant());
    return MyProfile.of(profile, account.age(), photosOf(account.id()));
  }

  private List<MyProfile.Photo> photosOf(UUID accountId) {
    List<UUID> ids = photos.photoIds(accountId);
    Map<UUID, Links> links = media.links(ids);
    return ids.stream()
        .filter(links::containsKey)
        .map(id -> MyProfile.Photo.of(id, links.get(id)))
        .toList();
  }

  /** Creates or replaces the caller's profile; the first save activates the account. */
  @Transactional
  public MyProfile save(String callerSubject, ProfileDraft draft) {
    AccountSummary account = identity.require(callerSubject);
    Profile profile =
        profiles
            .findById(account.id())
            .map(existing -> {
              existing.apply(draft, clock.instant());
              return existing;
            })
            .orElseGet(() -> profiles.save(Profile.create(account.id(), draft, clock.instant())));
    identity.activate(account.id());
    return MyProfile.of(profile, account.age(), photosOf(account.id()));
  }

  /** Members the caller has blocked, with names, for the "Blocked users" screen. */
  @Transactional(readOnly = true)
  public List<BlockedMember> blocked(String callerSubject) {
    UUID me = identity.require(callerSubject).id();
    return profiles.findByAccountIdIn(safety.blockedBy(me)).stream()
        .map(p -> new BlockedMember(p.getAccountId(), p.getDisplayName()))
        .sorted(Comparator.comparing(BlockedMember::displayName))
        .toList();
  }

  @Override
  @Transactional
  public void touch(UUID accountId) {
    profiles.findById(accountId).ifPresent(p -> p.touch(clock.instant()));
  }

  @Override
  @Transactional(readOnly = true)
  public Map<UUID, String> displayNames(Collection<UUID> accountIds) {
    return profiles.findByAccountIdIn(accountIds).stream()
        .collect(Collectors.toMap(Profile::getAccountId, Profile::getDisplayName));
  }

  @Override
  @Transactional(readOnly = true)
  public Optional<Card> card(UUID accountId) {
    return profiles
        .findById(accountId)
        .map(p ->
            new Card(
                p.getDisplayName(),
                p.getBio(),
                p.getPronouns(),
                p.getTags(),
                photos.photoIds(accountId),
                p.getLastActiveAt()));
  }

  @Override
  @Transactional(readOnly = true)
  public List<UUID> findByNamePrefix(String prefix, int limit) {
    String trimmed = prefix.strip();
    if (trimmed.isEmpty()) {
      return List.of();
    }
    return search.idsByNamePrefix(trimmed, limit);
  }

  @Override
  @Transactional
  public boolean removePhoto(UUID accountId, UUID mediaId) {
    List<UUID> current = photos.photoIds(accountId);
    if (!current.contains(mediaId)) {
      return false;
    }
    photos.replace(
        accountId, current.stream().filter(id -> !id.equals(mediaId)).toList(), clock.instant());
    return true;
  }

  /** A member the caller blocked. */
  public record BlockedMember(UUID accountId, String displayName) {}

  /** The caller has no profile yet. */
  public static class ProfileNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public ProfileNotFoundException() {
      super("Profile not found");
    }
  }

  /** More photos than allowed. */
  public static class TooManyPhotosException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public TooManyPhotosException() {
      super("Too many photos");
    }
  }
}
