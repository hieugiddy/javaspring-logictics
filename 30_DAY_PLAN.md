# Lộ trình Backend Java Logistics trong 30 ngày

> Phạm vi: Spring Boot microservices, Java 17, PostgreSQL, Redis, RabbitMQ, Gradle Wrapper, WAR, External Tomcat 10.1 (Servlet 6.0), Docker, Jenkins.
>
> **Trạng thái workspace:** Root project có `settings.gradle`, `build.gradle`; 8 services có `build.gradle` (war plugin, Spring Boot 3.3.5, Java 17, MyBatis cho product/inventory, RabbitMQ cho notification); Gradle Wrapper 8.10 đã generate (`gradlew`, `gradlew.bat`, `gradle/wrapper/`). Source Java nghiệp vụ chưa implement.

## Cách dùng kế hoạch

- Mỗi ngày dành 30-60 phút học, 60-120 phút thực hành, 30-60 phút kiểm tra/sửa lỗi và khoảng 15 phút ghi chú/commit.
- Đọc đúng tài liệu/section được chỉ ra trong ngày; không cần đọc hết hai README cùng lúc.
- Git commit hằng ngày. Không commit `.env`, mật khẩu, JWT secret, token, khóa SSH hay credential.
- Swagger được cập nhật theo từng API; không đợi tới cuối dự án mới bổ sung tài liệu API.
- Build command chuẩn: `./gradlew clean test bootWar` (Linux/Mac) hoặc `.\gradlew.bat clean test bootWar` (Windows).

## Cấu trúc thư mục chuẩn mỗi service

```
services/<service-name>/
├── build.gradle
├── src/
│   ├── main/
│   │   ├── java/com/wms/<service>/
│   │   │   ├── <Service>Application.java
│   │   │   ├── config/          # SecurityConfig, MyBatisConfig, RedisConfig, RabbitMQConfig
│   │   │   ├── controller/      # REST endpoints
│   │   │   ├── dto/             # Request/Response DTO (record)
│   │   │   ├── service/         # Use case / Application Service
│   │   │   ├── repository/      # JPA Repository / MyBatis Mapper interface
│   │   │   ├── entity/          # JPA Entity
│   │   │   ├── mapper/          # MyBatis XML mapper interface (nếu có)
│   │   │   ├── client/          # Feign/WebClient call sang service khác
│   │   │   ├── event/           # Event DTO, Publisher, Consumer
│   │   │   ├── exception/       # ApiException, GlobalExceptionHandler
│   │   │   └── common/          # Constants, utils
│   │   ├── resources/
│   │   │   ├── application.yml
│   │   │   ├── db/migration/V1__init.sql
│   │   │   └── mybatis/mapper/*.xml (nếu dùng MyBatis)
│   │   └── webapp/WEB-INF/web.xml (optional cho Tomcat)
│   └── test/
│       ├── java/... (unit + integration test)
│       └── resources/application-test.yml
└── Dockerfile (Day 27)
```

---

## Checklist Definition of Done cho mỗi feature

- [ ] Request/Response DTO có Jakarta Validation
- [ ] Controller mảnh, chỉ map HTTP -> DTO -> Service
- [ ] Service có `@Transactional`, business rule, authorization
- [ ] Repository/Mapper interface tách biệt; implement ở `db/`
- [ ] Entity/Mapper XML đúng schema; có index, FK, constraint
- [ ] Flyway migration versioned (V1, V2...)
- [ ] Unit test (JUnit 5 + Mockito) cover success/failure
- [ ] Integration test (MockMvc + Testcontainers) cover API contract
- [ ] Swagger/OpenAPI annotation đầy đủ
- [ ] Error handling: 400/401/403/404/409/422/500
- [ ] Log correlation ID, audit trail cho mutation

## Day 01 — Setup môi trường và service đầu tiên

### Goal

Tạo nền Java 17/Spring Boot 3.3.5/Gradle 8.10 và chạy được ứng dụng WAR trên External Tomcat 10.1 (Servlet 6.0).

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `JDK 17`, `Spring Boot lifecycle`, `Gradle Wrapper 8.10`, `WAR vs JAR`, `SpringBootServletInitializer`, `Tomcat 10.1 context path`, `springdoc-openapi-starter-webmvc-ui`.

### Files đã có sẵn (verify)

- Root: `settings.gradle`, `build.gradle` (Spring Boot 3.3.5, Spring Cloud 2023.0.4, Java 17)
- `services/product-service/build.gradle` (war plugin, MyBatis starter, providedRuntime tomcat)
- `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, `gradle/wrapper/gradle-wrapper.properties` (Gradle 8.10)

### Tasks

- [ ] Cài JDK 17 (temurin/zulu), IntelliJ IDEA, Git, Docker Desktop, Tomcat 10.1.x
- [ ] Verify Gradle Wrapper: `./gradlew --version` → Gradle 8.10, JVM 17
- [ ] Verify build: `./gradlew :services:product-service:compileJava` (should succeed)
- [ ] Thêm `SpringBootServletInitializer` trong `ProductApplication.java`:
  ```java
  @SpringBootApplication
  public class ProductApplication extends SpringBootServletInitializer {
      @Override protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
          return builder.sources(ProductApplication.class);
      }
      public static void main(String[] args) { SpringApplication.run(ProductApplication.class, args); }
  }
  ```
- [ ] Thêm `springdoc-openapi-starter-webmvc-ui` dependency trong build.gradle
- [ ] Tạo `application.yml` cơ bản:
  ```yaml
  server:
    port: 8082
    servlet:
      context-path: /product-service
  spring:
    application:
      name: product-service
    datasource:
      url: jdbc:postgresql://localhost:5432/product_db
      username: postgres
      password: postgres
    flyway:
      enabled: true
      locations: classpath:db/migration
  springdoc:
    api-docs:
      path: /api-docs
    swagger-ui:
      path: /swagger-ui.html
  ```
- [ ] Tạo `V1__init.sql` (empty hoặc chỉ comment)
- [ ] Tạo `HelloController`:
  ```java
  @RestController @RequestMapping("/api/v1")
  public class HelloController {
      @GetMapping("/hello")
      public Map<String, String> hello() { return Map.of("message", "Hello from Product Service"); }
  }
  ```
- [ ] Chạy infra: `docker compose -f infrastructure/docker-compose.yml up -d postgres redis rabbitmq`
- [ ] Build WAR: `./gradlew :services:product-service:clean :services:product-service:test :services:product-service:bootWar`
- [ ] Verify artifact: `ls -la services/product-service/build/libs/product-service.war`
- [ ] Deploy: copy WAR to `$TOMCAT_HOME/webapps/product-service.war`, start Tomcat

### Acceptance Criteria

- [ ] `./gradlew :services:product-service:bootWar` BUILD SUCCESSFUL
- [ ] WAR deploy lên Tomcat 10.1, context path `/product-service` hoạt động
- [ ] `GET http://localhost:8080/product-service/api/v1/hello` → 200 JSON
- [ ] `GET http://localhost:8080/product-service/swagger-ui.html` hiển thị endpoint `/api/v1/hello`

### Sau khi hoàn thành phải hiểu

Giải thích được: WAR vs JAR, tại sao `providedRuntime tomcat`, `SpringBootServletInitializer` role, context-path mapping trên Tomcat.

### Swagger

Mở `/product-service/swagger-ui.html`, xác認 endpoint `GET /api/v1/hello` có response 200, schema `Map<String,String>`.

### Git

```bash
git checkout -b feature/day-01-bootstrap
git add .
git commit -m "chore: initialize product-service spring boot war with gradle wrapper"
git push -u origin feature/day-01-bootstrap
# Tạo PR vào develop
```

### Từ khóa tự học

`JDK 17`, `Spring Boot 3.3.5`, `Gradle Wrapper 8.10`, `WAR packaging`, `SpringBootServletInitializer`, `Tomcat 10.1 Servlet 6.0`, `springdoc-openapi`, `context-path`.

### Tài liệu tham chiếu

[README_CICD_FILES.md](README_CICD_FILES.md) §2-§5; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §3, §20; [services/README.md](services/README.md) §7; `services/product-service/build.gradle`.

### Output

- `./gradlew :services:product-service:bootWar` → BUILD SUCCESSFUL
- WAR deploy Tomcat → `GET /product-service/api/v1/hello` → 200
- Swagger UI accessible tại `/product-service/swagger-ui.html`

---

## Day 02 — Package by feature (screen) và Dependency Injection

### Goal

Tạo cấu trúc package `screens/S06-product/{controller,service,repository,db}` cho màn Product, áp dụng Constructor Injection, tách biệt API layer, Use case layer, Persistence layer.

### Học gì để làm được Tasks

Kiến thức cần đọc trước khi làm task: `IoC`, `Dependency Injection`, `constructor injection`, `Controller-Service-Repository`, `package by feature`, `DTO`, `Port/Adapter pattern`.

### Cấu trúc thư mục target

```
services/product-service/src/main/java/com/wms/product/
├── ProductApplication.java
├── config/
│   ├── SecurityConfig.java
│   └── MyBatisConfig.java (nếu dùng MyBatis)
├── screens/
│   └── S06-product/
│       ├── controller/
│       │   └── ProductController.java
│       ├── dto/
│       │   ├── ProductResponse.java
│       │   ├── CreateProductRequest.java
│       │   ├── UpdateProductRequest.java
│       │   └── ProductListResponse.java (page wrapper)
│       ├── service/
│       │   ├── ProductQueryService.java (interface - port)
│       │   ├── ProductCommandService.java (interface - port)
│       │   └── impl/
│       │       ├── ProductQueryServiceImpl.java
│       │       └── ProductCommandServiceImpl.java
│       ├── repository/
│       │   ├── ProductRepository.java (JPA interface)
│       │   └── ProductQueryMapper.java (MyBatis interface)
│       └── db/
│           ├── jpa/
│           │   ├── ProductEntity.java
│           │   └── CategoryEntity.java
│           └── mybatis/
│               └── ProductMapper.xml
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   └── GlobalExceptionHandler.java
│   └── utils/
└── client/ (nếu cần call service khác)
```

### Tasks

- [ ] Tạo package structure như trên
- [ ] Tạo `ProductResponse` (record), `CreateProductRequest` (record + Jakarta Validation)
- [ ] Tạo `ProductRepository extends JpaRepository<ProductEntity, Long>` trong `db/jpa/`
- [ ] Tạo `ProductQueryMapper` interface + `ProductMapper.xml` trong `db/mybatis/` (basic select)
- [ ] Tạo `ProductQueryService` interface + `ProductQueryServiceImpl`:
  ```java
  @Service @RequiredArgsConstructor @Transactional(readOnly = true)
  public class ProductQueryServiceImpl implements ProductQueryService {
      private final ProductRepository productRepository;
      private final ProductQueryMapper productQueryMapper;
      // implement findById, findAll (pageable), search (MyBatis)
  }
  ```
- [ ] Tạo `ProductCommandService` interface + `ProductCommandServiceImpl`:
  ```java
  @Service @RequiredArgsConstructor
  public class ProductCommandServiceImpl implements ProductCommandService {
      private final ProductRepository productRepository;
      // implement create, update, delete (có @Transactional)
  }
  ```
- [ ] Tạo `ProductController` constructor-inject `ProductQueryService`, `ProductCommandService`
- [ ] Implement `GET /api/v1/products` (pageable), `GET /api/v1/products/{id}`
- [ ] Viết unit test cho `ProductQueryServiceImpl` (Mockito mock repository)

### Acceptance Criteria

- [ ] Project compile: `./gradlew :services:product-service:compileJava`
- [ ] Unit test pass: `./gradlew :services:product-service:test`
- [ ] Controller chỉ map HTTP -> DTO -> Service, KHÔNG có logic business
- [ ] Service implement interface (Port), không phụ thuộc Spring MVC/MyBatis
- [ ] Constructor injection everywhere (Lombok `@RequiredArgsConstructor` hoặc manual)

### Sau khi hoàn thành phải hiểu

Giải thích được: tại sao tách Query/Command service, tại sao Controller không inject Repository, Port/Adapter pattern benefits.

### Swagger

- `GET /api/v1/products?page=0&size=20` → 200, response: `ProductListResponse(items, page, size, totalElements, totalPages)`
- `GET /api/v1/products/{id}` → 200 `ProductResponse` hoặc 404

### Git

```bash
git checkout -b feature/day-02-product-layers
git add .
git commit -m "feat: add product screen layers (controller, service, repository, db)"
git push -u origin feature/day-02-product-layers
```

### Từ khóa tự học

`IoC`, `Constructor Injection`, `Package by Feature`, `Port/Adapter`, `Query/Command Separation`, `DTO vs Entity`.

### Tài liệu tham khảo

[README.md](README.md) §3 Cấu trúc thư mục; [services/product-service/README.md](services/product-service/README.md) §9; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §6, §10, §21.

### Output

- Package structure created under `screens/S06-product/`
- Controller → Service → Repository/Mapper flow works
- Unit test for query service passes
- Swagger shows list/detail endpoints

---

## Day 03 — REST API & HTTP Contract hoàn chỉnh

### Goal

Hoàn thiện CRUD Product API với HTTP method, status code, pagination, error response chuẩn.

### Học gì để làm được Tasks

`REST constraints`, `HTTP method semantics`, `Path variable vs Query param`, `HTTP status codes`, `JSON serialization`, `Problem Details (RFC 7807)`, `Correlation ID`.

### Tasks

- [ ] Implement đầy đủ endpoints trong `ProductController`:
  - `GET    /api/v1/products` (page, size, sort, keyword, categoryId, status)
  - `GET    /api/v1/products/{id}`
  - `POST   /api/v1/products` → 201 + Location header
  - `PUT    /api/v1/products/{id}` → 200
  - `PATCH  /api/v1/products/{id}/status` → 200 (partial update)
  - `DELETE /api/v1/products/{id}` → 204
- [ ] Request/Response DTO:
  - `CreateProductRequest`: sku, name, description, price, categoryId, status
  - `UpdateProductRequest`: name?, description?, price?, categoryId?, status?
  - `ProductResponse`: id, sku, name, description, price, categoryId, categoryName, status, createdAt, updatedAt
  - `ProductListResponse`: items[], page, size, totalElements, totalPages
- [ ] Implement `ProductCommandServiceImpl`:
  - `create()`: validate SKU unique, category exists → save → return response
  - `update()`: check exists, validate, save
  - `delete()`: check exists, soft delete hoặc hard delete
  - `changeStatus()`: validate transition ACTIVE↔INACTIVE
- [ ] Global Exception Handler (`@RestControllerAdvice`):
  - `MethodArgumentNotValidException` → 400 (field errors)
  - `EntityNotFoundException` → 404
  - `DataIntegrityViolationException` (unique constraint) → 409
  - `BusinessRuleException` → 422
  - Response format: `{code, message, timestamp, traceId, errors?}`
- [ ] Thêm `X-Correlation-ID` header propagation (Filter + MDC)

### Acceptance Criteria

- [ ] `POST /api/v1/products` valid → 201, Location header, body ProductResponse
- [ ] `POST` duplicate SKU → 409 `{code: "CONFLICT", message: "SKU already exists"}`
- [ ] `POST` invalid body (blank sku, negative price) → 400 field errors
- [ ] `GET /products/999` not found → 404
- [ ] `GET /products?page=0&size=5&sort=name,asc` → 200 paged response
- [ ] `DELETE /products/{id}` → 204 no content
- [ ] Tất cả response có `traceId` trong header và body error

### Sau khi hoàn thành phải hiểu

Giải thích được: khi nào dùng 201 vs 200, 204 vs 200, 400 vs 422 vs 409, pagination contract, correlation ID tracing.

### Swagger

Mỗi endpoint có: `@Operation(summary, description)`, `@ApiResponse` cho 200/201/400/404/409/422, `@Parameter` cho page/size/sort/keyword, `example` request/response.

### Git

```bash
git checkout -b feature/day-03-product-rest
git add .
git commit -m "feat: add product CRUD REST endpoints with HTTP contract"
git push -u origin feature/day-03-product-rest
```

### Từ khóa tự học

`REST`, `HTTP Status Codes`, `Problem Details`, `Pagination`, `Correlation ID`, `Location Header`, `Partial Update (PATCH)`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §6, §10, §16; [services/README.md](services/README.md) §17 API conventions.

### Output

- 6 endpoints CRUD hoạt động đúng HTTP contract
- Swagger UI đầy đủ docs cho Product API
- Error response format nhất quán tất cả endpoint

---

## Day 04 — DTO, Validation, Error Response & Exception Handling

### Goal

Chặn input sai tại biên API, trả lỗi có cấu trúc (RFC 7807), implement global exception handler, audit log.

### Học gì để làm được Tasks

`Jakarta Bean Validation 3.0`, `@Valid`, `@NotBlank`, `@Size`, `@PositiveOrZero`, `@DecimalMin`, `@NotNull`, `@Pattern`, `ConstraintViolation`, `@RestControllerAdvice`, `ProblemDetail`, `ErrorResponse`, `MDC`, `Correlation ID`.

### Tasks

- [ ] Cập nhật DTO với validation đầy đủ:
  ```java
  public record CreateProductRequest(
      @NotBlank @Size(max = 100) @Pattern(regexp = "^[A-Z0-9-]+$") String sku,
      @NotBlank @Size(max = 255) String name,
      @Size(max = 2000) String description,
      @NotNull @DecimalMin("0.00") @Digits(integer = 12, fraction = 2) BigDecimal price,
      Long categoryId,
      @NotNull @Pattern(regexp = "^(ACTIVE|INACTIVE)$") String status
  ) {}
  ```
  ```java
  public record UpdateProductRequest(
      @Size(max = 255) String name,
      @Size(max = 2000) String description,
      @DecimalMin("0.00") @Digits(integer = 12, fraction = 2) BigDecimal price,
      Long categoryId,
      @Pattern(regexp = "^(ACTIVE|INACTIVE)$") String status
  ) {}
  ```
- [ ] Tạo custom validation annotation `@ValidSku` + validator (check format, không trùng trong DB)
- [ ] Tạo `GlobalExceptionHandler extends ResponseEntityExceptionHandler`:
  ```java
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) {
      List<FieldError> errors = ex.getBindingResult().getFieldErrors().stream()
          .map(fe -> new FieldError(fe.getField(), fe.getDefaultMessage(), fe.getRejectedValue()))
          .toList();
      return ResponseEntity.badRequest().body(ErrorResponse.of("VALIDATION_ERROR", "Invalid request", errors));
  }
  @ExceptionHandler(EntityNotFoundException.class)
  public ResponseEntity<ErrorResponse> handleNotFound(EntityNotFoundException ex) {
      return ResponseEntity.status(404).body(ErrorResponse.of("NOT_FOUND", ex.getMessage()));
  }
  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> handleConflict(DataIntegrityViolationException ex) {
      return ResponseEntity.status(409).body(ErrorResponse.of("CONFLICT", "Duplicate value"));
  }
  @ExceptionHandler(BusinessRuleException.class)
  public ResponseEntity<ErrorResponse> handleBusiness(BusinessRuleException ex) {
      return ResponseEntity.status(422).body(ErrorResponse.of("BUSINESS_RULE_VIOLATION", ex.getMessage()));
  }
  ```
- [ ] Tạo `ErrorResponse` record: `code, message, timestamp, traceId, List<FieldError> errors`
- [ ] Tạo `CorrelationIdFilter` (OncePerRequestFilter): generate/extract `X-Correlation-ID`, put vào MDC, add vào response header
- [ ] Cấu hình `logback-spring.xml` với `%X{traceId}` pattern
- [ ] Unit test validation: test các case valid/invalid cho Create/Update request
- [ ] Integration test (MockMvc): test 400, 404, 409, 422 response format

### Acceptance Criteria

- [ ] `POST` SKU rỗng → 400 `{code:"VALIDATION_ERROR", errors:[{field:"sku", message:"SKU is required"}]}`
- [ ] `POST` SKU format sai (lowercase) → 400 custom validator message
- [ ] `POST` duplicate SKU → 409 `{code:"CONFLICT", message:"SKU already exists"}`
- [ ] `PUT /products/999` not found → 404 `{code:"NOT_FOUND", message:"Product not found"}`
- [ ] `POST` price âm → 400 field error price
- [ ] Tất cả error response có `traceId` khớp với response header `X-Correlation-ID`
- [ ] Log file chứa `traceId` cho mỗi request

### Sau khi hoàn thành phải hiểu

Giải thích được: validation tại controller vs service, RFC 7807 ProblemDetail, tại sao không throw Exception trực tiếp từ repository, correlation ID tracing.

### Swagger

Mỗi endpoint: `@ApiResponse` 400 (schema ErrorResponse với errors[]), 404, 409, 422. DTO schema hiển thị validation constraints (`@Schema(minLength, maxLength, pattern, minimum)`).

### Git

```bash
git checkout -b feature/day-04-validation-error-handling
git add .
git commit -m "feat: add validation, global exception handler, correlation ID"
git push -u origin feature/day-04-validation-error-handling
```

### Từ khóa tự học

`Bean Validation`, `Custom Validator`, `ProblemDetail RFC 7807`, `@RestControllerAdvice`, `MDC`, `Correlation ID`, `Error Response Contract`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §10, §16, §20; [services/README.md](services/README.md) §17.

### Output

- Validation annotations trên DTO
- Global exception handler cover 400/404/409/422/500
- Correlation ID filter + MDC logging
- Unit + integration test cho error cases
- Swagger docs error responses

---

## Day 05 — PostgreSQL, Flyway Migration, Schema & Index

### Goal

Tạo database schema từ Flyway migration, hiểu PK/FK/Unique/Check/Index, so sánh query plan.

### Học gì để làm được Tasks

`PostgreSQL 15+`, `Flyway 10+`, `DDL`, `Primary Key`, `Foreign Key`, `Unique Constraint`, `Check Constraint`, `Index (B-tree, Composite, Partial)`, `EXPLAIN ANALYZE`, `pg_stat_statements`.

### Files & Config

- `services/product-service/src/main/resources/db/migration/V1__create_product_schema.sql`
- `application.yml`: `spring.flyway.enabled=true`, `spring.flyway.locations=classpath:db/migration`
- `build.gradle`: `implementation 'org.springframework.boot:spring-boot-starter-flyway'`, `implementation 'org.flywaydb:flyway-database-postgresql'`

### Tasks

- [ ] Tạo `V1__create_product_schema.sql`:
  ```sql
  CREATE TABLE categories (
      id BIGSERIAL PRIMARY KEY,
      code VARCHAR(50) NOT NULL UNIQUE,
      name VARCHAR(255) NOT NULL,
      description TEXT,
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE TABLE products (
      id BIGSERIAL PRIMARY KEY,
      sku VARCHAR(100) NOT NULL UNIQUE,
      name VARCHAR(255) NOT NULL,
      description TEXT,
      price NUMERIC(18,2) NOT NULL CHECK (price >= 0),
      category_id BIGINT REFERENCES categories(id) ON DELETE SET NULL,
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
  );
  
  CREATE INDEX idx_products_category_id ON products(category_id);
  CREATE INDEX idx_products_status ON products(status);
  CREATE INDEX idx_products_name_gin ON products USING gin (to_tsvector('vietnamese', name));
  ```
- [ ] Tạo `V2__add_updated_at_trigger.sql`:
  ```sql
  CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
  BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
  CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  ```
- [ ] Run migration: `./gradlew :services:product-service:flywayMigrate` hoặc start app
- [ ] Verify: `docker exec -it postgres psql -U postgres -d product_db -c "\d products"`
- [ ] Tạo `ProductEntity` mapping đúng schema (JPA annotations)
- [ ] Tạo `CategoryEntity` + `@ManyToOne` relationship
- [ ] Test `EXPLAIN ANALYZE`:
  ```sql
  EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
  SELECT * FROM products WHERE category_id = 1 AND status = 'ACTIVE' ORDER BY name LIMIT 20;
  ```
- [ ] So sánh với/không có index `idx_products_category_id`, `idx_products_status`
- [ ] Thêm test data: `INSERT INTO categories (code, name) VALUES ('ELECTRONICS', 'Electronics');`

### Acceptance Criteria

- [ ] Flyway migration chạy thành công (check `flyway_schema_history` table)
- [ ] Tables có PK, FK, Unique, Check constraint đúng
- [ ] Index được tạo, `EXPLAIN ANALYZE` sử dụng index (Index Scan, không Seq Scan)
- [ ] Trigger `updated_at` tự cập nhật khi UPDATE
- [ ] JPA Entity mapping compile, không lỗi Hibernate

### Sau khi hoàn thành phải hiểu

Giải thích được: Flyway versioning strategy, khi nào dùng FK vs logical reference, index selectivity, partial index, trigger vs application-level updated_at.

### Swagger

Cập nhật response example nếu thêm `categoryName` field trong `ProductResponse`.

### Git

```bash
git checkout -b feature/day-05-postgres-flyway
git add .
git commit -m "feat: add product schema flyway migration with indexes and triggers"
git push -u origin feature/day-05-postgres-flyway
```

### Từ khóa tự học

`Flyway Migration`, `PostgreSQL DDL`, `Constraints`, `Index Types`, `EXPLAIN ANALYZE`, `Trigger`, `pg_stat_statements`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §16, §24-25; [services/README.md](services/README.md) §7 Database; `docs/SQL/schema.sql`.

### Output

- `V1__create_product_schema.sql`, `V2__add_updated_at_trigger.sql`
- Flyway migrate success
- `EXPLAIN ANALYZE` show Index Scan
- JPA Entity compile OK

---

## Day 06 — Hibernate/JPA CRUD & Entity Mapping

### Goal

Nối Product Service với PostgreSQL bằng JPA/Hibernate cho CRUD, map Entity ↔ DTO, hiểu Persistence Context, dirty checking.

### Học gì để làm được Tasks

`JPA 3.1`, `Hibernate 6.4`, `Persistence Context`, `Entity Lifecycle (transient/persistent/detached/removed)`, `JpaRepository`, `@ManyToOne`, `@OneToMany`, `Dirty Checking`, `@Version` (optimistic locking), `@CreatedDate`, `@LastModifiedDate`, `Auditing`.

### Tasks

- [ ] Tạo `ProductEntity` mapping đầy đủ:
  ```java
  @Entity @Table(name = "products")
  @EntityListeners(AuditingEntityListener.class)
  @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
  public class ProductEntity {
      @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
      private Long id;
      
      @Column(nullable = false, unique = true, length = 100)
      private String sku;
      
      @Column(nullable = false, length = 255)
      private String name;
      
      @Column(columnDefinition = "TEXT")
      private String description;
      
      @Column(nullable = false, precision = 18, scale = 2)
      private BigDecimal price;
      
      @Column(name = "category_id")
      private Long categoryId;
      
      @Column(nullable = false, length = 20)
      private String status;
      
      @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
      private Instant createdAt;
      
      @LastModifiedDate @Column(name = "updated_at", nullable = false)
      private Instant updatedAt;
      
      @Version @Column(name = "version", nullable = false)
      private Long version;
  }
  ```
- [ ] Tạo `CategoryEntity` tương tự
- [ ] Enable JPA Auditing: `@EnableJpaAuditing` trong config class
- [ ] Tạo `ProductRepository extends JpaRepository<ProductEntity, Long>`:
  ```java
  Optional<ProductEntity> findBySku(String sku);
  Page<ProductEntity> findByCategoryIdAndStatus(Long categoryId, String status, Pageable pageable);
  Page<ProductEntity> findByNameContainingIgnoreCaseAndStatus(String keyword, String status, Pageable pageable);
  boolean existsBySku(String sku);
  ```
- [ ] Implement `ProductCommandServiceImpl` dùng JPA:
  ```java
  @Transactional
  public ProductResponse create(CreateProductRequest req) {
      if (productRepository.existsBySku(req.sku())) 
          throw new BusinessRuleException("SKU already exists");
      if (req.categoryId() != null && !categoryRepository.existsById(req.categoryId()))
          throw new BusinessRuleException("Category not found");
      
      ProductEntity entity = ProductEntity.builder()
          .sku(req.sku().trim())
          .name(req.name().trim())
          .description(req.description())
          .price(req.price())
          .categoryId(req.categoryId())
          .status(req.status())
          .build();
      
      ProductEntity saved = productRepository.save(entity);
      return ProductResponse.from(saved);
  }
  ```
- [ ] Implement `ProductQueryServiceImpl`:
  - `findById`: `productRepository.findById(id).orElseThrow(...)`
  - `findAll`: `productRepository.findAll(pageable)` map sang `ProductListResponse`
- [ ] Tạo `ProductResponse.from(ProductEntity)` mapper (manual hoặc MapStruct)
- [ ] Test: `./gradlew :services:product-service:test` (unit + integration)
- [ ] Verify SQL log: bật `spring.jpa.show-sql=true`, `spring.jpa.properties.hibernate.format_sql=true`

### Acceptance Criteria

- [ ] `POST /products` → INSERT SQL, audit fields auto-populated, version=0
- [ ] `GET /products/{id}` → SELECT, map Entity→Response (không expose Entity)
- [ ] `PUT /products/{id}` → UPDATE, `updated_at` auto, version increment
- [ ] Concurrent UPDATE cùng version → `OptimisticLockingFailureException` → 409
- [ ] Dirty checking: chỉ field thay đổi mới UPDATE
- [ ] `Pageable` mapping đúng sort/page/size

### Sau khi hoàn thành phải hiểu

Giải thích được: Persistence Context lifecycle, dirty checking mechanism, `@Version` optimistic locking, khi nào dùng `save()` vs `saveAndFlush()`, `@EntityListeners(AuditingEntityListener.class)`.

### Swagger

Test POST/GET/PUT/DELETE trên Swagger UI, verify response schema, version field không lộ ra API (internal).

### Git

```bash
git checkout -b feature/day-06-product-jpa-crud
git add .
git commit -m "feat: implement product CRUD with JPA/Hibernate"
git push -u origin feature/day-06-product-jpa-crud
```

### Từ khóa tự học

`JPA Entity`, `Hibernate Persistence Context`, `Dirty Checking`, `Optimistic Locking @Version`, `JpaRepository`, `Auditing`, `Entity ↔ DTO Mapping`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §10, §16; [services/product-service/README.md](services/product-service/README.md) §9.

### Output

- ProductEntity, CategoryEntity với JPA annotations
- JpaRepository với query methods
- CRUD hoạt động, audit auto, optimistic lock test pass
- SQL log hiển thị INSERT/UPDATE/SELECT đúng

---

## Day 07 — JPA Relationship, LAZY/EAGER, N+1 Problem & Solutions

### Goal

Tải quan hệ Product-Category đúng nhu cầu, tránh N+1, tránh serialization cycle, tối ưu query.

### Học gì để làm được Tasks

`LAZY` vs `EAGER`, `N+1 Problem`, `Fetch Join`, `@EntityGraph`, `Projection (DTO)`, `@BatchSize`, `Open Session in View`, `Jackson @JsonIgnore`, `@JsonManagedReference/@JsonBackReference`.

### Tasks

- [ ] Cập nhật Entity relationship:
  ```java
  // ProductEntity
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "category_id", insertable = false, updatable = false)
  private CategoryEntity category;
  
  // CategoryEntity
  @OneToMany(mappedBy = "category", fetch = FetchType.LAZY)
  @BatchSize(size = 20)
  private Set<ProductEntity> products = new HashSet<>();
  ```
- [ ] Test N+1: gọi `GET /products` → log SQL, đếm query count
- [ ] Fix N+1 cho danh sách: dùng `@EntityGraph` hoặc fetch join:
  ```java
  @EntityGraph(attributePaths = {"category"}, type = EntityGraphType.LOAD)
  Page<ProductEntity> findByCategoryIdAndStatus(Long categoryId, String status, Pageable pageable);
  ```
  Hoặc custom query: `SELECT p FROM ProductEntity p LEFT JOIN FETCH p.category WHERE ...`
- [ ] Fix serialization cycle: thêm `@JsonIgnore` trên `CategoryEntity.products` hoặc dùng DTO projection
- [ ] Tạo projection interface cho list view (không load category):
  ```java
  public interface ProductListProjection {
      Long getId(); String getSku(); String getName(); BigDecimal getPrice(); String getStatus();
  }
  ```
  Repository: `Page<ProductListProjection> findProjectedByStatus(String status, Pageable pageable);`
- [ ] Test performance: so sánh query count & thời gian giữa EntityGraph vs Projection vs N+1
- [ ] Disable `spring.jpa.open-in-view=false` (default Spring Boot 3), hiểu implications

### Acceptance Criteria

- [ ] `GET /products` list 20 items → 1 query (fetch join) hoặc 1 query (projection), KHÔNG phải 21 queries
- [ ] `GET /products/{id}` load category → 1 query (fetch join) hoặc 2 queries (LAZY + explicit load)
- [ ] Response JSON không có circular reference error
- [ ] `@BatchSize` hoạt động khi access category.products collection

### Sau khi hoàn thành phải hiểu

Giải thích được: LAZY default, N+1 root cause, Fetch Join vs EntityGraph vs Projection trade-offs, khi nào disable Open Session in View, `@BatchSize` use case.

### Swagger

Response `ProductListResponse` không chứa category object (chỉ categoryId), `ProductResponse` có `categoryName` (từ fetch join).

### Git

```bash
git checkout -b feature/day-07-jpa-n1-optimization
git add .
git commit -m "perf: fix N+1 with fetch join and projection for product list"
git push -u origin feature/day-07-jpa-n1-optimization
```

### Từ khóa tự học

`LAZY`, `EAGER`, `N+1`, `Fetch Join`, `@EntityGraph`, `Projection`, `@BatchSize`, `Open Session in View`, `Jackson Serialization`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §9-10, §16-17.

### Output

- Entity relationship LAZY + @BatchSize
- List endpoint: 1 query (fetch join/projection)
- Detail endpoint: fetch join category
- No serialization cycle
- Performance test showing query count reduction

---

## Day 08 — MyBatis Mapper cho Search/Report Phức Tạp

### Goal

Dùng MyBatis cho truy vấn đọc cần SQL tường minh (search, filter động, report), hiểu `#{} vs ${}`, `resultMap`, `projection`.

### Học gì để làm được Tasks

`MyBatis 3.0.4`, `Mapper XML`, `#{} (prepared statement) vs ${} (string substitution)`, `resultMap`, `association/collection`, `dynamic SQL (<where>, <if>, <choose>, <trim>)`, `pagination (LIMIT/OFFSET)`, `TypeHandler`.

### Config & Files

- `build.gradle`: `implementation 'org.mybatis.spring.boot:mybatis-spring-boot-starter:3.0.4'`
- `application.yml`:
  ```yaml
  mybatis:
    mapper-locations: classpath:mybatis/mapper/**/*.xml
    type-aliases-package: com.wms.product.screens.S06-product.db.mybatis
    configuration:
      map-underscore-to-camel-case: true
      default-enum-type-handler: org.apache.ibatis.type.EnumTypeHandler
  ```
- `ProductMyBatisConfig.java`: `@MapperScan("com.wms.product.screens.S06-product.db.mybatis")`

### Tasks

- [ ] Tạo `ProductQueryMapper.java` interface:
  ```java
  @Mapper
  public interface ProductQueryMapper {
      List<ProductSearchResult> search(ProductSearchCriteria criteria);
      long countSearch(ProductSearchCriteria criteria);
      Optional<ProductDetailResult> findDetailById(Long id);
  }
  ```
- [ ] Tạo `ProductSearchCriteria` record: `keyword, categoryId, status, page, size, sortBy, sortDir`
- [ ] Tạo `ProductMapper.xml`:
  ```xml
  <resultMap id="searchResultMap" type="ProductSearchResult">
      <id property="id" column="id"/>
      <result property="sku" column="sku"/>
      <result property="name" column="name"/>
      <result property="price" column="price"/>
      <result property="status" column="status"/>
      <result property="categoryId" column="category_id"/>
      <result property="categoryName" column="category_name"/>
      <result property="createdAt" column="created_at"/>
  </resultMap>
  
  <sql id="searchWhere">
      <where>
          <if test="criteria.keyword != null and criteria.keyword != ''">
              AND (p.name ILIKE CONCAT('%', #{criteria.keyword}, '%') 
                   OR p.sku ILIKE CONCAT('%', #{criteria.keyword}, '%'))
          </if>
          <if test="criteria.categoryId != null">
              AND p.category_id = #{criteria.categoryId}
          </if>
          <if test="criteria.status != null and criteria.status != ''">
              AND p.status = #{criteria.status}
          </if>
      </where>
  </sql>
  
  <select id="search" resultMap="searchResultMap">
      SELECT p.id, p.sku, p.name, p.price, p.status, p.category_id, c.name as category_name, p.created_at
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      <include refid="searchWhere"/>
      <if test="criteria.sortBy != null">
          ORDER BY ${criteria.sortBy} ${criteria.sortDir}
      </if>
      LIMIT #{criteria.size} OFFSET #{criteria.offset}
  </select>
  
  <select id="countSearch" resultType="long">
      SELECT COUNT(*) FROM products p
      <include refid="searchWhere"/>
  </select>
  ```
- [ ] Implement `ProductQueryServiceImpl` dùng `ProductQueryMapper` cho search
- [ ] Validate `sortBy` against whitelist trước khi pass vào MyBatis (chống SQL injection từ `${}`)
- [ ] Unit test MyBatis mapper với `@MybatisTest` + Testcontainers PostgreSQL
- [ ] Compare: JPA vs MyBatis cho search query (performance, flexibility)

### Acceptance Criteria

- [ ] `GET /products?keyword=key&categoryId=1&status=ACTIVE&page=0&size=20&sortBy=name&sortDir=asc` → MyBatis query
- [ ] `#{criteria.keyword}` dùng prepared statement (safe), `${criteria.sortBy}` validated whitelist
- [ ] `resultMap` map đúng `category_name` từ JOIN
- [ ] Pagination đúng: `LIMIT size OFFSET (page * size)`
- [ ] Count query dùng chung `<where>` fragment

### Sau khi hoàn thành phải hiểu

Giải thích được: khi nào chọn MyBatis thay JPA, `#{} vs ${}` security, dynamic SQL tags, `resultMap` vs `resultType`, TypeHandler cho custom type.

### Swagger

Endpoint search: document tất cả query params, enum cho `sortBy` (sku, name, price, createdAt), `sortDir` (asc, desc).

### Git

```bash
git checkout -b feature/day-08-mybatis-mapper
git add .
git commit -m "feat: add product search MyBatis mapper with dynamic SQL"
git push -u origin feature/day-08-mybatis-mapper
```

### Từ khóa tự học

`MyBatis`, `Mapper XML`, `#{} vs ${}`, `Dynamic SQL`, `resultMap`, `Projection`, `Prepared Statement`, `SQL Injection Prevention`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §10, §16; `docs/SQL/schema.sql`; [services/product-service/README.md](services/product-service/README.md) §9.

### Output

- ProductQueryMapper interface + ProductMapper.xml
- Dynamic SQL với `<where>`, `<if>`, `<trim>`
- Search API dùng MyBatis, JPA dùng cho CRUD
- Whitelist validation cho `${sortBy}`
- Unit test mapper với Testcontainers

---

## Day 09 — Search, Filter, Sort, Pagination API Hoàn Chỉnh

### Goal

Hoàn thiện API danh sách catalog với full-text search, multi-filter, sort whitelist, pagination chuẩn.

### Học gì để làm được Tasks

`Dynamic SQL`, `Pagination (Offset vs Keyset)`, `Sort Allowlist`, `Index Selectivity`, `Query Plan`, `SQL Injection Prevention`, `Cursor-based Pagination`.

### Tasks

- [ ] Cập nhật `ProductController.search()`:
  ```java
  @GetMapping
  public ResponseEntity<ProductListResponse> search(
      @RequestParam(required = false) String keyword,
      @RequestParam(required = false) Long categoryId,
      @RequestParam(required = false) String status,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
      @RequestParam(defaultValue = "createdAt") String sortBy,
      @RequestParam(defaultValue = "desc") String sortDir
  ) {
      // validate sortBy against whitelist: sku, name, price, createdAt, updatedAt
      // validate sortDir: asc, desc
      ProductSearchCriteria criteria = new ProductSearchCriteria(...);
      ProductListResponse response = productQueryService.search(criteria);
      return ResponseEntity.ok(response);
  }
  ```
- [ ] Implement `ProductQueryService.search()`:
  - Validate sortBy whitelist → throw 400 nếu invalid
  - Delegate to MyBatis mapper
  - Map result sang `ProductListResponse(items, page, size, totalElements, totalPages)`
- [ ] Thêm database index cho query pattern:
  ```sql
  CREATE INDEX idx_products_search ON products (status, category_id, name);
  CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops); -- pg_trgm extension
  ```
- [ ] Test `EXPLAIN ANALYZE` với các filter combination
- [ ] Thêm integration test:
  - Filter by keyword, category, status
  - Sort by each allowed column asc/desc
  - Page boundary: page=0, last page, page > totalPages → empty items
  - Size limit: size=101 → 400
  - Invalid sortBy → 400
- [ ] Performance test: 10k products, measure response time < 200ms

### Acceptance Criteria

- [ ] Search API hỗ trợ tất cả filter combination
- [ ] Sort whitelist chặn injection (`sortBy=name; DROP TABLE` → 400)
- [ ] Pagination response format chuẩn: `items[], page, size, totalElements, totalPages`
- [ ] `EXPLAIN ANALYZE` show Index Scan cho các filter phổ biến
- [ ] Integration test cover tất cả case

### Sau khi hoàn thành phải hiểu

Giải thích được: Offset vs Keyset pagination trade-offs, sort whitelist security, composite index design, full-text search options (trgm, tsvector).

### Swagger

Endpoint `/api/v1/products`: query params đầy đủ với `schema`, `example`, `minimum`, `maximum`, `enum` cho sortBy/sortDir.

### Git

```bash
git checkout -b feature/day-09-product-search-pagination
git add .
git commit -m "feat: complete product search filter sort pagination API"
git push -u origin feature/day-09-product-search-pagination
```

### Từ khóa tự học

`Dynamic SQL`, `Pagination`, `Sort Allowlist`, `Index Design`, `Full-text Search`, `Keyset Pagination`, `Query Plan`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §4, §10, §16-17; [services/README.md](services/README.md) §17.

### Output

- Search API hoàn chỉnh với validation
- Index tối ưu cho query pattern
- Integration test cover edge cases
- Swagger docs đầy đủ

---

## Day 10 — User Service: Password Hashing, Entity, Repository

### Goal

Tạo User Service foundation: Entity, Repository, BCrypt PasswordEncoder, User lookup.

### Học gì để làm được Tasks

`BCrypt`, `PasswordEncoder`, `Salt`, `Cost Factor`, `User Entity`, `JpaRepository`, `Optional`, `Authentication vs Authorization`.

### Tasks

- [ ] Tạo `UserEntity`:
  ```java
  @Entity @Table(name = "users", uniqueConstraints = {
      @UniqueConstraint(name = "uk_users_username", columnNames = "username"),
      @UniqueConstraint(name = "uk_users_email", columnNames = "email")
  })
  public class UserEntity {
      @Id @GeneratedValue private Long id;
      @Column(nullable = false, length = 50) private String username;
      @Column(nullable = false, length = 100) private String email;
      @Column(name = "password_hash", nullable = false, length = 255) private String passwordHash;
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private Role role;
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private Status status;
      @CreatedDate private Instant createdAt;
      @LastModifiedDate private Instant updatedAt;
      @Version private Long version;
  }
  ```
- [ ] Tạo `UserRepository`:
  ```java
  Optional<UserEntity> findByUsername(String username);
  Optional<UserEntity> findByEmail(String email);
  boolean existsByUsername(String username);
  boolean existsByEmail(String email);
  ```
- [ ] Cấu hình `PasswordEncoder` bean:
  ```java
  @Bean PasswordEncoder passwordEncoder() { 
      return new BCryptPasswordEncoder(12); // cost factor 12
  }
  ```
- [ ] Tạo `UserService`:
  ```java
  @Transactional(readOnly = true)
  public UserEntity findByUsernameOrThrow(String username) {
      return userRepository.findByUsername(username)
          .orElseThrow(() -> new EntityNotFoundException("User not found"));
  }
  
  public boolean verifyPassword(String rawPassword, String encodedPassword) {
      return passwordEncoder.matches(rawPassword, encodedPassword);
  }
  ```
- [ ] Flyway migration `V1__create_user_schema.sql`:
  ```sql
  CREATE TABLE users (
      id BIGSERIAL PRIMARY KEY,
      username VARCHAR(50) NOT NULL UNIQUE,
      email VARCHAR(100) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      role VARCHAR(20) NOT NULL DEFAULT 'STAFF' CHECK (role IN ('SUPER_ADMIN','ADMIN','WAREHOUSE_MANAGER','STAFF','VIEWER')),
      status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','INACTIVE','LOCKED')),
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      version BIGINT NOT NULL DEFAULT 0
  );
  CREATE INDEX idx_users_username ON users(username);
  CREATE INDEX idx_users_email ON users(email);
  ```
- [ ] Seed data: `INSERT INTO users (username, email, password_hash, role) VALUES ('admin', 'admin@example.com', '$2a$12$...', 'SUPER_ADMIN');`
- [ ] Unit test: verify password match/mismatch, user not found, status check

### Acceptance Criteria

- [ ] BCrypt cost factor 12, password hash length 60 chars
- [ ] `verifyPassword()` trả true/false đúng
- [ ] Không log/return password hash
- [ ] Login fail không tiết lộ user tồn tại (same message cho wrong user/wrong pass)
- [ ] Migration chạy thành công, index tạo đúng

### Sau khi hoàn thành phải hiểu

Giải thích được: BCrypt cost factor trade-off, tại sao không dùng SHA/MD5, constant-time comparison, credential stuffing prevention.

### Git

```bash
git checkout -b feature/day-10-user-password
git add .
git commit -m "feat: add user entity, repository, BCrypt password encoder"
git push -u origin feature/day-10-user-password
```

### Từ khóa tự học

`BCrypt`, `PasswordEncoder`, `Cost Factor`, `Credential Stuffing`, `Timing Attack`, `Constant Time Comparison`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §8, §16; `services/auth-service/README.md`.

### Output

- UserEntity, UserRepository
- BCryptPasswordEncoder bean (cost 12)
- UserService verifyPassword()
- Flyway migration với constraints/index
- Unit test pass

---

## Day 11 — JWT Access Token (RS256, JWKS, Resource Server)

### Goal

Phát và xác minh JWT RS256 cho API bảo vệ, cấu hình Spring Security Resource Server.

### Học gì để làm được Tasks

`JWT`, `JWS`, `RS256`, `RSA Key Pair`, `JWKS`, `issuer`, `audience`, `subject`, `claims`, `JwtDecoder`, `SecurityFilterChain`, `OAuth2 Resource Server`.

### Tasks

- [ ] Generate RSA key pair (2048-bit) cho dev:
  ```bash
  openssl genrsa -out private_key.pem 2048
  openssl rsa -in private_key.pem -pubout -out public_key.pem
  ```
- [ ] Cấu hình `RsaKeyConfig` load keys từ file/classpath
- [ ] Tạo `TokenService` issue access token:
  ```java
  public String createAccessToken(UserEntity user) {
      Instant now = Instant.now();
      return Jwts.builder()
          .issuer("auth-service")
          .subject(user.getId().toString())
          .claim("username", user.getUsername())
          .claim("email", user.getEmail())
          .claim("role", user.getRole().name())
          .claim("scope", "read write")
          .issuedAt(Date.from(now))
          .expiration(Date.from(now.plusMinutes(15)))
          .id(UUID.randomUUID().toString())
          .signWith(privateKey, JwsAlgorithm.RS256)
          .compact();
  }
  ```
- [ ] Cấu hình `SecurityConfig` Resource Server:
  ```java
  @Bean SecurityFilterChain filterChain(HttpSecurity http) {
      return http.csrf(csrf -> csrf.disable())
          .sessionManagement(sm -> sm.sessionCreationPolicy(STATELESS))
          .authorizeHttpRequests(auth -> auth
              .requestMatchers("/api/auth/**", "/.well-known/jwks.json", "/actuator/health").permitAll()
              .anyRequest().authenticated())
          .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
          .build();
  }
  ```
- [ ] Cấu hình `JwtDecoder` bean validate `iss`, `aud`, `exp`, `nbf`, signature
- [ ] Tạo `JwkController` expose `GET /.well-known/jwks.json` trả public key JWKS format
- [ ] Bảo vệ endpoint test: `GET /api/v1/auth/me` → return current user từ `Authentication`
- [ ] Test: valid token → 200, expired → 401, invalid signature → 401, missing → 401

### Acceptance Criteria

- [ ] Access token RS256, 15min expiry, claims: iss, sub, username, email, role, scope, iat, exp, jti
- [ ] JWKS endpoint trả public key đúng format
- [ ] Resource Server validate signature, exp, iss, aud
- [ ] `GET /api/v1/auth/me` với Bearer token → 200 user info
- [ ] Token hết hạn/ sai chữ ký → 401 với error code

### Sau khi hoàn thành phải hiểu

Giải thích được: RS256 vs HS256, JWKS key rotation, JWT validation flow, Resource Server vs Authorization Server, claim mapping.

### Swagger

Cấu hình `securitySchemes: bearerAuth (http, bearer, bearerFormat: JWT)`, apply cho protected endpoints. Test Authorize button với token.

### Git

```bash
git checkout -b feature/day-11-jwt-access-token
git add .
git commit -m "feat: implement JWT RS256 access token with JWKS"
git push -u origin feature/day-11-jwt-access-token
```

### Từ khóa tự học

`JWT`, `RS256`, `JWKS`, `JwtDecoder`, `OAuth2 Resource Server`, `Claim`, `Key Rotation`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §20; [services/auth-service/README.md](services/auth-service/README.md).

### Output

- RSA key pair, JWKS endpoint
- TokenService issue RS256 JWT
- Resource Server config validate JWT
- Protected endpoint test pass

---

## Day 12 — Refresh Token (Opaque, Rotation, Revocation, Logout)

### Goal

Quản lý session dài hạn với opaque refresh token, rotation, revocation, logout-all.

### Học gì để làm được Tasks

`Opaque Token`, `SHA-256 Hash`, `Rotation`, `Revocation`, `Reuse Detection`, `Transaction`, `SecureRandom`, `Token Family`.

### Tasks

- [ ] Tạo `RefreshTokenEntity`:
  ```java
  @Entity @Table(name = "refresh_tokens")
  public class RefreshTokenEntity {
      @Id @GeneratedValue private Long id;
      @Column(name = "token_hash", nullable = false, length = 64, unique = true) private String tokenHash;
      @Column(name = "user_id", nullable = false) private Long userId;
      @Column(name = "jti", nullable = false, length = 36, unique = true) private String jti;
      @Column(name = "expires_at", nullable = false) private Instant expiresAt;
      @Column(name = "revoked_at") private Instant revokedAt;
      @Column(name = "replaced_by_jti", length = 36) private String replacedByJti;
      @CreatedDate private Instant createdAt;
  }
  ```
- [ ] Tạo `RefreshTokenRepository` với query: `findByTokenHash`, `findByUserId`, `revokeByJti`
- [ ] Implement `TokenService` refresh rotation:
  ```java
  @Transactional
  public TokenPair refresh(String refreshToken) {
      String hash = sha256(refreshToken);
      RefreshTokenEntity stored = repo.findByTokenHash(hash)
          .orElseThrow(() -> new InvalidTokenException("Invalid refresh token"));
      
      if (stored.getRevokedAt() != null) {
          revokeFamily(stored.getJti());
          throw new InvalidTokenException("Token reused, session revoked");
      }
      if (stored.getExpiresAt().isBefore(Instant.now())) {
          throw new InvalidTokenException("Token expired");
      }
      
      stored.setRevokedAt(Instant.now());
      String newJti = UUID.randomUUID().toString();
      stored.setReplacedByJti(newJti);
      
      RefreshTokenEntity newToken = new RefreshTokenEntity();
      newToken.setTokenHash(sha256(newRefreshToken));
      newToken.setUserId(stored.getUserId());
      newToken.setJti(newJti);
      newToken.setExpiresAt(Instant.now().plusDays(7));
      repo.save(newToken);
      
      return new TokenPair(createAccessToken(user), newRefreshToken);
  }
  ```
- [ ] Implement logout (revoke current) và logout-all (revoke all user tokens)
- [ ] Flyway migration `V2__create_refresh_tokens.sql`
- [ ] Unit test: rotation success, reuse detection revokes family, expired token, logout revokes

### Acceptance Criteria

- [ ] Refresh token opaque (random 32 bytes), chỉ lưu SHA-256 hash
- [ ] Rotation: old token revoked, new token issued, `replaced_by_jti` link
- [ ] Reuse detection: dùng token cũ → revoke toàn family, throw 401
- [ ] Logout: revoke current token family
- [ ] Logout-all: revoke all user tokens
- [ ] Token expiry 7 days, auto cleanup job (optional)

### Sau khi hoàn thành phải hiểu

Giải thích được: opaque vs JWT refresh token, rotation security benefit, reuse detection mechanism, token family chain, transaction boundary.

### Swagger

`POST /api/auth/refresh` request: `{refreshToken}`, response: `{accessToken, refreshToken}`. `POST /api/auth/logout`, `POST /api/auth/logout-all`.

### Git

```bash
git checkout -b feature/day-12-refresh-token-rotation
git add .
git commit -m "feat: implement opaque refresh token with rotation and reuse detection"
git push -u origin feature/day-12-refresh-token-rotation
```

### Từ khóa tự học

`Opaque Token`, `Token Rotation`, `Reuse Detection`, `Token Family`, `SHA-256`, `SecureRandom`, `Revocation`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §16; [services/auth-service/README.md](services/auth-service/README.md).

### Output

- RefreshTokenEntity, Repository
- TokenService refresh() với rotation
- Reuse detection revoke family
- Logout / logout-all
- Flyway migration
- Unit test cover all cases

---

## Day 13 — RBAC & Resource Ownership Authorization

### Goal

Áp dụng Role-Based Access Control (RBAC) và resource ownership authorization tại service layer.

### Học gì để làm được Tasks

`RBAC`, `@PreAuthorize`, `Method Security`, `SpEL`, `GrantedAuthority`, `Resource Ownership`, `Principal`, `Authentication`, `SecurityContext`.

### Tasks

- [ ] Cấu hình `MethodSecurityConfig`: `@EnableMethodSecurity(prePostEnabled = true, securedEnabled = true)`
- [ ] Custom `AuthenticationPrincipal` extract userId, role từ JWT:
  ```java
  @Component
  public class CurrentUser {
      public static UserPrincipal get() {
          Authentication auth = SecurityContextHolder.getContext().getAuthentication();
          return (UserPrincipal) auth.getPrincipal();
      }
  }
  ```
- [ ] Map JWT claims → `UserPrincipal` implement `UserDetails`:
  ```java
  public record UserPrincipal(Long userId, String username, String email, Role role, Set<String> scopes) 
      implements UserDetails { ... }
  ```
- [ ] Tạo `AuthorizationService` check permissions:
  ```java
  @Service @RequiredArgsConstructor
  public class AuthorizationService {
      public void requireRole(Role... allowed) {
          Role current = CurrentUser.get().role();
          if (!Arrays.asList(allowed).contains(current)) 
              throw new AccessDeniedException("Insufficient role");
      }
      
      public void requireOwnershipOrAdmin(Long resourceUserId) {
          UserPrincipal principal = CurrentUser.get();
          if (!principal.userId().equals(resourceUserId) && principal.role() != Role.ADMIN)
              throw new AccessDeniedException("Not owner or admin");
      }
  }
  ```
- [ ] Áp dụng `@PreAuthorize` trên service methods:
  ```java
  @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")
  public void deleteUser(Long userId) { ... }
  
  @PreAuthorize("hasRole('WAREHOUSE_MANAGER') and @authz.canAccessWarehouse(#warehouseId)")
  public void adjustInventory(Long warehouseId, ...) { ... }
  ```
- [ ] Tạo `WarehouseAssignment` entity/user-warehouse mapping (cho Day 15+)
- [ ] Integration test: 403 khi role thiếu, 403 khi không owner, 200 khi đúng quyền
- [ ] Unit test `AuthorizationService` với mock `SecurityContext`

### Acceptance Criteria

- [ ] `@PreAuthorize` trên service layer (không chỉ controller)
- [ ] Role hierarchy: SUPER_ADMIN > ADMIN > WAREHOUSE_MANAGER > STAFF > VIEWER
- [ ] Ownership check: user chỉ sửa resource của mình (trừ ADMIN)
- [ ] Warehouse-scoped permission (chuẩn bị cho Inventory Service)
- [ ] 403 response format chuẩn: `{code: "FORBIDDEN", message: "..."}`

### Sau khi hoàn thành phải hiểu

Giải thích được: RBAC vs ABAC, `@PreAuthorize` SpEL expressions, `SecurityContextHolder` thread-local, method security vs web security, custom permission evaluator.

### Swagger

Security requirement `bearerAuth` trên protected endpoints. Description chỉ rõ role required.

### Git

```bash
git checkout -b feature/day-13-rbac-authorization
git add .
git commit -m "feat: implement RBAC and resource ownership authorization"
git push -u origin feature/day-13-rbac-authorization
```

### Từ khóa tự học

`RBAC`, `@PreAuthorize`, `SpEL`, `Method Security`, `Principal`, `Permission Evaluator`, `Resource Ownership`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §2, §8, §11-13, §21; [services/README.md](services/README.md) §9.

### Output

- MethodSecurityConfig enable prePost
- UserPrincipal từ JWT claims
- AuthorizationService check role/ownership
- @PreAuthorize trên service methods
- Integration test 403 cases

---

## Day 14 — Transaction, Concurrency Control, Optimistic/Pessimistic Locking

### Goal

Đảm bảo mutation inventory an toàn: không lost update, không negative stock, ACID transaction.

### Học gì để làm được Tasks

`ACID`, `@Transactional`, `Propagation`, `Isolation`, `Lost Update`, `Optimistic Locking (@Version)`, `Pessimistic Locking (SELECT FOR UPDATE)`, `Rollback`, `Deadlock`, `Retry`.

### Tasks

- [ ] Cập nhật `InventoryEntity` với `@Version`:
  ```java
  @Embeddable public class InventoryId implements Serializable {
      @Column(name = "product_id") private Long productId;
      @Column(name = "warehouse_id") private Long warehouseId;
      // equals/hashCode
  }
  
  @Entity @Table(name = "inventory")
  public class InventoryEntity {
      @EmbeddedId private InventoryId id;
      @Column(nullable = false) private Integer quantity;
      @Column(name = "reserved_quantity", nullable = false) private Integer reservedQuantity;
      @Version @Column(nullable = false) private Long version;
      @UpdateTimestamp @Column(name = "updated_at") private Instant updatedAt;
  }
  ```
- [ ] Implement `AdjustInventoryService`:
  ```java
  @Service @RequiredArgsConstructor
  public class AdjustInventoryService {
      private final InventoryRepository inventoryRepo;
      private final InventoryTransactionRepository txRepo;
      
      @Transactional
      public InventoryResponse adjust(AdjustRequest req) {
          // 1. Lock row (optimistic via @Version)
          InventoryEntity inv = inventoryRepo.findById(new InventoryId(req.productId(), req.warehouseId()))
              .orElseThrow(() -> new NotFoundException("Inventory not found"));
          
          // 2. Business rule
          int available = inv.getQuantity() - inv.getReservedQuantity();
          int nextQty = inv.getQuantity() + req.delta();
          if (nextQty < inv.getReservedQuantity() || nextQty < 0)
              throw new BusinessRuleException("Insufficient available stock");
          
          // 3. Update
          inv.setQuantity(nextQty);
          inventoryRepo.save(inv); // @Version check on flush
          
          // 4. Record transaction
          txRepo.save(InventoryTransactionEntity.adjustment(req));
          
          return InventoryResponse.from(inv);
      }
  }
  ```
- [ ] Test concurrency: 2 threads cùng adjust cùng inventory → 1 success, 1 `OptimisticLockingFailureException` → map to 409
- [ ] Test rollback: ném exception sau save → verify inventory + transaction KHÔNG persist
- [ ] Optional: Pessimistic lock cho high-contention case:
  ```java
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  Optional<InventoryEntity> findByIdForUpdate(InventoryId id);
  ```
- [ ] Flyway migration: thêm `version` column, composite PK

### Acceptance Criteria

- [ ] `@Version` tăng sau mỗi update thành công
- [ ] Concurrent update → 1 success, 1 409 (OptimisticLockingFailureException)
- [ ] Transaction: adjust + insert history cùng commit/rollback
- [ ] Rollback test: exception giữa transaction → DB unchanged
- [ ] Business rule: nextQty < reservedQty → 422, no persist

### Sau khi hoàn thành phải hiểu

Giải thích được: Optimistic vs Pessimistic locking trade-off, `@Version` mechanism, `@Transactional` propagation/rollback rules, lost update prevention, deadlock avoidance.

### Swagger

`POST /api/v1/inventory/adjust` response 409 (concurrency), 422 (business rule), 200 (success).

### Git

```bash
git checkout -b feature/day-14-inventory-concurrency
git add .
git commit -m "feat: implement inventory adjustment with optimistic locking and transaction"
git push -u origin feature/day-14-inventory-concurrency
```

### Từ khóa tự học

`ACID`, `@Transactional`, `Optimistic Locking`, `@Version`, `Pessimistic Locking`, `SELECT FOR UPDATE`, `Lost Update`, `Deadlock`, `Rollback`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §12, §17-18; [services/inventory-service/README.md](services/inventory-service/README.md) §8.

### Output

- InventoryEntity với composite PK + @Version
- AdjustInventoryService @Transactional
- Concurrent test: 1 success, 1 409
- Rollback test pass
- Flyway migration version column

---

## Day 15 — Order Service & Inventory Workflow (Saga Pattern)

### Goal

Tạo Order, confirm/cancel với state machine, gọi Inventory Service reserve/release (không distributed transaction).

### Học gì để làm được Tasks

`Aggregate Root`, `State Machine`, `Saga Pattern`, `Choreography vs Orchestration`, `Idempotency`, `Outbox Pattern`, `Compensating Transaction`, `Circuit Breaker`, `Timeout Handling`.

### Tasks

- [ ] Tạo `OrderEntity`, `OrderItemEntity`:
  ```java
  @Entity @Table(name = "orders")
  public class OrderEntity {
      @Id @GeneratedValue private UUID id;
      @Column(name = "order_no", nullable = false, unique = true, length = 50) private String orderNo;
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private OrderType type; // INBOUND/OUTBOUND
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private OrderStatus status; // PENDING/CONFIRMED/CANCELLED/FAILED
      @Column(name = "user_id", nullable = false) private UUID userId;
      @Column(name = "warehouse_id") private Long warehouseId;
      @Column(precision = 18, scale = 2) private BigDecimal totalAmount;
      @Version private Long version;
      @CreatedDate private Instant createdAt;
      @LastModifiedDate private Instant updatedAt;
      @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
      private List<OrderItemEntity> items = new ArrayList<>();
  }
  ```
- [ ] State machine: `PENDING → CONFIRMED → (COMPLETED|CANCELLED)`, `PENDING → CANCELLED`, `CONFIRMED → CANCELLED` (with compensation)
- [ ] `OrderRepository`: `findByOrderNo`, `findByUserId`, `findByStatus`
- [ ] Implement `OrderCommandService`:
  ```java
  @Transactional
  public OrderResponse create(CreateOrderRequest req, UUID userId) {
      // 1. Validate items, get prices from Product Service (sync call)
      List<PricedItem> priced = productClient.getPrices(req.items());
      
      // 2. Create order PENDING
      OrderEntity order = OrderEntity.builder()
          .orderNo(generateOrderNo())
          .type(req.type())
          .userId(userId)
          .status(OrderStatus.PENDING)
          .totalAmount(calculateTotal(priced))
          .build();
      order.addItems(priced.stream().map(this::toItemEntity).toList());
      orderRepo.save(order);
      
      return OrderResponse.from(order);
  }
  
  @Transactional
  public OrderResponse confirm(UUID orderId, String idempotencyKey) {
      OrderEntity order = orderRepo.findById(orderId).orElseThrow(...);
      order.requireStatus(OrderStatus.PENDING);
      
      if (order.getType() == OrderType.OUTBOUND) {
          // 3. Call Inventory Service reserve (async HTTP)
          ReserveRequest reserveReq = buildReserveRequest(order, idempotencyKey);
          ReserveResponse reserveResp = inventoryClient.reserve(reserveReq);
          
          if (!reserveResp.success()) {
              order.markFailed(reserveResp.error());
              throw new BusinessRuleException("Insufficient stock");
          }
      }
      
      order.confirm(); // PENDING -> CONFIRMED
      // 4. Publish outbox event (OrderConfirmedEvent)
      outboxRepo.save(new OutboxEvent("order.confirmed", orderId, ...));
      return OrderResponse.from(order);
  }
  ```
- [ ] `InventoryClient` (WebClient/Feign) với retry, timeout, circuit breaker
- [ ] Idempotency: `idempotencyKey` header, Inventory Service check duplicate
- [ ] Outbox pattern: `OutboxEvent` table, `OutboxPublisher` (TransactionalEventListener hoặc scheduled)
- [ ] Compensation: cancel confirmed order → call Inventory release
- [ ] Integration test: create→confirm success, confirm insufficient stock → FAILED, cancel confirmed → release inventory

### Acceptance Criteria

- [ ] Order created PENDING with items, total from Product Service
- [ ] Confirm OUTBOUND → calls Inventory reserve, success → CONFIRMED
- [ ] Confirm insufficient stock → order FAILED, no partial persist
- [ ] Cancel CONFIRMED → calls Inventory release, order CANCELLED
- [ ] Idempotency key prevents duplicate reserve
- [ ] Outbox event published after commit
- [ ] No direct Inventory DB access from Order Service

### Sau khi hoàn thành phải hiểu

Giải thích được: Saga orchestration vs choreography, idempotency key design, outbox pattern reliability, compensating transaction, circuit breaker for cross-service calls.

### Swagger

`POST /api/v1/orders`, `POST /api/v1/orders/{id}/confirm`, `POST /api/v1/orders/{id}/cancel`. State transition diagram trong description.

### Git

```bash
git checkout -b feature/day-15-order-inventory-saga
git add .
git commit -m "feat: implement order service with inventory saga workflow"
git push -u origin feature/day-15-order-inventory-saga
```

### Từ khóa tự học

`Saga Pattern`, `Orchestration`, `Idempotency`, `Outbox Pattern`, `Compensating Transaction`, `Circuit Breaker`, `State Machine`, `Distributed Transaction Avoidance`.

### Tài liệu tham khảo

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §13, §17; [services/order-service/README.md](services/order-service/README.md) §6-7.

### Output

- OrderEntity, OrderItemEntity với state machine
- OrderCommandService create/confirm/cancel
- InventoryClient WebClient với retry/circuit breaker
- Idempotency key implementation
- OutboxEvent + publisher
- Integration test full workflow

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
