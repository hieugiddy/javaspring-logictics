CREATE TABLE orders (id UUID PRIMARY KEY,order_no VARCHAR(80) NOT NULL UNIQUE,user_id UUID,type VARCHAR(20) NOT NULL,status VARCHAR(30) NOT NULL,total_amount NUMERIC(18,2) NOT NULL DEFAULT 0,created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE TABLE order_items (id BIGSERIAL PRIMARY KEY,order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,product_id BIGINT NOT NULL,quantity INTEGER NOT NULL CHECK(quantity>0),unit_price NUMERIC(18,2) NOT NULL);
CREATE INDEX idx_orders_status_created ON orders(status,created_at DESC);
CREATE INDEX idx_order_items_order ON order_items(order_id);
