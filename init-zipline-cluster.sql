-- Initialize Zipline database for 2-Node Patroni Cluster
-- ========================================================

-- Create zipline database if it doesn't exist
CREATE DATABASE zipline;

-- Create zipline user with secure password
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zipline') THEN
        CREATE ROLE zipline LOGIN PASSWORD 'zipline_secure_2025';
    ELSE
        ALTER ROLE zipline WITH PASSWORD 'zipline_secure_2025';
    END IF;
END
$$;

-- Grant database ownership to zipline user
ALTER DATABASE zipline OWNER TO zipline;
GRANT ALL PRIVILEGES ON DATABASE zipline TO zipline;

-- Connect to zipline database for schema setup
\c zipline

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO zipline;
GRANT CREATE ON SCHEMA public TO zipline;
ALTER SCHEMA public OWNER TO zipline;

-- Grant future object permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO zipline;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO zipline;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO zipline;

-- Enable required extensions for Zipline
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create monitoring user for HAProxy health checks (optional)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'monitor') THEN
        CREATE ROLE monitor LOGIN PASSWORD 'monitor_pass_2025';
    END IF;
END
$$;

-- Grant minimal permissions to monitor user
GRANT CONNECT ON DATABASE zipline TO monitor;
GRANT USAGE ON SCHEMA public TO monitor;

-- Verification queries
SELECT 
    'Database setup completed!' as status,
    current_database() as database,
    current_user as executed_by,
    version() as postgresql_version;

-- Show created roles
\du
