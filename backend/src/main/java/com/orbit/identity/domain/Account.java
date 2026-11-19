package com.orbit.identity.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

/**
 * An Orbit account, keyed by the identity provider's subject. Created only through {@link
 * #register}, which enforces the age requirement.
 */
@Entity
@Table(name = "account")
public class Account {

  @Id private UUID id;

  @Column(name = "idp_subject", nullable = false, updatable = false)
  private String idpSubject;

  @Column(name = "birth_date", nullable = false)
  private LocalDate birthDate;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 16)
  private AccountStatus status;

  @Column(name = "suspended_until")
  private Instant suspendedUntil;

  @Version private Long version;

  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  /** For JPA only. */
  protected Account() {}

  private Account(String idpSubject, LocalDate birthDate, Instant now) {
    this.id = UUID.randomUUID();
    this.idpSubject = idpSubject;
    this.birthDate = birthDate;
    this.status = AccountStatus.ONBOARDING;
    this.createdAt = now;
    this.updatedAt = now;
  }

  /**
   * Registers a new account in {@link AccountStatus#ONBOARDING}.
   *
   * @throws IllegalArgumentException if the person is younger than {@link AgePolicy#MINIMUM_AGE};
   *     callers check {@link AgePolicy#isAdult} first to report this properly
   */
  public static Account register(String idpSubject, LocalDate birthDate, Clock clock) {
    Objects.requireNonNull(idpSubject, "idpSubject");
    Objects.requireNonNull(birthDate, "birthDate");
    if (!AgePolicy.isAdult(birthDate, LocalDate.now(clock))) {
      throw new IllegalArgumentException("Account holder must be at least 18");
    }
    return new Account(idpSubject, birthDate, clock.instant());
  }

  /** Moves an onboarding account to {@link AccountStatus#ACTIVE}; no-op otherwise. */
  public void activate(Clock clock) {
    if (status == AccountStatus.ONBOARDING) {
      status = AccountStatus.ACTIVE;
      updatedAt = clock.instant();
    }
  }

  /**
   * Suspends until {@code until}; a later suspension replaces an earlier one. A banned or deleting
   * account is left as it is.
   */
  public void suspend(Instant until, Clock clock) {
    if (status == AccountStatus.BANNED || status == AccountStatus.DELETING) {
      return;
    }
    status = AccountStatus.SUSPENDED;
    suspendedUntil = until;
    updatedAt = clock.instant();
  }

  /** Bans the account; any suspension end no longer applies. */
  public void ban(Clock clock) {
    status = AccountStatus.BANNED;
    suspendedUntil = null;
    updatedAt = clock.instant();
  }

  /** Lifts a suspension or ban; no-op otherwise. */
  public void reinstate(Clock clock) {
    if (status == AccountStatus.SUSPENDED || status == AccountStatus.BANNED) {
      status = AccountStatus.ACTIVE;
      suspendedUntil = null;
      updatedAt = clock.instant();
    }
  }

  /**
   * Whether the member is suspended or banned at {@code now}. A suspension whose end has passed no
   * longer counts, even before the job that lifts it has run.
   */
  public boolean isRestrictedAt(Instant now) {
    return status == AccountStatus.BANNED
        || (status == AccountStatus.SUSPENDED && suspendedUntil.isAfter(now));
  }

  /** Whether the member may appear to others and act at {@code now}. */
  public boolean isActiveAt(Instant now) {
    return status == AccountStatus.ONBOARDING
        || status == AccountStatus.ACTIVE
        || (status == AccountStatus.SUSPENDED && !isRestrictedAt(now));
  }

  /** Age in whole years on today's date. */
  public int ageOn(LocalDate today) {
    return AgePolicy.ageOn(birthDate, today);
  }

  public UUID getId() {
    return id;
  }

  public AccountStatus getStatus() {
    return status;
  }

  public Instant getSuspendedUntil() {
    return suspendedUntil;
  }

  public Instant getCreatedAt() {
    return createdAt;
  }

  @Override
  public boolean equals(Object other) {
    return this == other || (other instanceof Account account && id.equals(account.id));
  }

  @Override
  public int hashCode() {
    return id.hashCode();
  }
}
