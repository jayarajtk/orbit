package com.orbit.identity.infrastructure;

import com.orbit.identity.domain.Account;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/** Accounts by id or by identity-provider subject (unique). */
public interface AccountRepository extends JpaRepository<Account, UUID> {

  Optional<Account> findByIdpSubject(String idpSubject);

  boolean existsByIdpSubject(String idpSubject);

  /** Ends every suspension that ended by {@code now}; returns how many. */
  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query(
      """
      UPDATE Account a
      SET a.status = com.orbit.identity.domain.AccountStatus.ACTIVE,
          a.suspendedUntil = null,
          a.updatedAt = :now,
          a.version = a.version + 1
      WHERE a.status = com.orbit.identity.domain.AccountStatus.SUSPENDED
        AND a.suspendedUntil <= :now
      """)
  int liftSuspensionsEndedBy(@Param("now") Instant now);
}
