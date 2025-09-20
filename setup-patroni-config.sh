#!/bin/bash

# Setup Patroni Configuration Script
# Replaces environment variables in template
# ==========================================

set -e

echo "=== Setting up Patroni configuration ==="

# Define input and output files
TEMPLATE_FILE="/etc/patroni/patroni-template.yml"
CONFIG_FILE="/etc/patroni/patroni.yml"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "ERROR: Template file $TEMPLATE_FILE not found"
    exit 1
fi

# Replace environment variables in template
echo "Replacing environment variables in Patroni configuration..."

# Create config file from template
envsubst < "$TEMPLATE_FILE" > "$CONFIG_FILE"

# Verify the configuration was created
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Failed to create configuration file $CONFIG_FILE"
    exit 1
fi

# Set proper permissions
chmod 644 "$CONFIG_FILE"
chown postgres:postgres "$CONFIG_FILE"

echo "Patroni configuration created successfully at $CONFIG_FILE"

# Display configuration summary (without passwords)
echo "=== Configuration Summary ==="
echo "Scope: $PATRONI_SCOPE"
echo "Name: $PATRONI_NAME"
echo "REST API: $PATRONI_RESTAPI_CONNECT_ADDRESS"
echo "PostgreSQL: $PATRONI_POSTGRESQL_CONNECT_ADDRESS"
echo "etcd hosts: $PATRONI_ETCD3_HOSTS"
echo "Data directory: $PATRONI_POSTGRESQL_DATA_DIR"

# Validate configuration syntax (basic check)
if command -v python3 >/dev/null 2>&1; then
    echo "Validating YAML syntax..."
    python3 -c "
import yaml
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        yaml.safe_load(f)
    print('✅ Configuration syntax is valid')
except yaml.YAMLError as e:
    print(f'❌ Configuration syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ Error validating configuration: {e}')
    sys.exit(1)
"
else
    echo "⚠️  Python3 not available, skipping YAML validation"
fi

echo "=== Patroni configuration setup complete ==="
