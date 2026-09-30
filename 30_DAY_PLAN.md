# Lộ trình Backend Java Logistics trong 30 ngày

> Phạm vi: Spring Boot microservices, Java 17, PostgreSQL, Redis, RabbitMQ, Gradle Wrapper, WAR, External Tomcat 10.1 (Servlet 6.0), Docker, Jenkins.
>
> **Trạng thái workspace:** Root project có `settings.gradle`, `build.gradle`; 8 services có `build.gradle` (war plugin, Spring Boot 3.3.5, Java 17, MyBatis cho product/inventory, RabbitMQ cho notification); Gradle Wrapper 8.10 đã generate (`gradlew`, `gradlew.bat`, `gradle/wrapper/`). Source Java nghiệp vụ chưa implement.

## Cách dùng kế hoạch

- Mỗi ngày dành 30-60 phút học, 60-120 phút thực hành, 30-60 phút kiểm tra/sửa lỗi và khoảng 15 phút ghi chú/commit.
- Đọc đúng tài liệu/section được chỉ ra trong ngày; không cần đọc hết các README cùng lúc.
- Git commit hằng ngày. Không commit `.env`, mật khẩu, JWT secret, token, khóa SSH hay credential.
- Swagger được cập nhật theo từng API; không đợi tới cuối dự án mới bổ sung tài liệu API.
- Lệnh build chuẩn: `./gradlew clean test bootWar` (Linux/Mac) hoặc `.\gradlew.bat clean test bootWar` (Windows).

## Cấu trúc thư mục chuẩn mỗi service (Port/Adapter theo màn hình/use case)

```
services/<service-name>/
├── build.gradle
├── src/
│   ├── main/
│   │   ├── java/com/wms/<service>/
│   │   │   ├── <Service>Application.java
│   │   │   ├── config/          # SecurityConfig, MyBatisConfig, RedisConfig, RabbitMQConfig
│   │   │   ├── screens/         # Theo màn hình/use case (S01-login, S06-product, etc.)
│   │   │   │   └── SXX-<screen>/
│   │   │   │       ├── controller/      # REST endpoints (HTTP Adapter)
│   │   │   │       ├── dto/             # Request/Response DTO (record)
│   │   │   │       ├── service/         # Use case (Port interfaces + impl)
│   │   │   │       │   ├── <Feature>QueryService.java (Port)
│   │   │   │       │   ├── <Feature>CommandService.java (Port)
│   │   │   │       │   └── impl/
│   │   │   │       ├── repository/      # Repository/Mapper interfaces (Port)
│   │   │   │       └── db/              # Adapter implementations
│   │   │   │           ├── jpa/         # JPA Entity (Hibernate Adapter)
│   │   │   │           └── mybatis/     # MyBatis XML (MyBatis Adapter)
│   │   │   ├── client/          # WebClient/Feign call sang service khác (Outbound Port)
│   │   │   ├── event/           # Event DTO, Publisher, Consumer
│   │   │   ├── exception/       # ApiException, GlobalExceptionHandler
│   │   │   └── common/          # Security, Filter, Validation, Utils
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

**Quy tắc Port/Adapter:**

- `controller/` = HTTP Adapter (chỉ map HTTP → DTO → Service Port)
- `service/` interface = Use Case Port (định nghĩa nghiệp vụ)
- `service/impl/` = Use Case Adapter (implement Port, inject Repository Port)
- `repository/` interface = Persistence Port
- `db/jpa/` = JPA Entity (Hibernate Adapter)
- `db/mybatis/` = MyBatis XML (MyBatis Adapter)
- `client/` interface = Outbound Port, impl = WebClient Adapter

---

## Checklist Definition of Done cho mỗi tính năng

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

### Mục tiêu

Tạo nền Java 17/Spring Boot 3.3.5/Gradle 8.10 và chạy được ứng dụng WAR trên External Tomcat 10.1 (Servlet 6.0).

### Kiến thức cần đọc trước (Study Tasks Day 01)

| # | Chủ đề                              | Cụ thể cần nắm                                                                                       | Link học (Đọc theo thứ tự)                                                                                                                                                                                                         |
| - | -------------------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **JDK 17**                       | LTS version, record, pattern matching, sealed classes                                                    | [Oracle JDK 17 Docs](https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_windows-x64_bin.zip) \| [Baeldung Java 17 Features](https://www.baeldung.com/java-17-new-features)                                                                                            |
| 2 | **Spring Boot 3.3.x Lifecycle**  | ApplicationContext, Auto-configuration, ConditionEvaluation, Banner, ApplicationRunner/CommandLineRunner | [Spring Boot Reference - Application Startup](https://docs.spring.io/spring-boot/docs/3.3.x/reference/htmlsingle/#features.spring-application) \| [Spring Boot Lifecycle Events](https://www.baeldung.com/spring-boot-application-events) |
| 3 | **Gradle Wrapper 8.10**          | Cách Wrapper hoạt động,`gradle-wrapper.properties`, upgrade wrapper, cache                         | [Gradle Wrapper Docs](https://docs.gradle.org/8.10/userguide/gradle_wrapper.html) \| [Gradle Build Cache](https://docs.gradle.org/8.10/userguide/build_cache.html)                                                                        |
| 4 | **WAR vs JAR**                   | Servlet spec,`web.xml` vs `SpringBootServletInitializer`, embedded vs external Tomcat                | [Spring Boot WAR Deployment](https://docs.spring.io/spring-boot/docs/3.3.x/reference/htmlsingle/#howto.traditional-deployment) \| [Servlet 6.0 Spec](https://jakarta.ee/specifications/servlet/6.0/)                                      |
| 5 | **SpringBootServletInitializer** | `configure()` method, `SpringApplicationBuilder`, context path                                       | [SpringBootServletInitializer JavaDoc](https://docs.spring.io/spring-boot/docs/3.3.x/api/org/springframework/boot/web/servlet/support/SpringBootServletInitializer.html)                                                                 |
| 6 | **Tomcat 10.1 (Servlet 6.0)**    | `jakarta.*` namespace, context path, `server.xml`, deployment descriptor                             | [Tomcat 10.1 Docs](https://tomcat.apache.org/tomcat-10.1-doc/) \| [Servlet 6.0 Migration](https://jakarta.ee/specifications/servlet/6.0/jakarta-servlet-spec-6.0.html)                                                                    |
| 7 | **springdoc-openapi**            | `@OpenAPIDefinition`, `@Operation`, `@ApiResponse`, Swagger UI config                              | [springdoc Reference](https://springdoc.org/v2/#spring-boot) \| [OpenAPI 3.0 Spec](https://spec.openapis.org/oas/v3.0.3.html)                                                                                                             |
| 8 | **Gradle Multi-project**         | `settings.gradle`, `build.gradle` root, `subprojects {}`, `dependencyManagement`                 | [Gradle Multi-project Builds](https://docs.gradle.org/8.10/userguide/multi_project_builds.html)                                                                                                                                          |

**Thứ tự học gợi ý:** 1 → 4 → 5 → 6 → 2 → 3 → 7 → 8 (30-45 phút mỗi chủ đề)

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

### Tiêu chí chấp nhận

- [ ] `./gradlew :services:product-service:bootWar` BUILD SUCCESSFUL
- [ ] WAR deploy lên Tomcat 10.1, context path `/product-service` hoạt động
- [ ] `GET http://localhost:8080/product-service/api/v1/hello` → 200 JSON
- [ ] `GET http://localhost:8080/product-service/swagger-ui.html` hiển thị endpoint `/api/v1/hello`

### Sau khi hoàn thành phải hiểu

Giải thích được: WAR vs JAR, tại sao `providedRuntime tomcat`, vai trò của `SpringBootServletInitializer`, context-path mapping trên Tomcat.

### Swagger

Mở `/product-service/swagger-ui.html`, xác nhận endpoint `GET /api/v1/hello` có response 200, schema `Map<String,String>`.

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

### Tài liệu tham khảo

[README_CICD_FILES.md](README_CICD_FILES.md) §2-§5; [README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §3, §20; [services/README.md](services/README.md) §7; `services/product-service/build.gradle`.

### Output

- `./gradlew :services:product-service:bootWar` → BUILD SUCCESSFUL
- WAR deploy Tomcat → `GET /product-service/api/v1/hello` → 200
- Swagger UI accessible tại `/product-service/swagger-ui.html`

---

## Day 02 — Package by feature (screen) và Dependency Injection

### Mục tiêu

Tạo cấu trúc package `screens/S06-product/{controller,service,repository,db}` cho màn Product, áp dụng Constructor Injection, tách biệt API layer, Use case layer, Persistence layer.

### Kiến thức cần đọc trước (Study Tasks Day 02)

| # | Chủ đề                                       | Cụ thể cần nắm                                                                                                                                    | Link học (Đọc theo thứ tự)                                                                                                                                                                                                                                              |
| - | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **IoC Container & Dependency Injection**  | `ApplicationContext`, `BeanFactory`, `@Component`, `@Service`, `@Repository`, `@Configuration`, component scanning                        | [Spring IoC Container](https://docs.spring.io/spring-framework/reference/core/beans.html) \| [Spring DI Guide](https://www.baeldung.com/spring-dependency-injection)                                                                                                           |
| 2 | **Constructor Injection**                 | Tại sao prefer constructor injection, immutable dependencies, circular dependency detection                                                          | [Constructor Injection Best Practice](https://www.baeldung.com/constructor-injection-in-spring) \| [Spring Reference - Constructor-based DI](https://docs.spring.io/spring-framework/reference/core/beans/dependencies/factory-collaborators.html#beans-constructor-injection) |
| 3 | **Package by Feature vs Layer**           | Cấu trúc theo màn hình/use case (screen), tách biệt Port/Adapter, dependency rule                                                               | [Package by Feature](https://www.baeldung.com/java-package-by-feature) \| [Clean Architecture Package Structure](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)                                                                                 |
| 4 | **Port/Adapter (Hexagonal) Architecture** | Port = Interface (Use Case, Repository), Adapter = Implementation (JPA Entity, MyBatis XML, Controller), Dependency Inversion                         | [Ports and Adapters Pattern](https://alistair.cockburn.us/hexagonal-architecture/) \| [Spring Hexagonal Architecture](https://www.baeldung.com/hexagonal-architecture-spring)                                                                                                  |
| 5 | **CQRS Light (Query/Command Separation)** | Tách`QueryService` (read-only, `@Transactional(readOnly=true)`) và `CommandService` (write, `@Transactional`), read model khác write model | [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html) \| [Spring CQRS Example](https://www.baeldung.com/cqrs-pattern)                                                                                                                                                       |
| 6 | **DTO vs Entity**                         | Tại sao không expose Entity, record cho DTO, mapper manual/MapStruct                                                                                | [DTO Pattern](https://www.baeldung.com/java-dto-pattern) \| [MapStruct Guide](https://mapstruct.org/documentation/stable/reference/html/)                                                                                                                                      |
| 7 | **Lombok Best Practices**                 | `@RequiredArgsConstructor`, `@Getter`, `@Builder`, `@Slf4j`, tránh `@Data` trên Entity                                                    | [Lombok Best Practices](https://www.baeldung.com/lombok-best-practices)                                                                                                                                                                                                       |

**Thứ tự học:** 1 → 2 → 4 → 3 → 5 → 6 → 7 (45-60 phút mỗi chủ đề)

### Cấu trúc thư mục target (Port/Adapter pattern theo màn hình/use case)

Theo main README.md: `product-service` có màn hình `S06-product/`. Quy tắc: **Controller → Service (Use Case) → Repository Interface (Port) → Adapter trong `db/` (JPA/MyBatis/Procedure)**.

```
services/product-service/src/main/java/com/wms/product/
├── ProductApplication.java
├── config/
│   ├── SecurityConfig.java
│   ├── MyBatisConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S05-category/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── CategoryQueryService.java (interface - Port)
│   │   │   ├── CategoryCommandService.java (interface - Port)
│   │   │   └── impl/
│   │   ├── repository/
│   │   │   └── CategoryRepository.java (extends JpaRepository - Port)
│   │   └── db/
│   │       └── jpa/
│   │           └── CategoryEntity.java
│   ├── S06-product/
│   │   ├── controller/
│   │   │   └── ProductController.java
│   │   ├── dto/
│   │   │   ├── ProductResponse.java
│   │   │   ├── ProductListResponse.java
│   │   │   ├── CreateProductRequest.java
│   │   │   └── UpdateProductRequest.java
│   │   ├── service/
│   │   │   ├── ProductQueryService.java (interface - Port)
│   │   │   ├── ProductCommandService.java (interface - Port)
│   │   │   └── impl/
│   │   │       ├── ProductQueryServiceImpl.java
│   │   │       └── ProductCommandServiceImpl.java
│   │   ├── repository/ (Port interfaces)
│   │   │   ├── ProductRepository.java (extends JpaRepository)
│   │   │   └── ProductQueryMapper.java (MyBatis mapper interface)
│   │   └── db/ (Adapter implementations)
│   │       ├── jpa/
│   │       │   ├── ProductEntity.java
│   │       │   └── CategoryEntity.java (hoặc ref từ S05-category)
│   │       └── mybatis/
│   │           └── ProductMapper.xml
│   ├── S06a-csv-import/
│   └── S06b-csv-export/
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   ├── BusinessRuleException.java
│   │   ├── EntityNotFoundException.java
│   │   └── GlobalExceptionHandler.java
│   └── utils/
└── client/ (nếu cần call service khác)
```

**Lưu ý quan trọng:**

- `repository/` chỉ chứa **Interface (Port)** — `ProductRepository` (JPA) và `ProductQueryMapper` (MyBatis)
- `db/jpa/` chứa **JPA Entity** — Hibernate mapping table
- `db/mybatis/` chứa **MyBatis XML** — SQL mapping
- Spring Data JPA: Interface `ProductRepository` là Port, Spring sinh Adapter runtime
- MyBatis: Interface `ProductQueryMapper` là Port, XML là Adapter

### Tasks

- [ ] Tạo package structure như trên (`screens/S06-product/{controller,dto,service,repository,db}`)
- [ ] Tạo DTO records: `ProductResponse`, `ProductListResponse`, `CreateProductRequest`, `UpdateProductRequest` (với Jakarta Validation)
- [ ] Tạo **Port interfaces** trong `repository/`:

  - `ProductRepository extends JpaRepository<ProductEntity, Long>` (Port cho JPA)
  - `ProductQueryMapper` interface (Port cho MyBatis)
- [ ] Tạo **Adapter implementations** trong `db/`:

  - `db/jpa/ProductEntity.java`, `CategoryEntity.java` (JPA Entity mapping table)
  - `db/mybatis/ProductMapper.xml` (MyBatis SQL mapping)
- [ ] Tạo **Service interfaces (Port)** trong `service/`:

  - `ProductQueryService` (read-only use cases)
  - `ProductCommandService` (write use cases)
- [ ] Tạo **Service implementations (Adapter)** trong `service/impl/`:

  ```java
  @Service @RequiredArgsConstructor @Transactional(readOnly = true)
  public class ProductQueryServiceImpl implements ProductQueryService {
      private final ProductRepository productRepository;      // JPA Port
      private final ProductQueryMapper productQueryMapper;    // MyBatis Port
      // implement findById, findAll (pageable), search (MyBatis)
  }
  ```

  ```java
  @Service @RequiredArgsConstructor
  public class ProductCommandServiceImpl implements ProductCommandService {
      private final ProductRepository productRepository;
      // implement create, update, delete (có @Transactional)
  }
  ```
- [ ] Tạo `ProductController` constructor-inject `ProductQueryService`, `ProductCommandService`
- [ ] Implement `GET /api/v1/products` (pageable), `GET /api/v1/products/{id}`
- [ ] Viết unit test cho `ProductQueryServiceImpl` (Mockito mock Port interfaces)

### Tiêu chí chấp nhận

- [ ] Project compile: `./gradlew :services:product-service:compileJava`
- [ ] Unit test pass: `./gradlew :services:product-service:test`
- [ ] Controller chỉ map HTTP → DTO → Service, **KHÔNG** có logic business, **KHÔNG** inject Repository
- [ ] Service implement interface (Port), không phụ thuộc Spring MVC/MyBatis concrete class
- [ ] **Repository folder chỉ chứa Interface (Port)**: `ProductRepository`, `ProductQueryMapper`
- [ ] **db/ folder chứa Adapter**: JPA Entity (`db/jpa/`), MyBatis XML (`db/mybatis/`)
- [ ] Constructor injection everywhere (Lombok `@RequiredArgsConstructor` hoặc manual)
- [ ] `@Transactional` đặt ở Service implementation (Command), Query service `@Transactional(readOnly = true)`

### Sau khi hoàn thành phải hiểu

Giải thích được:

- Tại sao tách **Query/Command Service** (CQRS nhẹ): read model khác write model, tối ưu query
- Tại sao **Controller không inject Repository**: vi phạm Dependency Rule, Controller thuộc framework, Repository thuộc infrastructure
- **Port/Adapter pattern**: Service (Use Case) định nghĩa Port (interface), Infrastructure cài Adapter (JPA Entity, MyBatis XML)
- `repository/` = Port layer (interface), `db/` = Adapter layer (implementation)
- Spring Data JPA: Interface là Port, Spring sinh Adapter runtime
- MyBatis: Interface là Port, XML là Adapter
- Constructor Injection: dễ test, immutable dependencies, explicit dependencies

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

### Mục tiêu

Hoàn thiện CRUD Product API với HTTP method, status code, pagination, error response chuẩn.

### Kiến thức cần đọc trước (Study Tasks Day 03)

| # | Chủ đề                                   | Cụ thể cần nắm                                                                                                                                                            | Link học                                                                                                                                                                           |
| - | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **REST Constraints & HTTP Semantics** | 6 constraints (Client-Server, Stateless, Cacheable, Uniform Interface, Layered System, Code on Demand), HTTP method meanings (GET/POST/PUT/PATCH/DELETE), idempotency, safety | [REST API Tutorial](https://restfulapi.net/) \| [HTTP Methods RFC 9110](https://httpwg.org/specs/rfc9110.html)                                                                        |
| 2 | **Path Variable vs Query Param**      | Khi dùng`@PathVariable` (resource identity) vs `@RequestParam` (filter/sort/page), validation cho từng loại                                                            | [Spring @PathVariable vs @RequestParam](https://www.baeldung.com/spring-request-param-path-variable)                                                                                 |
| 3 | **HTTP Status Codes**                 | 2xx (200, 201, 204), 4xx (400, 401, 403, 404, 409, 422, 429), 5xx (500, 503), khi nào dùng mã nào                                                                         | [HTTP Status Codes](https://httpstatuses.com/) \| [REST HTTP Status Codes](https://restfulapi.net/http-status-codes/)                                                                 |
| 4 | **JSON Serialization (Jackson)**      | `@JsonProperty`, `@JsonIgnore`, `@JsonFormat`, serialization của `LocalDateTime`, `BigDecimal`, `UUID`, `enum`                                                 | [Jackson Annotations](https://github.com/FasterXML/jackson-annotations) \| [Spring JSON Serialization](https://www.baeldung.com/spring-boot-jackson-configuration)                    |
| 5 | **Problem Details (RFC 7807)**        | `type`, `title`, `status`, `detail`, `instance`, extension fields, Spring Boot `ErrorResponse` / `ProblemDetail`                                                | [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807) \| [Spring Boot ProblemDetail](https://docs.spring.io/spring-boot/docs/3.3.x/reference/htmlsingle/#features.error-handling) |
| 6 | **Correlation ID / Trace ID**         | MDC (Mapped Diagnostic Context),`X-Correlation-ID` header, filter extract/generate, logback pattern `%X{traceId}`                                                         | [Spring MDC](https://www.baeldung.com/spring-boot-logging-mdc) \| [Logback MDC](https://logback.qos.ch/manual/mdc.html)                                                               |
| 7 | **Spring MVC Annotations**            | `@RestController`, `@RequestMapping`, `@GetMapping`/`@PostMapping`/..., `@RequestBody`, `@Valid`, `@ModelAttribute`, `@RequestHeader`                         | [Spring MVC Annotations](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-requestmapping.html)                                                        |
| 8 | **Location Header & 201 Created**     | `ServletUriComponentsBuilder.fromCurrentRequest().path("/{id}").buildAndExpand(id).toUri()`                                                                                 | [Spring Location Header](https://www.baeldung.com/spring-mvc-custom-location-header)                                                                                                 |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (30-45 phút mỗi chủ đề)

### Package Structure (theo Day 02)

```
screens/S06-product/
├── controller/ProductController.java
├── dto/ (CreateProductRequest, UpdateProductRequest, ProductResponse, ProductListResponse)
├── service/
│   ├── ProductQueryService (Port interface)
│   ├── ProductCommandService (Port interface)
│   └── impl/
│       ├── ProductQueryServiceImpl
│       └── ProductCommandServiceImpl
├── repository/
│   ├── ProductRepository (Port - JPA)
│   └── ProductQueryMapper (Port - MyBatis)
└── db/ (Adapter - không sửa ở Day này)
```

### Tasks

- [ ] Implement đầy đủ endpoints trong `screens/S06-product/controller/ProductController.java`:
  - `GET    /api/v1/products` (page, size, sort, keyword, categoryId, status)
  - `GET    /api/v1/products/{id}`
  - `POST   /api/v1/products` → 201 + Location header
  - `PUT    /api/v1/products/{id}` → 200
  - `PATCH  /api/v1/products/{id}/status` → 200 (partial update)
  - `DELETE /api/v1/products/{id}` → 204
- [ ] Request/Response DTO trong `screens/S06-product/dto/`:
  - `CreateProductRequest`, `UpdateProductRequest`, `ProductResponse`, `ProductListResponse`
- [ ] Implement `ProductCommandServiceImpl` trong `screens/S06-product/service/impl/`:
  - `create()`: validate SKU unique, category exists → save via Port → return response
  - `update()`: check exists, validate, save
  - `delete()`: check exists, soft delete hoặc hard delete
  - `changeStatus()`: validate transition ACTIVE↔INACTIVE
- [ ] Global Exception Handler (`common/exception/GlobalExceptionHandler.java`):
  - `MethodArgumentNotValidException` → 400 (field errors)
  - `EntityNotFoundException` → 404
  - `DataIntegrityViolationException` (unique constraint) → 409
  - `BusinessRuleException` → 422
  - Response format: `{code, message, timestamp, traceId, errors?}`
- [ ] Thêm `X-Correlation-ID` header propagation (`common/filter/CorrelationIdFilter.java` + MDC)

### Tiêu chí chấp nhận

- [ ] `POST /api/v1/products` valid → 201, Location header, body ProductResponse
- [ ] `POST` duplicate SKU → 409 `{code: "CONFLICT", message: "SKU already exists"}`
- [ ] `POST` invalid body (blank sku, negative price) → 400 field errors
- [ ] `GET /products/999` not found → 404
- [ ] `GET /products?page=0&size=5&sort=name,asc` → 200 paged response
- [ ] `DELETE /products/{id}` → 204 no content
- [ ] Tất cả response có `traceId` trong header và body error

### Sau khi hoàn thành phải hiểu

Giải thích được: khi nào dùng 201 vs 200, 204 vs 200, 400 vs 422 vs 409, pagination contract, correlation ID tracing.

- Controller chỉ map HTTP → DTO → Service (Port), KHÔNG inject Repository
- Service impl gọi Port interface (`ProductRepository`, `ProductQueryMapper`)

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

### Mục tiêu

Chặn input sai tại biên API, trả lỗi có cấu trúc (RFC 7807), implement global exception handler, audit log.

### Kiến thức cần đọc trước (Study Tasks Day 04)

| # | Chủ đề                                                      | Cụ thể cần nắm                                                                                                                                                                                                                                                                            | Link học                                                                                                                                                                                                                   |
| - | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Jakarta Bean Validation 3.0 (JSR 380)**                | Built-in constraints:`@NotNull`, `@NotBlank`, `@NotEmpty`, `@Size`, `@Min`/`@Max`, `@Positive`/`@Negative`, `@DecimalMin`/`@DecimalMax`, `@Digits`, `@Pattern`, `@Email`, `@Past`/`@Future`, `@AssertTrue`/`@AssertFalse`                                   | [Bean Validation Spec](https://jakarta.ee/specifications/bean-validation/3.0/) \| [Hibernate Validator Reference](https://docs.jboss.org/hibernate/validator/8.0/reference/en-US/html_single/)                                |
| 2 | **Custom Constraint Validator**                          | Tạo`@ValidSku` annotation + `ConstraintValidator` implement, inject Repository để check unique trong DB, `ConstraintValidatorContext` custom message                                                                                                                                 | [Custom Validator](https://www.baeldung.com/spring-mvc-custom-validator) \| [Hibernate Validator Custom Constraints](https://docs.jboss.org/hibernate/validator/8.0/reference/en-US/html_single/#validator-customconstraints) |
| 3 | **Method Validation**                                    | `@Valid` trên `@RequestBody`, `@Validated` trên service method, cascade validation với `@Valid` trên nested object                                                                                                                                                                | [Method Validation](https://www.baeldung.com/javax-validation-method-constraints)                                                                                                                                            |
| 4 | **Global Exception Handler (`@RestControllerAdvice`)** | `@ExceptionHandler` cho: `MethodArgumentNotValidException` (400), `ConstraintViolationException` (400), `EntityNotFoundException` (404), `DataIntegrityViolationException` (409), `BusinessRuleException` (422), `OptimisticLockingFailureException` (409), `Exception` (500) | [Spring @RestControllerAdvice](https://www.baeldung.com/exception-handling-for-rest-with-spring) \| [Spring Boot Error Handling](https://docs.spring.io/spring-boot/docs/3.3.x/reference/htmlsingle/#features.error-handling) |
| 5 | **ProblemDetail / ErrorResponse (RFC 7807)**             | `ProblemDetail` (Spring 6+) hoặc custom `ErrorResponse` record: `code`, `message`, `timestamp`, `traceId`, `errors[]` (field, message, rejectedValue), `instance`                                                                                                            | [RFC 7807](https://datatracker.ietf.org/doc/html/rfc7807) \| [Spring ProblemDetail](https://docs.spring.io/spring-framework/reference/web/webflux/errors.html#webflux-errors-problem-detail)                                  |
| 6 | **Correlation ID Filter**                                | `OncePerRequestFilter`, extract/generate `X-Correlation-ID`, MDC put/remove, add to response header, logback `%X{traceId}`                                                                                                                                                              | [Spring MDC Filter](https://www.baeldung.com/spring-boot-logging-mdc)                                                                                                                                                        |
| 7 | **Validation Groups (Optional)**                         | `@Validated(OnCreate.class)`, `@Validated(OnUpdate.class)` cho validation khác nhau create vs update                                                                                                                                                                                     | [Validation Groups](https://www.baeldung.com/javax-validation-groups)                                                                                                                                                        |

**Thứ tự học:** 1 → 2 → 4 → 5 → 3 → 6 → 7 (45-60 phút mỗi chủ đề)

### Package Structure (theo Day 02)

```
screens/S06-product/
├── dto/
│   ├── CreateProductRequest.java
│   ├── UpdateProductRequest.java
│   ├── ProductResponse.java
│   └── ProductListResponse.java
common/
├── exception/
│   ├── ApiException.java
│   ├── BusinessRuleException.java
│   ├── EntityNotFoundException.java
│   ├── InvalidTokenException.java
│   └── GlobalExceptionHandler.java
└── filter/
    └── CorrelationIdFilter.java
```

### Tasks

- [ ] Cập nhật DTO trong `screens/S06-product/dto/` với validation đầy đủ:

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
- [ ] Tạo custom validation annotation `@ValidSku` + validator trong `common/validation/` (check format, không trùng trong DB qua Port)
- [ ] Tạo `GlobalExceptionHandler` trong `common/exception/`:

  ```java
  @ExceptionHandler(MethodArgumentNotValidException.class)
  public ResponseEntity<ErrorResponse> handleValidation(MethodArgumentNotValidException ex) { ... }
  @ExceptionHandler(EntityNotFoundException.class)
  public ResponseEntity<ErrorResponse> handleNotFound(EntityNotFoundException ex) { ... }
  @ExceptionHandler(DataIntegrityViolationException.class)
  public ResponseEntity<ErrorResponse> handleConflict(DataIntegrityViolationException ex) { ... }
  @ExceptionHandler(BusinessRuleException.class)
  public ResponseEntity<ErrorResponse> handleBusiness(BusinessRuleException ex) { ... }
  ```
- [ ] Tạo `ErrorResponse` record trong `common/exception/`: `code, message, timestamp, traceId, List<FieldError> errors`
- [ ] Tạo `CorrelationIdFilter` trong `common/filter/`: generate/extract `X-Correlation-ID`, put vào MDC, add vào response header
- [ ] Cấu hình `logback-spring.xml` với `%X{traceId}` pattern
- [ ] Unit test validation: test các case valid/invalid cho Create/Update request
- [ ] Integration test (MockMvc): test 400, 404, 409, 422 response format

### Tiêu chí chấp nhận

- [ ] `POST` SKU rỗng → 400 `{code:"VALIDATION_ERROR", errors:[{field:"sku", message:"SKU is required"}]}`
- [ ] `POST` SKU format sai (lowercase) → 400 custom validator message
- [ ] `POST` duplicate SKU → 409 `{code:"CONFLICT", message:"SKU already exists"}`
- [ ] `PUT /products/999` not found → 404 `{code:"NOT_FOUND", message:"Product not found"}`
- [ ] `POST` price âm → 400 field error price
- [ ] Tất cả error response có `traceId` khớp với response header `X-Correlation-ID`
- [ ] Log file chứa `traceId` cho mỗi request

### Sau khi hoàn thành phải hiểu

Giải thích được: validation tại controller vs service, RFC 7807 ProblemDetail, tại sao không throw Exception trực tiếp từ repository, correlation ID tracing.

- Validation annotations trên DTO (Controller layer)
- Business rule validation trong Service impl (Use Case layer)
- GlobalExceptionHandler ở `common/` (shared across services)
- CorrelationIdFilter ở `common/` (cross-cutting concern)

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

### Mục tiêu

Tạo database schema từ Flyway migration, hiểu PK/FK/Unique/Check/Index, so sánh query plan.

### Kiến thức cần đọc trước (Study Tasks Day 05)

| # | Chủ đề                                  | Cụ thể cần nắm                                                                                                                                                                                                       | Link học                                                                                                                                                                                       |
| - | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **PostgreSQL 15+ DDL & Constraints** | `CREATE TABLE`, `PRIMARY KEY` (serial/bigserial/uuid), `FOREIGN KEY` (ON DELETE CASCADE/SET NULL), `UNIQUE`, `CHECK`, `NOT NULL`, `DEFAULT`, `GENERATED ALWAYS AS IDENTITY`                              | [PostgreSQL DDL](https://www.postgresql.org/docs/15/ddl.html) \| [PostgreSQL Constraints](https://www.postgresql.org/docs/15/ddl-constraints.html)                                                |
| 2 | **Index Types & Design**             | B-tree (default), Hash, GiST, SP-GiST, GIN, BRIN; Composite index (column order), Partial index (`WHERE`), Expression index, Covering index (`INCLUDE`), `pg_stat_statements` để tìm missing index              | [PostgreSQL Indexes](https://www.postgresql.org/docs/15/indexes.html) \| [Use The Index, Luke](https://use-the-index-luke.com/)                                                                   |
| 3 | **EXPLAIN ANALYZE & Query Planning** | `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`, Seq Scan vs Index Scan vs Bitmap Heap Scan, Nested Loop vs Hash Join vs Merge Join, `rows=1` vs actual rows, `Buffers: shared hit/read`                                 | [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/15/using-explain.html) \| [Explain.depesz.com](https://explain.depesz.com/)                                                                  |
| 4 | **Flyway 10+ Migration**             | Versioned (`V1__`, `V2__`), Repeatable (`R__`), Undo (`U__`), Baseline, Callbacks (`afterMigrate`), `flyway_schema_history` table, naming convention, transaction per migration                              | [Flyway Documentation](https://flywaydb.org/documentation/) \| [Flyway Best Practices](https://www.baeldung.com/flyway)                                                                           |
| 5 | **Trigger & Function (PL/pgSQL)**    | `CREATE TRIGGER ... BEFORE UPDATE`, `NEW.updated_at = NOW()`, `CREATE OR REPLACE FUNCTION`, `RETURNS TRIGGER`, `LANGUAGE plpgsql`, row-level vs statement-level                                                | [PostgreSQL Triggers](https://www.postgresql.org/docs/15/sql-createtrigger.html) \| [PL/pgSQL](https://www.postgresql.org/docs/15/plpgsql.html)                                                   |
| 6 | **JPA Entity Mapping cho Schema**    | `@Table`, `@Column` (nullable, unique, length, precision, scale, columnDefinition), `@Id` + `@GeneratedValue` (IDENTITY/SEQUENCE), `@Version`, `@CreatedDate`/`@LastModifiedDate`, `@Enumerated(STRING)` | [JPA Mapping](https://docs.spring.io/spring-data/jpa/reference/jpa.html) \| [Hibernate Mapping](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#mapping) |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 (45-60 phút mỗi chủ đề)

### Files & Config

- Migration: `services/product-service/src/main/resources/db/migration/V1__create_product_schema.sql`, `V2__add_updated_at_trigger.sql`
- Config: `application.yml` flyway settings
- **Entity location**: `screens/S06-product/db/jpa/ProductEntity.java`, `CategoryEntity.java` (hoặc `S05-category/db/jpa/`)

### Tasks

- [ ] Tạo `V1__create_product_schema.sql`:
  ```sql
  CREATE TABLE categories (...);
  CREATE TABLE products (...);
  CREATE INDEX idx_products_category_id ON products(category_id);
  CREATE INDEX idx_products_status ON products(status);
  CREATE INDEX idx_products_name_gin ON products USING gin (to_tsvector('vietnamese', name));
  ```
- [ ] Tạo `V2__add_updated_at_trigger.sql` (trigger function + triggers)
- [ ] Run migration: `./gradlew :services:product-service:flywayMigrate` hoặc start app
- [ ] Verify: `docker exec -it postgres psql -U postgres -d product_db -c "\d products"`
- [ ] Tạo `ProductEntity` trong `screens/S06-product/db/jpa/` mapping đúng schema
- [ ] Tạo `CategoryEntity` trong `screens/S05-category/db/jpa/` + `@ManyToOne` relationship
- [ ] Test `EXPLAIN ANALYZE` so sánh với/không có index
- [ ] Thêm test data

### Tiêu chí chấp nhận

- [ ] Flyway migration chạy thành công (check `flyway_schema_history` table)
- [ ] Tables có PK, FK, Unique, Check constraint đúng
- [ ] Index được tạo, `EXPLAIN ANALYZE` sử dụng index (Index Scan, không Seq Scan)
- [ ] Trigger `updated_at` tự cập nhật khi UPDATE
- [ ] JPA Entity mapping compile, không lỗi Hibernate

### Sau khi hoàn thành phải hiểu

Giải thích được: Flyway versioning strategy, khi nào dùng FK vs logical reference, index selectivity, partial index, trigger vs application-level updated_at.

- Migration files ở `resources/db/migration/` (shared infrastructure)
- Entity ở `screens/S06-product/db/jpa/` (Adapter layer)
- Repository Port interface ở `screens/S06-product/repository/`

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
- JPA Entity compile OK (ở `screens/S06-product/db/jpa/`)

---

## Day 06 — Hibernate/JPA CRUD & Entity Mapping

### Mục tiêu

Nối Product Service với PostgreSQL bằng JPA/Hibernate cho CRUD, map Entity ↔ DTO, hiểu Persistence Context, dirty checking.

### Kiến thức cần đọc trước (Study Tasks Day 06)

| # | Chủ đề                                        | Cụ thể cần nắm                                                                                                                                                                                                   | Link học                                                                                                                                                                                                                         |
| - | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **JPA 3.1 & Hibernate 6.4 Core**           | `EntityManagerFactory`, `EntityManager`, `PersistenceContext`, `EntityManager` vs `Session`, Hibernate 6 changes (jakarta namespace, new parser)                                                           | [JPA 3.1 Spec](https://jakarta.ee/specifications/persistence/3.1/) \| [Hibernate 6.4 Migration](https://docs.jboss.org/hibernate/orm/6.4/migration-guide/html_single/)                                                              |
| 2 | **Persistence Context & Entity Lifecycle** | Transient → Persistent (`persist()`) → Detached (`detach()`/`clear()`) → Removed (`remove()`), Extended vs Transaction-scoped PC, `merge()` vs `save()`, `flush()` behavior                         | [Entity Lifecycle](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#entity-lifecycle) \| [Spring Data JPA save vs saveAndFlush](https://www.baeldung.com/spring-data-jpa-save-saveandflush) |
| 3 | **Dirty Checking & Flush**                 | Automatic dirty checking,`@DynamicUpdate`, `flush()` timing (before query, before commit), `FlushModeType`, read-only transaction optimization                                                                 | [Dirty Checking](https://www.baeldung.com/hibernate-dirty-checking) \| [Hibernate Flush](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#flushing)                                         |
| 4 | **Optimistic Locking (`@Version`)**      | `@Version` mechanism (increment on update), `OptimisticLockingFailureException` → 409, version column type (Long/Integer/Timestamp), `@OptimisticLocking` (ALL, DIRTY, NONE)                                  | [Optimistic Locking](https://www.baeldung.com/jpa-optimistic-locking) \| [Hibernate Optimistic Locking](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#locking-optimistic)                |
| 5 | **JpaRepository & Query Methods**          | `save()`, `saveAll()`, `findById()`, `findAll()`, `existsById()`, `deleteById()`, Derived queries (`findBy...`, `findTopNBy...`), `@Query` (JPQL/Native), `Pageable`, `Sort`, `@EntityGraph` | [Spring Data JPA](https://docs.spring.io/spring-data/jpa/reference/jpa.html) \| [Query Methods](https://docs.spring.io/spring-data/jpa/reference/jpa/query-methods.html)                                                            |
| 6 | **JPA Auditing**                           | `@EnableJpaAuditing`, `@EntityListeners(AuditingEntityListener.class)`, `@CreatedBy`, `@CreatedDate`, `@LastModifiedBy`, `@LastModifiedDate`, `AuditorAware<T>` bean                                   | [JPA Auditing](https://docs.spring.io/spring-data/jpa/reference/jpa/auditing.html) \| [Spring Boot Auditing](https://www.baeldung.com/spring-boot-jpa-auditing)                                                                     |
| 7 | **Entity ↔ DTO Mapping**                  | Manual mapper (`fromEntity()`), MapStruct (`@Mapper`), ModelMapper, record constructor, avoid exposing Entity fields                                                                                             | [MapStruct Guide](https://mapstruct.org/documentation/stable/reference/html/) \| [DTO Mapping](https://www.baeldung.com/entity-to-and-from-dto-for-a-jpa-entity)                                                                    |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 → 7 (45-60 phút mỗi chủ đề)

### Package Structure

```
screens/S06-product/
├── db/jpa/
│   ├── ProductEntity.java
│   └── CategoryEntity.java (hoặc ref từ S05-category)
├── repository/
│   └── ProductRepository.java (extends JpaRepository - Port)
├── service/
│   ├── ProductQueryService (Port)
│   ├── ProductCommandService (Port)
│   └── impl/
│       ├── ProductQueryServiceImpl.java
│       └── ProductCommandServiceImpl.java
```

### Tasks

- [ ] Tạo `ProductEntity` trong `screens/S06-product/db/jpa/` mapping đầy đủ:
  ```java
  @Entity @Table(name = "products")
  @EntityListeners(AuditingEntityListener.class)
  @Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
  public class ProductEntity { ... }
  ```
- [ ] Tạo `CategoryEntity` trong `screens/S05-category/db/jpa/` (hoặc cùng folder)
- [ ] Enable JPA Auditing: `@EnableJpaAuditing` trong `config/JpaAuditingConfig.java`
- [ ] Tạo `ProductRepository` trong `screens/S06-product/repository/`:
  ```java
  public interface ProductRepository extends JpaRepository<ProductEntity, Long> {
      Optional<ProductEntity> findBySku(String sku);
      Page<ProductEntity> findByCategoryIdAndStatus(Long categoryId, String status, Pageable pageable);
      Page<ProductEntity> findByNameContainingIgnoreCaseAndStatus(String keyword, String status, Pageable pageable);
      boolean existsBySku(String sku);
  }
  ```
- [ ] Implement `ProductCommandServiceImpl` trong `screens/S06-product/service/impl/` dùng JPA Port:
  ```java
  @Transactional
  public ProductResponse create(CreateProductRequest req) {
      if (productRepository.existsBySku(req.sku())) 
          throw new BusinessRuleException("SKU already exists");
      // ... build entity, save via Port, return Response
  }
  ```
- [ ] Implement `ProductQueryServiceImpl` trong `screens/S06-product/service/impl/`:
  - `findById`: `productRepository.findById(id).orElseThrow(...)`
  - `findAll`: `productRepository.findAll(pageable)` map sang `ProductListResponse`
- [ ] Tạo `ProductResponse.from(ProductEntity)` mapper (manual hoặc MapStruct) trong DTO hoặc mapper package
- [ ] Test: `./gradlew :services:product-service:test`
- [ ] Verify SQL log: bật `spring.jpa.show-sql=true`, `spring.jpa.properties.hibernate.format_sql=true`

### Tiêu chí chấp nhận

- [ ] `POST /products` → INSERT SQL, audit fields auto-populated, version=0
- [ ] `GET /products/{id}` → SELECT, map Entity→Response (không expose Entity)
- [ ] `PUT /products/{id}` → UPDATE, `updated_at` auto, version increment
- [ ] Concurrent UPDATE cùng version → `OptimisticLockingFailureException` → 409
- [ ] Dirty checking: chỉ field thay đổi mới UPDATE
- [ ] `Pageable` mapping đúng sort/page/size

### Sau khi hoàn thành phải hiểu

Giải thích được: Persistence Context lifecycle, dirty checking mechanism, `@Version` optimistic locking, khi nào dùng `save()` vs `saveAndFlush()`, `@EntityListeners(AuditingEntityListener.class)`.

- **Entity ở `db/jpa/`** (Adapter), **Repository interface ở `repository/`** (Port)
- Service impl inject Port (`ProductRepository`), không phụ thuộc Hibernate concrete class
- `@Transactional` ở Service impl (Command), Query service `@Transactional(readOnly = true)`

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

- ProductEntity, CategoryEntity ở `screens/S06-product/db/jpa/` (Adapter)
- ProductRepository ở `screens/S06-product/repository/` (Port)
- CRUD hoạt động, audit auto, optimistic lock test pass
- SQL log hiển thị INSERT/UPDATE/SELECT đúng

---

## Day 07 — JPA Relationship, LAZY/EAGER, N+1 Problem & Solutions

### Mục tiêu

Tải quan hệ Product-Category đúng nhu cầu, tránh N+1, tránh serialization cycle, tối ưu query.

### Kiến thức cần đọc trước (Study Tasks Day 07)

| # | Chủ đề                               | Cụ thể cần nắm                                                                                                                                                         | Link học                                                                                                                                                                                     |
| - | --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **FetchType LAZY vs EAGER**       | Default:`@ManyToOne`/`@OneToOne` = EAGER, `@OneToMany`/`@ManyToMany` = LAZY, performance impact, `Hibernate.initialize()`, `fetch = FetchType.LAZY` explicit   | [Fetch Types](https://www.baeldung.com/hibernate-lazy-eager-loading) \| [Hibernate Fetching](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#fetching) |
| 2 | **N+1 Problem**                   | Nguyên nhân (lazy load trong loop), phát hiện qua SQL log (`show-sql`), impact performance, 3 giải pháp chính                                                     | [N+1 Problem](https://www.baeldung.com/hibernate-n-plus-one) \| [Vlad Mihalcea N+1](https://vladmihalcea.com/the-n1-query-problem/)                                                             |
| 3 | **Fetch Join (JPQL)**             | `LEFT JOIN FETCH`, `JOIN FETCH`, distinct keyword để tránh duplicate, limitation (cannot fetch multiple bags)                                                       | [Fetch Join](https://www.baeldung.com/jpa-fetch-join) \| [Hibernate Fetch Join](https://docs.jboss.org/hibernate/orm/6.4/userguide/html_single/Hibernate_User_Guide.html#fetching-fetch-join)   |
| 4 | **@EntityGraph**                  | Named/Ad-hoc graph,`attributePaths`, `type = EntityGraphType.LOAD`/`FETCH`, combine với `JpaRepository`, dynamic graph                                            | [Entity Graph](https://www.baeldung.com/jpa-entity-graph) \| [Spring Data EntityGraph](https://docs.spring.io/spring-data/jpa/reference/jpa/entity-graph.html)                                  |
| 5 | **Projection (DTO/Interface)**    | Interface-based projection (closed/open), Class-based projection (record),`Page<Projection>`, `@Query` select specific columns, performance benefit                    | [Spring Data Projections](https://docs.spring.io/spring-data/jpa/reference/jpa/projections.html) \| [Hibernate Projection](https://www.baeldung.com/spring-data-jpa-projections)                |
| 6 | **@BatchSize**                    | `@BatchSize(size=20)` trên collection, batch loading cho LAZY collections, reduce N+1 cho collection access                                                             | [Batch Size](https://www.baeldung.com/hibernate-batchsize)                                                                                                                                     |
| 7 | **Serialization Cycle (Jackson)** | `@JsonIgnore` (break cycle), `@JsonManagedReference`/`@JsonBackReference` (parent/child), `@JsonIdentityInfo` (ObjectId), DTO projection thay vì serialize Entity | [Jackson Bidirectional](https://www.baeldung.com/jackson-bidirectional-relationships-and-infinite-recursion)                                                                                   |
| 8 | **Open Session in View (OSIV)**   | `spring.jpa.open-in-view=true/false` (default true Spring Boot 2, false Spring Boot 3), lazy loading trong view/template, trade-off                                      | [OSIV](https://www.baeldung.com/spring-open-session-in-view)                                                                                                                                   |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (30-45 phút mỗi chủ đề)

### Package Structure

```
screens/S06-product/
├── db/jpa/
│   ├── ProductEntity.java (cập nhật relationship)
│   └── CategoryEntity.java (cập nhật relationship)
├── repository/
│   └── ProductRepository.java (thêm EntityGraph methods)
├── service/impl/
│   └── ProductQueryServiceImpl.java (dùng projection)
```

### Tasks

- [ ] Cập nhật Entity relationship trong `screens/S06-product/db/jpa/`:

  ```java
  // ProductEntity
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "category_id", insertable = false, updatable = false)
  private CategoryEntity category;

  // CategoryEntity (trong S05-category/db/jpa/)
  @OneToMany(mappedBy = "category", fetch = FetchType.LAZY)
  @BatchSize(size = 20)
  private Set<ProductEntity> products = new HashSet<>();
  ```
- [ ] Test N+1: gọi `GET /products` → log SQL, đếm query count
- [ ] Fix N+1 cho danh sách: thêm method trong `ProductRepository` (Port):

  ```java
  @EntityGraph(attributePaths = {"category"}, type = EntityGraphType.LOAD)
  Page<ProductEntity> findByCategoryIdAndStatus(Long categoryId, String status, Pageable pageable);
  ```

  Hoặc custom query: `SELECT p FROM ProductEntity p LEFT JOIN FETCH p.category WHERE ...`
- [ ] Fix serialization cycle: thêm `@JsonIgnore` trên `CategoryEntity.products` hoặc dùng DTO projection
- [ ] Tạo projection interface trong `screens/S06-product/dto/`:

  ```java
  public interface ProductListProjection {
      Long getId(); String getSku(); String getName(); BigDecimal getPrice(); String getStatus();
  }
  ```

  Repository Port: `Page<ProductListProjection> findProjectedByStatus(String status, Pageable pageable);`
- [ ] Implement `ProductQueryServiceImpl` dùng projection cho list view
- [ ] Test performance: so sánh query count & thời gian giữa EntityGraph vs Projection vs N+1
- [ ] Disable `spring.jpa.open-in-view=false` (default Spring Boot 3), hiểu implications

### Tiêu chí chấp nhận

- [ ] `GET /products` list 20 items → 1 query (fetch join) hoặc 1 query (projection), KHÔNG phải 21 queries
- [ ] `GET /products/{id}` load category → 1 query (fetch join) hoặc 2 queries (LAZY + explicit load)
- [ ] Response JSON không có circular reference error
- [ ] `@BatchSize` hoạt động khi access category.products collection

### Sau khi hoàn thành phải hiểu

Giải thích được: LAZY default, N+1 root cause, Fetch Join vs EntityGraph vs Projection trade-offs, khi nào disable Open Session in View, `@BatchSize` use case.

- Relationship annotation trên **Entity ở `db/jpa/`** (Adapter)
- `@EntityGraph` / custom query trên **Repository Port interface ở `repository/`**
- Projection interface ở **DTO layer** (Use Case output)
- Service impl chọn strategy phù hợp (Port method)

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

- Entity relationship LAZY + @BatchSize (ở `db/jpa/`)
- List endpoint: 1 query (fetch join/projection)
- Detail endpoint: fetch join category
- No serialization cycle
- Performance test showing query count reduction

---

## Day 08 — MyBatis Mapper cho Search/Report Phức Tạp

### Mục tiêu

Dùng MyBatis cho truy vấn đọc cần SQL tường minh (search, filter động, report), hiểu `#{} vs ${}`, `resultMap`, `projection`.

### Kiến thức cần đọc trước (Study Tasks Day 08)

| # | Chủ đề                                                                                                                                                                                                                                     | Cụ thể cần nắm                                                                                                                                                                        | Link học                                                                                                                                           |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **MyBatis 3.0.4 Core**                                                                                                                                                                                                                  | `SqlSessionFactory`, `SqlSession`, `Mapper` interface, `@Mapper`/`@MapperScan`, `SqlSessionTemplate`, transaction management, `mybatis-spring-boot-starter` auto-config     | [MyBatis 3 Docs](https://mybatis.org/mybatis-3/) \| [MyBatis-Spring Boot](https://mybatis.org/spring-boot-starter/mybatis-spring-boot-autoconfigure/) |
| 2 | **Mapper XML Structure**                                                                                                                                                                                                                | `<mapper namespace="...">`, `<resultMap>`, `<id>`/`<result>`/`<association>`/`<collection>`, `<select>`/`<insert>`/`<update>`/`<delete>`, `<sql>` fragment reusable | [MyBatis XML](https://mybatis.org/mybatis-3/sqlmap-xml.html)                                                                                         |
| 3 | **Parameter Binding: `#{}` vs `${}`** | `#{}` = PreparedStatement (safe, type handler, prevent SQL injection), `${}` = String substitution (raw, dùng cho ORDER BY, table name), **không dùng `${}` cho user input** | [MyBatis Parameters](https://mybatis.org/mybatis-3/sqlmap-xml.html#Parameters) \| [SQL Injection Prevention](https://www.baeldung.com/mybatis-sql-injection)                                |                                                                                                                                                     |
| 4 | **Result Mapping**                                                                                                                                                                                                                      | `<resultMap>` với `<id>`, `<result>`, `<association>` (nested object), `<collection>` (list), constructor-based (`<constructor>`), auto-mapping (`autoMapping=true`)       | [Result Maps](https://mybatis.org/mybatis-3/sqlmap-xml.html#Result_Maps)                                                                             |
| 5 | **Dynamic SQL**                                                                                                                                                                                                                         | `<where>`, `<if test="...">`, `<choose>/<when>/<otherwise>`, `<trim>` (prefix/suffix), `<foreach>` (IN clause), `<bind>` (OGNL variable)                                      | [Dynamic SQL](https://mybatis.org/mybatis-3/dynamic-sql.html)                                                                                        |
| 6 | **TypeHandler**                                                                                                                                                                                                                         | Built-in handlers, custom TypeHandler cho enum,`LocalDateTime`, `UUID`, JSONB, register trong config hoặc `@MappedTypes`                                                           | [Type Handlers](https://mybatis.org/mybatis-3/sqlmap-xml.html#Type_Handlers) \| [Custom TypeHandler](https://www.baeldung.com/mybatis-type-handlers)  |
| 7 | **Pagination**                                                                                                                                                                                                                          | `LIMIT #{size} OFFSET #{offset}`, `RowBounds`, `PageHelper` (optional), count query tách biệt (`<sql id="countWhere">` reuse)                                                   | [MyBatis Pagination](https://github.com/pagehelper/Mybatis-PageHelper)                                                                               |
| 8 | **MyBatis-Spring Integration**                                                                                                                                                                                                          | `@Mapper` annotation, `@MapperScan("com.wms.product.screens.S06-product.repository")`, `SqlSessionTemplate` injection, transaction integration                                      | [MyBatis-Spring](http://mybatis.org/spring/)                                                                                                         |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 (30-45 phút mỗi chủ đề)

### Package Structure

```
screens/S06-product/
├── repository/
│   └── ProductQueryMapper.java (MyBatis Port interface)
├── db/mybatis/
│   └── ProductMapper.xml (MyBatis Adapter - SQL mapping)
├── service/
│   └── ProductQueryService.java (Port - thêm search method)
└── service/impl/
    └── ProductQueryServiceImpl.java (impl - delegate to MyBatis Port)
config/
└── MyBatisConfig.java (@MapperScan)
```

### Tasks

- [ ] Tạo `ProductQueryMapper` interface trong `screens/S06-product/repository/`:
  ```java
  @Mapper
  public interface ProductQueryMapper {
      List<ProductSearchResult> search(ProductSearchCriteria criteria);
      long countSearch(ProductSearchCriteria criteria);
      Optional<ProductDetailResult> findDetailById(Long id);
  }
  ```
- [ ] Tạo `ProductSearchCriteria` record trong `dto/`
- [ ] Tạo `ProductMapper.xml` trong `screens/S06-product/db/mybatis/`:
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
  ```
- [ ] Implement `ProductQueryServiceImpl` delegate to `ProductQueryMapper` Port
- [ ] Validate `sortBy` against whitelist trước khi pass vào MyBatis (chống SQL injection từ `${}`)
- [ ] Unit test MyBatis mapper với `@MybatisTest` + Testcontainers PostgreSQL
- [ ] Compare: JPA vs MyBatis cho search query (performance, flexibility)

### Tiêu chí chấp nhận

- [ ] `GET /products?keyword=key&categoryId=1&status=ACTIVE&page=0&size=20&sortBy=name&sortDir=asc` → MyBatis query
- [ ] `#{criteria.keyword}` dùng prepared statement (safe), `${criteria.sortBy}` validated whitelist
- [ ] `resultMap` map đúng `category_name` từ JOIN
- [ ] Pagination đúng: `LIMIT size OFFSET (page * size)`
- [ ] Count query dùng chung `<where>` fragment

### Sau khi hoàn thành phải hiểu

Giải thích được: khi nào chọn MyBatis thay JPA, `#{} vs ${}` security, dynamic SQL tags, `resultMap` vs `resultType`, TypeHandler cho custom type.

- **MyBatis Mapper Interface ở `repository/`** (Port)
- **MyBatis XML ở `db/mybatis/`** (Adapter)
- Service impl inject Port (`ProductQueryMapper`), không phụ thuộc XML
- `${}` chỉ dùng cho sortBy đã whitelist, `#{}` cho mọi parameter

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

- ProductQueryMapper interface ở `screens/S06-product/repository/` (Port)
- ProductMapper.xml ở `screens/S06-product/db/mybatis/` (Adapter)
- Dynamic SQL với `<where>`, `<if>`, `<trim>`
- Search API dùng MyBatis, JPA dùng cho CRUD
- Whitelist validation cho `${sortBy}`
- Unit test mapper với Testcontainers

---

## Day 09 — Search, Filter, Sort, Pagination API Hoàn Chỉnh

### Mục tiêu

Hoàn thiện API danh sách catalog với full-text search, multi-filter, sort whitelist, pagination chuẩn.

### Kiến thức cần đọc trước (Study Tasks Day 09)

| # | Chủ đề                                       | Cụ thể cần nắm                                                                                                                                                                  | Link học                                                                                                                                            |
| - | ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Pagination Strategies**                 | Offset pagination (`LIMIT/OFFSET`) vs Keyset pagination (`WHERE id > lastId ORDER BY id LIMIT`), trade-offs (deep paging performance, real-time data), `Pageable` Spring Data | [Pagination Patterns](https://www.baeldung.com/spring-data-jpa-pagination-sorting) \| [Keyset Pagination](https://vladmihalcea.com/keyset-pagination/) |
| 2 | **Sort Allowlist & Injection Prevention** | Whitelist column names (`sku`, `name`, `price`, `createdAt`), validate `sortDir` (`asc`/`desc`), reject raw SQL, MyBatis `${}` protection                           | [Sort Whitelist](https://www.baeldung.com/spring-data-jpa-sorting)                                                                                    |
| 3 | **Full-text Search PostgreSQL**           | `to_tsvector`/`to_tsquery`, `gin_trgm_ops` (pg_trgm), `websearch_to_tsquery`, `ts_rank`, multi-language config                                                            | [PostgreSQL Full Text Search](https://www.postgresql.org/docs/15/textsearch.html) \| [pg_trgm](https://www.postgresql.org/docs/15/pgtrgm.html)         |
| 4 | **Composite Index Design**                | Column order (equality first, then range),`INCLUDE` columns (covering index), partial index (`WHERE status = 'ACTIVE'`), index-only scan                                        | [Composite Indexes](https://use-the-index-luke.com/sql/where-clause/the-equals-operator/concatenated-indexes)                                         |
| 5 | **Cursor-based Pagination**               | `WHERE (created_at, id) > (?, ?) ORDER BY created_at, id LIMIT 20`, opaque cursor (base64 encode), Relay-style pagination                                                         | [Cursor Pagination](https://www.baeldung.com/spring-data-cursor-pagination)                                                                           |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 (30-45 phút mỗi chủ đề)

### Package Structure

```
screens/S06-product/
├── controller/ProductController.java (cập nhật search endpoint)
├── dto/
│   ├── ProductSearchCriteria.java
│   ├── ProductListResponse.java
│   └── ProductResponse.java
├── repository/
│   ├── ProductRepository (JPA Port)
│   └── ProductQueryMapper (MyBatis Port)
└── service/impl/
    └── ProductQueryServiceImpl.java (orchestrate JPA + MyBatis)
```

### Tasks

- [ ] Cập nhật `ProductController.search()` trong `screens/S06-product/controller/`:
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
- [ ] Implement `ProductQueryServiceImpl.search()` trong `screens/S06-product/service/impl/`:
  - Validate sortBy whitelist → throw 400 nếu invalid
  - Delegate to MyBatis Port (`ProductQueryMapper`) cho search phức tạp
  - Map result sang `ProductListResponse(items, page, size, totalElements, totalPages)`
- [ ] Thêm database index cho query pattern (Flyway migration):
  ```sql
  CREATE INDEX idx_products_search ON products (status, category_id, name);
  CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
  ```
- [ ] Test `EXPLAIN ANALYZE` với các filter combination
- [ ] Integration test: filter, sort, pagination boundary, invalid params

### Tiêu chí chấp nhận

- [ ] Search API hỗ trợ tất cả filter combination
- [ ] Sort whitelist chặn injection (`sortBy=name; DROP TABLE` → 400)
- [ ] Pagination response format chuẩn: `items[], page, size, totalElements, totalPages`
- [ ] `EXPLAIN ANALYZE` show Index Scan cho các filter phổ biến
- [ ] Integration test cover tất cả case

### Sau khi hoàn thành phải hiểu

Giải thích được: Offset vs Keyset pagination trade-offs, sort whitelist security, composite index design, full-text search options (trgm, tsvector).

- Controller validate input, delegate to Service Port
- Service impl orchestrates JPA Port (simple) + MyBatis Port (complex search)
- Whitelist validation ở Service layer (Use Case), không leak vào Adapter

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

### Mục tiêu

Tạo User Service foundation: Entity, Repository, BCrypt PasswordEncoder, User lookup.

### Kiến thức cần đọc trước (Study Tasks Day 10)

| # | Chủ đề                                 | Cụ thể cần nắm                                                                                                                                                                                            | Link học                                                                                                                                                             |
| - | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **BCrypt & Password Hashing**       | BCrypt algorithm (Blowfish-based), cost factor (log2 rounds), salt generation, hash format (`$2a$12$...`), constant-time comparison, timing attack prevention                                               | [BCrypt](https://www.baeldung.com/spring-security-bcrypt) \| [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) |
| 2 | **Spring Security PasswordEncoder** | `PasswordEncoder` interface, `BCryptPasswordEncoder(cost)`, `Pbkdf2PasswordEncoder`, `Argon2PasswordEncoder`, `DelegatingPasswordEncoder` (multi-format), upgrade encoding                          | [Spring Security PasswordEncoder](https://docs.spring.io/spring-security/reference/servlet/authentication/passwords/index.html)                                        |
| 3 | **Credential Stuffing Prevention**  | Rate limiting login, account lockout, CAPTCHA, breached password check (HaveIBeenPwned), multi-factor authentication                                                                                          | [Credential Stuffing](https://cheatsheetseries.owasp.org/cheatsheets/Credential_Stuffing_Prevention_Cheat_Sheet.html)                                                  |
| 4 | **JPA Entity & Repository**         | `@Entity`, `@Table`, `@Id`, `@GeneratedValue`, `@Column` (unique, nullable, length), `@Enumerated(STRING)`, `@Version`, `@CreatedDate`/`@LastModifiedDate`, `JpaRepository` query methods | [Spring Data JPA](https://docs.spring.io/spring-data/jpa/reference/jpa.html)                                                                                           |

**Thứ tự học:** 1 → 2 → 3 → 4 (45-60 phút mỗi chủ đề)

### Package Structure (auth-service)

```
services/auth-service/src/main/java/com/wms/auth/
├── screens/
│   ├── S01-login/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   ├── repository/
│   │   └── db/jpa/
│   ├── S02-session/
│   ├── S04-user-admin/
├── common/
└── config/
```

### Tasks

- [ ] Tạo `UserEntity` trong `screens/S01-login/db/jpa/` (hoặc `S04-user-admin/db/jpa/`):
  ```java
  @Entity @Table(name = "users", uniqueConstraints = {
      @UniqueConstraint(name = "uk_users_username", columnNames = "username"),
      @UniqueConstraint(name = "uk_users_email", columnNames = "email")
  })
  public class UserEntity { ... }
  ```
- [ ] Tạo `UserRepository` trong `screens/S01-login/repository/`:
  ```java
  Optional<UserEntity> findByUsername(String username);
  Optional<UserEntity> findByEmail(String email);
  boolean existsByUsername(String username);
  boolean existsByEmail(String email);
  ```
- [ ] Cấu hình `PasswordEncoder` bean trong `config/SecurityConfig.java`
- [ ] Tạo `UserService` trong `screens/S01-login/service/impl/`:
  ```java
  @Transactional(readOnly = true)
  public UserEntity findByUsernameOrThrow(String username) { ... }

  public boolean verifyPassword(String rawPassword, String encodedPassword) { ... }
  ```
- [ ] Flyway migration `V1__create_user_schema.sql` trong `resources/db/migration/`
- [ ] Seed data
- [ ] Unit test

### Tiêu chí chấp nhận

- [ ] BCrypt cost factor 12, password hash length 60 chars
- [ ] `verifyPassword()` trả true/false đúng
- [ ] Không log/return password hash
- [ ] Login fail không tiết lộ user tồn tại
- [ ] Migration chạy thành công, index tạo đúng

### Sau khi hoàn thành phải hiểu

Giải thích được: BCrypt cost factor trade-off, tại sao không dùng SHA/MD5, constant-time comparison, credential stuffing prevention.

- Entity ở `screens/S01-login/db/jpa/` (Adapter)
- Repository Port ở `screens/S01-login/repository/`
- Service impl ở `screens/S01-login/service/impl/`

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

[README_SCREEN_SPEC.md](README_SCREEN_SPEC.md) §5, §8, §16; [services/auth-service/README.md](services/auth-service/README.md).

### Output

- UserEntity ở `screens/S01-login/db/jpa/`
- UserRepository ở `screens/S01-login/repository/`
- BCryptPasswordEncoder bean (cost 12)
- UserService verifyPassword()
- Flyway migration với constraints/index
- Unit test pass

---

## Day 11 — JWT Access Token (RS256, JWKS, Resource Server)

### Mục tiêu

Phát và xác minh JWT RS256 cho API bảo vệ, cấu hình Spring Security Resource Server.

### Kiến thức cần đọc trước (Study Tasks Day 11)

| # | Chủ đề                                 | Cụ thể cần nắm                                                                                                                                                                 | Link học                                                                                                                                                          |
| - | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 | **JWT & JWS (RFC 7519/7515)**       | JWT structure (header.payload.signature), JWS (signed JWT), claims:`iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`, custom claims, JWT vs JWE                        | [RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519) \| [JWT.io](https://jwt.io/introduction)                                                                   |
| 2 | **RS256 (RSA Signature)**           | Asymmetric signing, RSA 2048-bit key pair,`SHA256withRSA`, private key sign / public key verify, key rotation, `jose` library (Nimbus)                                         | [RS256](https://www.baeldung.com/java-jwt-rsa) \| [Nimbus JOSE](https://connect2id.com/products/nimbus-jose-jwt)                                                     |
| 3 | **JWKS (JSON Web Key Set)**         | `jwks_uri`, public key exposure (`/.well-known/jwks.json`), key rotation (`kid` header), `jose4j`/`nimbus-jose-jwt` JWK support                                          | [JWKS Spec](https://datatracker.ietf.org/doc/html/rfc7517) \| [Spring JWKS](https://docs.spring.io/spring-security/reference/servlet/oauth2/resourceserver/jwt.html) |
| 4 | **Spring Security Resource Server** | `oauth2ResourceServer(jwt -> {})`, `JwtDecoder` bean, `JwtAuthenticationConverter` (claims → Authorities), `SecurityFilterChain` stateless, `BearerTokenAuthentication` | [Spring Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resourceserver/jwt.html)                                                   |
| 5 | **JwtDecoder Configuration**        | `NimbusJwtDecoder`, validate `iss`, `aud`, `exp`, `nbf`, clock skew, custom `OAuth2TokenValidator`, `JwtTimestampValidator`                                          | [JwtDecoder](https://docs.spring.io/spring-security/reference/servlet/oauth2/resourceserver/jwt.html#oauth2resourceserver-jwt-jwtdecoder)                           |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 (45-60 phút mỗi chủ đề)

### Package Structure (auth-service)

```
services/auth-service/src/main/java/com/wms/auth/
├── screens/
│   ├── S01-login/
│   │   ├── controller/AuthController.java
│   │   ├── dto/LoginRequest.java, RegisterRequest.java, AuthResponse.java
│   │   ├── service/
│   │   │   ├── AuthCommandService.java (Port)
│   │   │   └── impl/AuthCommandServiceImpl.java
│   │   ├── repository/UserRepository.java (Port)
│   │   └── db/jpa/UserEntity.java
│   ├── S02-session/
│   │   ├── controller/SessionController.java
│   │   ├── dto/RefreshRequest.java, TokenPairResponse.java
│   │   ├── service/
│   │   │   ├── TokenService.java (Port) - issue access/refresh
│   │   │   ├── RefreshTokenService.java (Port) - rotation
│   │   │   └── impl/TokenServiceImpl.java, RefreshTokenServiceImpl.java
│   │   ├── repository/RefreshTokenRepository.java (Port)
│   │   └── db/jpa/RefreshTokenEntity.java
│   └── S04-user-admin/
├── config/
│   ├── SecurityConfig.java (Resource Server)
│   ├── RsaKeyConfig.java
│   ├── JwtDecoderConfig.java
│   └── JwtAuthenticationConverter.java
├── controller/JwkController.java (/.well-known/jwks.json)
└── common/security/
    ├── CurrentUser.java
    ├── UserPrincipal.java
    └── AuthorizationService.java
```

### Tasks

- [ ] Generate RSA key pair (2048-bit) cho dev
- [ ] Tạo `RsaKeyConfig` trong `config/` load keys
- [ ] Tạo `TokenService` interface (Port) trong `screens/S01-login/service/` + impl:
  ```java
  public String createAccessToken(UserEntity user) {
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
- [ ] Cấu hình `SecurityConfig` Resource Server trong `config/`
- [ ] Cấu hình `JwtDecoder` bean validate `iss`, `aud`, `exp`, `nbf`, signature
- [ ] Tạo `JwkController` trong root controller package expose `GET /.well-known/jwks.json`
- [ ] Bảo vệ endpoint test: `GET /api/v1/auth/me` → return current user từ `Authentication`

### Tiêu chí chấp nhận

- [ ] Access token RS256, 15min expiry, claims: iss, sub, username, email, role, scope, iat, exp, jti
- [ ] JWKS endpoint trả public key đúng format
- [ ] Resource Server validate signature, exp, iss, aud
- [ ] `GET /api/v1/auth/me` với Bearer token → 200 user info
- [ ] Token hết hạn/ sai chữ ký → 401 với error code

### Sau khi hoàn thành phải hiểu

Giải thích được: RS256 vs HS256, JWKS key rotation, JWT validation flow, Resource Server vs Authorization Server, claim mapping.

- TokenService Port ở `screens/S01-login/service/`
- SecurityConfig ở `config/` (cross-cutting)
- JWKS controller ở root package

### Swagger

Cấu hình `securitySchemes: bearerAuth (http, bearer, bearerFormat: JWT)`, apply cho protected endpoints.

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
- TokenService Port ở `screens/S01-login/service/`
- Resource Server config validate JWT
- Protected endpoint test pass

---

## Day 12 — Refresh Token (Opaque, Rotation, Revocation, Logout)

### Mục tiêu

Quản lý session dài hạn với opaque refresh token, rotation, revocation, logout-all.

### Kiến thức cần đọc trước (Study Tasks Day 12)

| # | Chủ đề                                | Cụ thể cần nắm                                                                                                                    | Link học                                                                                                                                             |
| - | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Opaque Refresh Token**           | Random token (32 bytes), opaque = không chứa thông tin, chỉ lưu hash (SHA-256), không thể decode, thay cho JWT refresh token   | [Opaque Tokens](https://www.baeldung.com/spring-security-oauth-opaque-token) \| [OAuth 2.0 Threat Model](https://datatracker.ietf.org/doc/html/rfc6819) |
| 2 | **Token Rotation**                 | Mỗi lần refresh: revoke token cũ (`revoked_at`), tạo token mới, link qua `replaced_by_jti`, single-use, prevent replay       | [Token Rotation](https://auth0.com/blog/refresh-tokens-what-are-they-and-when-to-use-them/)                                                            |
| 3 | **Reuse Detection (Token Family)** | Nếu token cũ bị reuse → revoke toàn bộ family (cascade revoke), detect stolen token,`replaced_by_jti` chain traversal         | [Token Family](https://www.thread-safe.com/2018/09/oauth2-refresh-token-rotation-and.html)                                                             |
| 4 | **SHA-256 Hash Storage**           | `MessageDigest.getInstance("SHA-256")`, hex encode, constant-time comparison (`MessageDigest.isEqual()`), không lưu plain token | [SHA-256 Java](https://www.baeldung.com/sha-256-hashing-java)                                                                                          |
| 5 | **Transaction Boundary**           | `@Transactional` bao quanh: find → check → revoke old → save new → return, atomic all-or-nothing, rollback on exception         | [Spring Transaction](https://docs.spring.io/spring-framework/reference/data-access/transaction.html)                                                   |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 (45-60 phút mỗi chủ đề)

### Package Structure (auth-service)

```
services/auth-service/src/main/java/com/wms/auth/
├── screens/
│   ├── S02-session/
│   │   ├── controller/SessionController.java
│   │   ├── dto/RefreshRequest.java, TokenPairResponse.java
│   │   ├── service/
│   │   │   ├── RefreshTokenService.java (Port)
│   │   │   └── impl/RefreshTokenServiceImpl.java
│   │   ├── repository/
│   │   │   └── RefreshTokenRepository.java (Port)
│   │   └── db/jpa/
│   │       └── RefreshTokenEntity.java
│   └── S01-login/ (cập nhật login trả refresh token)
├── common/security/
│   ├── CurrentUser.java
│   ├── UserPrincipal.java
│   └── AuthorizationService.java
└── config/
    ├── SecurityConfig.java (Resource Server)
    ├── RsaKeyConfig.java
    └── JwtDecoderConfig.java
```

**Mỗi service khác** cũng có `common/security/` tương tự để extract principal và check authorization.

### Tasks

- [ ] Tạo `RefreshTokenEntity` trong `screens/S02-session/db/jpa/`:
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
- [ ] Tạo `RefreshTokenRepository` Port trong `screens/S02-session/repository/`
- [ ] Implement `RefreshTokenServiceImpl` trong `screens/S02-session/service/impl/`:
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
      // ... rotation logic
  }
  ```
- [ ] Implement logout (revoke current) và logout-all (revoke all user tokens)
- [ ] Flyway migration `V2__create_refresh_tokens.sql` trong `resources/db/migration/`
- [ ] Unit test: rotation success, reuse detection revokes family, expired token, logout revokes

### Tiêu chí chấp nhận

- [ ] Refresh token opaque (random 32 bytes), chỉ lưu SHA-256 hash
- [ ] Rotation: old token revoked, new token issued, `replaced_by_jti` link
- [ ] Reuse detection: dùng token cũ → revoke toàn family, throw 401
- [ ] Logout: revoke current token family
- [ ] Logout-all: revoke all user tokens
- [ ] Token expiry 7 days

### Sau khi hoàn thành phải hiểu

Giải thích được: opaque vs JWT refresh token, rotation security benefit, reuse detection mechanism, token family chain, transaction boundary.

- Entity ở `screens/S02-session/db/jpa/` (Adapter)
- Repository Port ở `screens/S02-session/repository/`
- Service Port + impl ở `screens/S02-session/service/`

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

- RefreshTokenEntity ở `screens/S02-session/db/jpa/`
- RefreshTokenRepository ở `screens/S02-session/repository/`
- RefreshTokenService Port + impl ở `screens/S02-session/service/`
- Reuse detection revoke family
- Logout / logout-all
- Flyway migration
- Unit test cover all cases

---

## Day 13 — RBAC & Resource Ownership Authorization

### Mục tiêu

Áp dụng Role-Based Access Control (RBAC) và resource ownership authorization tại service layer.

### Kiến thức cần đọc trước (Study Tasks Day 13)

| # | Chủ đề                                     | Cụ thể cần nắm                                                                                                                                                                                                            | Link học                                                                                                                                                                                 |
| - | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **RBAC Core**                           | Role hierarchy (`SUPER_ADMIN > ADMIN > WAREHOUSE_MANAGER > STAFF > VIEWER`), `GrantedAuthority` (`ROLE_` prefix), `Authentication.getAuthorities()`, role-based access                                                | [Spring Security RBAC](https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html)                                                                |
| 2 | **Method Security (`@PreAuthorize`)** | `@EnableMethodSecurity(prePostEnabled=true)`, SpEL expressions: `hasRole()`, `hasAuthority()`, `#id == principal.id`, `@authorizationService.canAccessWarehouse(#warehouseId)`, `@PostAuthorize`, `@PostFilter` | [Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html)                                                                             |
| 3 | **SpEL (Spring Expression Language)**   | Root objects:`principal`, `authentication`, `#root`, method calls on beans (`@beanName.method()`), projection, ternary operator                                                                                       | [SpEL Reference](https://docs.spring.io/spring-framework/reference/core/expressions.html)                                                                                                  |
| 4 | **Resource Ownership**                  | User chỉ truy cập resource của mình (`principal.id == resource.userId`), ADMIN bypass, warehouse-scoped permission (user-warehouse assignment), `@PreAuthorize("@authz.canAccessWarehouse(#warehouseId)")`            | [Resource-Based Authorization](https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html#authorization-websecurity-expression-accesscontrollist) |
| 5 | **Custom PermissionEvaluator**          | `implements PermissionEvaluator`, `hasPermission(auth, target, permission)`, register bean, use trong SpEL: `hasPermission(#order, 'CANCEL')`                                                                           | [PermissionEvaluator](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html#method-security-permissionevaluator)                                     |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 (45-60 phút mỗi chủ đề)

### Package Structure (cross-service, config ở common)

```
services/<each-service>/src/main/java/com/wms/<service>/
├── config/
│   └── MethodSecurityConfig.java (@EnableMethodSecurity)
├── common/
│   ├── security/
│   │   ├── CurrentUser.java (extract Principal)
│   │   ├── UserPrincipal.java (JWT claims mapping)
│   │   └── AuthorizationService.java (check permissions)
│   └── exception/AccessDeniedException.java
```

### Tasks

- [ ] Cấu hình `MethodSecurityConfig` trong mỗi service: `@EnableMethodSecurity(prePostEnabled = true)`
- [ ] Tạo `UserPrincipal` record trong `common/security/` implement `UserDetails`:
  ```java
  public record UserPrincipal(Long userId, String username, String email, Role role, Set<String> scopes) 
      implements UserDetails { ... }
  ```
- [ ] Tạo `CurrentUser` helper trong `common/security/` extract từ `SecurityContextHolder`
- [ ] Tạo `AuthorizationService` trong `common/security/` check permissions:
  ```java
  @Service @RequiredArgsConstructor
  public class AuthorizationService {
      public void requireRole(Role... allowed) { ... }
      public void requireOwnershipOrAdmin(Long resourceUserId) { ... }
      public boolean canAccessWarehouse(Long warehouseId) { ... }
  }
  ```
- [ ] Áp dụng `@PreAuthorize` trên **Service impl methods** (không phải controller):
  ```java
  // Trong ProductCommandServiceImpl
  @PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")
  public void deleteProduct(Long id) { ... }

  // Trong InventoryCommandServiceImpl
  @PreAuthorize("hasRole('WAREHOUSE_MANAGER') and @authorizationService.canAccessWarehouse(#warehouseId)")
  public void adjustInventory(Long warehouseId, ...) { ... }
  ```
- [ ] Tạo `WarehouseAssignment` entity trong `inventory-service/screens/S07-warehouse-zone/db/jpa/`
- [ ] Integration test: 403 khi role thiếu, 403 khi không owner, 200 khi đúng quyền
- [ ] Unit test `AuthorizationService` với mock `SecurityContext`

### Tiêu chí chấp nhận

- [ ] `@PreAuthorize` trên **Service impl layer** (Use Case boundary)
- [ ] Role hierarchy: SUPER_ADMIN > ADMIN > WAREHOUSE_MANAGER > STAFF > VIEWER
- [ ] Ownership check: user chỉ sửa resource của mình (trừ ADMIN)
- [ ] Warehouse-scoped permission (cho Inventory Service)
- [ ] 403 response format chuẩn: `{code: "FORBIDDEN", message: "..."}`

### Sau khi hoàn thành phải hiểu

Giải thích được: RBAC vs ABAC, `@PreAuthorize` SpEL expressions, `SecurityContextHolder` thread-local, method security vs web security, custom permission evaluator.

- `AuthorizationService` ở `common/security/` (shared kernel)
- `@PreAuthorize` trên **Service impl** (Use Case layer), không phải Controller
- SpEL expression có thể call Spring bean: `@authorizationService.canAccessWarehouse(#warehouseId)`

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

- MethodSecurityConfig enable prePost (mỗi service)
- UserPrincipal từ JWT claims (`common/security/`)
- AuthorizationService check role/ownership (`common/security/`)
- @PreAuthorize trên Service impl methods
- Integration test 403 cases

---

## Day 14 — Transaction, Concurrency Control, Optimistic/Pessimistic Locking

### Mục tiêu

Đảm bảo mutation inventory an toàn: không lost update, không negative stock, ACID transaction.

### Kiến thức cần đọc trước (Study Tasks Day 14)

| # | Chủ đề                                   | Cụ thể cần nắm                                                                                                                                                                                                                        | Link học                                                                                                                                                  |
| - | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **ACID & Transaction Basics**         | Atomicity, Consistency, Isolation, Durability,`@Transactional` propagation (`REQUIRED`, `REQUIRES_NEW`, `NESTED`, `MANDATORY`, `SUPPORTS`, `NOT_SUPPORTED`, `NEVER`), rollback rules (`rollbackFor`, `noRollbackFor`) | [Spring Transaction](https://docs.spring.io/spring-framework/reference/data-access/transaction.html#transaction-declarative)                                |
| 2 | **Isolation Levels**                  | `READ_UNCOMMITTED`, `READ_COMMITTED` (default PG), `REPEATABLE_READ`, `SERIALIZABLE`, phantom read, non-repeatable read, dirty read, `@Transactional(isolation = Isolation.READ_COMMITTED)`                                     | [Isolation Levels](https://www.baeldung.com/spring-transaction-isolation) \| [PostgreSQL Isolation](https://www.postgresql.org/docs/15/transaction-iso.html) |
| 3 | **Lost Update & Concurrency**         | Lost update pattern (read-modify-write), race condition, optimistic vs pessimistic prevention,`@Version` mechanism, `OptimisticLockingFailureException`                                                                               | [Lost Update](https://vladmihalcea.com/lost-update-anomaly/)                                                                                                |
| 4 | **Optimistic Locking (`@Version`)** | Version column (Long/Integer/Timestamp), auto-increment on update,`LockModeType.OPTIMISTIC`, `OptimisticLockingFailureException` → 409, `@OptimisticLocking` annotation                                                            | [Optimistic Locking](https://www.baeldung.com/jpa-optimistic-locking)                                                                                       |
| 5 | **Pessimistic Locking**               | `SELECT FOR UPDATE` (`LockModeType.PESSIMISTIC_WRITE`), `SELECT FOR SHARE` (`LockModeType.PESSIMISTIC_READ`), `JpaRepository.findByIdForUpdate()`, deadlock risk, timeout (`lock_timeout`)                                    | [Pessimistic Locking](https://www.baeldung.com/jpa-pessimistic-locking)                                                                                     |
| 6 | **Deadlock Prevention**               | Consistent lock ordering, lock timeout (`innodb_lock_wait_timeout`), retry logic (`@Retryable`), idempotency key, circuit breaker                                                                                                     | [Deadlock Prevention](https://vladmihalcea.com/how-to-prevent-deadlocks/)                                                                                   |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 (45-60 phút mỗi chủ đề)

### Package Structure (inventory-service)

```
services/inventory-service/src/main/java/com/wms/inventory/
├── screens/
│   ├── S08-inventory-adjust/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── InventoryAdjustService.java (Port)
│   │   │   └── impl/InventoryAdjustServiceImpl.java
│   │   ├── repository/
│   │   │   ├── InventoryRepository.java (Port - JPA)
│   │   │   └── InventoryTransactionRepository.java (Port - JPA)
│   │   └── db/jpa/
│   │       ├── InventoryEntity.java
│   │       ├── InventoryTransactionEntity.java
│   │       └── InventoryId.java (Embeddable)
│   ├── S08-inventory-lookup/
│   └── S08-transaction-history/
├── common/
└── config/
```

### Tasks

- [ ] Tạo `InventoryId` (Embeddable) + `InventoryEntity` trong `screens/S08-inventory-adjust/db/jpa/`:
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
- [ ] Tạo `InventoryRepository` Port trong `screens/S08-inventory-adjust/repository/`:
  ```java
  @Lock(LockModeType.PESSIMISTIC_WRITE) // optional
  Optional<InventoryEntity> findByIdForUpdate(InventoryId id);
  ```
- [ ] Implement `InventoryAdjustServiceImpl` trong `screens/S08-inventory-adjust/service/impl/`:
  ```java
  @Transactional
  public InventoryResponse adjust(AdjustRequest req) {
      InventoryEntity inv = inventoryRepo.findById(new InventoryId(req.productId(), req.warehouseId()))
          .orElseThrow(() -> new NotFoundException("Inventory not found"));

      int available = inv.getQuantity() - inv.getReservedQuantity();
      int nextQty = inv.getQuantity() + req.delta();
      if (nextQty < inv.getReservedQuantity() || nextQty < 0)
          throw new BusinessRuleException("Insufficient available stock");

      inv.setQuantity(nextQty);
      inventoryRepo.save(inv); // @Version check on flush

      txRepo.save(InventoryTransactionEntity.adjustment(req));

      return InventoryResponse.from(inv);
  }
  ```
- [ ] Test concurrency: 2 threads cùng adjust → 1 success, 1 `OptimisticLockingFailureException` → 409
- [ ] Test rollback: exception sau save → verify inventory + transaction KHÔNG persist
- [ ] Flyway migration: thêm `version` column, composite PK

### Tiêu chí chấp nhận

- [ ] `@Version` tăng sau mỗi update thành công
- [ ] Concurrent update → 1 success, 1 409 (OptimisticLockingFailureException)
- [ ] Transaction: adjust + insert history cùng commit/rollback
- [ ] Rollback test: exception giữa transaction → DB unchanged
- [ ] Business rule: nextQty < reservedQty → 422, no persist

### Sau khi hoàn thành phải hiểu

Giải thích được: Optimistic vs Pessimistic locking trade-off, `@Version` mechanism, `@Transactional` propagation/rollback rules, lost update prevention, deadlock avoidance.

- Entity + Embeddable ở `screens/S08-inventory-adjust/db/jpa/` (Adapter)
- Repository Port ở `screens/S08-inventory-adjust/repository/`
- Service Port + impl ở `screens/S08-inventory-adjust/service/`
- `@Transactional` ở Service impl (Command)

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

- InventoryEntity + InventoryId ở `screens/S08-inventory-adjust/db/jpa/`
- InventoryRepository Port ở `screens/S08-inventory-adjust/repository/`
- InventoryAdjustService Port + impl ở `screens/S08-inventory-adjust/service/`
- Concurrent test: 1 success, 1 409
- Rollback test pass
- Flyway migration version column

---

## Day 15 — Order Service & Inventory Workflow (Saga Pattern)

### Mục tiêu

Tạo Order, confirm/cancel với state machine, gọi Inventory Service reserve/release (không distributed transaction).

### Kiến thức cần đọc trước (Study Tasks Day 15)

| # | Chủ đề                              | Cụ thể cần nắm                                                                                                                                                                 | Link học                                                                                                                                                         |
| - | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Saga Pattern (Orchestration)** | Orchestrator coordinates local transactions, each step has compensating action, state machine drives flow, no distributed transaction (2PC)                                        | [Saga Pattern](https://microservices.io/patterns/data/saga.html) \| [Saga Orchestration](https://www.baeldung.com/saga-pattern-microservices)                       |
| 2 | **State Machine**                | Order states:`PENDING → CONFIRMED → COMPLETED/CANCELLED`, `PENDING → CANCELLED`, `CONFIRMED → CANCELLED` (compensation), valid transitions, `enum` + validation method | [State Machine](https://www.baeldung.com/java-state-machine)                                                                                                       |
| 3 | **Idempotency Key**              | Client-generated UUID, header`Idempotency-Key`, server deduplicate (Redis/DB), store result, retry-safe, 24h TTL                                                                 | [Idempotency](https://www.baeldung.com/spring-idempotency) \| [Stripe Idempotency](https://stripe.com/docs/api/idempotency)                                         |
| 4 | **Outbox Pattern**               | Local transaction: write domain data + outbox event (same DB),`TransactionalEventListener` (AFTER_COMMIT) → publish to RabbitMQ, reliability, no dual-write                     | [Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html) \| [Spring Outbox](https://www.baeldung.com/spring-transactional-event-listener) |
| 5 | **Compensating Transaction**     | Rollback logic for each step: cancel → release inventory,`OrderCancelService` calls `InventoryClient.release()`, handle partial failure, manual intervention queue            | [Compensating Transaction](https://microservices.io/patterns/data/compensating-transaction.html)                                                                   |
| 6 | **Circuit Breaker & Timeout**    | `Resilience4j` / `Spring Retry`, `@CircuitBreaker`, `@Retry`, `@TimeLimiter`, fallback, bulkhead, `WebClient` timeout config                                           | [Resilience4j](https://resilience4j.readme.io/docs/getting-started) \| [Spring Retry](https://docs.spring.io/spring-framework/reference/integration/retry.html)     |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 (45-60 phút mỗi chủ đề)

### Package Structure (order-service)

```
services/order-service/src/main/java/com/wms/order/
├── screens/
│   ├── S09-order-create/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── OrderCommandService.java (Port)
│   │   │   └── impl/OrderCommandServiceImpl.java
│   │   ├── repository/
│   │   │   ├── OrderRepository.java (Port)
│   │   │   └── OrderItemRepository.java (Port)
│   │   └── db/jpa/
│   │       ├── OrderEntity.java
│   │       └── OrderItemEntity.java
│   ├── S09-order-confirm/
│   ├── S09-order-cancel/
│   └── S09-order-list/
├── client/
│   └── InventoryClient.java (WebClient Port)
├── event/
│   └── OutboxEvent.java
├── common/
└── config/
```

### Tasks

- [ ] Tạo `OrderEntity`, `OrderItemEntity` trong `screens/S09-order-create/db/jpa/`:
  ```java
  @Entity @Table(name = "orders")
  public class OrderEntity {
      @Id @GeneratedValue private UUID id;
      @Column(name = "order_no", nullable = false, unique = true, length = 50) private String orderNo;
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private OrderType type;
      @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20) private OrderStatus status;
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
- [ ] `OrderRepository` Port trong `screens/S09-order-create/repository/`
- [ ] Implement `OrderCommandServiceImpl` trong `screens/S09-order-create/service/impl/`:
  ```java
  @Transactional
  public OrderResponse create(CreateOrderRequest req, UUID userId) {
      List<PricedItem> priced = productClient.getPrices(req.items());
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
          ReserveRequest reserveReq = buildReserveRequest(order, idempotencyKey);
          ReserveResponse reserveResp = inventoryClient.reserve(reserveReq);

          if (!reserveResp.success()) {
              order.markFailed(reserveResp.error());
              throw new BusinessRuleException("Insufficient stock");
          }
      }

      order.confirm();
      outboxRepo.save(new OutboxEvent("order.confirmed", orderId, ...));
      return OrderResponse.from(order);
  }
  ```
- [ ] `InventoryClient` (WebClient Port) trong `client/` với retry, timeout, circuit breaker
- [ ] Idempotency: `idempotencyKey` header, Inventory Service check duplicate
- [ ] Outbox pattern: `OutboxEvent` table, `OutboxPublisher` (TransactionalEventListener hoặc scheduled)
- [ ] Compensation: cancel confirmed order → call Inventory release
- [ ] Integration test: create→confirm success, confirm insufficient stock → FAILED, cancel confirmed → release inventory

### Tiêu chí chấp nhận

- [ ] Order created PENDING with items, total from Product Service
- [ ] Confirm OUTBOUND → calls Inventory reserve, success → CONFIRMED
- [ ] Confirm insufficient stock → order FAILED, no partial persist
- [ ] Cancel CONFIRMED → calls Inventory release, order CANCELLED
- [ ] Idempotency key prevents duplicate reserve
- [ ] Outbox event published after commit
- [ ] No direct Inventory DB access from Order Service

### Sau khi hoàn thành phải hiểu

Giải thích được: Saga orchestration vs choreography, idempotency key design, outbox pattern reliability, compensating transaction, circuit breaker for cross-service calls.

- Entity ở `screens/S09-order-create/db/jpa/` (Adapter)
- Repository Port ở `screens/S09-order-create/repository/`
- Service Port + impl ở `screens/S09-order-create/service/`
- InventoryClient Port ở `client/` (Outbound adapter)
- OutboxEvent ở `event/` (Infrastructure)

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

- OrderEntity, OrderItemEntity ở `screens/S09-order-create/db/jpa/`
- OrderRepository Port ở `screens/S09-order-create/repository/`
- OrderCommandService Port + impl ở `screens/S09-order-create/service/`
- InventoryClient WebClient Port ở `client/`
- Idempotency key implementation
- OutboxEvent + publisher
- Integration test full workflow

---

## Day 16 — Redis cache-aside

### Mục tiêu

Cache read-heavy API mà không biến Redis thành nguồn dữ liệu chuẩn.

### Kiến thức cần đọc trước (Study Tasks Day 16)

| # | Chủ đề                           | Cụ thể cần nắm                                                                                                                                                                               | Link học                                                                                                                                                                         |
| - | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Cache-Aside Pattern**       | Application quản lý cache: read → check cache → miss → load DB → put cache → return; write → update DB → invalidate cache; không dùng read-through/write-through                      | [Cache-Aside](https://docs.microsoft.com/en-us/azure/architecture/patterns/cache-aside) \| [Spring Cache](https://docs.spring.io/spring-framework/reference/integration/cache.html) |
| 2 | **Redis & Spring Data Redis** | `RedisTemplate`/`StringRedisTemplate`, `RedisConnectionFactory`, serialization (Jackson2JsonRedisSerializer), `@EnableCaching`, `@Cacheable`/`@CachePut`/`@CacheEvict`, TTL config | [Spring Data Redis](https://docs.spring.io/spring-data/redis/reference/)                                                                                                           |
| 3 | **Cache Key Design**          | Key format:`prefix:{entity}:{id}` (e.g., `product:123`), composite key cho query, namespace separation, key length limits, hash tags cho cluster                                             | [Cache Key Design](https://redis.io/docs/latest/develop/use/keyspace/)                                                                                                             |
| 4 | **TTL & Expiration**          | `expire` vs `pexpire`, random TTL (±10%) để tránh thundering herd, passive vs active expiration, `maxmemory-policy` (allkeys-lru, volatile-lru)                                        | [Redis Expiration](https://redis.io/docs/latest/operate/oss_and_stack/management/expiration/)                                                                                      |
| 5 | **Serialization**             | JSON (Jackson), Protobuf, Kryo;`@JsonSerialize`/`@JsonDeserialize`, generic type handling, versioning                                                                                        | [Redis Serialization](https://docs.spring.io/spring-data/redis/reference/redis/serializers.html)                                                                                   |
| 6 | **Cache Miss & Fallback**     | Cache miss → load DB → populate cache, circuit breaker khi Redis down (`@Cacheable` fallback), `RedisConnectionFailureException` handling                                                  | [Spring Cache Fallback](https://www.baeldung.com/spring-cache-fallback)                                                                                                            |

**Thứ tự học:** 1 → 2 → 3 → 4 → 5 → 6 (45-60 phút mỗi chủ đề)

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

### Mục tiêu

Giữ cache nhất quán sau mutation và hiểu giới hạn tốc độ.

### Kiến thức cần đọc trước (Study Tasks Day 17)

| # | Chủ đề                                  | Cụ thể cần nắm                                                                                                                                                           | Link học                                                                                        |
| - | ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| 1 | **Cache Invalidation Strategies**    | Write-through (update cache + DB), Write-behind (async), Invalidate-on-write (delete cache key), Read-through, hybrid approaches                                             | [Cache Invalidation](https://www.baeldung.com/spring-cache-invalidation)                          |
| 2 | **Transactional Invalidation**       | `@CacheEvict` trong `@Transactional`, `TransactionalEventListener` (AFTER_COMMIT) để xóa cache sau commit, rollback không invalidate, avoid dual-write             | [Spring Transactional Cache](https://www.baeldung.com/spring-cache-transactional)                 |
| 3 | **Cache Stampede (Thundering Herd)** | Nhiều request cùng miss \u2192 cùng load DB, giải pháp: random TTL jitter,`SETNX` lock (Redis), `CompletableFuture` memoization, `StampedLock`                    | [Cache Stampede](https://www.baeldung.com/cache-stampede)                                         |
| 4 | **Rate Limiting**                    | Token Bucket (Redis`INCR` + TTL), Leaky Bucket, Sliding Window Log, Spring Cloud Gateway `RequestRateLimiter`, `RedisRateLimiter`, per-user/IP/API                     | [Rate Limiting](https://www.baeldung.com/spring-cloud-gateway-rate-limiting)                      |
| 5 | **Distributed Lock (Redisson)**      | `RLock` (Redisson), `tryLock(timeout)`, `lock()`, `unlock()`, watchdog, lock expiration, không dùng lock thay DB constraint (race condition vẫn có thể xảy ra) | [Redisson Lock](https://github.com/redisson/redisson/wiki/8.-Distributed-locks-and-synchronizers) |

**Thứ tự học:** 1 \u2192 2 \u2192 3 \u2192 4 \u2192 5 (45-60 phút mỗi chủ đề)

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

### Mục tiêu

Gửi domain event và nhận event bằng Notification Service.

### Kiến thức cần đọc trước (Study Tasks Day 18)

| # | Chủ đề                              | Cụ thể cần nắm                                                                                                                                                                                      | Link học                                                                                                                 |
| - | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1 | **RabbitMQ Core Concepts**       | Exchange (direct, topic, fanout, headers), Queue, Binding, Routing Key, Message, Publisher, Consumer, Virtual Host, Connection/Channel                                                                  | [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html) \| [RabbitMQ Concepts](https://www.rabbitmq.com/docs/queues) |
| 2 | **Exchange Types**               | Direct (exact match), Topic (wildcard`*.`), Fanout (broadcast), Headers (header match), Dead Letter Exchange (DLX)                                                                                    | [Exchange Types](https://www.rabbitmq.com/docs/exchanges)                                                                  |
| 3 | **Message Properties & Headers** | `deliveryMode` (persistent=2), `contentType`, `correlationId`, `messageId`, `timestamp`, `expiration`, custom headers (`x-correlation-id`), `replyTo`                                   | [Message Properties](https://www.rabbitmq.com/docs/publishers)                                                             |
| 4 | **Spring AMQP & RabbitTemplate** | `RabbitTemplate` (sendAndReceive, convertAndSend), `MessageConverter` (Jackson2JsonMessageConverter), `ConfirmCallback` (publisher confirms), `ReturnCallback` (mandatory), `CorrelationData` | [Spring AMQP](https://docs.spring.io/spring-amqp/reference/html/)                                                          |
| 5 | **Consumer & Manual ACK**        | `@RabbitListener`, `Acknowledgment` interface, `channel.basicAck(deliveryTag, false)`, `basicNack(requeue=false)` \u2192 DLQ, `channel.basicQos(prefetchCount)`, error handling               | [Spring RabbitMQ Consumer](https://docs.spring.io/spring-amqp/reference/html/#receive)                                     |

**Thứ tự học:** 1 \u2192 2 \u2192 3 \u2192 4 \u2192 5 (45-60 phút mỗi chủ đề)

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

### Mục tiêu

Xử lý delivery at-least-once an toàn.

### Kiến thức cần đọc trước (Study Tasks Day 19)

| # | Chủ đề                                          | Cụ thể cần nắm                                                                                                                                                 | Link học                                                                               |
| - | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- |
| 1 | **At-Least-Once Delivery**                   | RabbitMQ default: at-least-once, publisher confirms + consumer manual ACK, duplicate messages possible, cần idempotency                                           | [RabbitMQ Reliability](https://www.rabbitmq.com/docs/reliability)                        |
| 2 | **Retry & Backoff**                          | `spring-retry` + `@Retryable`, exponential backoff (`@Backoff(delay=1000, multiplier=2)`), max attempts, `RetryListener`, `Recover` method               | [Spring Retry](https://docs.spring.io/spring-framework/reference/integration/retry.html) |
| 3 | **Dead Letter Exchange (DLX) & Queue (DLQ)** | `x-dead-letter-exchange`, `x-dead-letter-routing-key`, TTL-based DLQ, `x-message-ttl`, max length, DLQ monitoring                                            | [RabbitMQ DLX](https://www.rabbitmq.com/docs/dlx)                                        |
| 4 | **Idempotency Key**                          | Event`eventId` (UUID) làm key, store processed IDs (Redis SET / DB unique constraint), check before process, TTL 24h, atomic `SETNX`                          | [Idempotency](https://www.baeldung.com/spring-idempotency)                               |
| 5 | **Consumer Idempotency Pattern**             | Check idempotency key \u2192 process \u2192 store result \u2192 ACK; nếu crash giữa process/store \u2192 redeliver \u2192 check key exists \u2192 skip duplicate | [Consumer Idempotency](https://www.rabbitmq.com/docs/consumer-acknowledgements)          |

**Thứ tự học:** 1 \u2192 2 \u2192 3 \u2192 4 \u2192 5 (45-60 phút mỗi chủ đề)

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

### Mục tiêu

Persist notification từ domain event và cung cấp API cho user.

### Kiến thức cần đọc trước (Study Tasks Day 20)

| # | Chủ đề                                     | Cụ thể cần nắm                                                                                                                                                                          | Link học                                                                                                      |
| - | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| 1 | **Event-Driven Architecture**           | Event producer -> broker -> consumer, loose coupling, async, eventual consistency, event schema evolution, schema registry (optional)                                                       | [Event-Driven](https://microservices.io/patterns/data/event-driven-architecture.html)                           |
| 2 | **Eventual Consistency**                | BASE vs ACID, read-your-writes consistency, conflict resolution, saga vs event sourcing, compensation                                                                                       | [Eventual Consistency](https://www.baeldung.com/eventual-consistency)                                           |
| 3 | **Consumer Idempotency**                | Unique constraint`(event_id, user_id)`, `ON CONFLICT DO NOTHING`, atomic insert, Redis SETNX alternative, exactly-once semantics                                                        | [Idempotent Consumer](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html) |
| 4 | **Notification Inbox Pattern**          | User-centric notification store, per-user partitioning, read/unread status, mark-read idempotent, pagination, TTL/archive old notifications                                                 | [Notification Inbox](https://www.baeldung.com/spring-notification-inbox)                                        |
| 5 | **RabbitMQ Consumer for Notifications** | Multiple queues (`warehouse.events.order`, `warehouse.events.inventory`, `warehouse.events.shipment`), `@RabbitListener` per queue, shared `NotificationEventHandler`, manual ACK | [Spring RabbitMQ Multi-queue](https://docs.spring.io/spring-amqp/reference/html/#receive)                       |

**Thứ tự học:** 1 \u2192 2 \u2192 3 \u2192 4 \u2192 5 (45-60 phút mỗi chủ đề)

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

### Mục tiêu

Định tuyến API mà không biến Gateway thành nơi chứa nghiệp vụ/domain data.

### Kiến thức cần đọc trước

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

### Mục tiêu

Kiểm tra business rule bằng unit test nhanh, không cần DB.

### Kiến thức cần đọc trước

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

### Mục tiêu

Mock phụ thuộc ngoài để kiểm tra service/use case độc lập.

### Kiến thức cần đọc trước

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

### Mục tiêu

Kiểm tra luồng HTTP qua controller, validation, service và PostgreSQL.

### Kiến thức cần đọc trước

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

### Mục tiêu

Kiểm tra các adapter hạ tầng và security qua luồng tích hợp.

### Kiến thức cần đọc trước

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

### Mục tiêu

Đo và tối ưu truy vấn thực tế thay vì thêm index theo cảm tính.

### Kiến thức cần đọc trước

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

### Mục tiêu

Đóng gói service WAR cùng Tomcat và kiểm tra runtime giống deployment.

### Kiến thức cần đọc trước

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

### Mục tiêu

Tạo pipeline tự động checkout, test, đóng gói và lưu artifact.

### Kiến thức cần đọc trước

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

### Mục tiêu

Triển khai artifact đã build lên DEV, xác minh và có đường rollback.

### Kiến thức cần đọc trước

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

### Mục tiêu

Chứng minh luồng end-to-end từ đăng nhập tới order, tồn kho, event, notification và deployment.

### Kiến thức cần đọc trước

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

---

## Phụ lục A: Cross-Cutting Authentication & Authorization Reference

*Tham chiếu nhanh cho toàn bộ 30 ngày - áp dụng cho mọi service*

### A.1. Kiến trúc xác thực tổng quan

```
Client → Auth Service (Login) → Access Token (RS256, 15min) + Refresh Token (Opaque, 7 days)
         ↓
    API Gateway (Validate JWT, set headers X-User-Id, X-Role)
         ↓
    Target Service (Validate JWT again, map claims → UserPrincipal)
         ↓
    @PreAuthorize trên Service Impl (Use Case Boundary)
```

### A.2. Token Specifications

| Token | Type | Expiry | Storage | Rotation |
|-------|------|--------|---------|----------|
| Access Token | JWT RS256 | 15 phút | Client (memory) | No (short-lived) |
| Refresh Token | Opaque (random 32 bytes) | 7 ngày | DB (SHA-256 hash) | Yes (revoke old, issue new) |

**Access Token Claims:**
```json
{
  "iss": "auth-service",
  "sub": "123",
  "username": "admin",
  "email": "admin@example.com",
  "role": "ADMIN",
  "scope": "read write",
  "iat": 1234567890,
  "exp": 1234568790,
  "jti": "uuid-v4"
}
```

### A.3. Security Configuration Checklist (Mỗi Service)

```java
// 1. SecurityConfig.java - Resource Server
@Bean
SecurityFilterChain filterChain(HttpSecurity http) {
    return http
        .csrf(csrf -> csrf.disable())
        .sessionManagement(sm -> sm.sessionCreationPolicy(STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/auth/**", "/.well-known/jwks.json", "/actuator/health").permitAll()
            .anyRequest().authenticated())
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter())))
        .build();
}

// 2. JwtAuthenticationConverter.java - Map JWT claims → UserPrincipal
@Component
public class JwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> { ... }

// 3. MethodSecurityConfig.java - Enable @PreAuthorize
@EnableMethodSecurity(prePostEnabled = true, securedEnabled = true)
public class MethodSecurityConfig {}

// 4. CurrentUser.java - ThreadLocal helper
@Component
public class CurrentUser {
    public static UserPrincipal get() {
        return (UserPrincipal) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
    }
}

// 5. UserPrincipal.java - implements UserDetails
public record UserPrincipal(Long userId, String username, String email, Role role, Set<String> scopes) implements UserDetails { ... }

// 6. AuthorizationService.java - Shared kernel
@Service @RequiredArgsConstructor
public class AuthorizationService {
    public void requireRole(Role... allowed) { ... }
    public boolean canAccessWarehouse(Long warehouseId) { ... } // Check user-warehouse assignment
}
```

### A.4. @PreAuthorize Patterns (Use Case Boundary)

```java
// Role-based
@PreAuthorize("hasRole('ADMIN') or hasRole('SUPER_ADMIN')")
public ProductResponse create(CreateProductRequest request) { ... }

// Role + Custom PermissionEvaluator (SpEL call Spring bean)
@PreAuthorize("hasRole('WAREHOUSE_MANAGER') and @authorizationService.canAccessWarehouse(#warehouseId)")
public InventoryResponse adjust(AdjustInventoryRequest request) { ... }

// Ownership check
@PreAuthorize("#userId == authentication.principal.userId or hasRole('ADMIN')")
public OrderResponse cancel(UUID orderId, UUID userId) { ... }
```

### A.5. Service-to-Service Communication Security

```java
// WebClient with forwarded identity headers
@Component @RequiredArgsConstructor
public class WebClientInventoryClient implements InventoryClient {
    private final WebClient webClient;
    
    public ReserveResponse reserve(ReserveRequest req) {
        return webClient.post()
            .uri("/api/v1/inventory/reserve")
            .header("Idempotency-Key", req.idempotencyKey())
            .header("X-User-Id", CurrentUser.get().userId().toString())
            .header("X-Role", CurrentUser.get().role().name())
            .header("X-Correlation-ID", MDC.get("traceId"))
            .bodyValue(req)
            .retrieve()
            .onStatus(HttpStatus::is4xxClientError, r -> r.bodyToMono(String.class).map(InventoryServiceException::new))
            .onStatus(HttpStatus::is5xxServerError, r -> r.bodyToMono(String.class).map(InventoryServiceException::new))
            .bodyToMono(ReserveResponse.class)
            .block();
    }
}
```

**Headers bắt buộc forward:**
| Header | Value | Purpose |
|--------|-------|---------|
| `Idempotency-Key` | UUID | Deduplication cross-service |
| `X-User-Id` | Long | Authorization context |
| `X-Role` | String | Role-based access |
| `X-Correlation-ID` | String | Distributed tracing |

### A.6. Circuit Breaker Config (Resilience4j)

```yaml
resilience4j:
  circuitbreaker:
    instances:
      inventoryService:
        slidingWindowSize: 10
        minimumNumberOfCalls: 5
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
  retry:
    instances:
      inventoryService:
        maxAttempts: 3
        waitDuration: 500ms
        enableExponentialBackoff: true
        exponentialBackoffMultiplier: 2
```

```java
@CircuitBreaker(name = "inventoryService", fallbackMethod = "reserveFallback")
@Retry(name = "inventoryService")
public ReserveResponse reserve(ReserveRequest req) { ... }
```

### A.7. Error Response Format (RFC 7807)

```json
{
  "code": "FORBIDDEN",
  "message": "Insufficient role: requires ADMIN",
  "timestamp": "2026-09-30T10:30:00Z",
  "traceId": "abc-123-def",
  "errors": null
}
```

| Code | HTTP Status | When |
|------|-------------|------|
| `VALIDATION_ERROR` | 400 | @Valid failed |
| `UNAUTHORIZED` | 401 | Missing/invalid/expired token |
| `FORBIDDEN` | 403 | Role/ownership check failed |
| `NOT_FOUND` | 404 | Resource not found |
| `CONFLICT` | 409 | Duplicate key, optimistic lock |
| `BUSINESS_RULE_VIOLATION` | 422 | Business logic violation |
| `INTERNAL_ERROR` | 500 | Unexpected error |

### A.8. Quick Reference: Day-to-Day Security Tasks

| Day | Security Focus | Key Deliverable |
|-----|---------------|-----------------|
| 1-2 | Project setup | SecurityConfig, JwtAuthenticationConverter, CurrentUser |
| 3-4 | API Contract | @Valid, GlobalExceptionHandler, ProblemDetail |
| 5-7 | Data Layer | UserEntity, PasswordEncoder, JPA Auditing |
| 8-9 | Search/Query | MyBatis, Sort Whitelist, SQL Injection Prevention |
| 10-12 | Auth Core | BCrypt, JWT RS256, JWKS, Refresh Rotation, Reuse Detection |
| 13 | Authorization | @EnableMethodSecurity, @PreAuthorize, AuthorizationService |
| 14 | Concurrency | @Version, Optimistic Locking, @Transactional |
| 15 | Saga | Idempotency Key, Outbox Pattern, Compensating Transaction |
| 16-17 | Cache | @Cacheable, @CacheEvict (AFTER_COMMIT), Rate Limiting |
| 18-20 | Messaging | RabbitMQ, Manual ACK, Idempotent Consumer, DLQ |
| 21 | Gateway | Route Config, JWT Validation, Header Forwarding |
| 22-25 | Testing | @MockMvc, @SpringBootTest, Testcontainers, Security Test |
| 26 | Performance | EXPLAIN ANALYZE, Index, Connection Pool |
| 27-29 | Deploy | Docker WAR, Tomcat 10.1, Jenkins CI/CD |
| 30 | E2E Demo | Login → Order → Inventory → Event → Notification |

### A.9. Security Testing Checklist

```java
// Unit Test - AuthorizationService
@Test
void canAccessWarehouse_admin_returnsTrue() {
    // given
    UserPrincipal admin = new UserPrincipal(1L, "admin", "a@b.com", Role.ADMIN, Set.of());
    mockStatic(CurrentUser.class).when(CurrentUser::get).thenReturn(admin);
    
    // when
    boolean result = authz.canAccessWarehouse(1L);
    
    // then
    assertTrue(result);
}

// Integration Test - @PreAuthorize
@Test
@WithMockUser(roles = "WAREHOUSE_MANAGER")
void adjustInventory_warehouseManager_canAccess() {
    // given
    given(authz.canAccessWarehouse(1L)).willReturn(true);
    
    // when/then
    mockMvc.post("/api/v1/inventory/adjust")
        .header("Authorization", "Bearer " + token)
        .contentType(JSON)
        .content(body)
        .andExpect(status().isOk());
}

// Integration Test - 403 Forbidden
@Test
@WithMockUser(roles = "STAFF")
void adjustInventory_staff_cannotAccess() {
    mockMvc.post("/api/v1/inventory/adjust")
        .header("Authorization", "Bearer " + token)
        .contentType(JSON)
        .content(body)
        .andExpect(status().isForbidden())
        .andExpect(jsonPath("$.code").value("FORBIDDEN"));
}
```

### A.10. Production Security Hardening

| Area | Recommendation |
|------|----------------|
| **Keys** | RSA keys từ Vault/KMS, không commit file `.pem`, key rotation 90 ngày |
| **HTTPS** | Gateway terminate TLS 1.3, service-to-service mTLS (optional) |
| **Rate Limit** | `/api/auth/login` max 5 req/min/IP, burst 10 |
| **Audit Log** | Log login/logout/failed attempts với correlation ID, userId, IP |
| **CORS** | Chỉ allow frontend domain, no `*` |
| **Headers** | `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Content-Security-Policy` |
| **Secrets** | Không hardcode, dùng Spring Cloud Config / Vault, rotate định kỳ |

---

*End of 30-Day Plan - Phụ lục A cung cấp tham chiếu bảo mật xuyên suốt cho toàn bộ lộ trình.*
