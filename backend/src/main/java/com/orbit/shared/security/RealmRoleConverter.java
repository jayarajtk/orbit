package com.orbit.shared.security;

import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;

/**
 * Turns a Keycloak token into an authentication with its scopes ({@code SCOPE_…}) and its realm
 * roles ({@code ROLE_…}, upper case), so {@code hasRole("MODERATOR")} matches the realm role {@code
 * moderator} (ADR-0007). The principal name stays the token subject.
 */
public final class RealmRoleConverter implements Converter<Jwt, AbstractAuthenticationToken> {

  private static final String REALM_ACCESS = "realm_access";
  private static final String ROLES = "roles";

  private final JwtGrantedAuthoritiesConverter scopes = new JwtGrantedAuthoritiesConverter();

  @Override
  public AbstractAuthenticationToken convert(Jwt jwt) {
    List<GrantedAuthority> authorities = new ArrayList<>(scopes.convert(jwt));
    for (String role : realmRoles(jwt)) {
      authorities.add(new SimpleGrantedAuthority("ROLE_" + role.toUpperCase(Locale.ROOT)));
    }
    return new JwtAuthenticationToken(jwt, authorities, jwt.getSubject());
  }

  /** The realm roles in the token; anything malformed counts as no roles. */
  private static List<String> realmRoles(Jwt jwt) {
    if (!(jwt.getClaims().get(REALM_ACCESS) instanceof Map<?, ?> access)
        || !(access.get(ROLES) instanceof Collection<?> roles)) {
      return List.of();
    }
    return roles.stream().filter(String.class::isInstance).map(String.class::cast).toList();
  }
}
