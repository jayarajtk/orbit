package com.orbit.shared.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * Default-deny security for the whole API. Every request needs a valid OIDC bearer token except the
 * public health probes, and the moderation API also needs the {@code moderator} realm role
 * (ADR-0007). Object-level checks live on service methods ({@code @PreAuthorize}).
 */
@Configuration(proxyBeanMethods = false)
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

  private static final long HSTS_MAX_AGE_SECONDS = 31_536_000L;

  @Bean
  SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
    http
        // Stateless bearer-token API: no cookies or browser session, so CSRF does not apply.
        .csrf(AbstractHttpConfigurer::disable)
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth ->
            auth.requestMatchers(
                    HttpMethod.GET, "/actuator/health", "/actuator/health/**", "/actuator/info")
                .permitAll()
                .requestMatchers("/api/v1/admin/**")
                .hasRole("MODERATOR")
                .anyRequest()
                .authenticated())
        .oauth2ResourceServer(oauth2 ->
            oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(new RealmRoleConverter()))
                .authenticationEntryPoint(new ProblemDetailAuthenticationEntryPoint()))
        .headers(headers ->
            headers
                .contentSecurityPolicy(
                    csp -> csp.policyDirectives("default-src 'none'; frame-ancestors 'none'"))
                .httpStrictTransportSecurity(
                    hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(HSTS_MAX_AGE_SECONDS)));
    return http.build();
  }
}
