package com.orbit.identity.application;

import com.orbit.identity.domain.Account;
import com.orbit.identity.domain.AccountStatus;
import java.time.Instant;
import java.util.UUID;

/**
 * Read model of an account. Deliberately excludes the birth date and identity-provider subject. The
 * status is as of now: a suspension that has ended reads as {@code ACTIVE} even before the job that
 * lifts it has run.
 */
public record AccountView(UUID id, AccountStatus status, Instant createdAt) {

  static AccountView from(Account account, Instant now) {
    AccountStatus status =
        account.getStatus() == AccountStatus.SUSPENDED && !account.isRestrictedAt(now)
            ? AccountStatus.ACTIVE
            : account.getStatus();
    return new AccountView(account.getId(), status, account.getCreatedAt());
  }
}
