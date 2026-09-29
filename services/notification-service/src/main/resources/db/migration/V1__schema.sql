CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE notifications (id UUID PRIMARY KEY DEFAULT gen_random_uuid(),user_id UUID,event_id VARCHAR(100) NOT NULL,type VARCHAR(50) NOT NULL,title VARCHAR(255) NOT NULL,message TEXT NOT NULL,status VARCHAR(20) NOT NULL DEFAULT 'UNREAD',created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),UNIQUE(event_id,user_id));
CREATE INDEX idx_notifications_user_status ON notifications(user_id,status,created_at DESC);
