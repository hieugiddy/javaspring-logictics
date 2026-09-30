# notification-service

## 1. Vai trò

Notification Service sở hữu bảng `notifications` và là nơi nhận các domain event từ RabbitMQ để tạo notification cho người dùng.

```mermaid
flowchart LR
  E[(RabbitMQ)] --> C[NotificationConsumer]
  C --> S[NotificationCommandService / NotificationQueryService]
  S --> R[NotificationRepository (JPA Port)]
  R --> DB[(notification_db\nnotifications)]
  API[NotificationController] --> S
```

## 2. Thư viện

- WebMVC
- Validation
- Spring Security
- OAuth2 Resource Server + JOSE
- Spring Data JPA
- PostgreSQL
- Flyway
- Actuator
- `spring-boot-starter-amqp` (RabbitMQ)
- Spring Boot Test

## 3. Source hiện tại

```text
notification-service/
├── build.gradle
└── src/main
    ├── java/com/wms/notification
    │   ├── NotificationApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

RabbitMQ dependency đã có trong build.gradle, nhưng consumer/controller nghiệp vụ chưa được implement trong source hiện tại.

Cấu trúc mục tiêu (Port/Adapter theo màn hình):

```text
com.wms.notification
├── config/
│   ├── SecurityConfig.java
│   ├── RabbitMQConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S11-notification-list/
│   │   ├── controller/
│   │   │   └── NotificationController.java
│   │   ├── dto/
│   │   │   ├── NotificationResponse.java
│   │   │   ├── NotificationListResponse.java
│   │   │   └── MarkReadRequest.java
│   │   ├── service/
│   │   │   ├── NotificationQueryService.java (Port)
│   │   │   └── impl/NotificationQueryServiceImpl.java
│   │   ├── repository/
│   │   │   └── NotificationRepository.java (JPA Port)
│   │   └── db/
│   │       └── jpa/
│   │           └── NotificationEntity.java
│   ├── S11-mark-read/
│   │   ├── controller/
│   │   ├── dto/
│   │   ├── service/
│   │   │   ├── NotificationCommandService.java (Port)
│   │   │   └── impl/NotificationCommandServiceImpl.java
│   │   └── repository/
│   │       └── NotificationRepository.java (Port)
│   ├── S11-event-consumer/
│   │   ├── consumer/
│   │   │   └── NotificationEventConsumer.java
│   │   ├── event/
│   │   │   ├── OrderCreatedEvent.java
│   │   │   ├── InventoryAdjustedEvent.java
│   │   │   └── ShipmentStatusChangedEvent.java
│   │   └── service/
│   │       ├── NotificationEventHandler.java (Port)
│   │       └── impl/NotificationEventHandlerImpl.java
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   ├── BusinessRuleException.java
│   │   ├── EntityNotFoundException.java
│   │   └── GlobalExceptionHandler.java
│   ├── filter/
│   │   └── CorrelationIdFilter.java
│   └── security/
│       └── CurrentUser.java (extract UserPrincipal from JWT)
└── config/
```

## 4. API mục tiêu

```text
GET  /api/v1/notifications
GET  /api/v1/notifications/{id}
POST /api/v1/notifications/{id}/read
POST /api/v1/notifications/read-all
```

## 5. Event flow

Các event có thể đến từ Order/Inventory/Shipment qua RabbitMQ:

```text
Order/Inventory/Shipment
        |
        | domain event (RabbitMQ)
        v
NotificationEventConsumer (S11-event-consumer)
        |
        v
NotificationEventHandler (Port)
        |
        v
NotificationCommandService (Port) -> create notification
        |
        v
notification_db
```

Consumer đảm bảo idempotency: cùng một event được giao lại không tạo duplicate notification (unique constraint `event_id, user_id` + `ON CONFLICT DO NOTHING`).

## 6. Demo flow mục tiêu

Ví dụ Shipment Service phát event:

```json
{
  "eventId": "...",
  "eventType": "shipment.status.changed",
  "aggregateId": "...",
  "userId": "...",
  "status": "DELIVERED"
}
```

Consumer xử lý (manual ACK):

```text
RabbitMQ message
  -> deserialize event
  -> kiểm tra eventId đã xử lý chưa (idempotency)
  -> tạo notification (transactional)
  -> commit DB
  -> ACK message
```

Nếu ghi DB thất bại, không ACK để message có thể retry theo policy. Production cần cấu hình retry/DLQ.

## 7. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service Port
- **Service Interface (Port)**: `NotificationQueryService`, `NotificationCommandService`, `NotificationEventHandler`
- **Service Impl (Adapter)**: inject Repository Port, `@Transactional`
- **Repository Interface (Port)**: `NotificationRepository` (extend JpaRepository)
- **db/jpa/**: JPA Entity (Hibernate Adapter)
- **consumer/**: RabbitMQ `@RabbitListener` (Infrastructure Adapter)
- **Migration**: `resources/db/migration/`

## 8. Chi tiết triển khai màn hình S11

### 8.1 DTO (trong `screens/S11-notification-list/dto/`, `S11-mark-read/dto/`)

```java
public record NotificationResponse(
    UUID id,
    String type,
    String title,
    String message,
    String status, // UNREAD, READ
    Instant createdAt
) {}

public record NotificationListResponse(
    List<NotificationResponse> items,
    int page,
    int size,
    long totalElements,
    int totalPages
) {}

public record MarkReadRequest(
    @NotNull UUID notificationId
) {}
```

### 8.2 Event DTO (trong `screens/S11-event-consumer/event/`)

```java
public record OrderCreatedEvent(
    String eventId,
    UUID userId,
    UUID orderId,
    String orderNo,
    Instant occurredAt,
    String correlationId
) {}

public record InventoryAdjustedEvent(
    String eventId,
    UUID userId,
    Long productId,
    Long warehouseId,
    Integer delta,
    Instant occurredAt,
    String correlationId
) {}

public record ShipmentStatusChangedEvent(
    String eventId,
    UUID userId,
    UUID shipmentId,
    String trackingNumber,
    String status,
    Instant occurredAt,
    String correlationId
) {}
```

### 8.3 Entity (trong `screens/S11-notification-list/db/jpa/`)

```java
@Entity @Table(name = "notifications", uniqueConstraints = {
    @UniqueConstraint(name = "uk_notifications_event_user", columnNames = {"event_id", "user_id"})
})
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class NotificationEntity {
    @Id @GeneratedValue private UUID id;
    
    @Column(name = "user_id", nullable = false)
    private UUID userId;
    
    @Column(name = "event_id", nullable = false, length = 100)
    private String eventId;
    
    @Column(nullable = false, length = 50)
    private String type;
    
    @Column(nullable = false, length = 255)
    private String title;
    
    @Column(columnDefinition = "TEXT")
    private String message;
    
    @Column(nullable = false, length = 20)
    private String status; // UNREAD, READ
    
    @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @LastModifiedDate @Column(name = "updated_at")
    private Instant updatedAt;
}
```

### 8.4 Repository Port (trong `screens/S11-notification-list/repository/`)

```java
public interface NotificationRepository extends JpaRepository<NotificationEntity, UUID> {
    Page<NotificationEntity> findByUserId(UUID userId, Pageable pageable);
    Page<NotificationEntity> findByUserIdAndStatus(UUID userId, String status, Pageable pageable);
    
    // Atomic upsert for idempotency
    @Modifying
    @Query(value = """
        INSERT INTO notifications (id, user_id, event_id, type, title, message, status, created_at, updated_at)
        VALUES (:id, :userId, :eventId, :type, :title, :message, 'UNREAD', NOW(), NOW())
        ON CONFLICT (event_id, user_id) DO NOTHING
        """, nativeQuery = true)
    int insertIfAbsent(@Param("id") UUID id, @Param("userId") UUID userId, @Param("eventId") String eventId,
                       @Param("type") String type, @Param("title") String title, @Param("message") String message);
    
    @Modifying
    @Query("UPDATE NotificationEntity n SET n.status = 'READ' WHERE n.id = :id AND n.userId = :userId AND n.status <> 'READ'")
    int markAsRead(@Param("id") UUID id, @Param("userId") UUID userId);
}
```

### 8.5 Service Port & Impl (trong `screens/S11-notification-list/service/`, `S11-mark-read/service/`, `S11-event-consumer/service/`)

```java
// Port - Query
public interface NotificationQueryService {
    NotificationListResponse findByUserId(UUID userId, Pageable pageable);
    NotificationListResponse findByUserIdAndStatus(UUID userId, String status, Pageable pageable);
}

// Port - Command
public interface NotificationCommandService {
    void markAsRead(UUID userId, UUID notificationId);
    void markAllAsRead(UUID userId);
}

// Port - Event Handler
public interface NotificationEventHandler {
    void handleOrderCreated(OrderCreatedEvent event);
    void handleInventoryAdjusted(InventoryAdjustedEvent event);
    void handleShipmentStatusChanged(ShipmentStatusChangedEvent event);
}

// Impl - Query
@Service @RequiredArgsConstructor @Transactional(readOnly = true)
public class NotificationQueryServiceImpl implements NotificationQueryService {
    private final NotificationRepository notifications;
    
    public NotificationListResponse findByUserId(UUID userId, Pageable pageable) {
        Page<NotificationEntity> page = notifications.findByUserId(userId, pageable);
        return NotificationListResponse.from(page);
    }
}

// Impl - Command
@Service @RequiredArgsConstructor
public class NotificationCommandServiceImpl implements NotificationCommandService {
    private final NotificationRepository notifications;
    
    @Transactional
    public void markAsRead(UUID userId, UUID notificationId) {
        int updated = notifications.markAsRead(notificationId, userId);
        if (updated == 0) {
            throw new EntityNotFoundException("Notification not found or already read");
        }
    }
    
    @Transactional
    public void markAllAsRead(UUID userId) {
        // Bulk update
        notifications.findByUserIdAndStatus(userId, "UNREAD", Pageable.unpaged())
            .forEach(n -> n.setStatus("READ"));
    }
}

// Impl - Event Handler (Idempotent Consumer)
@Service @RequiredArgsConstructor
public class NotificationEventHandlerImpl implements NotificationEventHandler {
    private final NotificationRepository notifications;
    
    @Transactional
    public void handleOrderCreated(OrderCreatedEvent event) {
        createIfAbsent(event.userId(), event.eventId(), "ORDER_CREATED",
            "Đơn hàng mới", "Đơn hàng " + event.orderNo() + " đã được tạo");
    }
    
    @Transactional
    public void handleInventoryAdjusted(InventoryAdjustedEvent event) {
        createIfAbsent(event.userId(), event.eventId(), "INVENTORY_ADJUSTED",
            "Tồn kho thay đổi", "Sản phẩm trong kho " + event.warehouseId() + " đã điều chỉnh " + event.delta());
    }
    
    @Transactional
    public void handleShipmentStatusChanged(ShipmentStatusChangedEvent event) {
        createIfAbsent(event.userId(), event.eventId(), "SHIPMENT_STATUS_CHANGED",
            "Trạng thái vận chuyển", "Đơn " + event.trackingNumber() + " hiện ở trạng thái " + event.status());
    }
    
    private void createIfAbsent(UUID userId, String eventId, String type, String title, String message) {
        UUID id = UUID.randomUUID();
        int inserted = notifications.insertIfAbsent(id, userId, eventId, type, title, message);
        // inserted = 0 nghĩa là đã tồn tại (idempotent)
    }
}
```

### 8.6 RabbitMQ Consumer (trong `screens/S11-event-consumer/consumer/`)

```java
@Component @RequiredArgsConstructor
public class NotificationEventConsumer {
    private final NotificationEventHandler eventHandler;
    private final ObjectMapper objectMapper;
    
    @RabbitListener(queues = "${app.rabbitmq.queues.order-events}")
    public void consumeOrderCreated(Message message, Channel channel, @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) {
        handle(message, channel, deliveryTag, OrderCreatedEvent.class, eventHandler::handleOrderCreated);
    }
    
    @RabbitListener(queues = "${app.rabbitmq.queues.inventory-events}")
    public void consumeInventoryAdjusted(Message message, Channel channel, @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) {
        handle(message, channel, deliveryTag, InventoryAdjustedEvent.class, eventHandler::handleInventoryAdjusted);
    }
    
    @RabbitListener(queues = "${app.rabbitmq.queues.shipment-events}")
    public void consumeShipmentStatusChanged(Message message, Channel channel, @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) {
        handle(message, channel, deliveryTag, ShipmentStatusChangedEvent.class, eventHandler::handleShipmentStatusChanged);
    }
    
    private <T> void handle(Message message, Channel channel, long deliveryTag, Class<T> eventType, java.util.function.Consumer<T> handler) {
        try {
            T event = objectMapper.readValue(message.getBody(), eventType);
            handler.accept(event);
            channel.basicAck(deliveryTag, false);
        } catch (Exception e) {
            // Log error with correlation ID
            // Reject with requeue=false to send to DLQ after max retries
            try {
                channel.basicNack(deliveryTag, false, false);
            } catch (IOException ex) {
                // log
            }
        }
    }
}
```

### 8.7 Controller (trong `screens/S11-notification-list/controller/`, `S11-mark-read/controller/`)

```java
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {
    private final NotificationQueryService queryService;
    private final NotificationCommandService commandService;
    
    @GetMapping
    public ResponseEntity<NotificationListResponse> findAll(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") @Min(0) int page,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
            @AuthenticationPrincipal UserPrincipal principal) {
        if ("UNREAD".equalsIgnoreCase(status) || "READ".equalsIgnoreCase(status)) {
            return ResponseEntity.ok(queryService.findByUserIdAndStatus(principal.userId(), status.toUpperCase(), PageRequest.of(page, size)));
        }
        return ResponseEntity.ok(queryService.findByUserId(principal.userId(), PageRequest.of(page, size)));
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<NotificationResponse> findById(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        // Repository luôn filter by userId
        return queryService.findById(id, principal.userId())
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }
    
    @PostMapping("/{id}/read")
    public ResponseEntity<Void> markAsRead(@PathVariable UUID id, @AuthenticationPrincipal UserPrincipal principal) {
        commandService.markAsRead(principal.userId(), id);
        return ResponseEntity.noContent().build();
    }
    
    @PostMapping("/read-all")
    public ResponseEntity<Void> markAllAsRead(@AuthenticationPrincipal UserPrincipal principal) {
        commandService.markAllAsRead(principal.userId());
        return ResponseEntity.noContent().build();
    }
}
```

### 8.8 Cấu hình RabbitMQ (application.yml)

```yaml
spring:
  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest
    listener:
      simple:
        acknowledge-mode: manual
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1000
        default-requeue-rejected: false

app:
  rabbitmq:
    queues:
      order-events: warehouse.events.order
      inventory-events: warehouse.events.inventory
      shipment-events: warehouse.events.shipment
```

### 8.9 Test

- Consumer idempotent: cùng eventId + userId chỉ tạo 1 notification.
- Atomic insert `ON CONFLICT DO NOTHING` ngăn race condition.
- Manual ACK: chỉ ACK sau khi transaction commit thành công.
- Retry/DLQ: message lỗi sau 3 lần retry chuyển DLQ.
- API mark-read: chỉ user sở hữu mới được đọc, lặp lại idempotent.
- 404/403 đúng policy khi notification không tồn tại hoặc không thuộc user.
