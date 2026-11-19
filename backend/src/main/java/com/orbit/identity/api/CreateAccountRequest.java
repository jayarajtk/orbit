package com.orbit.identity.api;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import java.time.LocalDate;

/** Body of {@code POST /api/v1/accounts}. The identity comes from the bearer token. */
record CreateAccountRequest(@NotNull @Past LocalDate birthDate) {}
