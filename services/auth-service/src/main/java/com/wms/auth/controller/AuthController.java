package com.wms.auth.controller;

import com.wms.auth.dto.AuthResponse;
import com.wms.auth.dto.LoginRequest;
import com.wms.auth.dto.LogoutRequest;
import com.wms.auth.dto.RefreshRequest;
import com.wms.auth.dto.RegisterRequest;
import com.wms.auth.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public AuthResponse register(@Valid @RequestBody RegisterRequest request) {
        return authService.register(request);
    }

    @PostMapping("/login")
    public AuthResponse login(@Valid @RequestBody LoginRequest request) {
        return authService.login(request);
    }

    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return authService.refresh(request);
    }

    @PostMapping("/logout")
    public Map<String, String> logout(@Valid @RequestBody LogoutRequest request) {
        authService.logout(request);
        return Map.of("message", "Logged out");
    }

    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal Jwt jwt) {
        return Map.of(
                "userId", jwt.getSubject(),
                "username", jwt.getClaimAsString("username"),
                "email", jwt.getClaimAsString("email"),
                "role", jwt.getClaimAsString("role")
        );
    }
}
