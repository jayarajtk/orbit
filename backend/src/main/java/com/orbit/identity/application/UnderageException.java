package com.orbit.identity.application;

/** The person is younger than the minimum age to hold an account. */
public class UnderageException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  public UnderageException() {
    super("Account holder is under the minimum age");
  }
}
