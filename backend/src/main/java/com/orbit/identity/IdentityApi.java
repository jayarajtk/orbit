package com.orbit.identity;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

/**
 * What other modules may ask of identity. The birth date never leaves this module; only the age
 * does.
 */
public interface IdentityApi {

  /** The account for an identity-provider subject, if the member has onboarded. */
  Optional<AccountSummary> findBySubject(String idpSubject);

  /** The account with this id, if any. */
  Optional<AccountSummary> findById(UUID accountId);

  /** Marks an onboarding account as active (called once the profile exists). */
  void activate(UUID accountId);

  /** Where the account stands with moderation, if it exists. */
  Optional<Standing> standing(UUID accountId);

  /**
   * Suspends the account until {@code until}, or extends a current suspension. Publishes {@link
   * AccountRestricted}. A banned account stays banned.
   *
   * @throws IllegalArgumentException if there is no such account
   */
  void suspend(UUID accountId, Instant until);

  /**
   * Bans the account. Publishes {@link AccountRestricted}.
   *
   * @throws IllegalArgumentException if there is no such account
   */
  void ban(UUID accountId);

  /**
   * Lifts a suspension or ban. No-op for accounts that aren't restricted.
   *
   * @throws IllegalArgumentException if there is no such account
   */
  void reinstate(UUID accountId);

  /**
   * The caller's account, for endpoints that need one.
   *
   * @throws AccountRestrictedException if the caller is suspended or banned
   * @throws AccountRequiredException if the caller has not onboarded
   */
  default AccountSummary require(String idpSubject) {
    AccountSummary account = findBySubject(idpSubject).orElseThrow(AccountRequiredException::new);
    if (account.restricted()) {
      throw new AccountRestrictedException();
    }
    if (!account.active()) {
      throw new AccountRequiredException();
    }
    return account;
  }

  /** The caller has no usable account; mapped to 403 {@code urn:orbit:problem:account-required}. */
  class AccountRequiredException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    /** Creates the exception. */
    public AccountRequiredException() {
      this("An active account is required");
    }

    AccountRequiredException(String message) {
      super(message);
    }
  }

  /**
   * The caller is suspended or banned; mapped to 403 {@code urn:orbit:problem:account-restricted}
   * so the app shows the restriction screen rather than onboarding.
   */
  final class AccountRestrictedException extends AccountRequiredException {
    private static final long serialVersionUID = 1L;

    /** Creates the exception. */
    public AccountRestrictedException() {
      super("The account is suspended or banned");
    }
  }

  /**
   * Minimal view of an account for other modules.
   *
   * @param id account id
   * @param age age in whole years today
   * @param active whether the account may appear to others and act
   * @param restricted whether it is suspended or banned right now
   */
  record AccountSummary(UUID id, int age, boolean active, boolean restricted) {}

  /**
   * An account's moderation standing.
   *
   * @param status {@code ONBOARDING}, {@code ACTIVE}, {@code SUSPENDED}, {@code BANNED} or {@code
   *     DELETING}
   * @param suspendedUntil when a suspension ends; null otherwise
   * @param createdAt when the account was created
   */
  record Standing(String status, Instant suspendedUntil, Instant createdAt) {}

  /**
   * Published when an account is suspended or banned, so live connections can be closed.
   *
   * @param accountId the restricted account
   */
  record AccountRestricted(UUID accountId) {}
}
