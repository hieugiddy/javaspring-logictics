package com.wms.auth.dto;

import java.time.Instant;
import java.util.UUID;

public record AuthResponse(
        String tokenType,
        String accessToken,
        long expiresIn,
        String refreshToken,
        Instant refreshExpiresAt,
        UserResponse user
) {
    public record UserResponse(UUID id, String username, String email, String role, String status) {}
}
