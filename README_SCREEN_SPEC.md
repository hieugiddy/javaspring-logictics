# Đặc tả Logistics Warehouse — Nghiệp vụ, Màn hình và API

Tài liệu này là nguồn đặc tả tổng hợp cho phạm vi nghiệp vụ, ranh giới microservice, luồng màn hình, hợp đồng HTTP, kiểm tra dữ liệu, phân quyền, lưu trữ, sự kiện và tiêu chí nghiệm thu. Hướng dẫn môi trường/build/CI/CD nằm trong [README_CICD_FILES.md](README_CICD_FILES.md).

> Đây là hợp đồng mục tiêu để triển khai. Các endpoint được đề xuất và các thiếu sót schema được ghi rõ bên dưới cần được đối chiếu với mã nguồn trước khi xem là chức năng đã chạy.
>
> **Tình trạng hiện tại:** thư mục service mới là khung; chưa có controller/entity Spring. Tài liệu này là bản thiết kế, không khẳng định API đã được cài đặt.

## 1. Phạm vi hệ thống

Hệ thống quản lý kho logistics gồm:

- Tài khoản, vai trò, đăng nhập, refresh session và đăng xuất.
- Kho hàng và khu vực kho.
- Danh mục sản phẩm, category và nhập/xuất CSV.
- Tra cứu tồn kho, điều chỉnh số lượng và lịch sử biến động bất biến.
- Đơn nhập/đơn xuất với chuyển trạng thái rõ ràng.
- Shipment và theo dõi vận chuyển.
- Notification phát sinh từ sự kiện nghiệp vụ.

Client là nhân viên kho/quản trị viên truy cập qua API Gateway. Base path: `/api/v1`.

## 2. Vai trò và phân quyền

| Vai trò              | Quyền mặc định                                          |
| --------------------- | ----------------------------------------------------------- |
| `VIEWER`            | Chỉ đọc tài nguyên được cấp quyền                 |
| `STAFF`             | Thực hiện nghiệp vụ kho được giao                    |
| `WAREHOUSE_MANAGER` | Quản lý nghiệp vụ tại kho được phân công          |
| `ADMIN`             | Quản lý catalog, người dùng vận hành và nghiệp vụ |
| `SUPER_ADMIN`       | Quản trị toàn hệ thống và vai trò                    |

Gateway xác thực JWT; service sở hữu nghiệp vụ phải kiểm tra quyền tại service/use-case boundary. Mọi thao tác theo kho phải xác minh người dùng được phép truy cập kho đó.

**Thiếu trong schema:** bảng `users` chưa có quan hệ gán người dùng vào kho. Trước khi áp dụng quyền `WAREHOUSE_MANAGER`, cần bổ sung bảng như `user_warehouses(user_id, warehouse_id)` và quy định ai được cấp/thu hồi quyền.

Quy tắc chung:

- Username, email, SKU, mã kho và tracking number (nếu có) phải duy nhất.
- Số lượng là số nguyên; số lượng trên order item phải dương; tồn kho không được âm.
- Mỗi lần thay đổi tồn phải ghi inventory transaction trong cùng transaction của Inventory Service.
- Không coi duplicate, xung đột đồng thời hoặc chuyển trạng thái sai là thành công.
- Service không truy cập trực tiếp bảng thuộc service khác.

## 3. Kiến trúc và quyền sở hữu dữ liệu

```text
Trình duyệt / API client
          |
          v
API Gateway :8080
  |       |        |          |          |          |
  v       v        v          v          v          v
User    Product  Inventory   Order    Shipping  Notification
:8081    :8082    :8083       :8084     :8085       :8086
  |       |        |            |          |           |
  DB      DB       DB           DB         DB          DB
                   |            |
                   +--- sự kiện RabbitMQ ---+---------> consumer
```

| Service              | Dữ liệu sở hữu                                                             | Trách nhiệm                                          |
| -------------------- | ------------------------------------------------------------------------------ | ------------------------------------------------------ |
| API Gateway          | Không sở hữu bảng nghiệp vụ                                              | Định tuyến và ranh giới xác thực                |
| User Service         | `users`, `refresh_tokens`                                                  | Kiểm tra mật khẩu, phát JWT, xoay/thu hồi session |
| Product Service      | `categories`, `products`                                                   | CRUD, tìm kiếm catalog, import/export CSV            |
| Inventory Service    | `warehouses`, `warehouse_zones`, `inventory`, `inventory_transactions` | Quản lý kho và tồn                                 |
| Order Service        | `orders`, `order_items`                                                    | Đơn nhập/xuất và chuyển trạng thái             |
| Shipping Service     | `shipments`                                                                  | Vận chuyển và tracking                              |
| Notification Service | `notifications`                                                              | API thông báo và RabbitMQ consumer                  |

REST dùng cho truy vấn/lệnh cần phản hồi tức thời. RabbitMQ dùng cho notification và sự kiện bất đồng bộ. Luồng qua nhiều service dùng saga/outbox và xử lý idempotent, không dùng distributed database transaction.

## 4. Quy ước HTTP chung

### Xác thực và danh sách

- API bảo vệ nhận `Authorization: Bearer <access-token>`.
- Login, refresh, Swagger và endpoint tracking công khai (nếu được bật rõ ràng) không yêu cầu access token.
- Danh sách dùng `page` bắt đầu từ 0, `size` mặc định 20/tối đa 100, `sort` theo allowlist và filter được tài liệu hóa.
- Response danh sách:

```json
{
  "items": [],
  "page": 0,
  "size": 20,
  "totalElements": 0,
  "totalPages": 0
}
```

- Dùng DTO làm hợp đồng API, không trả JPA Entity. Không trả password hash, refresh-token hash, khóa ký hoặc secret service.
- Giá tiền có hai chữ số thập phân; số lượng là số nguyên.

### Hợp đồng lỗi

```json
{
  "code": "ORDER_409",
  "message": "Trạng thái đơn hàng không cho phép thao tác này",
  "timestamp": "2026-09-29T10:00:00Z",
  "traceId": "..."
}
```

| HTTP | Ý nghĩa và xử lý trên giao diện                                                    |
| ---: | ----------------------------------------------------------------------------------------- |
|  400 | Dữ liệu/query không hợp lệ; hiển thị lỗi tại trường                            |
|  401 | Thiếu/sai/hết hạn thông tin xác thực; refresh một lần rồi yêu cầu đăng nhập |
|  403 | Đã xác thực nhưng không đủ quyền; không tự retry mutation                      |
|  404 | Không tìm thấy hoặc không tiết lộ tài nguyên                                     |
|  409 | Trùng dữ liệu/xung đột version/trạng thái; giữ form và tải lại                 |
|  422 | Vi phạm nghiệp vụ, ví dụ không đủ tồn                                            |
|  429 | Bị giới hạn tốc độ; tuân theo`Retry-After`                                       |
|  5xx | Lỗi hệ thống/mạng; giữ dữ liệu an toàn và hiển thị trace ID                    |

### 4.1. Dùng các đối tượng SQL ở giai đoạn nào?

| Đối tượng trong`schema.sql`                | Màn hình/nghiệp vụ                             | Giai đoạn sử dụng                                                             | Quy tắc                                                                                      |
| ------------------------------------------------ | -------------------------------------------------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `v_inventory_availability`                     | S03 Dashboard, S08 Tra cứu tồn                   | Sau khi kiểm tra quyền, trong bước đọc trước khi tạo response            | Dùng cho danh sách theo kho; không dùng để ghi tồn                                     |
| `mv_product_stock_summary`                     | S03 Dashboard tổng quan                           | Đọc snapshot đã refresh; refresh nền sau sự kiện tồn kho hoặc theo lịch | Hiện tổng hợp toàn hệ thống, không dùng để quyết định xuất hàng                |
| `fn_available_inventory(product, warehouse)`   | S08 Chi tiết một SKU tại một kho               | Khi cần tính tồn khả dụng cho một dòng/chi tiết                           | Hàm chỉ đọc; danh sách lớn nên dùng view để tránh N+1                              |
| `sp_adjust_inventory(...)`                     | S08 Điều chỉnh tồn                             | Sau khi kiểm tra DTO/quyền, trong transaction DB và trước commit             | Procedure cập nhật tồn và ghi lịch sử; không chạy thêm SQL update/insert thay thế   |
| `fn_set_updated_at()` và `trg_*_updated_at` | S02/S04/S05/S06/S07/S08/S09/S10/S11 khi UPDATE | Tự chạy `BEFORE UPDATE`, ngay trước khi dòng được ghi | Cập nhật timestamp trên bảng mutable; Java không tự gán `updated_at`; trigger không thay kiểm tra nghiệp vụ |
| Index thường/partial/expression/covering       | Các API danh sách và lọc                       | PostgreSQL planner chọn index khi thực thi SELECT                               | Thiết kế/đánh giá bằng`EXPLAIN (ANALYZE, BUFFERS)`                                    |
| Index trên partition                            | S08 Lịch sử tồn sau khi bảng được partition | Query có điều kiện trên partition key, thường là khoảng`created_at`    | Partition pruning loại partition không liên quan; bảng demo chưa phải bảng nghiệp vụ |

Luồng điều chỉnh tồn: **API nhận request -> kiểm tra role/kho và DTO -> mở transaction -> gọi procedure -> trigger cập nhật `updated_at` -> commit -> sau commit mới xóa cache/phát event**. Procedure lỗi thì rollback toàn bộ transaction. Với dashboard, view trả dữ liệu đọc hiện thời; materialized view là snapshot có thể trễ và cần refresh nền.

Các bảng mutable trong schema đều có `updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()`; trigger tự cập nhật giá trị này ở mọi `UPDATE`. Với API sửa dữ liệu, có thể dùng timestamp client đã đọc để phát hiện bản ghi bị sửa xen giữa:

```sql
UPDATE products
SET name = :name
WHERE id = :id
  AND updated_at = :expected_updated_at
RETURNING id, name, updated_at;
```

Nếu không có dòng trả về thì dữ liệu đã đổi hoặc không tồn tại; service đọc lại để phân biệt 404/409. `updated_at` hỗ trợ optimistic exclusion nhưng không phải khóa version tuyệt đối: PostgreSQL `NOW()` ổn định trong cùng transaction và timestamp có thể không phù hợp khi tranh chấp cao. Inventory dùng `version BIGINT`/`@Version` làm cơ chế kiểm tra chính; các bảng khác có thể bổ sung `version` nếu cần kiểm soát concurrency chặt hơn.

## 5. Đăng nhập và quản lý session

### S01 — Đăng nhập

**Nghiệp vụ:** xác thực tài khoản đang hoạt động, cấp access JWT ngắn hạn và tạo refresh session. Không bao giờ trả password hash.

**Input**

```http
POST /api/v1/auth/login
Content-Type: application/json
```

```json
{"username":"staff01","password":"DemoPass!2026"}
```

**Output — 200**

```json
{
  "accessToken":"<signed-jwt>",
  "refreshToken":"<opaque-random-token>",
  "tokenType":"Bearer",
  "expiresIn":900,
  "user":{"id":"11111111-1111-4111-8111-111111111111","username":"staff01","email":"staff01@example.test","role":"STAFF"}
}
```

**Logic:** validate DTO -> tìm user theo username/email -> tài khoản không tồn tại/không hoạt động hoặc sai mật khẩu đều trả cùng lỗi 401 -> BCrypt verify -> phát token -> hash refresh token -> lưu hash và hạn dùng -> trả profile an toàn.

**SQL — User Service DB**

```sql
SELECT id, username, email, password_hash, role, status
FROM users
WHERE username = :login OR email = :login;

INSERT INTO refresh_tokens
    (user_id, token_hash, jti, expires_at, created_at)
VALUES
    (:user_id, :refresh_token_hash, :jti, :expires_at, NOW());
```

**Data mẫu đã lưu:** user `staff01`, role `STAFF`, status `ACTIVE`; `refresh_tokens.token_hash` chỉ chứa hash, không lưu `DemoPass!2026` hay refresh token thô.

### S02 — Refresh, logout và hồ sơ hiện tại

**Nghiệp vụ:** xoay refresh session; thu hồi một session hoặc tất cả session; chỉ trả hồ sơ của user đang đăng nhập.

**Input mẫu**

```http
POST /api/v1/auth/refresh
Content-Type: application/json
```

```json
{"refreshToken":"<opaque-random-token>"}
```

```http
POST /api/v1/auth/logout
Authorization: Bearer <access-token>
Content-Type: application/json
```

```json
{"refreshToken":"<opaque-random-token>"}
```

**API:** `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`, `POST /api/v1/auth/logout-all`, `GET /api/v1/auth/me`.

**Output:** refresh trả cặp token mới; logout/logout-all trả `204 No Content`; `/auth/me` trả `id`, `username`, `email`, `role`, `status`.

```json
{"id":"11111111-1111-4111-8111-111111111111","username":"staff01","email":"staff01@example.test","role":"STAFF","status":"ACTIVE"}
```

**Logic:** hash token đầu vào -> tìm session chưa revoke và chưa hết hạn -> revoke token cũ và insert token mới trong một transaction. Logout-all revoke các session của user hiện tại. Dùng lại token đã revoke -> 401.

**SQL**

```sql
SELECT id, user_id, jti, expires_at, revoked_at
FROM refresh_tokens
WHERE token_hash = :token_hash;

UPDATE refresh_tokens
SET revoked_at = NOW(), last_used_at = NOW(), replaced_by_jti = :replacement_jti
WHERE id = :session_id AND revoked_at IS NULL AND expires_at > NOW();

UPDATE refresh_tokens
SET revoked_at = NOW()
WHERE user_id = :user_id AND revoked_at IS NULL;
```

### JWT và kiểm tra token

```json
{
  "sub":"<user-uuid>","username":"staff01","role":"STAFF",
  "iss":"logistics-user-service","aud":"logistics-api",
  "iat":1700000000,"exp":1700000900,"jti":"<uuid>"
}
```

Kiểm tra chữ ký, `exp`, `nbf`, `iss`, `aud`; ánh xạ role thành Spring Security authority. Các service downstream phải kiểm tra cùng issuer/audience và áp dụng authorization.

## 6. Danh mục màn hình và API

Tất cả path dưới đây nằm sau `/api/v1`.

| Màn hình            | API chính                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| S03 Dashboard         | `GET /dashboard?warehouseId=&from=&to=`                                                        |
| S04 Người dùng     | `GET/POST/PATCH /users...`                                                                     |
| S05 Category          | `GET/POST/PUT/DELETE /categories...`                                                           |
| S06 Sản phẩm        | `GET/POST/PUT/DELETE /products...`, `POST /products/import`, `GET /products/export`        |
| S07 Kho/zone          | `GET/POST/PUT/DELETE /warehouses...` và `/warehouses/{warehouseId}/zones...`                |
| S08 Tồn kho          | `GET /inventory`, `POST /inventory/adjust`, `GET /inventory/transactions`                  |
| S09 Đơn nhập/xuất | `GET/POST /orders...`, `PUT /orders/{id}/confirm`, `PUT /orders/{id}/cancel`               |
| S10 Shipment          | `GET/POST /shipments...`, `PUT /shipments/{id}/status`                                       |
| S11 Notification      | `GET /notifications...`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all` |

Route chưa có implementation phải được bổ sung vào Gateway/service sở hữu, quyền, Swagger và test trước khi UI sử dụng.

## 7. S03 — Dashboard

**Nghiệp vụ:** tổng hợp nhanh tình hình theo kho và khoảng thời gian; chỉ đọc, mọi số liệu phải theo phạm vi kho người dùng được truy cập.

**Input:** `GET /api/v1/dashboard?warehouseId=10&from=2026-09-01&to=2026-09-30`. Ngày cuối được chuyển thành khoảng nửa mở `to_exclusive` khi truy vấn SQL.

**Output mẫu**

```json
{
  "warehouseId":10,
  "period":{"from":"2026-09-01","to":"2026-09-30"},
  "inventory":{"skuCount":1,"onHandQuantity":120,"reservedQuantity":8,"availableQuantity":112},
  "orders":{"inboundOpen":1,"outboundOpen":1},
  "dailyMovement":[]
}
```

**Logic:** xác minh quyền kho -> gọi aggregate từ Inventory/Order service sở hữu dữ liệu -> ghép DTO tại dashboard projection/Gateway -> cache TTL ngắn -> invalidation theo domain event. Ngày sai -> 400; không đủ quyền -> 403/404 theo chính sách không tiết lộ tài nguyên.

**SQL — Inventory Service DB**

```sql
SELECT COUNT(*) AS sku_count,
       COALESCE(SUM(quantity), 0) AS on_hand_quantity,
       COALESCE(SUM(reserved_quantity), 0) AS reserved_quantity,
       COALESCE(SUM(quantity - reserved_quantity), 0) AS available_quantity
FROM v_inventory_availability
WHERE warehouse_id = :warehouse_id;
```

`v_inventory_availability` là view đọc hiện thời theo từng kho. `mv_product_stock_summary` chỉ dùng cho thẻ tổng hợp toàn hệ thống vì view vật hóa hiện không có `warehouse_id`:

```sql
SELECT product_id, sku, product_name, total_quantity, total_reserved, total_available
FROM mv_product_stock_summary
ORDER BY sku;
```

Refresh materialized view ở worker/scheduler sau khi nhận sự kiện tồn kho hoặc theo lịch, không refresh đồng bộ trong request dashboard:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock_summary;
```

Lệnh `CONCURRENTLY` cần unique index và phải chạy ngoài transaction block.

**SQL — Order Service DB** (chạy riêng, không join database service khác)

```sql
SELECT type, status, COUNT(*) AS order_count
FROM orders
WHERE status IN ('PENDING', 'CONFIRMED', 'PROCESSING')
GROUP BY type, status;
```

**SQL — tổng nhập/xuất theo ngày**

```sql
SELECT DATE_TRUNC('day', created_at)::date AS movement_date,
       SUM(CASE WHEN transaction_type = 'INBOUND' THEN quantity ELSE 0 END) AS inbound_quantity,
       SUM(CASE WHEN transaction_type = 'OUTBOUND' THEN quantity ELSE 0 END) AS outbound_quantity
FROM inventory_transactions
WHERE warehouse_id = :warehouse_id
  AND created_at >= :from_inclusive
  AND created_at < :to_exclusive
GROUP BY DATE_TRUNC('day', created_at)::date
ORDER BY movement_date;
```

**Thiếu trong schema:** `products` chưa có `min_stock`, chưa thể tính KPI hàng dưới định mức. `orders` chưa có warehouse/date scope nên số đơn hiện chỉ tổng toàn hệ thống; không được gắn nhãn số tổng này là số theo kho.

## 8. S04 — Quản lý người dùng và vai trò

**Nghiệp vụ:** tạo/cập nhật tài khoản, không làm lộ credential và ngăn tự nâng quyền.

**Input mẫu**

```http
POST /api/v1/users
Authorization: Bearer <admin-token>
Content-Type: application/json
```

```json
{"username":"staff01","email":"staff01@example.test","initialPassword":"DemoPass!2026","role":"STAFF","status":"ACTIVE"}
```

**Output mẫu**

```json
{"id":"11111111-1111-4111-8111-111111111111","username":"staff01","email":"staff01@example.test","role":"STAFF","status":"ACTIVE","createdAt":"2026-09-29T09:00:00Z"}
```

**API:** `GET /api/v1/users?page=0&size=20&keyword=staff&role=STAFF&status=ACTIVE`; `GET /users/{id}`; `POST /users`; `PATCH /users/{id}`; `PATCH /users/{id}/status`.

**Logic:** SUPER_ADMIN quản lý mọi role; ADMIN chỉ quản lý user không phải SUPER_ADMIN. Kiểm tra username/email/role, hash mật khẩu, cấm tự nâng quyền; revoke session khi khóa tài khoản hoặc thay role nhạy cảm. Trùng username/email -> 409.

**SQL — User Service DB**

```sql
SELECT id, username, email, role, status, created_at, updated_at
FROM users
WHERE (:keyword IS NULL OR username ILIKE '%' || :keyword || '%' OR email ILIKE '%' || :keyword || '%')
  AND (:role IS NULL OR role = :role)
  AND (:status IS NULL OR status = :status)
ORDER BY created_at DESC
LIMIT :size OFFSET (:page * :size);

INSERT INTO users (username, email, password_hash, role, status)
VALUES (:username, :email, :password_hash, :role, :status)
RETURNING id, username, email, role, status, created_at;
```

Khi `PATCH` user, `trg_users_updated_at` chạy ở giai đoạn `BEFORE UPDATE`; ứng dụng không cần tự gán `updated_at`. Trigger này không chạy khi `INSERT`.

## 9. S05 — Danh mục category

**Nghiệp vụ:** phân loại sản phẩm để lọc/tổng hợp; không xóa category còn được product tham chiếu.

**Input:** `POST /api/v1/categories` với `{"name":"Packaging","description":"Boxes and packing supplies"}`. Tên bắt buộc, trim, tối đa 150 ký tự và duy nhất; mô tả tối đa 500 ký tự.

**Output mẫu:** `{"id":1,"name":"Packaging","description":"Boxes and packing supplies","createdAt":"2026-09-29T09:00:00Z"}`.

**API:** `GET /categories?page=0&size=20&keyword=pack`; `GET /categories/{id}`; `POST`; `PUT /{id}`; `DELETE /{id}`. ADMIN/SUPER_ADMIN được sửa; role catalog được đọc.

**SQL — Product Service DB**

```sql
SELECT id, name, description, created_at
FROM categories
WHERE (:keyword IS NULL OR name ILIKE '%' || :keyword || '%')
ORDER BY name
LIMIT :size OFFSET (:page * :size);

INSERT INTO categories (name, description)
VALUES (:name, :description)
RETURNING id, name, description, created_at;

SELECT EXISTS (SELECT 1 FROM products WHERE category_id = :category_id);
```

Nếu category còn product tham chiếu, từ chối xóa với 409 hoặc yêu cầu chuyển product sang category khác trong thao tác riêng.

## 10. S06 — Catalog sản phẩm và CSV

**Nghiệp vụ:** quản lý SKU, hỗ trợ lọc/tìm kiếm và trao đổi catalog bằng CSV.

**Input tạo/cập nhật**

```json
{"sku":"SKU-001","name":"Packing Box M","description":"Medium box","price":125000.00,"categoryId":1,"status":"ACTIVE"}
```

**Output mẫu**

```json
{"id":1001,"sku":"SKU-001","name":"Packing Box M","description":"Medium box","price":125000.00,"categoryId":1,"status":"ACTIVE","createdAt":"2026-09-29T09:05:00Z"}
```

**API catalog:** `GET /api/v1/products?page=0&size=20&keyword=box&categoryId=1&status=ACTIVE&sort=name,asc`; `GET /products/{id}`; `POST /products`; `PUT /products/{id}`; `DELETE /products/{id}`.

**Logic catalog:** SKU duy nhất; giá không âm; category phải tồn tại; status là `ACTIVE|INACTIVE`; sort chỉ nhận cột trong allowlist. Ưu tiên chuyển `INACTIVE` thay vì xóa product đã có lịch sử.

**SQL tìm kiếm/tạo sản phẩm**

```sql
SELECT p.id, p.sku, p.name, p.description, p.price, p.category_id, p.status,
       p.created_at, p.updated_at
FROM products p
WHERE (:keyword IS NULL OR p.sku ILIKE '%' || :keyword || '%' OR p.name ILIKE '%' || :keyword || '%')
  AND (:category_id IS NULL OR p.category_id = :category_id)
  AND (:status IS NULL OR p.status = :status)
ORDER BY p.name ASC
LIMIT :size OFFSET (:page * :size);

INSERT INTO products (sku, name, description, price, category_id, status)
VALUES (:sku, :name, :description, :price, :category_id, :status)
RETURNING id, sku, name, description, price, category_id, status, created_at;
```

**CSV nhập mẫu**

```csv
sku,name,description,price,categoryId,status
SKU-001,Packing Box M,Medium box,125000.00,1,ACTIVE
SKU-002,Stretch Wrap,Clear 30cm roll,89000.00,1,ACTIVE
```

### S06a — Import sản phẩm bằng CSV

**API:** `POST /api/v1/products/import`, `multipart/form-data`, field `file`. Người dùng cần quyền `ADMIN` hoặc `SUPER_ADMIN`.

**Giới hạn và quy tắc:** UTF-8, chấp nhận BOM ở đầu file; tối đa mặc định 10 MB/10.000 dòng dữ liệu (cấu hình được). Header bắt buộc theo đúng tập cột `sku,name,description,price,categoryId,status`; chuẩn hóa khoảng trắng/header nhưng không tự đoán cột. SKU/name bắt buộc; giá phải parse được và không âm; category phải tồn tại; status chỉ `ACTIVE|INACTIVE`; dòng trùng SKU trong file hoặc DB bị từ chối.

**Xử lý:** kiểm tra kích thước -> parse CSV theo chuẩn dấu quote/escape -> validate toàn bộ dòng và gom lỗi -> nếu có lỗi thì không ghi dữ liệu -> nếu hợp lệ, batch insert trong một transaction -> commit -> trả thống kê. Không dùng `split(',')` vì description có thể chứa dấu phẩy/quote/newline.

**Output thành công — 200**

```json
{"fileName":"products.csv","totalRows":2,"importedRows":2,"rejectedRows":0,"errors":[]}
```

**Output có lỗi — 400**

```json
{
  "fileName":"products.csv","totalRows":2,"importedRows":0,"rejectedRows":1,
  "errors":[{"row":3,"column":"price","value":"-5","message":"Giá phải lớn hơn hoặc bằng 0"}]
}
```

**SQL:** sau khi validate category/SKU, insert theo batch trong transaction. Mẫu một dòng:

```sql
INSERT INTO products (sku, name, description, price, category_id, status)
VALUES (:sku, :name, :description, :price, :category_id, :status);
```

Bắt lỗi unique violation để trả lỗi dòng/SKU; rollback toàn bộ file theo chính sách all-or-nothing. Trả tối đa số lỗi cấu hình để không tạo response quá lớn.

### S06b — Export sản phẩm bằng CSV

**API:** `GET /api/v1/products/export?keyword=box&categoryId=1&status=ACTIVE`; cùng filter với màn danh sách, không nhận `page/size` vì export toàn bộ kết quả lọc. Yêu cầu đăng nhập; giới hạn quyền theo chính sách catalog.

**Response:** `200 OK`, `Content-Type: text/csv; charset=UTF-8`, `Content-Disposition: attachment; filename="products-20260929.csv"`. Tên cột ổn định:

```text
sku,name,description,price,categoryId,categoryName,status,createdAt
```

**File mẫu**

```csv
sku,name,description,price,categoryId,categoryName,status,createdAt
SKU-001,"Packing Box M","Medium box",125000.00,1,Packaging,ACTIVE,2026-09-29T09:05:00Z
SKU-002,"Stretch Wrap","Clear, 30cm roll",89000.00,1,Packaging,ACTIVE,2026-09-29T09:10:00Z
```

**Logic:** validate filter/sort -> truy vấn theo filter -> stream từng dòng để không giữ toàn bộ kết quả trong RAM -> escape dấu quote/comma/newline theo CSV -> xuất UTF-8 (nếu yêu cầu mở Excel có thể bật BOM bằng cấu hình). Với trường văn bản bắt đầu bằng `=`, `+`, `-`, `@`, tab hoặc carriage return, thêm dấu nháy đơn để giảm rủi ro formula injection; không sửa giá trị số đã validate. Không ghi token/secret vào file.

**SQL — Product Service DB**

```sql
SELECT p.sku, p.name, p.description, p.price,
       p.category_id, c.name AS category_name, p.status, p.created_at
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
WHERE (:keyword IS NULL OR p.sku ILIKE '%' || :keyword || '%' OR p.name ILIKE '%' || :keyword || '%')
  AND (:category_id IS NULL OR p.category_id = :category_id)
  AND (:status IS NULL OR p.status = :status)
ORDER BY p.name ASC, p.id ASC;
```

Truy vấn export không phân trang nhưng phải dùng cursor/fetch size và stream response. Có thể thêm giới hạn số dòng, async export hoặc file tạm khi dữ liệu lớn.

**Test CSV bắt buộc:** BOM/UTF-8 tiếng Việt; dấu phẩy/quote/newline trong description; file rỗng; thiếu/thừa header; SKU trùng; category không tồn tại; giá sai/âm; file vượt giới hạn; không import từng phần khi một dòng lỗi; export đúng filter/order; chống formula injection; không rò dữ liệu khác tenant/kho nếu có scope.

**Schema note:** bảng `products` hiện không có `created_by`; chỉ thêm nếu cần audit owner.

Khi `PUT` sản phẩm, `trg_products_updated_at` tự cập nhật `updated_at` ở bước `BEFORE UPDATE`; service không truyền timestamp này. Import bằng `INSERT` không kích hoạt trigger.

## 11. S07 — Kho và zone

**Nghiệp vụ:** khai báo cơ sở vật lý và khu vực; code zone chỉ duy nhất trong một kho.

**Input kho**

```json
{"code":"WH-HCM-01","name":"Kho chính TP.HCM","location":"Quận 7","address":"12 Sample Street"}
```

**Input zone**

```json
{"code":"A-01","name":"Dãy A / Kệ 01"}
```

**Output mẫu:** `{"id":10,"code":"WH-HCM-01","name":"Kho chính TP.HCM","location":"Quận 7","address":"12 Sample Street"}`.

**API:** `GET/POST/PUT/DELETE /api/v1/warehouses...`; zone dùng `/api/v1/warehouses/{warehouseId}/zones...`. ADMIN/SUPER_ADMIN quản lý; WAREHOUSE_MANAGER cần dữ liệu gán kho.

**SQL — Inventory Service DB**

```sql
INSERT INTO warehouses (code, name, location, address)
VALUES (:code, :name, :location, :address)
RETURNING id, code, name, location, address;

INSERT INTO warehouse_zones (warehouse_id, code, name)
VALUES (:warehouse_id, :zone_code, :zone_name)
RETURNING id, warehouse_id, code, name;

SELECT id, code, name
FROM warehouse_zones
WHERE warehouse_id = :warehouse_id
ORDER BY code;
```

Khi cập nhật kho, `trg_warehouses_updated_at` tự gán `updated_at` trước khi ghi. `warehouse_zones` hiện không có cột timestamp nên không gắn trigger này cho zone.

Không xóa kho đang được inventory/history/order tham chiếu hoặc zone đang có inventory. Mã trùng -> 409.

## 12. S08 — Tra cứu, điều chỉnh và lịch sử tồn kho

**Nghiệp vụ:** hiển thị tồn thực tế/đã giữ/có thể dùng; chỉ người được phân quyền tại kho mới được điều chỉnh.

**API tra cứu:** `GET /api/v1/inventory?warehouseId=10&productId=1001&page=0&size=20`.

**Output mẫu**

```json
{"items":[{"warehouseId":10,"productId":1001,"quantity":120,"reservedQuantity":8,"availableQuantity":112,"updatedAt":"2026-09-29T09:15:00Z"}],"page":0,"size":20,"totalElements":1,"totalPages":1}
```

**API điều chỉnh:** `POST /api/v1/inventory/adjust`.

```json
{"warehouseId":10,"productId":1001,"quantityDelta":5,"reason":"CYCLE_COUNT","referenceNo":"CC-2026-001"}
```

**Logic:** xác thực kho/sản phẩm/quyền -> mở transaction -> gọi `sp_adjust_inventory` -> procedure khóa dòng khi UPDATE, kiểm tra tồn sau điều chỉnh, tăng `version` và ghi transaction bất biến -> commit -> sau commit mới xóa cache/phát event. SQLSTATE `23514` ánh xạ thành 422; `P0002` thành 404. Trigger `trg_inventory_updated_at` tự cập nhật timestamp. Không gọi procedure rồi chạy thêm UPDATE/INSERT cho cùng request.

**SQL tra cứu**

```sql
SELECT warehouse_id, product_id, quantity, reserved_quantity,
       quantity - reserved_quantity AS available_quantity, updated_at
FROM v_inventory_availability
WHERE (:warehouse_id IS NULL OR warehouse_id = :warehouse_id)
  AND (:product_id IS NULL OR product_id = :product_id)
ORDER BY warehouse_id, product_id
LIMIT :size OFFSET (:page * :size);
```

Với màn chi tiết một SKU có thể dùng function chỉ đọc:

```sql
SELECT fn_available_inventory(:product_id, :warehouse_id) AS available_quantity;
```

Không gọi function một lần cho từng dòng của danh sách lớn; dùng view để tránh N+1 query.

**Cách ưu tiên — dùng procedure trong transaction của ứng dụng**

```sql
CALL sp_adjust_inventory(:product_id, :warehouse_id, :quantity_delta, :reference_no);
```

**Cách thay thế — Java tự thực hiện SQL lạc quan**

Chỉ chọn cách này nếu không dùng `sp_adjust_inventory`; cả hai cách đều phải nằm trong cùng transaction.

```sql
UPDATE inventory
SET quantity = :new_quantity, version = version + 1
WHERE warehouse_id = :warehouse_id
  AND product_id = :product_id
  AND version = :expected_version
  AND :new_quantity >= reserved_quantity;

INSERT INTO inventory_transactions
    (product_id, warehouse_id, transaction_type, quantity, reference_no, created_at)
VALUES
    (:product_id, :warehouse_id, 'ADJUSTMENT', :quantity_delta, :reference_no, NOW());
```

  Khi dùng cách SQL thay thế, `trg_inventory_updated_at` tự gán `updated_at`. Nếu UPDATE không tác động dòng nào, rollback và phân biệt xung đột version (409) với vi phạm số lượng (422).

**Lịch sử:** `GET /api/v1/inventory/transactions?warehouseId=10&productId=1001&page=0&size=20`, mới nhất trước; không sửa transaction cũ, điều chỉnh bằng bản ghi mới.

```sql
SELECT id, product_id, warehouse_id, order_id, transaction_type,
       quantity, reference_no, created_at
FROM inventory_transactions
WHERE warehouse_id = :warehouse_id
  AND (:product_id IS NULL OR product_id = :product_id)
  AND (:transaction_type IS NULL OR transaction_type = :transaction_type)
  AND created_at >= :from_inclusive AND created_at < :to_exclusive
ORDER BY created_at DESC
LIMIT :size OFFSET (:page * :size);
```

**Thiếu trong schema:** thêm `CHECK (reserved_quantity <= quantity)`; `inventory_transactions` chưa có `reason`/`created_by`, cần bổ sung nếu yêu cầu audit.

## 13. S09 — Đơn nhập/xuất

**Nghiệp vụ:** tạo đơn có loại, kiểm tra dòng hàng, rồi chuyển trạng thái hợp lệ. Nhập làm tăng tồn khi nhận; xuất kiểm tra/giữ tồn rồi bàn giao cho Shipping.

**Input/API:** `POST /api/v1/orders`.

```json
{"type":"OUTBOUND","warehouseId":10,"items":[{"productId":1001,"quantity":3}]}
```

**Output mẫu**

```json
{"id":"22222222-2222-4222-8222-222222222222","orderNo":"OUT-2026-0001","type":"OUTBOUND","status":"PENDING","totalAmount":375000.00,"items":[{"productId":1001,"quantity":3,"unitPrice":125000.00}]}
```

**API:** `GET /api/v1/orders?type=OUTBOUND&status=PENDING&warehouseId=10&page=0&size=20`; `GET /orders/{id}`; `POST /orders`; `PUT /orders/{id}/confirm`; `PUT /orders/{id}/cancel`.

**Logic:** `type` là `INBOUND|OUTBOUND`; có ít nhất một item; quantity dương; total do server tính; xác minh quyền kho. Confirm phải khóa/kiểm tra tồn và chỉ chuyển trạng thái được phép. Cancel giải phóng reservation nếu có. Luồng nhiều service dùng saga/outbox và event idempotent.

**SQL — schema Java hiện tại**

```sql
INSERT INTO orders (id, order_no, user_id, type, status, total_amount)
VALUES (:id, :order_no, :user_id, :type, 'PENDING', :total_amount);

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (:order_id, :product_id, :quantity, :unit_price);

SELECT o.id, o.order_no, o.user_id, o.type, o.status, o.total_amount,
       o.created_at, oi.product_id, oi.quantity, oi.unit_price
FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE o.id = :order_id;

UPDATE orders SET status = 'CONFIRMED'
WHERE id = :order_id AND status = 'PENDING';
```

Khi UPDATE order, `trg_orders_updated_at` tự cập nhật `updated_at` ở giai đoạn ghi dòng. Trigger không kiểm tra quyền hoặc state transition; service phải kiểm tra trước lệnh này.

**Thiếu trong schema:** `orders` chưa có `warehouse_id`; order item chưa lưu số lượng đã nhận/đã pick; chưa có trạng thái nghiệp vụ đủ chi tiết. Cần migration trước khi nhận diện scope kho/nhận hàng/pick-pack-shipping. Trạng thái sai -> 409; thiếu tồn -> 422.

## 14. S10 — Shipment và tracking

**Nghiệp vụ:** tạo tối đa một shipment cho đơn xuất đủ điều kiện và cập nhật trạng thái vận chuyển theo transition hợp lệ.

**Input/API:** `POST /api/v1/shipments`.

```json
{"orderId":"22222222-2222-4222-8222-222222222222","carrier":"VNPost","trackingNumber":"VN-TRACK-0001"}
```

**Output mẫu:** `{"id":"33333333-3333-4333-8333-333333333333","orderId":"22222222-2222-4222-8222-222222222222","carrier":"VNPost","trackingNumber":"VN-TRACK-0001","status":"CREATED"}`.

**API:** `GET /api/v1/shipments?status=IN_TRANSIT&page=0&size=20`; `GET /shipments/{id}`; `PUT /shipments/{id}/status` với `{"status":"IN_TRANSIT"}`.

**Logic:** kiểm tra order đủ điều kiện -> insert shipment -> khi đổi trạng thái, kiểm tra transition -> persist -> phát `shipment.status.changed`. Trùng order/tracking -> 409.

**SQL — Shipping Service DB**

```sql
INSERT INTO shipments (order_id, carrier, tracking_number, status)
VALUES (:order_id, :carrier, :tracking_number, 'CREATED')
RETURNING id, order_id, carrier, tracking_number, status, created_at;

UPDATE shipments SET status = :new_status
WHERE id = :shipment_id AND status = :expected_status;
```

Trong SQL nghiệp vụ, chỉ cập nhật `status`; `trg_shipments_updated_at` tự gán timestamp trong bước `BEFORE UPDATE`. Service vẫn phải xác thực quyền và trạng thái chuyển tiếp trước khi chạy UPDATE.

## 15. S11 — Notification

**Nghiệp vụ:** hiển thị thông báo của user hiện tại, đánh dấu một/tất cả đã đọc và tránh tạo bản sao khi RabbitMQ giao lại message.

**API:** `GET /api/v1/notifications?status=UNREAD&page=0&size=20`; `GET /notifications/{id}`; `PATCH /notifications/{id}/read`; `PATCH /notifications/read-all`.

**Output mẫu**

```json
{"items":[{"id":"44444444-4444-4444-8444-444444444444","type":"ORDER_COMPLETED","title":"Đơn hàng đã hoàn tất","message":"OUT-2026-0001 đã được giao cho vận chuyển","status":"UNREAD","createdAt":"2026-09-29T10:00:00Z"}],"page":0,"size":20,"totalElements":1,"totalPages":1}
```

**Logic:** luôn lọc theo `user_id` lấy từ JWT; mark-read idempotent. Consumer phải lưu notification trước ACK; một `event_id`/người nhận chỉ tạo tối đa một dòng.

**SQL — Notification Service DB**

```sql
SELECT id, event_id, type, title, message, status, created_at
FROM notifications
WHERE user_id = :user_id
  AND (:status IS NULL OR status = :status)
ORDER BY created_at DESC LIMIT :size OFFSET (:page * :size);

UPDATE notifications SET status = 'READ'
WHERE id = :notification_id AND user_id = :user_id AND status <> 'READ';

INSERT INTO notifications (user_id, event_id, type, title, message, status)
VALUES (:user_id, :event_id, :type, :title, :message, 'UNREAD')
ON CONFLICT (event_id, user_id) DO NOTHING;
```

## 16. S12 — Lỗi và trạng thái rỗng

| Tình huống          | Ví dụ                           | Xử lý trên giao diện                                          |
| --------------------- | --------------------------------- | ----------------------------------------------------------------- |
| Validation            | SKU rỗng, giá âm               | Đánh dấu trường lỗi, không gửi request                    |
| Chưa xác thực      | JWT hết hạn                     | Refresh một lần, nếu thất bại thì về đăng nhập          |
| Không đủ quyền    | STAFF sửa role user              | Hiển thị thông báo quyền; không tự retry                   |
| Không tìm thấy     | Product đã bị xóa             | Hiển thị trạng thái không tìm thấy và quay về danh sách |
| Xung đột            | SKU trùng, version tồn kho cũ  | Giữ dữ liệu form, thông báo xung đột và tải lại         |
| Vi phạm nghiệp vụ  | Xuất nhiều hơn tồn khả dụng | Hiển thị số lượng còn dùng được                         |
| Danh sách rỗng      | Không có kết quả filter       | Hiển thị nút xóa filter                                       |
| Lỗi mạng/hệ thống | Service timeout                   | Giữ bản nháp an toàn, hiển thị trace ID và nút thử lại  |

## 17. Lược đồ dữ liệu và quy tắc lưu trữ

PostgreSQL là nguồn dữ liệu chuẩn. Mỗi service sở hữu bảng và migration của bounded context. Dùng Flyway; không sửa migration đã chạy trên môi trường dùng chung.

| Cách lưu trữ | Trường hợp phù hợp                                                                            |
| --------------- | -------------------------------------------------------------------------------------------------- |
| Hibernate/JPA   | CRUD đơn giản, vòng đời aggregate, optimistic locking, auditing                              |
| MyBatis         | Join/read model phức tạp, filter động, báo cáo, batch, query cần kiểm soát execution plan |

Không dùng cả hai cho cùng entity/use case nếu không có lý do. Dùng prepared parameter; whitelist cột sort; chỉ select cột cần thiết; phân trang dữ liệu lớn.

Các bảng trong `docs/SQL/schema.sql`:

- User: `users`, `refresh_tokens`.
- Product: `categories`, `products`.
- Inventory: `warehouses`, `warehouse_zones`, `inventory`.
- Order: `orders`, `order_items`.
- Lịch sử tồn: `inventory_transactions`.
- Vận chuyển: `shipments`.
- Thông báo: `notifications`.

Ràng buộc/index chính: username/email/SKU/mã kho/tracking number duy nhất; `(warehouse_id, code)` của zone duy nhất; order quantity dương; tồn không âm; index category, warehouse inventory, trạng thái/thời gian order, order item, inventory history, shipment status, notification user/status/time.

Ví dụ về view/materialized view, function, procedure, trigger, B-tree/composite/partial/expression/covering index và partition RANGE/LIST/HASH nằm cuối `docs/SQL/schema.sql`. PostgreSQL tạo index cục bộ trên từng partition; thuật ngữ global index theo Oracle không áp dụng trực tiếp.

**Các thiếu sót cần migration:** bảng gán user-kho; `products.min_stock`; `orders.warehouse_id`; số lượng nhận/pick và trạng thái inbound/outbound chi tiết; ràng buộc `reserved_quantity <= quantity`; audit fields `created_by/reason` cho transaction tồn kho nếu cần.

## 18. Transaction, khóa và hiệu năng

Luồng thay đổi tồn:

```text
BEGIN
  khóa dòng (SELECT FOR UPDATE) hoặc kiểm tra @Version
  kiểm tra tồn hiện tại/reserved/available
  cập nhật inventory và version
  insert inventory_transactions
  lưu outbox event nếu cần
COMMIT
sau commit mới dispatch event và invalidation cache an toàn
```

Dùng optimistic `@Version` khi xung đột ít; dùng pessimistic lock cho các request cùng phân bổ tồn. Không cập nhật inventory và history ở hai transaction tách rời. Đo query chậm bằng `EXPLAIN ANALYZE`; tránh N+1, truy vấn không giới hạn, sort động không kiểm soát và giữ lock quá lâu. Tối ưu index, connection pool, batch và timeout dựa trên số đo.

## 19. Redis

Redis không phải nguồn dữ liệu chuẩn. Luồng cache-aside: cache hit thì trả dữ liệu; cache miss gọi DB/service sở hữu rồi set TTL. Key tham khảo:

```text
product:{id}
inventory:{warehouseId}:{productId}
rate-limit:{clientId}
lock:inventory:{warehouseId}:{productId}
```

Mutation thành công: commit DB trước rồi evict/update key liên quan; dashboard/tồn biến động dùng TTL ngắn. Distributed lock không thay thế constraint và transaction DB. Mỗi endpoint cần ghi rõ TTL, tập key invalidation và mức chấp nhận dữ liệu cũ.

## 20. RabbitMQ

Exchange: `warehouse.events`.

| Routing key                 | Ý nghĩa                                            |
| --------------------------- | ---------------------------------------------------- |
| `inventory.updated`       | Điều chỉnh tồn hoặc ảnh hưởng tồn từ order |
| `order.created`           | Order Service tạo đơn                             |
| `order.completed`         | Quy trình đơn hoàn tất                          |
| `shipment.status.changed` | Shipping thay đổi trạng thái                     |
| `notification.created`    | Sự kiện notification nếu dùng như domain event  |

Message gồm event ID, loại event, thời điểm phát sinh, aggregate/reference ID, actor nếu có và correlation ID. Delivery là at-least-once. Consumer dùng manual ACK, idempotency, retry có giới hạn/backoff, DLX/DLQ và log có cấu trúc. Không ACK trước khi tác động dữ liệu được commit.

## 21. Test và Swagger

- **Unit:** JUnit 5 + Mockito cho validation, chuyển trạng thái, quyền, pricing và quy tắc tồn.
- **API:** MockMvc/WebTestClient kiểm tra status, DTO/error contract, pagination, JWT, quyền và validation.
- **Integration:** Spring Boot Test + Testcontainers cho PostgreSQL; thêm Redis/RabbitMQ container khi kiểm tra tích hợp tương ứng.
- **Messaging:** duplicate event, retry, DLQ, ACK sau persistence, idempotency, correlation ID.
- **Security matrix:** không/sai/hết hạn token -> 401; token hợp lệ nhưng sai role -> 403; đúng role -> 2xx phù hợp.
- **Swagger:** mọi endpoint mô tả DTO, validation, quyền, response thành công/lỗi và Bearer scheme. Path (có thể kèm context path): `/swagger-ui.html`, `/v3/api-docs`, `/v3/api-docs.yaml`.

## 22. Tiêu chí hoàn thành tính năng

```text
API + request/response DTO + validation
+ kiểm tra quyền và ownership
+ schema/migration và service sở hữu dữ liệu
+ transaction/locking khi cần
+ cache/event side effect khi cần
+ unit test + integration/API test phù hợp
+ Swagger example + error mapping + structured log
+ tài liệu và loading/empty/error state trên giao diện
```

## 23. Lộ trình học và triển khai

1. Môi trường, Gradle/WAR/Tomcat, endpoint đầu tiên, Swagger.
2. DI/layer, REST, DTO validation, error handling.
3. SQL/schema/index, JPA/Hibernate, MyBatis search.
4. User/password/JWT/refresh rotation/RBAC.
5. Transaction, locking, order/inventory workflow.
6. Redis TTL/invalidation và RabbitMQ retry/DLQ/idempotency.
7. Gateway/ranh giới service/notification consumer.
8. Unit, API, security và Testcontainers integration test.
9. Hiệu năng query, Docker, Jenkins, smoke/rollback.
10. Demo end-to-end và rà Definition of Done.

## 24. Tài sản hỗ trợ

- `docs/SQL/schema.sql` — schema PostgreSQL nền cho đặc tả này.
- `docs/ERD.png` — sơ đồ quan hệ dữ liệu.
- `docs/architecture-overview.png` — sơ đồ service.
- `docs/auth-flow.png` — sơ đồ login/JWT.

## 25. Data mẫu xuyên suốt

Fixture dưới đây dành cho **một database học tập cục bộ** chạy schema Java. Production tách database theo service; không dùng fixture này để biện minh cho cross-service join.

```sql
INSERT INTO users (id, username, email, password_hash, role, status)
VALUES ('11111111-1111-4111-8111-111111111111', 'staff01', 'staff01@example.test', '<bcrypt-hash>', 'STAFF', 'ACTIVE');

INSERT INTO categories (id, name, description)
VALUES (1, 'Packaging', 'Packing materials');

INSERT INTO products (id, sku, name, description, price, category_id, status)
VALUES (1001, 'SKU-001', 'Packing Box M', 'Medium box', 125000.00, 1, 'ACTIVE');

INSERT INTO warehouses (id, code, name, location, address)
VALUES (10, 'WH-HCM-01', 'Kho chính TP.HCM', 'Quận 7', '12 Sample Street');

INSERT INTO warehouse_zones (id, warehouse_id, code, name)
VALUES (101, 10, 'A-01', 'Dãy A / Kệ 01');

INSERT INTO inventory (product_id, warehouse_id, quantity, reserved_quantity, version)
VALUES (1001, 10, 120, 8, 1);

INSERT INTO orders (id, order_no, user_id, type, status, total_amount)
VALUES ('22222222-2222-4222-8222-222222222222', 'OUT-2026-0001', '11111111-1111-4111-8111-111111111111', 'OUTBOUND', 'PENDING', 375000.00);

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES ('22222222-2222-4222-8222-222222222222', 1001, 3, 125000.00);

INSERT INTO shipments (id, order_id, carrier, tracking_number, status)
VALUES ('33333333-3333-4333-8333-333333333333', '22222222-2222-4222-8222-222222222222', 'VNPost', 'VN-TRACK-0001', 'CREATED');

INSERT INTO notifications (id, user_id, event_id, type, title, message, status)
VALUES ('44444444-4444-4444-8444-444444444444', '11111111-1111-4111-8111-111111111111', 'evt-order-0001', 'ORDER_CREATED', 'Đã tạo đơn hàng', 'OUT-2026-0001 đã được tạo', 'UNREAD');

SELECT setval(pg_get_serial_sequence('categories', 'id'), (SELECT MAX(id) FROM categories));
SELECT setval(pg_get_serial_sequence('products', 'id'), (SELECT MAX(id) FROM products));
SELECT setval(pg_get_serial_sequence('warehouses', 'id'), (SELECT MAX(id) FROM warehouses));
SELECT setval(pg_get_serial_sequence('warehouse_zones', 'id'), (SELECT MAX(id) FROM warehouse_zones));
```

Chỉ dùng ID cố định cho fixture local. `<bcrypt-hash>` là placeholder, phải thay bằng BCrypt hash do ứng dụng tạo; tuyệt đối không lưu mật khẩu thô.
