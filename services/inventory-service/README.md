# inventory-service

## 1. Vai trò

Inventory Service quản lý số lượng tồn và lịch sử biến động:
- `inventory`
- `inventory_transactions`

Đây là service cần chú ý nhất về concurrency vì nhiều request có thể cùng điều chỉnh một SKU trong một kho.

```mermaid
flowchart LR
  C[Client] --> G[Gateway :8080]
  G --> IC[InventoryController]
  IC --> IS[InventoryAdjustService / InventoryQueryService]
  IS --> IR[InventoryRepository (JPA Port) / InventoryQueryMapper (MyBatis Port)]
  IR --> DB[(inventory_db)]
  IS --> IT[InventoryTransactionRepository (JPA Port)]
  IT --> DB
  IS --> P[Product Service\nlogical reference]
```

## 2. Thư viện

WebMVC, Validation, Security, OAuth2 Resource Server/JOSE, JPA/Hibernate, MyBatis, PostgreSQL, Flyway, Actuator, Test.

## 3. Source hiện tại

```text
inventory-service/
├── build.gradle
└── src/main
    ├── java/com/wms/inventory
    │   ├── InventoryApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

Cấu trúc mục tiêu (Port/Adapter theo màn hình):

```text
com.wms.inventory
├── config/
│   ├── SecurityConfig.java
│   ├── MyBatisConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S08-inventory-lookup/
│   │   ├── controller/
│   │   │   └── InventoryQueryController.java
│   │   ├── dto/
│   │   │   ├── InventoryResponse.java
│   │   │   ├── InventoryListResponse.java
│   │   │   └── InventorySearchCriteria.java
│   │   ├── service/
│   │   │   ├── InventoryQueryService.java (Port)
│   │   │   └── impl/InventoryQueryServiceImpl.java
│   │   ├── repository/
│   │   │   ├── InventoryRepository.java (JPA Port)
│   │   │   └── InventoryQueryMapper.java (MyBatis Port)
│   │   └── db/
│   │       ├── jpa/
│   │       │   ├── InventoryEntity.java
│   │       │   ├── InventoryTransactionEntity.java
│   │       │   └── InventoryId.java (Embeddable)
│   │       └── mybatis/
│   │           └── InventoryMapper.xml
│   ├── S08-inventory-adjust/
│   │   ├── controller/
│   │   │   └── InventoryCommandController.java
│   │   ├── dto/
│   │   │   ├── AdjustInventoryRequest.java
│   │   │   ├── ReserveInventoryRequest.java
│   │   │   └── ReleaseInventoryRequest.java
│   │   ├── service/
│   │   │   ├── InventoryAdjustService.java (Port)
│   │   │   ├── InventoryReservationService.java (Port)
│   │   │   └── impl/
│   │   │       ├── InventoryAdjustServiceImpl.java
│   │   │       └── InventoryReservationServiceImpl.java
│   │   ├── repository/
│   │   │   ├── InventoryRepository.java (JPA Port)
│   │   │   └── InventoryTransactionRepository.java (JPA Port)
│   │   └── db/
│   │       └── jpa/ (shared với S08-inventory-lookup)
│   ├── S08-transaction-history/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   ├── repository/
│   │   └── db/mybatis/
├── client/
│   └── ProductClient.java (WebClient Port)
├── event/
│   ├── InventoryEventPublisher.java (Port)
│   └── impl/InventoryEventPublisherImpl.java
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   ├── BusinessRuleException.java
│   │   ├── EntityNotFoundException.java
│   │   ├── OptimisticLockingException.java
│   │   └── GlobalExceptionHandler.java
│   ├── filter/
│   │   └── CorrelationIdFilter.java
│   └── security/
│       └── AuthorizationService.java (warehouse-scoped)
└── config/
```

## 4. API mục tiêu

```text
GET  /api/v1/inventory
GET  /api/v1/inventory/{productId}/{warehouseId}
POST /api/v1/inventory/adjust
POST /api/v1/inventory/reserve
POST /api/v1/inventory/release
GET  /api/v1/inventory/transactions
```

Controller nghiệp vụ chưa có trong source hiện tại.

## 5. Quy tắc concurrency

Khi update stock, không làm:
```text
SELECT quantity
UPDATE quantity = quantity - x
```
mà không có locking/version.

Thiết kế mục tiêu dùng **optimistic locking (`@Version`)** hoặc **pessimistic lock (`SELECT FOR UPDATE`)** tùy use case. Mọi thay đổi tồn phải ghi `inventory_transactions` trong cùng transaction.

## 6. Demo reserve stock

```http
POST http://localhost:8080/api/v1/inventory/reserve
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "productId": "...",
  "warehouseId": "...",
  "quantity": 5,
  "orderId": "..."
}
```

Luồng:

```text
Client
 -> Gateway/JWT
 -> InventoryCommandController
 -> InventoryReservationService (Port)
 -> InventoryReservationServiceImpl (Adapter)
 -> InventoryRepository (Port) + InventoryTransactionRepository (Port)
 -> inventory_db
 -> ReserveInventoryResponse
 -> Gateway
 -> Client
```

Nếu Order Service gọi reserve:

```text
Order Service
 -> HTTP Inventory API
 -> Inventory transaction
 -> success/failure
 -> Order Service tiếp tục hoặc rollback state theo business flow
```

## 7. Cross-service rule

`product_id` và `warehouse_id` là ID tham chiếu logic. Không tạo FK PostgreSQL sang `product_db` hoặc `warehouse_db`.

## 8. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service Port
- **Service Interface (Port)**: `InventoryAdjustService`, `InventoryQueryService`, `InventoryReservationService`
- **Service Impl (Adapter)**: inject Repository Port, `@Transactional`
- **Repository Interface (Port)**: `InventoryRepository`, `InventoryTransactionRepository`, `InventoryQueryMapper`
- **db/jpa/**: JPA Entity + Embeddable ID (Hibernate Adapter)
- **db/mybatis/**: MyBatis XML cho query phức tạp (MyBatis Adapter)
- **Migration**: `resources/db/migration/`

## 9. Chi tiết triển khai màn hình S08-inventory-adjust

### 9.1 Request DTO (trong `screens/S08-inventory-adjust/dto/`)

```java
public record AdjustInventoryRequest(
    @NotNull Long productId,
    @NotNull Long warehouseId,
    @NotNull Integer quantityDelta,
    @NotBlank String reason,
    String referenceNo
) {}

public record ReserveInventoryRequest(
    @NotNull Long productId,
    @NotNull Long warehouseId,
    @NotNull @Positive Integer quantity,
    @NotNull String orderId,
    @NotNull String idempotencyKey
) {}

public record ReleaseInventoryRequest(
    @NotNull Long productId,
    @NotNull Long warehouseId,
    @NotNull @Positive Integer quantity,
    @NotNull String orderId,
    @NotNull String idempotencyKey
) {}
```

### 9.2 Khóa ghép và Entity (trong `screens/S08-inventory-adjust/db/jpa/`)

```java
@Embeddable
public class InventoryId implements Serializable {
    @Column(name = "product_id")
    private Long productId;

    @Column(name = "warehouse_id")
    private Long warehouseId;

    protected InventoryId() {}

    public InventoryId(Long productId, Long warehouseId) {
        this.productId = productId;
        this.warehouseId = warehouseId;
    }

    @Override
    public boolean equals(Object o) { ... }
    @Override
    public int hashCode() { ... }
}

@Entity
@Table(name = "inventory")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class InventoryEntity {
    @EmbeddedId
    private InventoryId id;

    @Column(nullable = false)
    private Integer quantity;

    @Column(name = "reserved_quantity", nullable = false)
    private Integer reservedQuantity;

    @Version
    @Column(nullable = false)
    private Long version;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
}

@Entity
@Table(name = "inventory_transactions")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class InventoryTransactionEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "product_id", nullable = false)
    private Long productId;

    @Column(name = "warehouse_id", nullable = false)
    private Long warehouseId;

    @Column(name = "order_id")
    private UUID orderId;

    @Column(nullable = false)
    private Integer quantityDelta;

    @Column(nullable = false, length = 50)
    private String type; // ADJUSTMENT, RESERVE, RELEASE

    @Column(length = 100)
    private String referenceNo;

    @Column(length = 255)
    private String reason;

    @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
```

### 9.3 Repository Port (trong `screens/S08-inventory-adjust/repository/`)

```java
public interface InventoryRepository extends JpaRepository<InventoryEntity, InventoryId> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<InventoryEntity> findByIdForUpdate(InventoryId id);
}

public interface InventoryTransactionRepository extends JpaRepository<InventoryTransactionEntity, Long> {
    List<InventoryTransactionEntity> findByProductIdAndWarehouseId(Long productId, Long warehouseId);
}
```

### 9.4 Service Port & Impl (trong `screens/S08-inventory-adjust/service/`)

```java
// Port - Adjust
public interface InventoryAdjustService {
    InventoryResponse adjust(AdjustInventoryRequest request);
}

// Port - Reservation
public interface InventoryReservationService {
    ReserveInventoryResponse reserve(ReserveInventoryRequest request);
    ReleaseInventoryResponse release(ReleaseInventoryRequest request);
}

// Impl - Adjust
@Service @RequiredArgsConstructor
public class InventoryAdjustServiceImpl implements InventoryAdjustService {
    private final InventoryRepository inventoryRepo;
    private final InventoryTransactionRepository txRepo;
    private final AuthorizationService authz;

    @Transactional
    public InventoryResponse adjust(AdjustInventoryRequest req) {
        authz.requireWarehouseAccess(req.warehouseId());
        
        InventoryId id = new InventoryId(req.productId(), req.warehouseId());
        InventoryEntity stock = inventoryRepo.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Inventory not found"));

        int available = stock.getQuantity() - stock.getReservedQuantity();
        int nextQty = stock.getQuantity() + req.quantityDelta();
        if (nextQty < stock.getReservedQuantity() || nextQty < 0) {
            throw new BusinessRuleException("Insufficient available stock");
        }

        stock.setQuantity(nextQty); // @Version check on flush
        txRepo.save(InventoryTransactionEntity.adjustment(req));
        return InventoryResponse.from(stock);
    }
}

// Impl - Reservation
@Service @RequiredArgsConstructor
public class InventoryReservationServiceImpl implements InventoryReservationService {
    private final InventoryRepository inventoryRepo;
    private final InventoryTransactionRepository txRepo;
    private final IdempotencyService idempotency;

    @Transactional
    public ReserveInventoryResponse reserve(ReserveInventoryRequest req) {
        // Check idempotency
        if (idempotency.alreadyProcessed(req.idempotencyKey())) {
            return idempotency.getResult(req.idempotencyKey());
        }

        authz.requireWarehouseAccess(req.warehouseId());
        
        InventoryId id = new InventoryId(req.productId(), req.warehouseId());
        InventoryEntity stock = inventoryRepo.findByIdForUpdate(id) // Pessimistic lock
            .orElseThrow(() -> new EntityNotFoundException("Inventory not found"));

        int available = stock.getQuantity() - stock.getReservedQuantity();
        if (available < req.quantity()) {
            ReserveInventoryResponse fail = ReserveInventoryResponse.failed("Insufficient stock");
            idempotency.saveResult(req.idempotencyKey(), fail);
            return fail;
        }

        stock.setReservedQuantity(stock.getReservedQuantity() + req.quantity());
        txRepo.save(InventoryTransactionEntity.reserve(req));
        
        ReserveInventoryResponse success = ReserveInventoryResponse.success();
        idempotency.saveResult(req.idempotencyKey(), success);
        return success;
    }

    @Transactional
    public ReleaseInventoryResponse release(ReleaseInventoryRequest req) {
        // Similar to reserve but decrease reservedQuantity
        // Check idempotency
    }
}
```

### 9.5 Controller (trong `screens/S08-inventory-adjust/controller/`)

```java
@RestController
@RequestMapping("/api/v1/inventory")
@RequiredArgsConstructor
public class InventoryCommandController {
    private final InventoryAdjustService adjustService;
    private final InventoryReservationService reservationService;

    @PostMapping("/adjust")
    public ResponseEntity<InventoryResponse> adjust(@Valid @RequestBody AdjustInventoryRequest request) {
        return ResponseEntity.ok(adjustService.adjust(request));
    }

    @PostMapping("/reserve")
    public ResponseEntity<ReserveInventoryResponse> reserve(@Valid @RequestBody ReserveInventoryRequest request) {
        return ResponseEntity.ok(reservationService.reserve(request));
    }

    @PostMapping("/release")
    public ResponseEntity<ReleaseInventoryResponse> release(@Valid @RequestBody ReleaseInventoryRequest request) {
        return ResponseEntity.ok(reservationService.release(request));
    }
}

@RestController
@RequestMapping("/api/v1/inventory")
@RequiredArgsConstructor
public class InventoryQueryController {
    private final InventoryQueryService queryService;

    @GetMapping
    public ResponseEntity<InventoryListResponse> search(
            @RequestParam(required = false) Long productId,
            @RequestParam(required = false) Long warehouseId,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return ResponseEntity.ok(queryService.search(productId, warehouseId, status, page, size));
    }

    @GetMapping("/{productId}/{warehouseId}")
    public ResponseEntity<InventoryResponse> findById(@PathVariable Long productId, @PathVariable Long warehouseId) {
        return ResponseEntity.ok(queryService.findById(productId, warehouseId));
    }
}
```

### 9.6 MyBatis Mapper XML cho lookup (trong `screens/S08-inventory-lookup/db/mybatis/InventoryMapper.xml`)

```xml
<resultMap id="inventoryResultMap" type="InventoryResponse">
    <id property="productId" column="product_id"/>
    <id property="warehouseId" column="warehouse_id"/>
    <result property="quantity" column="quantity"/>
    <result property="reservedQuantity" column="reserved_quantity"/>
    <result property="availableQuantity" column="available_quantity"/>
    <result property="status" column="status"/>
    <result property="updatedAt" column="updated_at"/>
    <association property="product" javaType="ProductInfo">
        <id property="id" column="product_id"/>
        <result property="sku" column="sku"/>
        <result property="name" column="product_name"/>
    </association>
    <association property="warehouse" javaType="WarehouseInfo">
        <id property="id" column="warehouse_id"/>
        <result property="code" column="warehouse_code"/>
        <result property="name" column="warehouse_name"/>
    </association>
</resultMap>

<select id="search" resultMap="inventoryResultMap">
    SELECT i.product_id, i.warehouse_id, i.quantity, i.reserved_quantity,
           (i.quantity - i.reserved_quantity) as available_quantity,
           i.updated_at,
           p.sku, p.name as product_name,
           w.code as warehouse_code, w.name as warehouse_name
    FROM inventory i
    LEFT JOIN products p ON i.product_id = p.id
    LEFT JOIN warehouses w ON i.warehouse_id = w.id
    <where>
        <if test="productId != null">AND i.product_id = #{productId}</if>
        <if test="warehouseId != null">AND i.warehouse_id = #{warehouseId}</if>
    </where>
    ORDER BY i.updated_at DESC
    LIMIT #{size} OFFSET #{offset}
</select>
```

### 9.7 Test cần có

- Điều chỉnh hợp lệ tạo đúng một inventory transaction.
- Số lượng mới thấp hơn `reserved_quantity` trả 422 và rollback.
- Hai request cùng `version` không thể cùng ghi đè; request xung đột trả 409.
- User không được gán warehouse trả 403.
- Reserve idempotent: cùng `idempotencyKey` chỉ reserve một lần.
- Pessimistic lock cho reserve: `SELECT FOR UPDATE` trên inventory row.
- Sau commit mới xóa cache và phát event qua outbox.
