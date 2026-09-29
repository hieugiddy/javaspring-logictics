# Lộ trình Backend Java Logistics trong 30 ngày

> Phạm vi: Spring Boot microservices, Java 17, PostgreSQL, Redis, RabbitMQ, Gradle WAR/Tomcat, Docker, Jenkins. Mỗi ngày học một phần, hoàn thành task nhỏ, kiểm tra bằng test/Swagger, rồi commit.
>
> **Trạng thái workspace:** các service hiện là scaffold; chưa có source Java, Gradle Wrapper hoặc `build.gradle`. Hoàn thành Day 1 để tạo nền trước khi chạy các lệnh build/test ở những ngày sau.

## Cách dùng kế hoạch

- Mỗi ngày dành 30-60 phút học, 60-120 phút thực hành, 30-60 phút kiểm tra/sửa lỗi và khoảng 15 phút ghi chú/commit.
- Đọc đúng tài liệu/section được chỉ ra trong ngày; không cần đọc hết hai README cùng lúc.
- Git commit hằng ngày. Không commit `.env`, mật khẩu, JWT secret, token, khóa SSH hay credential.
- Swagger được cập nhật theo từng API; không đợi tới cuối dự án mới bổ sung tài liệu API.

---

## Day 01 — Setup môi trường và service đầu tiên

### Goal

Tạo nền Java 17/Spring Boot/Gradle và chạy được một ứng dụng WAR nhỏ trên Tomcat.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `JDK 17`, `Spring Boot lifecycle`, `Gradle Wrapper`, `WAR vs JAR`, `SpringBootServletInitializer`, `Tomcat context path`, `springdoc`.

### Tasks

- [ ] Cài JDK 17, IntelliJ, Git, Docker và Tomcat 10.1 tương thích.
- [ ] Tạo Gradle Wrapper và một `product-service` Spring Boot.
- [ ] Thêm plugin `war`, `SpringBootServletInitializer`, Actuator và springdoc.
- [ ] Chạy PostgreSQL/Redis/RabbitMQ bằng Compose khi file hạ tầng đã sẵn sàng.
- [ ] Tạo `GET /api/v1/hello`; build `clean test bootWar`; deploy WAR local.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo nền Java 17/Spring Boot/Gradle và chạy được một ứng dụng WAR nhỏ trên Tomcat. Kiểm chứng mức hiểu bằng output: Service khởi động được; WAR và Swagger UI truy cập được.

### Swagger

Mở `/product-service/swagger-ui.html`, xác nhận endpoint hello có request/response và trả 200.

### Git

Tạo `main` và `develop`; làm trên `feature/day-01-bootstrap`; commit `chore: initialize spring boot war service`.

### Từ khóa tự học

`JDK 17`, `Spring Boot lifecycle`, `Gradle Wrapper`, `WAR vs JAR`, `SpringBootServletInitializer`, `Tomcat context path`, `springdoc`.

### Tài liệu tham chiếu

[README_CICD_FILES.md](README_CICD_FILES.md) §2-§5; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §3, §20; `docs/templates/build.gradle.example`.

### Output

Service khởi động được; WAR và Swagger UI truy cập được.

---

## Day 02 — Package theo màn hình và dependency injection

### Goal

Tạo cấu trúc package `screens/<feature>/controller/service/repository/db` cho một màn Product.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `IoC`, `Dependency Injection`, `constructor injection`, `Controller-Service-Repository`, `package by feature`, `DTO`.

### Tasks

- [ ] Tạo `screens/S06-product/` gồm controller, service, repository, db/jpa và DTO.
- [ ] Dùng constructor injection; không khởi tạo service bằng `new` trong controller.
- [ ] Tạo API đọc danh sách product tạm thời từ in-memory repository.
- [ ] Giữ domain/use-case không phụ thuộc Spring MVC hoặc MyBatis cụ thể.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo cấu trúc package `screens/<feature>/controller/service/repository/db` cho một màn Product. Kiểm chứng mức hiểu bằng output: Một luồng controller -> service -> repository chạy được và có DTO riêng.

### Swagger

Đưa `GET /api/v1/products` lên Swagger; khai báo `page`, `size`, response DTO và ví dụ danh sách rỗng.

### Git

Nhánh `feature/day-02-product-layers`; commit `feat: add product screen layers`.

### Từ khóa tự học

`IoC`, `Dependency Injection`, `constructor injection`, `Controller-Service-Repository`, `package by feature`, `DTO`.

### Tài liệu tham chiếu

[README.md](README.md) §3 phần cấu trúc package; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §6, §10, §21.

### Output

Một luồng controller -> service -> repository chạy được và có DTO riêng.

---

## Day 03 — REST API và HTTP contract

### Goal

Hiểu cách ánh xạ HTTP method, route, query, body và status code vào use case.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `REST constraints`, `GET/POST/PUT/PATCH/DELETE`, `path variable`, `query parameter`, `HTTP status`, `JSON`.

### Tasks

- [ ] Hoàn thiện `GET /products`, `GET /products/{id}`, `POST /products`.
- [ ] Dùng request/response DTO, không trả JPA entity.
- [ ] Trả 200 khi đọc, 201 khi tạo; trả 404 khi không có product.
- [ ] Kiểm tra request bằng curl/Postman và gọi qua Gateway nếu Gateway đã có.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Hiểu cách ánh xạ HTTP method, route, query, body và status code vào use case. Kiểm chứng mức hiểu bằng output: API Product hoạt động với contract HTTP nhất quán.

### Swagger

Bổ sung summary, mô tả, path/query parameter, request body, response 200/201/404.

### Git

Nhánh `feature/day-03-product-rest`; commit `feat: add product rest endpoints`.

### Từ khóa tự học

`REST constraints`, `GET/POST/PUT/PATCH/DELETE`, `path variable`, `query parameter`, `HTTP status`, `JSON`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §6, §10; [README_CICD_FILES.md](README_CICD_FILES.md) §5 phần Swagger.

### Output

API Product hoạt động với contract HTTP nhất quán.

---

## Day 04 — DTO, validation và error response

### Goal

Chặn input sai tại biên API và trả lỗi có cấu trúc.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `Jakarta Bean Validation`, `@Valid`, `ConstraintViolation`, `@RestControllerAdvice`, `Problem Details`, `trace ID`.

### Tasks

- [ ] Tạo DTO tạo/cập nhật product và response DTO.
- [ ] Dùng Jakarta Validation: `@NotBlank`, `@Size`, `@PositiveOrZero`, `@NotNull`.
- [ ] Tạo exception handler chung bằng `@RestControllerAdvice`.
- [ ] Chuẩn hóa error gồm `code`, `message`, `timestamp`, `traceId`.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Chặn input sai tại biên API và trả lỗi có cấu trúc. Kiểm chứng mức hiểu bằng output: SKU rỗng/giá âm trả 400; duplicate SKU trả 409; lỗi có trace ID.

### Swagger

Khai báo schema DTO, field bắt buộc, giới hạn chiều dài và response 400/409.

### Git

Nhánh `feature/day-04-validation`; commit `feat: validate product requests`.

### Từ khóa tự học

`Jakarta Bean Validation`, `@Valid`, `ConstraintViolation`, `@RestControllerAdvice`, `Problem Details`, `trace ID`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §10, §16, §20.

### Output

SKU rỗng/giá âm trả 400; duplicate SKU trả 409; lỗi có trace ID.

---

## Day 05 — PostgreSQL, schema và migration

### Goal

Tạo database từ DDL/migration, hiểu PK/FK/unique/check/index.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `PostgreSQL`, `primary key`, `foreign key`, `UNIQUE`, `CHECK`, `Flyway`, `DDL`, `EXPLAIN ANALYZE`.

### Tasks

- [ ] Khởi động PostgreSQL local và chạy `docs/SQL/schema.sql` trong database học tập.
- [ ] Kiểm tra bảng User, Category, Product, Warehouse, Inventory, Order, Shipment, Notification.
- [ ] Tạo migration đầu tiên bằng Flyway cho service đang làm.
- [ ] Không sửa migration đã chạy trên môi trường dùng chung.
- [ ] So sánh query có index và không index bằng `EXPLAIN ANALYZE`.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo database từ DDL/migration, hiểu PK/FK/unique/check/index. Kiểm chứng mức hiểu bằng output: Database/migration tạo được; hiểu mỗi service sở hữu bảng nào.

### Swagger

Xác nhận response Product không phụ thuộc cấu trúc DB/entity; cập nhật ví dụ nếu thêm category field.

### Git

Nhánh `feature/day-05-postgres`; commit `feat: add initial product schema migration`.

### Từ khóa tự học

`PostgreSQL`, `primary key`, `foreign key`, `UNIQUE`, `CHECK`, `Flyway`, `DDL`, `EXPLAIN ANALYZE`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §16, §24-§25; [README_CICD_FILES.md](README_CICD_FILES.md) §3.

### Output

Database/migration tạo được; hiểu mỗi service sở hữu bảng nào.

---

## Day 06 — Hibernate/JPA CRUD

### Goal

Nối Product Service với PostgreSQL bằng JPA cho CRUD đơn giản.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `JPA`, `Hibernate`, `Persistence Context`, `Entity lifecycle`, `JpaRepository`, `@ManyToOne`, `dirty checking`.

### Tasks

- [ ] Tạo `ProductEntity`, `CategoryEntity`, quan hệ `ManyToOne`.
- [ ] Tạo Spring Data repository trong lớp `db/jpa`.
- [ ] Map entity sang DTO tại service; không serialize entity trực tiếp.
- [ ] Kiểm tra transaction và SQL do Hibernate sinh.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Nối Product Service với PostgreSQL bằng JPA cho CRUD đơn giản. Kiểm chứng mức hiểu bằng output: Product CRUD đọc/ghi PostgreSQL qua JPA và DTO.

### Swagger

Thử POST/GET/GET-by-id trong Swagger; cập nhật schema nếu response có category.

### Git

Nhánh `feature/day-06-product-jpa`; commit `feat: persist product with jpa`.

### Từ khóa tự học

`JPA`, `Hibernate`, `Persistence Context`, `Entity lifecycle`, `JpaRepository`, `@ManyToOne`, `dirty checking`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §10, §16; [README_CICD_FILES.md](README_CICD_FILES.md) §5.

### Output

Product CRUD đọc/ghi PostgreSQL qua JPA và DTO.

---

## Day 07 — Quan hệ dữ liệu, LAZY và N+1

### Goal

Tải quan hệ Product-Category đúng nhu cầu mà không phát sinh truy vấn dư thừa.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `LAZY`, `EAGER`, `N+1`, `fetch join`, `EntityGraph`, `projection`, `serialization cycle`.

### Tasks

- [ ] Thiết lập `ManyToOne`/`OneToMany` và kiểm tra JSON không đệ quy.
- [ ] Thử LAZY/EAGER; bật Hibernate SQL log.
- [ ] Tạo projection/fetch query cho màn danh sách.
- [ ] Không expose collection/entity graph ngoài ý muốn.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tải quan hệ Product-Category đúng nhu cầu mà không phát sinh truy vấn dư thừa. Kiểm chứng mức hiểu bằng output: Danh sách Product không tạo N+1 và response không bị vòng lặp.

### Swagger

Kiểm tra response Product có category fields cần thiết nhưng không lộ entity nội bộ.

### Git

Nhánh `feature/day-07-product-category`; commit `perf: fetch product category efficiently`.

### Từ khóa tự học

`LAZY`, `EAGER`, `N+1`, `fetch join`, `EntityGraph`, `projection`, `serialization cycle`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §9-§10, §16-§17.

### Output

Danh sách Product không tạo N+1 và response không bị vòng lặp.

---

## Day 08 — MyBatis mapper

### Goal

Dùng MyBatis cho một truy vấn đọc cần SQL tường minh.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `MyBatis`, `Mapper XML`, `#{}` vs `${}`, `resultMap`, `projection`, `prepared statement`.

### Tasks

- [ ] Tạo `ProductQueryRepository` interface và MyBatis mapper/XML.
- [ ] Dùng bind parameter `#{}`; không nối chuỗi input vào SQL.
- [ ] Map kết quả sang DTO/read model.
- [ ] Giữ mapper trong `screens/S06-product/db/mybatis`.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Dùng MyBatis cho một truy vấn đọc cần SQL tường minh. Kiểm chứng mức hiểu bằng output: Product search chạy bằng mapper có bind parameter.

### Swagger

Mô tả query filter và read model trả về; kiểm tra response có ví dụ.

### Git

Nhánh `feature/day-08-product-mybatis`; commit `feat: add product search mapper`.

### Từ khóa tự học

`MyBatis`, `Mapper XML`, `#{}` vs `${}`, `resultMap`, `projection`, `prepared statement`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §10, §16; `docs/SQL/schema.sql`.

### Output

Product search chạy bằng mapper có bind parameter.

---

## Day 09 — Search, filter, sort và pagination

### Goal

Hoàn thiện API danh sách catalog theo query chuẩn.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `dynamic SQL`, `pagination`, `sort allowlist`, `index selectivity`, `query plan`, `SQL injection`.

### Tasks

- [ ] Hỗ trợ keyword/category/status/page/size/sort.
- [ ] Whitelist tên cột sort; chặn raw SQL/order expression từ client.
- [ ] Dùng `LIMIT/OFFSET` hoặc `Pageable` phù hợp adapter.
- [ ] Tạo response list có `items`, `page`, `size`, `totalElements`, `totalPages`.
- [ ] Dùng EXPLAIN để kiểm tra index phù hợp.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Hoàn thiện API danh sách catalog theo query chuẩn. Kiểm chứng mức hiểu bằng output: API Product list có filter/search/sort/page và test cho boundary.

### Swagger

Khai báo đầy đủ query parameter, giá trị mặc định, giới hạn size và lỗi 400.

### Git

Nhánh `feature/day-09-product-search`; commit `feat: add product filtering and pagination`.

### Từ khóa tự học

`dynamic SQL`, `pagination`, `sort allowlist`, `index selectivity`, `query plan`, `SQL injection`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §10, §16-§17; [README_CICD_FILES.md](README_CICD_FILES.md) §5.

### Output

API Product list có filter/search/sort/page và test cho boundary.

---

## Day 10 — User Service và password hashing

### Goal

Tạo nền xác thực bằng tài khoản lưu PostgreSQL.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `PasswordEncoder`, `BCrypt`, `salt`, `authentication`, `credential stuffing`, `safe error message`.

### Tasks

- [ ] Tạo `UserEntity`/repository và seed user local.
- [ ] Cấu hình BCrypt `PasswordEncoder`.
- [ ] Tạo use case tìm user theo username/email và kiểm tra status.
- [ ] Không log/return mật khẩu; lỗi đăng nhập không tiết lộ user có tồn tại hay không.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo nền xác thực bằng tài khoản lưu PostgreSQL. Kiểm chứng mức hiểu bằng output: Kiểm tra mật khẩu đúng/sai; DB chỉ lưu BCrypt hash.

### Swagger

Tạo mô tả `POST /auth/login` dạng public, request DTO và 200/401.

### Git

Nhánh `feature/day-10-user-password`; commit `feat: add user password authentication base`.

### Từ khóa tự học

`PasswordEncoder`, `BCrypt`, `salt`, `authentication`, `credential stuffing`, `safe error message`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §8, §16; `docs/SQL/schema.sql`.

### Output

Kiểm tra mật khẩu đúng/sai; DB chỉ lưu BCrypt hash.

---

## Day 11 — JWT access token

### Goal

Phát và xác minh JWT cho API được bảo vệ.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `JWT`, `JWS`, `RS256/HMAC`, `issuer`, `audience`, `JwtDecoder`, `SecurityContext`.

### Tasks

- [ ] Tạo JWT issuer tại User Service.
- [ ] Cấu hình `iss`, `aud`, `sub`, `role`, `iat`, `exp`, `jti`.
- [ ] Cấu hình Spring Security Resource Server/JwtDecoder.
- [ ] Bảo vệ `GET /api/v1/auth/me` và một Product API.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Phát và xác minh JWT cho API được bảo vệ. Kiểm chứng mức hiểu bằng output: Không token -> 401; token đúng -> 200; chữ ký/expiry sai -> 401.

### Swagger

Cấu hình HTTP Bearer scheme; test nút Authorize với token hợp lệ/hết hạn.

### Git

Nhánh `feature/day-11-jwt`; commit `feat: issue and validate jwt access tokens`.

### Từ khóa tự học

`JWT`, `JWS`, `RS256/HMAC`, `issuer`, `audience`, `JwtDecoder`, `SecurityContext`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §20; [README_CICD_FILES.md](README_CICD_FILES.md) §5.

### Output

Không token -> 401; token đúng -> 200; chữ ký/expiry sai -> 401.

---

## Day 12 — Refresh token, rotation và logout

### Goal

Quản lý session dài hạn mà không lưu refresh token thô.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `opaque token`, `token hash`, `rotation`, `revocation`, `session reuse`, `transaction`.

### Tasks

- [ ] Tạo `refresh_tokens` migration/entity.
- [ ] Sinh opaque random token, lưu hash, `jti`, expiry, revoke state.
- [ ] Cài `POST /auth/refresh`, `/logout`, `/logout-all`.
- [ ] Xoay token cũ thành token mới trong transaction; thử reuse token đã revoke.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Quản lý session dài hạn mà không lưu refresh token thô. Kiểm chứng mức hiểu bằng output: Refresh rotation thành công; dùng lại token cũ trả 401; logout thu hồi session.

### Swagger

Mô tả body refresh/logout và kết quả 200/204/401; không đưa token thật vào example.

### Git

Nhánh `feature/day-12-refresh-session`; commit `feat: rotate and revoke refresh sessions`.

### Từ khóa tự học

`opaque token`, `token hash`, `rotation`, `revocation`, `session reuse`, `transaction`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §16; `docs/SQL/schema.sql`.

### Output

Refresh rotation thành công; dùng lại token cũ trả 401; logout thu hồi session.

---

## Day 13 — RBAC và ownership

### Goal

Áp quyền theo role và phạm vi tài nguyên.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `RBAC`, `@PreAuthorize`, `method security`, `ownership`, `least privilege`, `403`.

### Tasks

- [ ] Ánh xạ role claim vào Spring authorities.
- [ ] Tạo method security/service authorization.
- [ ] Chặn ADMIN thao tác trên SUPER_ADMIN theo policy.
- [ ] Thiết kế user-warehouse assignment trước khi bật quyền manager theo kho.
- [ ] Test cả success và forbidden.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Áp quyền theo role và phạm vi tài nguyên. Kiểm chứng mức hiểu bằng output: Role sai bị 403; không tự nâng quyền; warehouse scope có dữ liệu assignment rõ ràng.

### Swagger

Gắn security requirement và mô tả role cần có cho mỗi endpoint user/product/inventory.

### Git

Nhánh `feature/day-13-rbac`; commit `feat: enforce role and resource access rules`.

### Từ khóa tự học

`RBAC`, `@PreAuthorize`, `method security`, `ownership`, `least privilege`, `403`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §2, §8, §11-§13, §21.

### Output

Role sai bị 403; không tự nâng quyền; warehouse scope có dữ liệu assignment rõ ràng.

---

## Day 14 — Transaction và concurrency

### Goal

Đảm bảo mutation tồn không bị mất cập nhật hoặc tạo tồn âm.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `ACID`, `@Transactional`, `isolation`, `lost update`, `@Version`, `SELECT FOR UPDATE`, `rollback`.

### Tasks

- [ ] Viết `AdjustInventoryService` có `@Transactional`.
- [ ] Chọn optimistic `@Version` hoặc `SELECT FOR UPDATE` cho use case.
- [ ] Ghi inventory và history trong cùng transaction.
- [ ] Cố tình ném exception giữa transaction để kiểm tra rollback.
- [ ] Gửi hai request đồng thời và kiểm tra xung đột.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Đảm bảo mutation tồn không bị mất cập nhật hoặc tạo tồn âm. Kiểm chứng mức hiểu bằng output: Inventory update và transaction history commit/rollback cùng nhau.

### Swagger

Mô tả 409 concurrency conflict và 422 business rule trên API điều chỉnh tồn.

### Git

Nhánh `feature/day-14-inventory-transaction`; commit `feat: make inventory adjustment transactional`.

### Từ khóa tự học

`ACID`, `@Transactional`, `isolation`, `lost update`, `@Version`, `SELECT FOR UPDATE`, `rollback`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §12, §17-§18; `docs/SQL/schema.sql`.

### Output

Inventory update và transaction history commit/rollback cùng nhau.

---

## Day 15 — Order và Inventory workflow

### Goal

Tạo và chuyển trạng thái order với kiểm tra tồn.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `aggregate`, `state machine`, `reservation`, `saga`, `service ownership`, `idempotency`.

### Tasks

- [ ] Tạo order và order item DTO/entity/repository.
- [ ] Tính tổng tiền từ giá DB, không tin tổng client gửi.
- [ ] Cài confirm/cancel với state transition rõ ràng.
- [ ] Khi outbound confirm, kiểm tra/giữ tồn qua Inventory Service; không query DB service khác.
- [ ] Xử lý insufficient stock và concurrent conflict.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo và chuyển trạng thái order với kiểm tra tồn. Kiểm chứng mức hiểu bằng output: Order sai trạng thái/thiếu tồn không làm DB cập nhật một phần.

### Swagger

Khai báo create/detail/confirm/cancel, enum type/status, 409/422 và ví dụ order nhiều dòng.

### Git

Nhánh `feature/day-15-order-inventory`; commit `feat: add order inventory workflow`.

### Từ khóa tự học

`aggregate`, `state machine`, `reservation`, `saga`, `service ownership`, `idempotency`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §13, §17; `docs/SQL/schema.sql`.

### Output

Order sai trạng thái/thiếu tồn không làm DB cập nhật một phần.

---

## Day 16 — Redis cache-aside

### Goal

Cache read-heavy API mà không biến Redis thành nguồn dữ liệu chuẩn.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `cache-aside`, `TTL`, `cache key`, `serialization`, `cache miss`, `source of truth`.

### Tasks

- [ ] Kết nối Redis và tạo cache adapter.
- [ ] Cache product detail hoặc inventory lookup bằng key ổn định.
- [ ] Cấu hình TTL và serialize DTO.
- [ ] Đo cache miss/hit và kiểm tra fallback khi Redis unavailable.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Cache read-heavy API mà không biến Redis thành nguồn dữ liệu chuẩn. Kiểm chứng mức hiểu bằng output: Read endpoint dùng cache có TTL và fallback DB.

### Swagger

Giữ nguyên HTTP contract; xác nhận cache hit/miss trả cùng response schema.

### Git

Nhánh `feature/day-16-redis-cache`; commit `feat: cache product and inventory reads`.

### Từ khóa tự học

`cache-aside`, `TTL`, `cache key`, `serialization`, `cache miss`, `source of truth`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §18; [README_CICD_FILES.md](README_CICD_FILES.md) §3, §6.

### Output

Read endpoint dùng cache có TTL và fallback DB.

---

## Day 17 — Cache invalidation và rate limit

### Goal

Giữ cache nhất quán sau mutation và hiểu giới hạn tốc độ.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `cache invalidation`, `stale data`, `cache stampede`, `rate limit`, `distributed lock`, `after commit`.

### Tasks

- [ ] Invalidate key sau update product/inventory thành công.
- [ ] Chỉ xóa cache sau DB commit; test transaction rollback không phát event/invalidation sai.
- [ ] Xác định khi nào cần rate limit và khóa phân tán; không dùng Redis lock thay DB constraint.
- [ ] Thử stale cache và ghi lại cách xử lý.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Giữ cache nhất quán sau mutation và hiểu giới hạn tốc độ. Kiểm chứng mức hiểu bằng output: Mutation commit xong mới invalidate cache; test rollback giữ dữ liệu/cache đúng.

### Swagger

Không đổi payload; mô tả 429/Retry-After nếu bật rate limit ở Gateway.

### Git

Nhánh `feature/day-17-cache-invalidation`; commit `fix: invalidate cache after committed writes`.

### Từ khóa tự học

`cache invalidation`, `stale data`, `cache stampede`, `rate limit`, `distributed lock`, `after commit`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §12, §18; [README.md](README.md) §11-§12.

### Output

Mutation commit xong mới invalidate cache; test rollback giữ dữ liệu/cache đúng.

---

## Day 18 — RabbitMQ producer và consumer

### Goal

Gửi domain event và nhận event bằng Notification Service.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `exchange`, `queue`, `routing key`, `binding`, `producer`, `consumer`, `manual ACK`.

### Tasks

- [ ] Khai báo exchange `warehouse.events`, routing key và queue.
- [ ] Tạo event DTO có event ID, occurred-at, aggregate ID và correlation ID.
- [ ] Publish `order.created` hoặc `inventory.updated` sau khi business transaction hoàn tất.
- [ ] Tạo consumer local ghi log có cấu trúc.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Gửi domain event và nhận event bằng Notification Service. Kiểm chứng mức hiểu bằng output: Producer gửi event; consumer nhận đúng queue và log correlation ID.

### Swagger

RabbitMQ nội bộ không cần REST endpoint; nếu có endpoint xem sự kiện thì không cho client phát message tùy ý.

### Git

Nhánh `feature/day-18-rabbitmq`; commit `feat: publish and consume warehouse events`.

### Từ khóa tự học

`exchange`, `queue`, `routing key`, `binding`, `producer`, `consumer`, `manual ACK`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §3, §19; [README_CICD_FILES.md](README_CICD_FILES.md) §3.

### Output

Producer gửi event; consumer nhận đúng queue và log correlation ID.

---

## Day 19 — Retry, DLQ và idempotency

### Goal

Xử lý delivery at-least-once an toàn.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `at-least-once`, `redelivery`, `ack/nack`, `DLX`, `DLQ`, `backoff`, `idempotency`.

### Tasks

- [ ] Bật manual ACK; chỉ ACK sau khi persistence hoàn tất.
- [ ] Thêm bounded retry/backoff và DLX/DLQ.
- [ ] Dùng `event_id` làm idempotency key; thử phát lại cùng message.
- [ ] Ghi failure reason và correlation ID nhưng không log secret.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Xử lý delivery at-least-once an toàn. Kiểm chứng mức hiểu bằng output: Message trùng chỉ tạo một kết quả nghiệp vụ; message lỗi được retry rồi chuyển DLQ.

### Swagger

Mô tả lỗi API liên quan event nếu có; broker retry/DLQ không phơi chi tiết nội bộ cho client.

### Git

Nhánh `feature/day-19-messaging-reliability`; commit `feat: add retry dlq and idempotent consumer`.

### Từ khóa tự học

`at-least-once`, `redelivery`, `ack/nack`, `DLX`, `DLQ`, `backoff`, `idempotency`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §15, §19-§20.

### Output

Message trùng chỉ tạo một kết quả nghiệp vụ; message lỗi được retry rồi chuyển DLQ.

---

## Day 20 — Notification Service

### Goal

Persist notification từ domain event và cung cấp API cho user.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `event-driven`, `eventual consistency`, `consumer idempotency`, `unique constraint`, `notification inbox`.

### Tasks

- [ ] Tạo Notification entity/repository và consumer.
- [ ] Deduplicate theo `(event_id, user_id)`.
- [ ] Cài list/detail/mark-read/mark-all-read; chỉ đọc notification của user hiện tại.
- [ ] Kiểm tra ACK sau insert và xử lý duplicate insert.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Persist notification từ domain event và cung cấp API cho user. Kiểm chứng mức hiểu bằng output: Order event tạo notification duy nhất; user chỉ xem/đọc notification của mình.

### Swagger

Tài liệu hóa list/filter, mark-read, mark-all-read, Bearer auth và output mẫu.

### Git

Nhánh `feature/day-20-notifications`; commit `feat: add notification api and consumer`.

### Từ khóa tự học

`event-driven`, `eventual consistency`, `consumer idempotency`, `unique constraint`, `notification inbox`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §15, §19-§20; `docs/SQL/schema.sql`.

### Output

Order event tạo notification duy nhất; user chỉ xem/đọc notification của mình.

---

## Day 21 — API Gateway và ranh giới service

### Goal

Định tuyến API mà không biến Gateway thành nơi chứa nghiệp vụ/domain data.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `API Gateway`, `bounded context`, `database ownership`, `OpenFeign`, `timeout`, `circuit breaker`.

### Tasks

- [ ] Khai báo route cho auth, products, inventory, orders, shipment và notification.
- [ ] Truyền trace/correlation ID; cấu hình timeout cho REST client.
- [ ] Kiểm tra JWT ở Gateway và authorization lại trong service đích.
- [ ] Xác nhận không có cross-service DB query.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Định tuyến API mà không biến Gateway thành nơi chứa nghiệp vụ/domain data. Kiểm chứng mức hiểu bằng output: Gateway route đúng service; service vẫn enforce role/ownership.

### Swagger

Cấu hình Gateway OpenAPI aggregation nếu chọn; nếu chưa, Swagger từng service phải chỉ rõ base URL/context path.

### Git

Nhánh `feature/day-21-api-gateway`; commit `feat: route service apis through gateway`.

### Từ khóa tự học

`API Gateway`, `bounded context`, `database ownership`, `OpenFeign`, `timeout`, `circuit breaker`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §3-§4; [README.md](README.md) §3 và phần cấu trúc service.

### Output

Gateway route đúng service; service vẫn enforce role/ownership.

---

## Day 22 — JUnit 5

### Goal

Kiểm tra business rule bằng unit test nhanh, không cần DB.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `JUnit 5`, `AAA`, `assertions`, `parameterized test`, `test fixture`, `unit test boundary`.

### Tasks

- [ ] Test ProductService/AuthService theo Arrange-Act-Assert.
- [ ] Test validation, not-found, duplicate và insufficient stock.
- [ ] Tách test theo feature package; đặt tên nêu điều kiện/kết quả.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Kiểm tra business rule bằng unit test nhanh, không cần DB. Kiểm chứng mức hiểu bằng output: Unit test cho luồng success và business failure chính.

### Swagger

Dùng ví dụ Swagger làm input test; ghi nhận mọi khác biệt contract rồi cập nhật DTO/OpenAPI.

### Git

Nhánh `feature/day-22-junit`; commit `test: cover product auth and stock rules`.

### Từ khóa tự học

`JUnit 5`, `AAA`, `assertions`, `parameterized test`, `test fixture`, `unit test boundary`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §20-§21; [README_CICD_FILES.md](README_CICD_FILES.md) §7.

### Output

Unit test cho luồng success và business failure chính.

---

## Day 23 — Mockito

### Goal

Mock phụ thuộc ngoài để kiểm tra service/use case độc lập.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `mock`, `stub`, `verify`, `interaction test`, `Mockito`, `test double`.

### Tasks

- [ ] Dùng `@Mock`, `@InjectMocks`, `when/thenReturn`, `verify`.
- [ ] Test service gọi repository/event publisher đúng một lần.
- [ ] Test rollback/error mapping khi repository ném exception.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Mock phụ thuộc ngoài để kiểm tra service/use case độc lập. Kiểm chứng mức hiểu bằng output: Unit test service không cần database/broker thật.

### Swagger

Không thêm route mới; đối chiếu test với request/response contract hiện có.

### Git

Nhánh `feature/day-23-mockito`; commit `test: isolate use cases with mockito`.

### Từ khóa tự học

`mock`, `stub`, `verify`, `interaction test`, `Mockito`, `test double`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §20-§21.

### Output

Unit test service không cần database/broker thật.

---

## Day 24 — API integration test

### Goal

Kiểm tra luồng HTTP qua controller, validation, service và PostgreSQL.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `MockMvc`, `@SpringBootTest`, `Testcontainers`, `test slice`, `transaction rollback`, `contract test`.

### Tasks

- [ ] Dùng `@SpringBootTest` + MockMvc.
- [ ] Khởi chạy PostgreSQL bằng Testcontainers.
- [ ] Test CRUD Product, pagination, lỗi DTO và transaction.
- [ ] Reset dữ liệu giữa test; không phụ thuộc thứ tự chạy.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Kiểm tra luồng HTTP qua controller, validation, service và PostgreSQL. Kiểm chứng mức hiểu bằng output: API integration test chạy với PostgreSQL container.

### Swagger

So sánh OpenAPI schema với response test; phát hiện drift giữa implementation và docs.

### Git

Nhánh `feature/day-24-api-integration`; commit `test: add product api integration coverage`.

### Từ khóa tự học

`MockMvc`, `@SpringBootTest`, `Testcontainers`, `test slice`, `transaction rollback`, `contract test`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §10, §20-§21.

### Output

API integration test chạy với PostgreSQL container.

---

## Day 25 — Security, Redis và RabbitMQ integration test

### Goal

Kiểm tra các adapter hạ tầng và security qua luồng tích hợp.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `Spring Security test`, `JWT test`, `Testcontainers Redis`, `RabbitMQ integration`, `idempotency`, `DLQ test`.

### Tasks

- [ ] Test không token/sai token/hết hạn token và role không đủ.
- [ ] Test refresh rotation, logout/revoke.
- [ ] Test Redis cache miss/hit/invalidation.
- [ ] Test RabbitMQ duplicate, retry, DLQ và ACK sau persistence.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Kiểm tra các adapter hạ tầng và security qua luồng tích hợp. Kiểm chứng mức hiểu bằng output: Security matrix và tích hợp Redis/RabbitMQ có test lặp lại được.

### Swagger

Dùng Swagger Authorize kiểm tra thủ công; tự động hóa các case chính bằng MockMvc/security test.

### Git

Nhánh `feature/day-25-integration-security-messaging`; commit `test: cover jwt redis and rabbitmq integration`.

### Từ khóa tự học

`Spring Security test`, `JWT test`, `Testcontainers Redis`, `RabbitMQ integration`, `idempotency`, `DLQ test`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §15, §18-§20.

### Output

Security matrix và tích hợp Redis/RabbitMQ có test lặp lại được.

---

## Day 26 — SQL và hiệu năng

### Goal

Đo và tối ưu truy vấn thực tế thay vì thêm index theo cảm tính.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `EXPLAIN ANALYZE`, `buffer`, `selectivity`, `composite index`, `partial index`, `partition pruning`, `N+1`.

### Tasks

- [ ] Đo product search, inventory lookup, order detail bằng `EXPLAIN (ANALYZE, BUFFERS)`.
- [ ] Kiểm tra N+1, select dư cột, sort không index và pagination lớn.
- [ ] Đánh giá B-tree/composite/partial/expression index và partition pruning.
- [ ] Ghi số liệu trước/sau cùng kích thước dữ liệu.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Đo và tối ưu truy vấn thực tế thay vì thêm index theo cảm tính. Kiểm chứng mức hiểu bằng output: Có đo đạc, lý do chọn index/query và cải thiện có thể lặp lại.

### Swagger

Xác nhận query filter/sort/page có giới hạn hợp lý và không cho truyền tên cột tùy ý.

### Git

Nhánh `perf/day-26-query-tuning`; commit `perf: tune warehouse read queries`.

### Từ khóa tự học

`EXPLAIN ANALYZE`, `buffer`, `selectivity`, `composite index`, `partial index`, `partition pruning`, `N+1`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §16-§18, `docs/SQL/schema.sql` phần kiến thức mở rộng.

### Output

Có đo đạc, lý do chọn index/query và cải thiện có thể lặp lại.

---

## Day 27 — Docker, WAR và Tomcat

### Goal

Đóng gói service WAR cùng Tomcat và kiểm tra runtime giống deployment.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `Docker multi-stage`, `image layer`, `WAR deployment`, `Tomcat context path`, `health check`, `secret injection`.

### Tasks

- [ ] Tạo Dockerfile multi-stage: Gradle build -> Tomcat runtime.
- [ ] Pin image version; inject config/secrets qua environment.
- [ ] Chạy PostgreSQL/Redis/RabbitMQ bằng Compose; chạy service container.
- [ ] Xác nhận context path, port, log và `/actuator/health`.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Đóng gói service WAR cùng Tomcat và kiểm tra runtime giống deployment. Kiểm chứng mức hiểu bằng output: Service chạy trong container và kết nối được dependency local.

### Swagger

Truy cập Swagger qua Tomcat/container với context path thực tế; kiểm tra Bearer Authorize.

### Git

Nhánh `feature/day-27-docker-war`; commit `build: package service war in tomcat image`.

### Từ khóa tự học

`Docker multi-stage`, `image layer`, `WAR deployment`, `Tomcat context path`, `health check`, `secret injection`.

### Tài liệu tham chiếu

[README_CICD_FILES.md](README_CICD_FILES.md) §5-§6; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §20.

### Output

Service chạy trong container và kết nối được dependency local.

---

## Day 28 — Jenkins CI

### Goal

Tạo pipeline tự động checkout, test, đóng gói và lưu artifact.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `Jenkinsfile`, `agent`, `stage`, `artifact`, `quality gate`, `Jenkins credentials`, `webhook`.

### Tasks

- [ ] Cấu hình Jenkins agent/credential và webhook.
- [ ] Chạy Gradle compile/unit/integration test, static analysis và `bootWar`.
- [ ] Lưu WAR theo commit SHA, lưu JUnit report.
- [ ] Bất kỳ quality gate nào fail thì dừng pipeline.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Tạo pipeline tự động checkout, test, đóng gói và lưu artifact. Kiểm chứng mức hiểu bằng output: Jenkins build/test tự động; artifact WAR được fingerprint/version hóa.

### Swagger

Có thể kiểm tra OpenAPI generation trong build; không để endpoint/docs generation lỗi bị bỏ qua.

### Git

Tạo `feature/day-28-jenkins-ci`; mở PR/MR vào develop; commit `ci: add gradle test and war pipeline`.

### Từ khóa tự học

`Jenkinsfile`, `agent`, `stage`, `artifact`, `quality gate`, `Jenkins credentials`, `webhook`.

### Tài liệu tham chiếu

[README_CICD_FILES.md](README_CICD_FILES.md) §7, §9; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §21.

### Output

Jenkins build/test tự động; artifact WAR được fingerprint/version hóa.

---

## Day 29 — Jenkins CD, health check và rollback

### Goal

Triển khai artifact đã build lên DEV, xác minh và có đường rollback.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `artifact promotion`, `deployment strategy`, `smoke test`, `health check`, `rollback`, `environment approval`.

### Tasks

- [ ] Deploy đúng WAR artifact lên Tomcat DEV qua SCP/SSH hoặc Tomcat Manager.
- [ ] Chạy health check và smoke test API sau deployment.
- [ ] Lưu phiên bản hiện tại/trước đó; thử rollback khi smoke test fail.
- [ ] Promote cùng artifact qua staging/production sau approval; không commit secret.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Triển khai artifact đã build lên DEV, xác minh và có đường rollback. Kiểm chứng mức hiểu bằng output: DEV deployment có health/smoke gate và rollback được kiểm thử.

### Swagger

Mở Swagger ở môi trường DEV; xác nhận context path/base URL, security scheme và API response.

### Git

Tạo nhánh `feature/day-29-jenkins-cd`; commit `ci: deploy war and verify health`; chỉ promote tag/commit đã qua gate.

### Từ khóa tự học

`artifact promotion`, `deployment strategy`, `smoke test`, `health check`, `rollback`, `environment approval`.

### Tài liệu tham chiếu

[README_CICD_FILES.md](README_CICD_FILES.md) §7; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §20-§21.

### Output

DEV deployment có health/smoke gate và rollback được kiểm thử.

---

## Day 30 — Tích hợp, demo và review

### Goal

Chứng minh luồng end-to-end từ đăng nhập tới order, tồn kho, event, notification và deployment.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `end-to-end test`, `acceptance criteria`, `observability`, `release tag`, `definition of done`, `technical debt`.

### Tasks

- [ ] Demo login/JWT/RBAC; tạo product/order; xác nhận tác động inventory transaction.
- [ ] Phát event, xử lý notification idempotent; chứng minh Redis invalidation.
- [ ] Chạy toàn bộ unit/integration/security test.
- [ ] Build WAR, deploy DEV, mở Swagger, chạy health/smoke test và thử rollback.
- [ ] Ghi lại schema gap/API gap còn lại; không giả định scaffold đã triển khai tính năng.

### Sau khi hoàn thành phải hiểu

Sau ngày này, tự giải thích được mục tiêu: Chứng minh luồng end-to-end từ đăng nhập tới order, tồn kho, event, notification và deployment. Kiểm chứng mức hiểu bằng output: Demo có bằng chứng test/build/deploy, biết rõ phần nào đã chạy và phần nào còn là thiết kế.

### Swagger

Dùng Swagger làm checklist contract cuối: endpoint, DTO, validation, role, success/error schema và ví dụ.

### Git

Tạo tag demo/release theo commit đã qua CI; cập nhật README/changelog nếu repository có quy ước; không commit secret hoặc dữ liệu thật.

### Từ khóa tự học

`end-to-end test`, `acceptance criteria`, `observability`, `release tag`, `definition of done`, `technical debt`.

### Tài liệu tham chiếu

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §21-§25; [README_CICD_FILES.md](README_CICD_FILES.md) §7-§9.

### Output

Demo có bằng chứng test/build/deploy, biết rõ phần nào đã chạy và phần nào còn là thiết kế.

---

## Quy ước Git dùng xuyên suốt

```text
main
└── develop
    ├── feature/day-XX-...
    ├── fix/day-XX-...
    └── perf/day-XX-...
```

Mỗi ngày: branch ngắn hạn -> commit nhỏ có động từ -> chạy test liên quan -> mở PR/MR vào `develop`. Chỉ merge/promote lên `main` sau quality gate. Ví dụ commit: `feat: add inventory adjustment`, `test: cover refresh rotation`, `docs: update order api contract`.
