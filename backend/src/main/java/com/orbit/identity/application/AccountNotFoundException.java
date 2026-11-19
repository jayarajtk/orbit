package com.orbit.identity.application;

/** No account exists yet for this sign-in identity; the client should onboard. */
public class AccountNotFoundException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public AccountNotFoundException() {
    super("Account not found");
  }
}
