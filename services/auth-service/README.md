# auth-service

## 1. Vai trò

Auth Service sở hữu `users` và `refresh_tokens`. Đây là service duy nhất phát hành access JWT cho hệ thống.

```mermaid
flowchart LR
 C[Client] --> AC[AuthController]
 AC --> AS[AuthService]
 AS --> UR[UserRepository]
 AS --> TS[TokenService]
 UR --> DB[(auth_db)]
 TS --> RT[RefreshTokenRepository]
 RT --> DB
 TS --> JWT[RS256 JWT]
```

## 2. Thư viện

- WebMVC
- Spring Security
- Spring Data JPA
- Bean Validation
- OAuth2 Resource Server
- Spring Security JOSE/Nimbus
- Flyway + PostgreSQL
- Actuator
- Spring Boot Test + Spring Security Test
- PostgreSQL JDBC

## 3. Cấu trúc source hiện tại

```text
auth-service/
├── pom.xml
├── README.md
└── src/main
    ├── java/com/wms/auth
    │   ├── AuthApplication.java
    │   ├── config
    │   │   ├── RsaKeyConfig.java
    │   │   ├── SecurityConfig.java
    │   │   └── SecurityProperties.java
    │   ├── controller
    │   │   ├── AuthController.java
    │   │   └── JwkController.java
    │   ├── dto
    │   │   ├── AuthResponse.java
    │   │   ├── LoginRequest.java
    │   │   ├── LogoutRequest.java
    │   │   ├── RefreshRequest.java
    │   │   └── RegisterRequest.java
    │   ├── entity
    │   │   ├── RefreshToken.java
    │   │   └── User.java
    │   ├── exception
    │   │   ├── ApiException.java
    │   │   └── GlobalExceptionHandler.java
    │   ├── repository
    │   │   ├── RefreshTokenRepository.java
    │   │   └── UserRepository.java
    │   └── service
    │       ├── AuthService.java
    │       └── TokenService.java
    └── resources
        ├── application.yml
        └── db/migration/V1__auth_schema.sql
```

## 4. Database

- `users`: id, username, email, password hash, role, status, timestamps.
- `refresh_tokens`: token hash, user id, JTI, expiration, revoked time, replacement JTI.

## 5. Token design

- Access token: RSA 2048, RS256, mặc định 15 phút.
- Refresh token: random opaque token, mặc định 7 ngày.
- Chỉ hash SHA-256 của refresh token được lưu DB.
- Refresh rotation: token cũ bị revoke, tạo token mới.
- Password: BCrypt.
- JWT claims gồm issuer, subject, username, email, role, scope, iat, exp, jti.

Private/public key local được tạo ở `JWT_KEY_DIRECTORY` nếu chưa có. Production nên dùng secret manager/KMS/Vault và có key rotation.

## 6. API

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/auth/me
GET  /.well-known/jwks.json
```

## 7. Demo login từ đầu đến cuối

### Bước 1 — register

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","email":"admin@example.com","password":"ChangeMe123!"}'
```

### Bước 2 — login

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"ChangeMe123!"}'
```

### Bước 3 — gọi API bảo vệ

```bash
curl http://localhost:8080/api/auth/me \
  -H "Authorization: Bearer <accessToken>"
```

### Luồng code

```text
POST /api/auth/login
 -> AuthController.login()
 -> AuthService.login()
 -> UserRepository.findByUsername()
 -> PasswordEncoder.matches()
 -> TokenService.issueTokens()
 -> RefreshTokenRepository.save()
 -> AuthResponse
 -> HTTP 200
```

### Bước 4 — refresh

```bash
curl -X POST http://localhost:8080/api/auth/refresh \
  -H 'Content-Type: application/json' \
  -d '{"refreshToken":"<refreshToken>"}'
```

Luồng:

```text
refresh token
 -> hash SHA-256
 -> tìm refresh_tokens
 -> kiểm tra revoked/expired
 -> revoke token cũ
 -> tạo access + refresh token mới
 -> lưu replacement JTI
 -> trả AuthResponse
```

## 8. Cách mở rộng code

- `controller`: chỉ HTTP contract.
- `dto`: request/response.
- `service`: login, register, refresh, logout.
- `repository`: query DB.
- `entity`: mapping bảng.
- `config`: security/key.
- `exception`: chuyển lỗi domain thành JSON HTTP.

Không đặt password hash/JWT signing logic trong Controller.

## 9. Đọc và mở rộng code hiện có

Luồng login đang được triển khai theo các file:

```text
AuthController.login(LoginRequest)
  -> AuthService.login()
  -> UserRepository.findByUsername()
  -> PasswordEncoder.matches()
  -> TokenService.issueAccessToken()
  -> RefreshTokenRepository.save()  # chỉ lưu SHA-256 hash
  -> AuthResponse
```

Ví dụ khung use case login hiện tại:

```java
@Transactional
public AuthResponse login(LoginRequest request) {
  User user = users.findByUsername(request.username().trim())
      .orElseThrow(() -> new ApiException(
          HttpStatus.UNAUTHORIZED, "Invalid username or password"));

  if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
    throw new ApiException(HttpStatus.UNAUTHORIZED, "Invalid username or password");
  }
  if (user.getStatus() != User.UserStatus.ACTIVE) {
    throw new ApiException(HttpStatus.FORBIDDEN, "User is not active");
  }
  return issueSession(user);
}
```

Khi thêm API user/role: tạo Request/Response DTO có Bean Validation -> thêm method vào `AuthController` -> xử lý quyền/nghiệp vụ ở service -> dùng `UserRepository` -> test 200/400/401/403/409 bằng MockMvc. Không trả `passwordHash`, `tokenHash`, private key hoặc refresh token đã lưu.

**Đối chiếu implementation:** README và code hiện có login theo username; nếu muốn login bằng email, bổ sung `findByEmail`/query có chủ đích và test, không chỉ sửa mô tả API.
