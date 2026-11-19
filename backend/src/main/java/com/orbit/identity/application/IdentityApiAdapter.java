package com.orbit.identity.application;

import com.orbit.identity.IdentityApi;
import com.orbit.identity.domain.Account;
import com.orbit.identity.infrastructure.AccountRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Implements {@link IdentityApi} for the other modules. */
@Service
class IdentityApiAdapter implements IdentityApi {

  private static final Logger log = LoggerFactory.getLogger(IdentityApiAdapter.class);

  private final AccountRepository accounts;
  private final ApplicationEventPublisher events;
  private final Clock clock;

  IdentityApiAdapter(AccountRepository accounts, ApplicationEventPublisher events, Clock clock) {
    this.accounts = accounts;
    this.events = events;
    this.clock = clock;
  }

  @Override
  @Transactional(readOnly = true)
  public Optional<AccountSummary> findBySubject(String idpSubject) {
    return accounts.findByIdpSubject(idpSubject).map(this::summarize);
  }

  @Override
  @Transactional(readOnly = true)
  public Optional<AccountSummary> findById(UUID accountId) {
    return accounts.findById(accountId).map(this::summarize);
  }

  @Override
  @Transactional
  public void activate(UUID accountId) {
    accounts.findById(accountId).ifPresent(account -> account.activate(clock));
  }

  @Override
  @Transactional(readOnly = true)
  public Optional<Standing> standing(UUID accountId) {
    return accounts
        .findById(accountId)
        .map(account ->
            new Standing(
                account.getStatus().name(), account.getSuspendedUntil(), account.getCreatedAt()));
  }

  @Override
  @Transactional
  public void suspend(UUID accountId, Instant until) {
    Account account = load(accountId);
    account.suspend(until, clock);
    log.info("Account {} suspended until {}", accountId, until);
    events.publishEvent(new AccountRestricted(accountId));
  }

  @Override
  @Transactional
  public void ban(UUID accountId) {
    load(accountId).ban(clock);
    log.info("Account {} banned", accountId);
    events.publishEvent(new AccountRestricted(accountId));
  }

  @Override
  @Transactional
  public void reinstate(UUID accountId) {
    load(accountId).reinstate(clock);
    log.info("Account {} reinstated", accountId);
  }

  private Account load(UUID accountId) {
    return accounts
        .findById(accountId)
        .orElseThrow(() -> new IllegalArgumentException("No account " + accountId));
  }

  private AccountSummary summarize(Account account) {
    Instant now = clock.instant();
    return new AccountSummary(
        account.getId(),
        account.ageOn(LocalDate.now(clock)),
        account.isActiveAt(now),
        account.isRestrictedAt(now));
  }
}
