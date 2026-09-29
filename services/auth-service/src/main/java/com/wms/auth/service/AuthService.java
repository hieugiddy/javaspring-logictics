package com.wms.auth.service;

import com.wms.auth.config.SecurityProperties;
import com.wms.auth.dto.AuthResponse;
import com.wms.auth.dto.LoginRequest;
import com.wms.auth.dto.LogoutRequest;
import com.wms.auth.dto.RefreshRequest;
import com.wms.auth.dto.RegisterRequest;
import com.wms.auth.entity.RefreshToken;
import com.wms.auth.entity.User;
import com.wms.auth.exception.ApiException;
import com.wms.auth.repository.RefreshTokenRepository;
import com.wms.auth.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

@Service
public class AuthService {
    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokenService;
    private final SecurityProperties properties;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(UserRepository users,
                       RefreshTokenRepository refreshTokens,
                       PasswordEncoder passwordEncoder,
                       TokenService tokenService,
                       SecurityProperties properties) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.passwordEncoder = passwordEncoder;
        this.tokenService = tokenService;
        this.properties = properties;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String username = request.username().trim();
        String email = request.email().trim().toLowerCase();
        if (users.existsByUsername(username)) {
            throw new ApiException(HttpStatus.CONFLICT, "Username already exists");
        }
        if (users.existsByEmail(email)) {
            throw new ApiException(HttpStatus.CONFLICT, "Email already exists");
        }

        User user = new User();
        user.setId(UUID.randomUUID());
        user.setUsername(username);
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(User.Role.STAFF);
        user.setStatus(User.UserStatus.ACTIVE);
        users.save(user);
        return issueSession(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        User user = users.findByUsername(request.username().trim())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Invalid username or password"));
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid username or password");
        }
        if (user.getStatus() != User.UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "User is not active");
        }
        return issueSession(user);
    }

    @Transactional
    public AuthResponse refresh(RefreshRequest request) {
        String hash = sha256(request.refreshToken());
        RefreshToken current = refreshTokens.findByTokenHash(hash)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "Invalid refresh token"));
        Instant now = Instant.now();
        if (current.getRevokedAt() != null || !current.getExpiresAt().isAfter(now)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Refresh token expired or revoked");
        }
        User user = current.getUser();
        if (user.getStatus() != User.UserStatus.ACTIVE) {
            throw new ApiException(HttpStatus.FORBIDDEN, "User is not active");
        }

        IssuedSession next = issueSessionInternal(user);
        current.setRevokedAt(now);
        current.setReplacedByJti(next.refreshJti());
        current.setLastUsedAt(now);
        refreshTokens.save(current);
        return next.response();
    }

    @Transactional
    public void logout(LogoutRequest request) {
        refreshTokens.findByTokenHash(sha256(request.refreshToken())).ifPresent(token -> {
            if (token.getRevokedAt() == null) {
                token.setRevokedAt(Instant.now());
                token.setLastUsedAt(Instant.now());
                refreshTokens.save(token);
            }
        });
    }

    private AuthResponse issueSession(User user) {
        return issueSessionInternal(user).response();
    }

    private IssuedSession issueSessionInternal(User user) {
        TokenService.AccessToken access = tokenService.issueAccessToken(user);
        String refreshPlain = generateRefreshToken();
        RefreshToken refresh = new RefreshToken();
        refresh.setId(UUID.randomUUID());
        refresh.setUser(user);
        refresh.setTokenHash(sha256(refreshPlain));
        UUID refreshJti = UUID.randomUUID();
        refresh.setJti(refreshJti);
        refresh.setExpiresAt(Instant.now().plus(properties.getRefreshTokenDays(), ChronoUnit.DAYS));
        refreshTokens.save(refresh);

        AuthResponse response = new AuthResponse(
                "Bearer",
                access.value(),
                Math.max(1, properties.getAccessTokenMinutes() * 60),
                refreshPlain,
                refresh.getExpiresAt(),
                new AuthResponse.UserResponse(user.getId(), user.getUsername(), user.getEmail(), user.getRole().name(), user.getStatus().name())
        );
        return new IssuedSession(response, refreshJti);
    }

    private String generateRefreshToken() {
        byte[] bytes = new byte[64];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String sha256(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private record IssuedSession(AuthResponse response, UUID refreshJti) {}
}