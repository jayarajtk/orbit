package com.orbit.identity.application;

/** An account already exists for this sign-in identity. */
public class AccountAlreadyExistsException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public AccountAlreadyExistsException() {
    super("Account already exists");
  }

  public AccountAlreadyExistsException(Throwable cause) {
    super("Account already exists", cause);
  }
}
