package com.orbit.identity.api;

import com.orbit.identity.application.AccountService;
import jakarta.validation.Valid;
import java.net.URI;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Onboarding endpoints. The account always belongs to the token's subject. */
@RestController
@RequestMapping("/api/v1")
class AccountController {

  private static final URI MY_ACCOUNT = URI.create("/api/v1/me");

  private final AccountService accountService;

  AccountController(AccountService accountService) {
    this.accountService = accountService;
  }

  @PostMapping("/accounts")
  ResponseEntity<AccountResponse> createAccount(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody CreateAccountRequest request) {
    var account = accountService.register(token.getSubject(), request.birthDate());
    return ResponseEntity.created(MY_ACCOUNT).body(AccountResponse.from(account));
  }

  @GetMapping("/me")
  AccountResponse myAccount(@AuthenticationPrincipal Jwt token) {
    return AccountResponse.from(accountService.findMine(token.getSubject()));
  }
}
