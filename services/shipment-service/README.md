# shipment-service

## 1. Vai trò

Quản lý vận chuyển và tracking dựa trên bảng `shipments`.

```mermaid
flowchart LR
  C[Client] --> G[Gateway :8080]
  G --> SC[ShipmentController]
  SC --> SS[ShipmentCommandService / ShipmentQueryService]
  SS --> SR[ShipmentRepository (JPA Port)]
  SR --> DB[(shipment_db\nshipments)]
  SS -. future event .-> K[(RabbitMQ)]
```

## 2. Thư viện

WebMVC, Validation, Security, OAuth2 Resource Server/JOSE, JPA/Hibernate, PostgreSQL, Flyway, Actuator, Test.

## 3. Source hiện tại

```text
shipment-service/
├── build.gradle
└── src/main
    ├── java/com/wms/shipment
    │   ├── ShipmentApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

Cấu trúc mục tiêu (Port/Adapter theo màn hình):

```text
com.wms.shipment
├── config/
│   ├── SecurityConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S10-shipment/
│   │   ├── controller/
│   │   │   └── ShipmentController.java
│   │   ├── dto/
│   │   │   ├── ShipmentResponse.java
│   │   │   ├── ShipmentListResponse.java
│   │   │   ├── CreateShipmentRequest.java
│   │   │   └── UpdateShipmentStatusRequest.java
│   │   ├── service/
│   │   │   ├── ShipmentCommandService.java (Port)
│   │   │   ├── ShipmentQueryService.java (Port)
│   │   │   └── impl/
│   │   │       ├── ShipmentCommandServiceImpl.java
│   │   │       └── ShipmentQueryServiceImpl.java
│   │   ├── repository/
│   │   │   └── ShipmentRepository.java (JPA Port)
│   │   └── db/
│   │       └── jpa/
│   │           └── ShipmentEntity.java
│   ├── S10-tracking-status/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   └── repository/
├── client/
│   └── OrderClient.java (WebClient Port)
├── event/
│   ├── ShipmentEventPublisher.java (Port)
│   └── impl/ShipmentEventPublisherImpl.java
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
POST   /api/v1/shipments
GET    /api/v1/shipments/{id}
GET    /api/v1/shipments/{id}/tracking
PUT    /api/v1/shipments/{id}/status
GET    /api/v1/shipments
```

Chưa implement controller nghiệp vụ.

## 5. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service Port
- **Service Interface (Port)**: `ShipmentCommandService`, `ShipmentQueryService`
- **Service Impl (Adapter)**: inject Repository Port + Client Port, `@Transactional`
- **Repository Interface (Port)**: `ShipmentRepository` (extend JpaRepository)
- **Client Interface (Port)**: `OrderClient` (WebClient)
- **db/jpa/**: JPA Entity (Hibernate Adapter)
- **event/**: Outbox pattern cho domain event
- **Migration**: `resources/db/migration/`

## 6. Demo tracking flow

```http
GET http://localhost:8080/api/v1/shipments/{id}/tracking
Authorization: Bearer <JWT>
```

Luồng:

```text
Client -> Gateway -> ShipmentController
       -> ShipmentQueryService (Port)
       -> ShipmentQueryServiceImpl (Adapter)
       -> ShipmentRepository (Port)
       -> shipment_db
       -> ShipmentResponse
       -> Gateway
       -> Client
```

Khi thay đổi trạng thái shipment, phát event qua RabbitMQ để Notification Service xử lý bất đồng bộ.

## 7. Cross-service rule

`order_id` là ID tham chiếu logic. Không truy vấn `order_db` trực tiếp. Trước khi tạo shipment, kiểm tra đơn xuất qua Order Client API.

## 8. Chi tiết triển khai màn hình S10-shipment

### 8.1 Request DTO (trong `screens/S10-shipment/dto/`)

```java
public record CreateShipmentRequest(
    @NotNull UUID orderId,
    @Size(max = 100) String carrier,
    @Size(max = 150) String trackingNumber
) {}

public record UpdateShipmentStatusRequest(
    @NotNull ShipmentStatus status
) {}

public enum ShipmentStatus {
    CREATED, IN_TRANSIT, DELIVERED, FAILED
}
```

### 8.2 Entity (trong `screens/S10-shipment/db/jpa/`)

```java
@Entity @Table(name = "shipments")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ShipmentEntity {
    @Id @GeneratedValue private UUID id;
    
    @Column(name = "order_id", nullable = false, unique = true)
    private UUID orderId;
    
    @Column(length = 100)
    private String carrier;
    
    @Column(name = "tracking_number", nullable = false, unique = true, length = 150)
    private String trackingNumber;
    
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private ShipmentStatus status;
    
    @Version @Column(name = "version", nullable = false)
    private Long version;
    
    @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @LastModifiedDate @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    
    // Factory methods
    public static ShipmentEntity created(UUID orderId, String carrier, String trackingNumber) {
        ShipmentEntity e = new ShipmentEntity();
        e.setOrderId(orderId);
        e.setCarrier(carrier);
        e.setTrackingNumber(trackingNumber);
        e.setStatus(ShipmentStatus.CREATED);
        return e;
    }
    
    public boolean changeStatus(ShipmentStatus next) {
        // Validate transition
        if (!isValidTransition(this.status, next)) {
            return false;
        }
        this.status = next;
        return true;
    }
    
    private boolean isValidTransition(ShipmentStatus current, ShipmentStatus next) {
        return switch (current) {
            case CREATED -> next == ShipmentStatus.IN_TRANSIT || next == ShipmentStatus.FAILED;
            case IN_TRANSIT -> next == ShipmentStatus.DELIVERED || next == ShipmentStatus.FAILED;
            case DELIVERED, FAILED -> false;
        };
    }
}
```

### 8.3 Repository Port (trong `screens/S10-shipment/repository/`)

```java
public interface ShipmentRepository extends JpaRepository<ShipmentEntity, UUID> {
    boolean existsByOrderId(UUID orderId);
    boolean existsByTrackingNumber(String trackingNumber);
    
    @Modifying
    @Query("UPDATE ShipmentEntity s SET s.status = :nextStatus, s.updatedAt = NOW() WHERE s.id = :id AND s.status = :currentStatus")
    int changeStatusIfCurrent(@Param("id") UUID id, @Param("currentStatus") ShipmentStatus currentStatus, @Param("nextStatus") ShipmentStatus nextStatus);
}
```

### 8.4 Service Port & Impl (trong `screens/S10-shipment/service/`)

```java
// Port - Command
public interface ShipmentCommandService {
    ShipmentResponse create(CreateShipmentRequest request);
    void changeStatus(UUID shipmentId, ShipmentStatus nextStatus);
}

// Port - Query
public interface ShipmentQueryService {
    ShipmentResponse findById(UUID id);
    ShipmentListResponse findAll(Pageable pageable);
    ShipmentTrackingResponse findTracking(UUID id);
}

// Impl - Command
@Service @RequiredArgsConstructor
public class ShipmentCommandServiceImpl implements ShipmentCommandService {
    private final ShipmentRepository shipments;
    private final OrderClient orderClient;
    private final ShipmentEventPublisher eventPublisher;
    
    @Transactional
    public ShipmentResponse create(CreateShipmentRequest request) {
        // Check order ready via Order Client
        orderClient.requireOutboundOrderReady(request.orderId());
        
        if (shipments.existsByOrderId(request.orderId())) {
            throw new BusinessRuleException("Shipment already exists for order");
        }
        if (shipments.existsByTrackingNumber(request.trackingNumber())) {
            throw new BusinessRuleException("Tracking number already exists");
        }
        
        ShipmentEntity shipment = ShipmentEntity.created(
            request.orderId(), request.carrier(), request.trackingNumber());
        ShipmentEntity saved = shipments.save(shipment);
        
        // Publish event after commit
        eventPublisher.publishShipmentCreated(saved);
        
        return ShipmentResponse.from(saved);
    }
    
    @Transactional
    public void changeStatus(UUID shipmentId, ShipmentStatus next) {
        ShipmentEntity shipment = shipments.findById(shipmentId)
            .orElseThrow(() -> new EntityNotFoundException("Shipment not found"));
        
        if (!shipment.changeStatus(next)) {
            throw new BusinessRuleException("Invalid status transition: " + shipment.getStatus() + " -> " + next);
        }
        
        // Optimistic locking via conditional update
        int changed = shipments.changeStatusIfCurrent(shipmentId, shipment.getStatus(), next);
        if (changed == 0) {
            throw new OptimisticLockingException("Shipment status changed concurrently");
        }
        
        // Publish event after commit
        eventPublisher.publishStatusChanged(shipmentId, next);
    }
}

// Impl - Query
@Service @RequiredArgsConstructor @Transactional(readOnly = true)
public class ShipmentQueryServiceImpl implements ShipmentQueryService {
    private final ShipmentRepository shipments;
    
    public ShipmentResponse findById(UUID id) {
        ShipmentEntity entity = shipments.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Shipment not found"));
        return ShipmentResponse.from(entity);
    }
    
    public ShipmentTrackingResponse findTracking(UUID id) {
        ShipmentEntity entity = shipments.findById(id)
            .orElseThrow(() -> new EntityNotFoundException("Shipment not found"));
        return ShipmentTrackingResponse.from(entity);
    }
}
```

### 8.5 Client Port (trong `client/`)

```java
// Port interface
public interface OrderClient {
    void requireOutboundOrderReady(UUID orderId);
    OrderResponse findById(UUID id);
}

// WebClient Adapter
@Component @RequiredArgsConstructor
public class WebClientOrderClient implements OrderClient {
    private final WebClient webClient;
    
    public void requireOutboundOrderReady(UUID orderId) {
        OrderResponse order = webClient.get()
            .uri("/api/v1/orders/{id}", orderId)
            .retrieve()
            .onStatus(HttpStatus::is4xxClientError, r -> Mono.error(new OrderNotReadyException()))
            .bodyToMono(OrderResponse.class)
            .block();
        
        if (order.type() != OrderType.OUTBOUND || order.status() != OrderStatus.CONFIRMED) {
            throw new OrderNotReadyException("Order not ready for shipment");
        }
    }
}
```

### 8.6 Controller (trong `screens/S10-shipment/controller/`)

```java
@RestController
@RequestMapping("/api/v1/shipments")
@RequiredArgsConstructor
public class ShipmentController {
    private final ShipmentCommandService commandService;
    private final ShipmentQueryService queryService;
    
    @PostMapping
    public ResponseEntity<ShipmentResponse> create(@Valid @RequestBody CreateShipmentRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(commandService.create(request));
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<ShipmentResponse> findById(@PathVariable UUID id) {
        return ResponseEntity.ok(queryService.findById(id));
    }
    
    @GetMapping("/{id}/tracking")
    public ResponseEntity<ShipmentTrackingResponse> tracking(@PathVariable UUID id) {
        return ResponseEntity.ok(queryService.findTracking(id));
    }
    
    @PutMapping("/{id}/status")
    public ResponseEntity<Void> changeStatus(@PathVariable UUID id, @Valid @RequestBody UpdateShipmentStatusRequest request) {
        commandService.changeStatus(id, request.status());
        return ResponseEntity.noContent().build();
    }
    
    @GetMapping
    public ResponseEntity<ShipmentListResponse> findAll(
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        return ResponseEntity.ok(queryService.findAll(PageRequest.of(page, size)));
    }
}
```

### 8.7 Event Publisher (trong `event/`)

```java
// Port
public interface ShipmentEventPublisher {
    void publishShipmentCreated(ShipmentEntity shipment);
    void publishStatusChanged(UUID shipmentId, ShipmentStatus newStatus);
}

// Impl (Outbox pattern)
@Component @RequiredArgsConstructor
public class ShipmentEventPublisherImpl implements ShipmentEventPublisher {
    private final OutboxEventRepository outboxRepo;
    
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publishShipmentCreated(ShipmentEntity shipment) {
        OutboxEvent event = new OutboxEvent(
            "shipment.created",
            shipment.getId(),
            Map.of("trackingNumber", shipment.getTrackingNumber())
        );
        outboxRepo.save(event);
    }
    
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void publishStatusChanged(UUID shipmentId, ShipmentStatus newStatus) {
        OutboxEvent event = new OutboxEvent(
            "shipment.status.changed",
            shipmentId,
            Map.of("status", newStatus.name())
        );
        outboxRepo.save(event);
    }
}
```

### 8.8 Test

- Tạo shipment cho order chưa sẵn sàng -> từ chối (OrderClient check).
- Tạo hai shipment cho cùng order hoặc tracking number -> 409.
- Transition hợp lệ thành công; transition không hợp lệ -> 409.
- Cập nhật đồng thời cùng trạng thái chỉ một request thắng (optimistic lock).
- Event `shipment.status.changed` chỉ phát sau khi commit (TransactionalEventListener).
