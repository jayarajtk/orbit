package com.orbit.identity.api;

import com.orbit.identity.application.AccountView;
import com.orbit.identity.domain.AccountStatus;
import java.time.Instant;
import java.util.UUID;

/** Account as returned by the API. Never includes the birth date. */
record AccountResponse(UUID id, AccountStatus status, Instant createdAt) {

  static AccountResponse from(AccountView view) {
    return new AccountResponse(view.id(), view.status(), view.createdAt());
  }
}
