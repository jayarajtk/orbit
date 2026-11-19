package com.orbit.profile.infrastructure;

import com.orbit.profile.domain.Profile;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/** Profiles by account id. */
public interface ProfileRepository extends JpaRepository<Profile, UUID> {

  List<Profile> findByAccountIdIn(Collection<UUID> accountIds);
}
