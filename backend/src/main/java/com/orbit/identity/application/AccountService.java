package com.orbit.identity.application;

import com.orbit.identity.domain.Account;
import com.orbit.identity.domain.AgePolicy;
import com.orbit.identity.infrastructure.AccountRepository;
import java.time.Clock;
import java.time.LocalDate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Account onboarding. The caller's identity always comes from the validated token's subject, never
 * from the request body, so a member can only create or read their own account.
 */
@Service
public class AccountService {

  private static final Logger log = LoggerFactory.getLogger(AccountService.class);

  private final AccountRepository accounts;
  private final Clock clock;

  public AccountService(AccountRepository accounts, Clock clock) {
    this.accounts = accounts;
    this.clock = clock;
  }

  /**
   * Creates the account for {@code idpSubject}.
   *
   * @throws UnderageException if the person is under 18 (nothing is stored)
   * @throws AccountAlreadyExistsException if this identity already has an account
   */
  @Transactional
  public AccountView register(String idpSubject, LocalDate birthDate) {
    if (!AgePolicy.isAdult(birthDate, LocalDate.now(clock))) {
      log.info("Account registration rejected: under minimum age");
      throw new UnderageException();
    }
    if (accounts.existsByIdpSubject(idpSubject)) {
      throw new AccountAlreadyExistsException();
    }
    try {
      Account account = accounts.saveAndFlush(Account.register(idpSubject, birthDate, clock));
      log.info("Account {} registered", account.getId());
      return AccountView.from(account, clock.instant());
    } catch (DataIntegrityViolationException e) {
      // A concurrent request for the same identity won the race on the unique constraint.
      throw new AccountAlreadyExistsException(e);
    }
  }

  /**
   * Returns the caller's account.
   *
   * @throws AccountNotFoundException if this identity has not onboarded yet
   */
  @Transactional(readOnly = true)
  public AccountView findMine(String idpSubject) {
    return accounts
        .findByIdpSubject(idpSubject)
        .map(account -> AccountView.from(account, clock.instant()))
        .orElseThrow(AccountNotFoundException::new);
  }
}
