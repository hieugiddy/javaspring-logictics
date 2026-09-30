# product-service

## 1. Vai trò

Quản lý catalog: `categories` và `products`.

```mermaid
flowchart LR
  C[Client] --> G[Gateway :8080]
  G --> PC[ProductController]
  PC --> PS[ProductQueryService / ProductCommandService]
  PS --> PR[ProductRepository (JPA) / ProductQueryMapper (MyBatis)]
  PR --> DB[(product_db\ncategories\nproducts)]
```

## 2. Thư viện

WebMVC, Validation, Security, OAuth2 Resource Server/JOSE, JPA/Hibernate, MyBatis, PostgreSQL, Flyway, Actuator, Test.

## 3. Source hiện tại

```text
product-service/
├── build.gradle
└── src/main
    ├── java/com/wms/product
    │   ├── ProductApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

Đây là skeleton. Khi code nghiệp vụ, dùng cấu trúc **Port/Adapter theo màn hình/use case**:

```text
com.wms.product
├── config/
│   ├── SecurityConfig.java
│   ├── MyBatisConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S05-category/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── CategoryQueryService.java (Port)
│   │   │   ├── CategoryCommandService.java (Port)
│   │   │   └── impl/
│   │   ├── repository/
│   │   │   └── CategoryRepository.java (Port - JPA)
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
│   │   │   ├── ProductQueryService.java (Port)
│   │   │   ├── ProductCommandService.java (Port)
│   │   │   └── impl/
│   │   │       ├── ProductQueryServiceImpl.java
│   │   │       └── ProductCommandServiceImpl.java
│   │   ├── repository/ (Port interfaces)
│   │   │   ├── ProductRepository.java (JPA Port)
│   │   │   └── ProductQueryMapper.java (MyBatis Port)
│   │   └── db/ (Adapter implementations)
│   │       ├── jpa/
│   │       │   ├── ProductEntity.java
│   │       │   └── CategoryEntity.java
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
│   ├── filter/
│   │   └── CorrelationIdFilter.java
│   └── validation/
│       └── ValidSkuValidator.java
└── client/ (nếu cần call service khác)
```

## 4. Database

`categories` chứa nhóm sản phẩm; `products` chứa SKU/tên/giá và `category_id` thuộc logical boundary của product service.

## 5. API mục tiêu

```text
GET    /api/v1/categories
GET    /api/v1/categories/{id}
POST   /api/v1/categories
PUT    /api/v1/categories/{id}
DELETE /api/v1/categories/{id}

GET    /api/v1/products
GET    /api/v1/products/{id}
POST   /api/v1/products
PUT    /api/v1/products/{id}
PATCH  /api/v1/products/{id}/status
DELETE /api/v1/products/{id}
```

Các endpoint trên là **thiết kế mục tiêu**, chưa có controller trong source hiện tại.

## 6. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service (Port), KHÔNG inject Repository
- **Service Interface (Port)** định nghĩa use case: `ProductQueryService`, `ProductCommandService`
- **Service Impl (Adapter)** implement Port, inject Repository Port, có `@Transactional`
- **Repository Interface (Port)**: `ProductRepository` (JPA), `ProductQueryMapper` (MyBatis)
- **db/jpa/** chứa JPA Entity (Hibernate Adapter)
- **db/mybatis/** chứa MyBatis XML (MyBatis Adapter)
- **Migration** ở `resources/db/migration/` (shared infrastructure)

## 7. Demo flow

```http
POST http://localhost:8080/api/v1/products
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "sku": "SKU-001",
  "name": "Keyboard",
  "categoryId": "..."
}
```

Luồng:

```text
Client
 -> Gateway JWT validation
 -> ProductController
 -> ProductCommandService (Port)
 -> ProductCommandServiceImpl (Adapter)
 -> ProductRepository (Port) / ProductQueryMapper (Port)
 -> product_db
 -> ProductResponse
 -> Gateway
 -> Client
```

## 8. Cross-service rule

Inventory Service có thể lưu `product_id`, nhưng không JOIN trực tiếp `product_db`. Nếu cần tên sản phẩm, gọi Product API hoặc dùng event/cache phù hợp.

## 9. Chi tiết triển khai màn hình S06-product

### 9.1 Request DTO (trong `screens/S06-product/dto/`)

```java
public record CreateProductRequest(
    @NotBlank @Size(max = 100) @Pattern(regexp = "^[A-Z0-9-]+$") String sku,
    @NotBlank @Size(max = 255) String name,
    @Size(max = 2000) String description,
    @NotNull @DecimalMin("0.00") @Digits(integer = 12, fraction = 2) BigDecimal price,
    Long categoryId,
    @NotNull @Pattern(regexp = "^(ACTIVE|INACTIVE)$") String status
) {}

public record UpdateProductRequest(
    @Size(max = 255) String name,
    @Size(max = 2000) String description,
    @DecimalMin("0.00") @Digits(integer = 12, fraction = 2) BigDecimal price,
    Long categoryId,
    @Pattern(regexp = "^(ACTIVE|INACTIVE)$") String status
) {}
```

### 9.2 Entity (trong `screens/S06-product/db/jpa/`)

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

### 9.3 Repository Port (trong `screens/S06-product/repository/`)

```java
public interface ProductRepository extends JpaRepository<ProductEntity, Long> {
    Optional<ProductEntity> findBySku(String sku);
    Page<ProductEntity> findByCategoryIdAndStatus(Long categoryId, String status, Pageable pageable);
    Page<ProductEntity> findByNameContainingIgnoreCaseAndStatus(String keyword, String status, Pageable pageable);
    boolean existsBySku(String sku);
    
    @EntityGraph(attributePaths = {"category"}, type = EntityGraphType.LOAD)
    Page<ProductEntity> findByCategoryIdAndStatusWithCategory(Long categoryId, String status, Pageable pageable);
}

@Mapper
public interface ProductQueryMapper {
    List<ProductSearchResult> search(ProductSearchCriteria criteria);
    long countSearch(ProductSearchCriteria criteria);
    Optional<ProductDetailResult> findDetailById(Long id);
}
```

### 9.4 Service Port & Impl (trong `screens/S06-product/service/`)

```java
// Port - Query
public interface ProductQueryService {
    ProductResponse findById(Long id);
    ProductListResponse findAll(Pageable pageable);
    ProductListResponse search(ProductSearchCriteria criteria);
}

// Port - Command
public interface ProductCommandService {
    ProductResponse create(CreateProductRequest request);
    ProductResponse update(Long id, UpdateProductRequest request);
    void delete(Long id);
    ProductResponse changeStatus(Long id, String status);
}

// Impl - Query
@Service @RequiredArgsConstructor @Transactional(readOnly = true)
public class ProductQueryServiceImpl implements ProductQueryService {
    private final ProductRepository productRepository;
    private final ProductQueryMapper productQueryMapper;
    
    public ProductResponse findById(Long id) {
        ProductEntity entity = productRepository.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Product not found"));
        return ProductResponse.from(entity);
    }
    
    public ProductListResponse search(ProductSearchCriteria criteria) {
        // validate sortBy whitelist
        // delegate to MyBatis Port
        List<ProductSearchResult> results = productQueryMapper.search(criteria);
        long total = productQueryMapper.countSearch(criteria);
        return ProductListResponse.of(results, criteria.page(), criteria.size(), total);
    }
}

// Impl - Command
@Service @RequiredArgsConstructor
public class ProductCommandServiceImpl implements ProductCommandService {
    private final ProductRepository productRepository;
    private final CategoryRepository categoryRepository;
    
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
}
```

### 9.5 Controller (trong `screens/S06-product/controller/`)

```java
@RestController
@RequestMapping("/api/v1/products")
@RequiredArgsConstructor
public class ProductController {
    private final ProductQueryService productQueryService;
    private final ProductCommandService productCommandService;
    
    @GetMapping
    public ResponseEntity<ProductListResponse> search(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) Long categoryId,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        
        // validate sortBy whitelist
        ProductSearchCriteria criteria = new ProductSearchCriteria(keyword, categoryId, status, page, size, sortBy, sortDir);
        return ResponseEntity.ok(productQueryService.search(criteria));
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<ProductResponse> findById(@PathVariable Long id) {
        return ResponseEntity.ok(productQueryService.findById(id));
    }
    
    @PostMapping
    public ResponseEntity<ProductResponse> create(@Valid @RequestBody CreateProductRequest request) {
        ProductResponse response = productCommandService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<ProductResponse> update(@PathVariable Long id, @Valid @RequestBody UpdateProductRequest request) {
        return ResponseEntity.ok(productCommandService.update(id, request));
    }
    
    @PatchMapping("/{id}/status")
    public ResponseEntity<ProductResponse> changeStatus(@PathVariable Long id, @RequestParam String status) {
        return ResponseEntity.ok(productCommandService.changeStatus(id, status));
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        productCommandService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
```

Controller chỉ bind/validate DTO và gọi Service Port; Service Impl kiểm tra business rule, transaction; Repository Port làm persistence. Response là DTO, không trả Entity trực tiếp.

### 9.6 MyBatis Mapper XML (trong `screens/S06-product/db/mybatis/ProductMapper.xml`)

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

### 9.7 Swagger và test

- Thêm `@Operation`/`@ApiResponse` cho 200, 201, 400, 401, 403, 404, 409, 422.
- Unit test: `ProductQueryServiceImpl` (mock Port), `ProductCommandServiceImpl` (mock Port).
- Integration test (MockMvc): JSON validation, status code, response DTO, JWT.
- Migration không có FK `category_id` mặc định; nếu thêm FK, migration và JPA mapping cập nhật đồng thời.

CSV import/export được đặc tả tại màn hình S06a/S06b trong `README_SCREEN_SPEC.md`.
