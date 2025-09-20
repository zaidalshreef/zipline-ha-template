#!/bin/bash

# Custom entrypoint for PostgreSQL + Patroni
# Handles configuration and startup for HA cluster
# ===============================================

set -e

echo "=== Patroni PostgreSQL HA Entrypoint ==="

# Validate required environment variables
if [ -z "$PATRONI_NAME" ]; then
    echo "ERROR: PATRONI_NAME environment variable is required"
    exit 1
fi

if [ -z "$PATRONI_ETCD3_HOSTS" ]; then
    echo "ERROR: PATRONI_ETCD3_HOSTS environment variable is required"
    exit 1
fi

if [ -z "$PATRONI_RESTAPI_CONNECT_ADDRESS" ]; then
    echo "ERROR: PATRONI_RESTAPI_CONNECT_ADDRESS environment variable is required"
    exit 1
fi

if [ -z "$PATRONI_POSTGRESQL_CONNECT_ADDRESS" ]; then
    echo "ERROR: PATRONI_POSTGRESQL_CONNECT_ADDRESS environment variable is required"
    exit 1
fi

# Set up Zipline password if not provided
export ZIPLINE_PASSWORD="${ZIPLINE_PASSWORD:-zipline_secure_2025}"

# Create Patroni configuration from template
echo "Generating Patroni configuration..."
/usr/local/bin/setup-patroni-config.sh

# Ensure proper ownership of data directory
echo "Setting up data directory ownership..."
mkdir -p "$PATRONI_POSTGRESQL_DATA_DIR"
chown -R postgres:postgres "$PATRONI_POSTGRESQL_DATA_DIR"

# Ensure proper ownership of log directory
mkdir -p /var/log/patroni
chown -R postgres:postgres /var/log/patroni
chmod 755 /var/log/patroni

# Wait for etcd to be available
echo "Waiting for etcd to be available..."
IFS=',' read -ra ETCD_HOSTS <<< "$PATRONI_ETCD3_HOSTS"
for host in "${ETCD_HOSTS[@]}"; do
    echo "Checking etcd at $host..."
    until curl -s "http://$host/health" >/dev/null 2>&1; do
        echo "Waiting for etcd at $host..."
        sleep 5
    done
    echo "etcd at $host is ready"
done

echo "All etcd nodes are ready"

# Start Patroni
echo "Starting Patroni with configuration: /etc/patroni/patroni.yml"
echo "Patroni name: $PATRONI_NAME"
echo "Patroni scope: $PATRONI_SCOPE"
echo "etcd hosts: $PATRONI_ETCD3_HOSTS"

# Run as postgres user
exec gosu postgres "$@"
