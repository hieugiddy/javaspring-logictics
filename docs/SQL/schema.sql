CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(30) NOT NULL DEFAULT 'STAFF',
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(128) NOT NULL UNIQUE,
  jti UUID NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  replaced_by_jti UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_used_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_refresh_tokens_user_revoked
  ON refresh_tokens(user_id, revoked_at);
CREATE INDEX idx_refresh_tokens_expires
  ON refresh_tokens(expires_at);

CREATE TABLE categories (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(150) NOT NULL UNIQUE,
  description VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE products (
  id BIGSERIAL PRIMARY KEY,
  sku VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  price NUMERIC(18,2) NOT NULL DEFAULT 0,
  category_id BIGINT REFERENCES categories(id),
  status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE warehouses (
  id BIGSERIAL PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  location VARCHAR(255),
  address VARCHAR(500),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE warehouse_zones (
  id BIGSERIAL PRIMARY KEY,
  warehouse_id BIGINT NOT NULL REFERENCES warehouses(id),
  code VARCHAR(50) NOT NULL,
  name VARCHAR(150) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (warehouse_id, code)
);

CREATE TABLE inventory (
  product_id BIGINT NOT NULL REFERENCES products(id),
  warehouse_id BIGINT NOT NULL REFERENCES warehouses(id),
  quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
  reserved_quantity INTEGER NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
  version BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (product_id, warehouse_id)
);

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no VARCHAR(80) NOT NULL UNIQUE,
  user_id UUID REFERENCES users(id),
  type VARCHAR(20) NOT NULL,
  status VARCHAR(30) NOT NULL,
  total_amount NUMERIC(18,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id BIGINT NOT NULL REFERENCES products(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(18,2) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory_transactions (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES products(id),
  warehouse_id BIGINT NOT NULL REFERENCES warehouses(id),
  order_id UUID REFERENCES orders(id),
  transaction_type VARCHAR(30) NOT NULL,
  quantity INTEGER NOT NULL,
  reference_no VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE shipments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL UNIQUE REFERENCES orders(id),
  carrier VARCHAR(100),
  tracking_number VARCHAR(150) UNIQUE,
  status VARCHAR(30) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  event_id VARCHAR(100) NOT NULL,
  type VARCHAR(50) NOT NULL,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'UNREAD',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (event_id, user_id)
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_inventory_warehouse ON inventory(warehouse_id);
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_inventory_tx_product_warehouse_created ON inventory_transactions(product_id, warehouse_id, created_at DESC);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_notifications_user_status ON notifications(user_id, status, created_at DESC);

-- ============================================================
-- KIẾN THỨC MỞ RỘNG: VIEW, FUNCTION, PROCEDURE, TRIGGER, INDEX
-- VÀ PARTITION (PostgreSQL)
-- ============================================================

-- 1. VIEW: đóng gói truy vấn thường dùng; view thường không lưu dữ liệu riêng.
CREATE OR REPLACE VIEW v_inventory_availability AS
SELECT i.warehouse_id,
       w.code AS warehouse_code,
       i.product_id,
       p.sku,
       p.name AS product_name,
       i.quantity,
       i.reserved_quantity,
       GREATEST(i.quantity - i.reserved_quantity, 0) AS available_quantity,
       i.updated_at
FROM inventory i
JOIN products p ON p.id = i.product_id
JOIN warehouses w ON w.id = i.warehouse_id;

-- Ví dụ: SELECT * FROM v_inventory_availability WHERE warehouse_id = 10;

-- MATERIALIZED VIEW lưu kết quả; phải refresh khi dữ liệu nguồn thay đổi.
CREATE MATERIALIZED VIEW mv_product_stock_summary AS
SELECT p.id AS product_id,
       p.sku,
       p.name AS product_name,
       COUNT(i.warehouse_id) AS warehouse_count,
       COALESCE(SUM(i.quantity), 0) AS total_quantity,
       COALESCE(SUM(i.reserved_quantity), 0) AS total_reserved,
       COALESCE(SUM(i.quantity - i.reserved_quantity), 0) AS total_available
FROM products p
LEFT JOIN inventory i ON i.product_id = p.id
GROUP BY p.id, p.sku, p.name;

CREATE UNIQUE INDEX idx_mv_product_stock_summary_product
  ON mv_product_stock_summary(product_id);

-- CONCURRENTLY cần unique index và không chạy bên trong transaction block.
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_product_stock_summary;

-- 2. FUNCTION: nhận đầu vào và trả về một giá trị/bảng; có thể gọi trong SELECT.
CREATE OR REPLACE FUNCTION fn_available_inventory(
  p_product_id BIGINT,
  p_warehouse_id BIGINT
)
RETURNS INTEGER
LANGUAGE SQL
STABLE
AS $$
  SELECT COALESCE(
    (
      SELECT i.quantity - i.reserved_quantity
      FROM inventory i
      WHERE i.product_id = p_product_id
        AND i.warehouse_id = p_warehouse_id
    ),
    0
  )::INTEGER;
$$;

-- Ví dụ: SELECT fn_available_inventory(1001, 10);

-- 3. PROCEDURE: gọi bằng CALL; ví dụ dưới đây điều chỉnh tồn và ghi lịch sử.
-- UPDATE giữ khóa dòng đến hết transaction. Nếu INSERT lịch sử lỗi, caller phải
-- rollback transaction để không giữ lại phần UPDATE.
CREATE OR REPLACE PROCEDURE sp_adjust_inventory(
  p_product_id BIGINT,
  p_warehouse_id BIGINT,
  p_quantity_delta INTEGER,
  p_reference_no VARCHAR(100) DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_inventory inventory%ROWTYPE;
BEGIN
  IF p_quantity_delta = 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Độ lệch tồn kho không được bằng 0';
  END IF;

  UPDATE inventory i
  SET quantity = i.quantity + p_quantity_delta,
      version = i.version + 1,
      updated_at = NOW()
  WHERE i.product_id = p_product_id
    AND i.warehouse_id = p_warehouse_id
    AND i.quantity + p_quantity_delta >= i.reserved_quantity
    AND i.quantity + p_quantity_delta >= 0
  RETURNING i.* INTO v_inventory;

  IF NOT FOUND THEN
    IF EXISTS (
      SELECT 1 FROM inventory
      WHERE product_id = p_product_id AND warehouse_id = p_warehouse_id
    ) THEN
      RAISE EXCEPTION USING
        ERRCODE = '23514',
        MESSAGE = 'Số lượng mới thấp hơn lượng đã giữ hoặc nhỏ hơn 0';
    ELSE
      RAISE EXCEPTION USING
        ERRCODE = 'P0002',
        MESSAGE = 'Không tìm thấy dòng tồn kho';
    END IF;
  END IF;

  INSERT INTO inventory_transactions
      (product_id, warehouse_id, transaction_type, quantity, reference_no)
  VALUES
      (p_product_id, p_warehouse_id, 'ADJUSTMENT', p_quantity_delta, p_reference_no);
END;
$$;

-- Ví dụ: CALL sp_adjust_inventory(1001, 10, 5, 'CC-2026-001');
-- Quy ước ví dụ: quantity trong transaction ADJUSTMENT là delta có dấu.

-- 4. TRIGGER: tự cập nhật updated_at trước mỗi lần UPDATE.
-- Trigger gọi function; trigger không phải nơi phù hợp để giấu nghiệp vụ lớn.
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_refresh_tokens_updated_at ON refresh_tokens;
CREATE TRIGGER trg_refresh_tokens_updated_at
BEFORE UPDATE ON refresh_tokens
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at
BEFORE UPDATE ON categories
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_warehouses_updated_at ON warehouses;
CREATE TRIGGER trg_warehouses_updated_at
BEFORE UPDATE ON warehouses
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_warehouse_zones_updated_at ON warehouse_zones;
CREATE TRIGGER trg_warehouse_zones_updated_at
BEFORE UPDATE ON warehouse_zones
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_inventory_updated_at ON inventory;
CREATE TRIGGER trg_inventory_updated_at
BEFORE UPDATE ON inventory
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON orders;
CREATE TRIGGER trg_orders_updated_at
BEFORE UPDATE ON orders
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_order_items_updated_at ON order_items;
CREATE TRIGGER trg_order_items_updated_at
BEFORE UPDATE ON order_items
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_shipments_updated_at ON shipments;
CREATE TRIGGER trg_shipments_updated_at
BEFORE UPDATE ON shipments
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_notifications_updated_at ON notifications;
CREATE TRIGGER trg_notifications_updated_at
BEFORE UPDATE ON notifications
FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 5. INDEX: chọn theo điều kiện lọc/sắp xếp thực tế; kiểm tra bằng EXPLAIN.
-- UNIQUE trong PRIMARY KEY/UNIQUE đã tự tạo index tương ứng.
-- PostgreSQL mặc định dùng B-tree: phù hợp equality, range và ORDER BY.
-- Composite index phụ thuộc thứ tự cột; đặt cột lọc thường dùng ở đầu.
-- Partial index chỉ index một tập dòng; expression index index biểu thức.
CREATE INDEX idx_products_active_name
  ON products(name)
  WHERE status = 'ACTIVE';

CREATE INDEX idx_products_name_lower
  ON products(LOWER(name));

-- Covering index có thể chứa cột trả về để hỗ trợ index-only scan.
-- Chỉ bật sau khi đo bằng EXPLAIN (ANALYZE, BUFFERS), vì index làm tăng chi phí ghi.
-- CREATE INDEX idx_inventory_wh_product_cover
--   ON inventory(warehouse_id, product_id)
--   INCLUDE (quantity, reserved_quantity);

CREATE INDEX idx_orders_pending_created
  ON orders(created_at DESC)
  WHERE status = 'PENDING';

-- 6. PARTITION: ví dụ bảng giao dịch phân vùng RANGE theo tháng.
-- Đây là bảng demo tách biệt; không thay thế inventory_transactions ở trên.
-- Khi partition, UNIQUE/PRIMARY KEY phải chứa partition key (created_at).
-- RANGE phù hợp dữ liệu theo thời gian; LIST phù hợp nhóm giá trị rời rạc;
-- HASH phù hợp chia đều dữ liệu khi không có khoảng thời gian tự nhiên.
CREATE TABLE inventory_transactions_partition_demo (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY,
  product_id BIGINT NOT NULL,
  warehouse_id BIGINT NOT NULL,
  transaction_type VARCHAR(30) NOT NULL,
  quantity INTEGER NOT NULL,
  reference_no VARCHAR(100),
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE inventory_transactions_demo_2026_09
  PARTITION OF inventory_transactions_partition_demo
  FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');

CREATE TABLE inventory_transactions_demo_2026_10
  PARTITION OF inventory_transactions_partition_demo
  FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

-- Index khai báo trên bảng cha được PostgreSQL tạo/duy trì index tương ứng
-- trên các partition hiện có; partition mới cũng cần index tương ứng.
CREATE INDEX idx_inventory_tx_demo_warehouse_created
  ON inventory_transactions_partition_demo(warehouse_id, created_at DESC);

-- Query có điều kiện created_at giúp PostgreSQL loại partition không liên quan.
-- SELECT * FROM inventory_transactions_partition_demo
-- WHERE created_at >= '2026-09-01' AND created_at < '2026-10-01';

-- 7. LOCAL INDEX VÀ GLOBAL INDEX
-- Oracle phân biệt local/global index. PostgreSQL không có global index độc lập
-- bao phủ mọi partition theo cùng mô hình đó. Index trên bảng partitioned là
-- partitioned index ở mức logic, được hiện thực bằng index cục bộ trên từng
-- partition. UNIQUE constraint trên bảng partitioned phải bao gồm partition key.
-- Với bảng không partition, index thông thường bao phủ toàn bộ bảng; không gọi
-- nó là “global index” theo thuật ngữ Oracle.

-- Cách xem index và partition trong PostgreSQL:
-- \d+ inventory_transactions_partition_demo
-- SELECT * FROM pg_indexes WHERE tablename LIKE 'inventory_transactions_demo%';
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT * FROM inventory_transactions_partition_demo
-- WHERE warehouse_id = 10
--   AND created_at >= '2026-09-01' AND created_at < '2026-10-01';

-- Chỉ dùng partition khi dữ liệu/khối lượng truy vấn có nhu cầu thực tế; cần có
-- lịch tạo partition tương lai, chính sách lưu trữ và kiểm tra partition pruning.
