package com.orbit.moderation.application;

/** Why a moderation request was refused. Each maps to one problem type in the API layer. */
public final class ModerationExceptions {

  private ModerationExceptions() {}

  /** No such member. */
  public static class MemberNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public MemberNotFoundException() {
      super("Member not found");
    }
  }

  /** No such appeal. */
  public static class AppealNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AppealNotFoundException() {
      super("Appeal not found");
    }
  }

  /** The action doesn't make sense for this member; the message says why, for the moderator. */
  public static class InvalidActionException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidActionException(String reason) {
      super(reason);
    }
  }

  /** Someone already decided this appeal. */
  public static class AppealDecidedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AppealDecidedException() {
      super("Appeal already decided");
    }
  }

  /** A member tried to appeal while not suspended or banned. */
  public static class NotRestrictedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public NotRestrictedException() {
      super("Not suspended or banned");
    }
  }

  /** A member tried to appeal the same action twice. */
  public static class AppealExistsException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AppealExistsException() {
      super("Already appealed");
    }
  }
}
