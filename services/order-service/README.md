# order-service

## 1. Vai trò

Quản lý `orders` và `order_items`. Order Service là nơi điều phối trạng thái đơn và cần giao tiếp với Inventory Service để kiểm tra/giữ tồn.

```mermaid
flowchart LR
  C[Client] --> G[Gateway :8080]
  G --> OC[OrderController]
  OC --> OS[OrderCommandService / OrderQueryService]
  OS --> OR[OrderRepository (JPA Port)]
  OR --> DB[(order_db\norders\norder_items)]
  OS --> IC[InventoryClient (WebClient Port)]
  IC --> I[Inventory Service :8084]
```

## 2. Thư viện

WebMVC, Validation, Security, OAuth2 Resource Server/JOSE, JPA/Hibernate, PostgreSQL, Flyway, Actuator, Test, WebClient.

## 3. Source hiện tại

```text
order-service/
├── build.gradle
└── src/main
    ├── java/com/wms/order
    │   ├── OrderApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

Cấu trúc mục tiêu (Port/Adapter theo màn hình):

```text
com.wms.order
├── config/
│   ├── SecurityConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S09-order-create/
│   │   ├── controller/
│   │   │   └── OrderCreateController.java
│   │   ├── dto/
│   │   │   ├── CreateOrderRequest.java
│   │   │   ├── OrderItemRequest.java
│   │   │   └── OrderResponse.java
│   │   ├── service/
│   │   │   ├── OrderCommandService.java (Port)
│   │   │   └── impl/OrderCommandServiceImpl.java
│   │   ├── repository/
│   │   │   ├── OrderRepository.java (JPA Port)
│   │   │   └── OrderItemRepository.java (JPA Port)
│   │   └── db/
│   │       └── jpa/
│   │           ├── OrderEntity.java
│   │           └── OrderItemEntity.java
│   ├── S09-order-confirm/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── OrderConfirmService.java (Port)
│   │   │   └── impl/OrderConfirmServiceImpl.java
│   │   └── repository/
│   │       └── OrderRepository.java (Port)
│   ├── S09-order-cancel/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── OrderCancelService.java (Port)
│   │   │   └── impl/OrderCancelServiceImpl.java
│   │   └── repository/
│   ├── S09-order-list/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── OrderQueryService.java (Port)
│   │   │   └── impl/OrderQueryServiceImpl.java
│   │   ├── repository/
│   │   │   └── OrderRepository.java (Port)
│   │   └── db/mybatis/
│   │       └── OrderMapper.xml
├── client/
│   ├── InventoryClient.java (WebClient Port)
│   └── ProductClient.java (WebClient Port)
├── event/
│   ├── OutboxEvent.java
│   └── OutboxPublisher.java (TransactionalEventListener)
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   ├── BusinessRuleException.java
│   │   ├── EntityNotFoundException.java
│   │   └── GlobalExceptionHandler.java
│   ├── filter/
│   │   └── CorrelationIdFilter.java
│   └── security/
│       └── AuthorizationService.java
└── config/
```

## 4. API mục tiêu

```text
POST   /api/v1/orders
GET    /api/v1/orders/{id}
GET    /api/v1/orders
POST   /api/v1/orders/{id}/confirm
POST   /api/v1/orders/{id}/cancel
```

Chưa implement trong source hiện tại.

## 5. Tư duy state transition

Không cho phép Controller tự ý đổi `status`.

```text
OrderCommandService / OrderConfirmService / OrderCancelService
 -> kiểm tra current state
 -> kiểm tra transition hợp lệ
 -> gọi Inventory Service (qua Client Port) nếu cần
 -> cập nhật order/order_items
 -> lưu outbox event
```

State machine: `PENDING → CONFIRMED → (COMPLETED|CANCELLED)`, `PENDING → CANCELLED`, `CONFIRMED → CANCELLED` (with compensation).

## 6. Demo tạo đơn

```http
POST http://localhost:8080/api/v1/orders
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "userId": "...",
  "items": [
    {"productId":"...", "quantity":2}
  ]
}
```

Luồng mục tiêu:

```text
Client
 -> Gateway
 -> OrderCreateController
 -> OrderCommandService (Port)
 -> OrderCommandServiceImpl (Adapter)
 -> OrderRepository (Port) + OrderItemRepository (Port)
 -> order_db (PENDING)
 -> ProductClient.getPrices() (sync, ngoài transaction)
 -> InventoryClient.reserve() (async, idempotency key)
 -> Inventory Service
 -> OrderConfirmService.confirm() -> CONFIRMED + outbox event
 -> response
```

Không giữ transaction DB mở khi gọi Inventory Service. Nếu reserve thất bại, chuyển order về trạng thái phù hợp; nếu timeout không rõ kết quả, retry/query bằng cùng idempotency key. Order Service không tự truy cập inventory_db để sửa dữ liệu.

## 7. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service Port
- **Service Interface (Port)**: `OrderCommandService`, `OrderConfirmService`, `OrderCancelService`, `OrderQueryService`
- **Service Impl (Adapter)**: inject Repository Port + Client Port, `@Transactional`
- **Repository Interface (Port)**: `OrderRepository`, `OrderItemRepository` (extend JpaRepository)
- **Client Interface (Port)**: `InventoryClient`, `ProductClient` (WebClient)
- **db/jpa/**: JPA Entity (Hibernate Adapter)
- **db/mybatis/**: MyBatis XML cho query phức tạp (list view)
- **event/**: Outbox pattern cho domain event
- **Migration**: `resources/db/migration/`

## 8. Chi tiết triển khai màn hình S09-order-create/confirm/cancel

### 8.1 Request DTO (trong `screens/S09-order-create/dto/`)

```java
public record CreateOrderRequest(
    @NotBlank @Pattern(regexp = "^(INBOUND|OUTBOUND)$") String type,
    @NotNull Long warehouseId,
    @NotEmpty List<@Valid OrderItemRequest> items
) {}

public record OrderItemRequest(
    @NotNull Long productId,
    @Positive Integer quantity
) {}

public record ConfirmOrderRequest(
    @NotNull String idempotencyKey
) {}

public record CancelOrderRequest(
    @NotBlank String reason
) {}
```

### 8.2 Entity (trong `screens/S09-order-create/db/jpa/`)

```java
@Entity @Table(name = "orders")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class OrderEntity {
    @Id @GeneratedValue private UUID id;
    
    @Column(name = "order_no", nullable = false, unique = true, length = 50)
    private String orderNo;
    
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private OrderType type; // INBOUND, OUTBOUND
    
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private OrderStatus status; // PENDING, CONFIRMED, CANCELLED, FAILED, COMPLETED
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Column(name = "warehouse_id")
    private Long warehouseId;
    
    @Column(precision = 18, scale = 2)
    private BigDecimal totalAmount;
    
    @Version private Long version;
    
    @CreatedDate private Instant createdAt;
    @LastModifiedDate private Instant updatedAt;
    
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItemEntity> items = new ArrayList<>();
    
    // Domain methods
    public void confirm() { this.status = OrderStatus.CONFIRMED; }
    public void cancel(String reason) { this.status = OrderStatus.CANCELLED; this.cancelReason = reason; }
    public void markFailed(String error) { this.status = OrderStatus.FAILED; this.errorMessage = error; }
    public boolean canConfirm() { return this.status == OrderStatus.PENDING; }
    public boolean canCancel() { return this.status == OrderStatus.PENDING || this.status == OrderStatus.CONFIRMED; }
}

@Entity @Table(name = "order_items")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class OrderItemEntity {
    @Id @GeneratedValue private Long id;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private OrderEntity order;
    
    @Column(name = "product_id", nullable = false)
    private Long productId;
    
    @Column(nullable = false)
    private Integer quantity;
    
    @Column(name = "unit_price", precision = 18, scale = 2)
    private BigDecimal unitPrice;
    
    @CreatedDate @Column(name = "created_at")
    private Instant createdAt;
}
```

### 8.3 Repository Port (trong `screens/S09-order-create/repository/`)

```java
public interface OrderRepository extends JpaRepository<OrderEntity, UUID> {
    Optional<OrderEntity> findByOrderNo(String orderNo);
    Page<OrderEntity> findByUserId(UUID userId, Pageable pageable);
    Page<OrderEntity> findByStatus(OrderStatus status, Pageable pageable);
}

public interface OrderItemRepository extends JpaRepository<OrderItemEntity, Long> {
    List<OrderItemEntity> findByOrderId(UUID orderId);
}
```

### 8.4 Service Port & Impl (trong `screens/S09-order-create/service/`)

```java
// Port - Command
public interface OrderCommandService {
    OrderResponse create(CreateOrderRequest request, UUID userId);
}

// Port - Confirm (separate use case)
public interface OrderConfirmService {
    OrderResponse confirm(UUID orderId, String idempotencyKey);
}

// Port - Cancel
public interface OrderCancelService {
    OrderResponse cancel(UUID orderId, CancelOrderRequest request);
}

// Port - Query
public interface OrderQueryService {
    OrderResponse findById(UUID id);
    OrderListResponse findAll(UUID userId, OrderStatus status, Pageable pageable);
}

// Impl - Create
@Service @RequiredArgsConstructor
public class OrderCommandServiceImpl implements OrderCommandService {
    private final OrderRepository orderRepo;
    private final OrderItemRepository itemRepo;
    private final ProductClient productClient;
    
    @Transactional
    public OrderResponse create(CreateOrderRequest req, UUID userId) {
        // 1. Validate items, get prices from Product Service (sync, outside tx)
        List<PricedOrderItem> pricedItems = productClient.getCurrentPrices(req.items());
        
        // 2. Create order PENDING
        BigDecimal total = pricedItems.stream()
            .map(i -> i.unitPrice().multiply(BigDecimal.valueOf(i.quantity())))
            .reduce(BigDecimal.ZERO, BigDecimal::add);
        
        OrderEntity order = OrderEntity.builder()
            .orderNo(generateOrderNo())
            .type(req.type())
            .userId(userId)
            .warehouseId(req.warehouseId())
            .status(OrderStatus.PENDING)
            .totalAmount(total)
            .build();
        
        order.addItems(pricedItems.stream().map(this::toItemEntity).toList());
        orderRepo.save(order);
        
        return OrderResponse.from(order);
    }
}

// Impl - Confirm (Saga Orchestration)
@Service @RequiredArgsConstructor
public class OrderConfirmServiceImpl implements OrderConfirmService {
    private final OrderRepository orderRepo;
    private final InventoryClient inventoryClient;
    private final OutboxEventRepository outboxRepo;
    private final IdempotencyService idempotency;
    
    @Transactional
    public OrderResponse confirm(UUID orderId, String idempotencyKey) {
        // Check idempotency
        if (idempotency.alreadyProcessed(idempotencyKey)) {
            return idempotency.getResult(idempotencyKey);
        }
        
        OrderEntity order = orderRepo.findById(orderId)
            .orElseThrow(() -> new EntityNotFoundException("Order not found"));
        
        if (!order.canConfirm()) {
            throw new BusinessRuleException("Order cannot be confirmed from status: " + order.getStatus());
        }
        
        if (order.getType() == OrderType.OUTBOUND) {
            // 3. Call Inventory Service reserve
            ReserveRequest reserveReq = buildReserveRequest(order, idempotencyKey);
            ReserveResponse reserveResp = inventoryClient.reserve(reserveReq);
            
            if (!reserveResp.success()) {
                order.markFailed(reserveResp.error());
                OrderResponse fail = OrderResponse.from(order);
                idempotency.saveResult(idempotencyKey, fail);
                return fail;
            }
        }
        
        // 4. Confirm order
        order.confirm();
        
        // 5. Publish outbox event
        outboxRepo.save(new OutboxEvent("order.confirmed", orderId, ...));
        
        OrderResponse success = OrderResponse.from(order);
        idempotency.saveResult(idempotencyKey, success);
        return success;
    }
}

// Impl - Cancel
@Service @RequiredArgsConstructor
public class OrderCancelServiceImpl implements OrderCancelService {
    private final OrderRepository orderRepo;
    private final InventoryClient inventoryClient;
    private final OutboxEventRepository outboxRepo;
    
    @Transactional
    public OrderResponse cancel(UUID orderId, CancelOrderRequest req) {
        OrderEntity order = orderRepo.findById(orderId)
            .orElseThrow(() -> new EntityNotFoundException("Order not found"));
        
        if (!order.canCancel()) {
            throw new BusinessRuleException("Order cannot be cancelled from status: " + order.getStatus());
        }
        
        // Compensation: if CONFIRMED, release inventory
        if (order.getStatus() == OrderStatus.CONFIRMED && order.getType() == OrderType.OUTBOUND) {
            ReleaseRequest releaseReq = buildReleaseRequest(order);
            inventoryClient.release(releaseReq);
        }
        
        order.cancel(req.reason());
        outboxRepo.save(new OutboxEvent("order.cancelled", orderId, ...));
        return OrderResponse.from(order);
    }
}
```

### 8.5 Client Port (trong `client/`)

```java
// Port interface
public interface InventoryClient {
    ReserveResponse reserve(ReserveRequest request);
    ReleaseResponse release(ReleaseRequest request);
}

// WebClient Adapter impl
@Component @RequiredArgsConstructor
public class WebClientInventoryClient implements InventoryClient {
    private final WebClient webClient;
    
    public ReserveResponse reserve(ReserveRequest req) {
        return webClient.post()
            .uri("/api/v1/inventory/reserve")
            .header("Idempotency-Key", req.idempotencyKey())
            .bodyValue(req)
            .retrieve()
            .onStatus(HttpStatus::is4xxClientError, 
                r -> r.bodyToMono(String.class).map(InventoryServiceException::new))
            .onStatus(HttpStatus::is5xxServerError,
                r -> r.bodyToMono(String.class).map(InventoryServiceException::new))
            .bodyToMono(ReserveResponse.class)
            .block(); // or reactive
    }
}
```

### 8.6 Controller (trong `screens/S09-order-create/controller/`, `S09-order-confirm/controller/`, `S09-order-cancel/controller/`)

```java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderCreateController {
    private final OrderCommandService orderCommandService;
    
    @PostMapping
    public ResponseEntity<OrderResponse> create(
            @Valid @RequestBody CreateOrderRequest request,
            @AuthenticationPrincipal UserPrincipal principal) {
        OrderResponse response = orderCommandService.create(request, principal.userId());
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }
}

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderConfirmController {
    private final OrderConfirmService confirmService;
    
    @PostMapping("/{id}/confirm")
    public ResponseEntity<OrderResponse> confirm(
            @PathVariable UUID id,
            @Valid @RequestBody ConfirmOrderRequest request) {
        return ResponseEntity.ok(confirmService.confirm(id, request.idempotencyKey()));
    }
}

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderCancelController {
    private final OrderCancelService cancelService;
    
    @PostMapping("/{id}/cancel")
    public ResponseEntity<OrderResponse> cancel(
            @PathVariable UUID id,
            @Valid @RequestBody CancelOrderRequest request) {
        return ResponseEntity.ok(cancelService.cancel(id, request));
    }
}

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderListController {
    private final OrderQueryService queryService;
    
    @GetMapping
    public ResponseEntity<OrderListResponse> findAll(
            @RequestParam(required = false) OrderStatus status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @AuthenticationPrincipal UserPrincipal principal) {
        return ResponseEntity.ok(queryService.findAll(principal.userId(), status, PageRequest.of(page, size)));
    }
}
```

### 8.7 Test cần có

- Tạo order lưu header và các line trong cùng local transaction.
- Giá/tổng tiền lấy từ Product Service response và tính bằng `BigDecimal`.
- Confirm OUTBOUND đúng state gọi Inventory reserve đúng một lần theo idempotency key.
- Inventory timeout không làm order chuyển `CONFIRMED` sai.
- Cancel CONFIRMED → gọi Inventory release (compensation).
- Outbox event published after commit.
- Không inject `InventoryRepository` hoặc mở connection tới inventory_db.
