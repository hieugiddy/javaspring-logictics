# warehouse-service

## 1. Vai trò

Quản lý kho và khu vực kho: `warehouses`, `warehouse_zones`.

```mermaid
flowchart LR
  C[Client] --> G[Gateway :8080]
  G --> WC[WarehouseController / ZoneController]
  WC --> WS[WarehouseQueryService / WarehouseCommandService]
  WS --> WR[WarehouseRepository (JPA Port)]
  WR --> DB[(warehouse_db\nwarehouses\nwarehouse_zones)]
```

## 2. Thư viện

WebMVC, Validation, Security, OAuth2 Resource Server/JOSE, JPA/Hibernate, PostgreSQL, Flyway, Actuator, Test.

## 3. Source hiện tại

```text
warehouse-service/
├── build.gradle
└── src/main
    ├── java/com/wms/warehouse
    │   ├── WarehouseApplication.java
    │   └── SecurityConfig.java
    └── resources
        ├── application.yml
        └── db/migration/V1__schema.sql
```

Cấu trúc nghiệp vụ mục tiêu (Port/Adapter theo màn hình):

```text
com.wms.warehouse
├── config/
│   ├── SecurityConfig.java
│   └── JpaAuditingConfig.java
├── screens/
│   ├── S07-warehouse-zone/
│   │   ├── controller/
│   │   │   ├── WarehouseController.java
│   │   │   └── ZoneController.java
│   │   ├── dto/
│   │   │   ├── WarehouseResponse.java
│   │   │   ├── ZoneResponse.java
│   │   │   ├── CreateWarehouseRequest.java
│   │   │   ├── UpdateWarehouseRequest.java
│   │   │   ├── CreateZoneRequest.java
│   │   │   └── UpdateZoneRequest.java
│   │   ├── service/
│   │   │   ├── WarehouseQueryService.java (Port)
│   │   │   ├── WarehouseCommandService.java (Port)
│   │   │   └── impl/
│   │   │       ├── WarehouseQueryServiceImpl.java
│   │   │       └── WarehouseCommandServiceImpl.java
│   │   ├── repository/
│   │   │   ├── WarehouseRepository.java (JPA Port)
│   │   │   └── WarehouseZoneRepository.java (JPA Port)
│   │   └── db/
│   │       └── jpa/
│   │           ├── WarehouseEntity.java
│   │           └── WarehouseZoneEntity.java
├── common/
│   ├── exception/
│   │   ├── ApiException.java
│   │   ├── BusinessRuleException.java
│   │   ├── EntityNotFoundException.java
│   │   └── GlobalExceptionHandler.java
│   └── filter/
│       └── CorrelationIdFilter.java
└── client/ (Inventory Service sẽ call Warehouse Service)
```

## 4. API mục tiêu

```text
GET    /api/v1/warehouses
GET    /api/v1/warehouses/{id}
POST   /api/v1/warehouses
PUT    /api/v1/warehouses/{id}
DELETE /api/v1/warehouses/{id}

GET    /api/v1/warehouse-zones
GET    /api/v1/warehouse-zones/{id}
POST   /api/v1/warehouse-zones
PUT    /api/v1/warehouse-zones/{id}
DELETE /api/v1/warehouse-zones/{id}
```

Chưa implement controller trong source hiện tại.

## 5. Quy tắc kiến trúc

- **Controller** chỉ map HTTP → DTO → Service Port
- **Service Interface (Port)**: `WarehouseQueryService`, `WarehouseCommandService`
- **Service Impl (Adapter)**: inject Repository Port, `@Transactional`
- **Repository Interface (Port)**: `WarehouseRepository`, `WarehouseZoneRepository` (extend JpaRepository)
- **db/jpa/**: JPA Entity (Hibernate Adapter)
- **Migration**: `resources/db/migration/`

## 6. Demo flow

```http
POST http://localhost:8080/api/v1/warehouses
Authorization: Bearer <JWT>
Content-Type: application/json

{
  "code": "WH-HCM-01",
  "name": "Kho HCM"
}
```

Luồng:

```text
Client -> Gateway -> WarehouseController
       -> WarehouseCommandService (Port)
       -> WarehouseCommandServiceImpl (Adapter)
       -> WarehouseRepository (Port)
       -> warehouse_db
       -> WarehouseResponse
       -> Gateway
       -> Client
```

## 7. Cross-service rule

Inventory Service giữ `warehouse_id` (logical reference), không truy cập `warehouse_db` trực tiếp. Khi cần chi tiết kho, gọi Warehouse Service API.

## 8. Chi tiết triển khai màn hình S07-warehouse-zone

### 8.1 Request DTO (trong `screens/S07-warehouse-zone/dto/`)

```java
public record CreateWarehouseRequest(
    @NotBlank @Size(max = 50) String code,
    @NotBlank @Size(max = 255) String name,
    @Size(max = 255) String location,
    @Size(max = 500) String address
) {}

public record UpdateWarehouseRequest(
    @Size(max = 255) String name,
    @Size(max = 255) String location,
    @Size(max = 500) String address
) {}

public record CreateZoneRequest(
    @NotBlank @Size(max = 50) String code,
    @NotBlank @Size(max = 150) String name
) {}

public record UpdateZoneRequest(
    @Size(max = 150) String name
) {}
```

### 8.2 Entity (trong `screens/S07-warehouse-zone/db/jpa/`)

```java
@Entity @Table(name = "warehouses")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WarehouseEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false, unique = true, length = 50)
    private String code;
    
    @Column(nullable = false, length = 255)
    private String name;
    
    @Column(length = 255)
    private String location;
    
    @Column(length = 500)
    private String address;
    
    @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @LastModifiedDate @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    
    @Version @Column(name = "version", nullable = false)
    private Long version;
}

@Entity @Table(name = "warehouse_zones")
@EntityListeners(AuditingEntityListener.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class WarehouseZoneEntity {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "warehouse_id", nullable = false)
    private WarehouseEntity warehouse;
    
    @Column(nullable = false, length = 50)
    private String code;
    
    @Column(nullable = false, length = 150)
    private String name;
    
    @CreatedDate @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    
    @LastModifiedDate @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;
    
    @Version @Column(name = "version", nullable = false)
    private Long version;
}
```

### 8.3 Repository Port (trong `screens/S07-warehouse-zone/repository/`)

```java
public interface WarehouseRepository extends JpaRepository<WarehouseEntity, Long> {
    boolean existsByCode(String code);
}

public interface WarehouseZoneRepository extends JpaRepository<WarehouseZoneEntity, Long> {
    boolean existsByWarehouseIdAndCode(Long warehouseId, String code);
    List<WarehouseZoneEntity> findByWarehouseIdOrderByCode(Long warehouseId);
}
```

### 8.4 Service Port & Impl (trong `screens/S07-warehouse-zone/service/`)

```java
// Port - Query
public interface WarehouseQueryService {
    WarehouseResponse findById(Long id);
    List<WarehouseResponse> findAll();
    ZoneResponse findZoneById(Long id);
    List<ZoneResponse> findZonesByWarehouseId(Long warehouseId);
}

// Port - Command
public interface WarehouseCommandService {
    WarehouseResponse createWarehouse(CreateWarehouseRequest request);
    WarehouseResponse updateWarehouse(Long id, UpdateWarehouseRequest request);
    void deleteWarehouse(Long id);
    ZoneResponse createZone(Long warehouseId, CreateZoneRequest request);
    ZoneResponse updateZone(Long id, UpdateZoneRequest request);
    void deleteZone(Long id);
}

// Impl
@Service @RequiredArgsConstructor
public class WarehouseCommandServiceImpl implements WarehouseCommandService {
    private final WarehouseRepository warehouses;
    private final WarehouseZoneRepository zones;
    
    @Transactional
    public WarehouseResponse createWarehouse(CreateWarehouseRequest request) {
        String code = request.code().trim();
        if (warehouses.existsByCode(code)) {
            throw new BusinessRuleException("Warehouse code already exists");
        }
        WarehouseEntity entity = WarehouseEntity.builder()
            .code(code)
            .name(request.name().trim())
            .location(request.location())
            .address(request.address())
            .build();
        return WarehouseResponse.from(warehouses.save(entity));
    }
    
    @Transactional
    public ZoneResponse createZone(Long warehouseId, CreateZoneRequest request) {
        WarehouseEntity warehouse = warehouses.findById(warehouseId)
            .orElseThrow(() -> new EntityNotFoundException("Warehouse not found"));
        if (zones.existsByWarehouseIdAndCode(warehouseId, request.code().trim())) {
            throw new BusinessRuleException("Zone code already exists in warehouse");
        }
        WarehouseZoneEntity zone = WarehouseZoneEntity.builder()
            .warehouse(warehouse)
            .code(request.code().trim())
            .name(request.name().trim())
            .build();
        return ZoneResponse.from(zones.save(zone));
    }
}
```

### 8.4 Controller (trong `screens/S07-warehouse-zone/controller/`)

```java
@RestController
@RequestMapping("/api/v1/warehouses")
@RequiredArgsConstructor
public class WarehouseController {
    private final WarehouseQueryService queryService;
    private final WarehouseCommandService commandService;
    
    @GetMapping
    public ResponseEntity<List<WarehouseResponse>> findAll() {
        return ResponseEntity.ok(queryService.findAll());
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<WarehouseResponse> findById(@PathVariable Long id) {
        return ResponseEntity.ok(queryService.findById(id));
    }
    
    @PostMapping
    public ResponseEntity<WarehouseResponse> create(@Valid @RequestBody CreateWarehouseRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(commandService.createWarehouse(request));
    }
    
    @PutMapping("/{id}")
    public ResponseEntity<WarehouseResponse> update(@PathVariable Long id, @Valid @RequestBody UpdateWarehouseRequest request) {
        return ResponseEntity.ok(commandService.updateWarehouse(id, request));
    }
    
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        commandService.deleteWarehouse(id);
        return ResponseEntity.noContent().build();
    }
}

@RestController
@RequestMapping("/api/v1/warehouse-zones")
@RequiredArgsConstructor
public class ZoneController {
    private final WarehouseQueryService queryService;
    private final WarehouseCommandService commandService;
    
    @GetMapping
    public ResponseEntity<List<ZoneResponse>> findAll(@RequestParam Long warehouseId) {
        return ResponseEntity.ok(queryService.findZonesByWarehouseId(warehouseId));
    }
    
    @GetMapping("/{id}")
    public ResponseEntity<ZoneResponse> findById(@PathVariable Long id) {
        return ResponseEntity.ok(queryService.findZoneById(id));
    }
    
    @PostMapping
    public ResponseEntity<ZoneResponse> create(@Valid @RequestBody CreateZoneRequest request) {
        // warehouseId từ request hoặc path variable
        return ResponseEntity.status(HttpStatus.CREATED).body(commandService.createZone(request.warehouseId(), request));
    }
}
```

Controller chỉ bind/validate DTO và gọi Service Port; Service Impl kiểm tra business rule, transaction; Repository Port làm persistence. Response là DTO, không trả Entity trực tiếp.

### 8.5 Swagger và test

- Thêm `@Operation`/`@ApiResponse` cho 200, 201, 400, 401, 403, 404, 409.
- Unit test: `WarehouseCommandServiceImpl` (mock Port), `WarehouseQueryServiceImpl` (mock Port).
- Integration test (MockMvc): JSON validation, status code, response DTO, JWT.
- Migration chưa có FK `warehouse_id` trong `warehouse_zones`; nếu thêm FK, migration và JPA mapping cập nhật đồng thời.
