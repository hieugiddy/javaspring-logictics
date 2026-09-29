CREATE TABLE shipments (id UUID PRIMARY KEY,order_id UUID NOT NULL UNIQUE,carrier VARCHAR(100),tracking_number VARCHAR(150) UNIQUE,status VARCHAR(30) NOT NULL,created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW());
CREATE INDEX idx_shipments_status ON shipments(status);
