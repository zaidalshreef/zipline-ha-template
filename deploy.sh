#!/bin/bash

# Zipline Zero-Downtime HA Cluster - 2-Node Deployment Script
# ===========================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Load configuration
if [ ! -f "configs/cluster.env" ]; then
    error "Configuration file configs/cluster.env not found!"
    echo "Please copy configs/cluster.env.example to configs/cluster.env and configure your settings."
    exit 1
fi

source configs/cluster.env

log "🚀 Starting Zipline Zero-Downtime HA Deployment"
log "==============================================="
log "Project: $PROJECT_NAME"
log "Node 1: $NODE1_IP"
log "Node 2: $NODE2_IP"

# Test SSH connectivity
log "🔐 Testing SSH connectivity..."
if timeout 10 ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "zaid@$NODE2_IP" "echo 'SSH connection successful'" > /dev/null 2>&1; then
    success "SSH connection to Node 2 ($NODE2_IP) successful"
else
    error "Cannot connect to Node 2 ($NODE2_IP) via SSH"
    echo "Please ensure:"
    echo "1. SSH key is set up: ssh-copy-id zaid@$NODE2_IP"
    echo "2. Node 2 is reachable and running"
    exit 1
fi

# Create required directories on both nodes
log "📁 Creating required directories..."

# Local directories (Node 1)
log "Creating directories on Node 1 (local)..."
sudo mkdir -p /data/zipline/{etcd1,patroni1,uploads,public,themes}
sudo chown -R $USER:$USER /data/zipline

# Remote directories (Node 2)
log "Creating directories on Node 2 ($NODE2_IP)..."
ssh "zaid@$NODE2_IP" "sudo mkdir -p /data/zipline/{etcd2,patroni2,uploads,public,themes} && sudo chown -R zaid:zaid /data/zipline"

# Copy template to Node 2
log "📋 Copying template to Node 2..."
rsync -avz --exclude='.git' . "zaid@$NODE2_IP:~/zipline-ha-template/"

# Stop any conflicting services on Node 2
log "🛑 Stopping conflicting services on Node 2..."
ssh "zaid@$NODE2_IP" "docker stop postgres_replica_node2 postgres_standby_simple || true"

# Deploy Node 2 first
log "🌐 Deploying Node 2 ($NODE2_IP)..."
ssh "zaid@$NODE2_IP" "cd zipline-ha-template && docker compose -f docker/docker-compose.node2.yml down --remove-orphans || true"
ssh "zaid@$NODE2_IP" "cd zipline-ha-template && docker compose -f docker/docker-compose.node2.yml up -d"

# Deploy Node 1
log "🏠 Deploying Node 1 (local)..."
docker compose -f docker/docker-compose.node1.yml down --remove-orphans || true
docker compose -f docker/docker-compose.node1.yml up -d

# Wait for cluster formation
log "⏳ Waiting for cluster formation..."
sleep 60

# Test cluster
log "🔍 Testing cluster health..."
echo ""
echo "Node 1 Status:"
if curl -s "http://$NODE1_IP:8008/health" | python3 -c "import sys,json; data=json.load(sys.stdin); print(f\"✅ {data['role']} - {data['state']}\")" 2>/dev/null; then
    success "Node 1 is healthy"
else
    warning "Node 1 not ready yet"
fi

echo ""
echo "Node 2 Status:"
if curl -s "http://$NODE2_IP:8008/health" | python3 -c "import sys,json; data=json.load(sys.stdin); print(f\"✅ {data['role']} - {data['state']}\")" 2>/dev/null; then
    success "Node 2 is healthy"
else
    warning "Node 2 not ready yet"
fi

echo ""
echo "Cluster Overview:"
if curl -s "http://$NODE1_IP:8008/cluster" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f\"Cluster: {data.get('scope', 'unknown')}\")
    if 'members' in data:
        for member in data['members']:
            name = member.get('name', 'unknown')
            role = member.get('role', 'unknown') 
            state = member.get('state', 'unknown')
            print(f\"  {name}: {role} ({state})\")
except:
    print('Cluster info not available yet')
" 2>/dev/null; then
    success "Cluster information retrieved"
else
    warning "Cluster still forming..."
fi

echo ""
success "🎉 Deployment completed!"
echo ""
echo "🌐 Access Points:"
echo "   Zipline UI: http://$NODE1_IP:3000"
echo "   HA Database: $NODE1_IP:5000"
echo "   HAProxy Stats: http://$NODE1_IP:8404"
echo "   Node 1 API: http://$NODE1_IP:8008"
echo "   Node 2 API: http://$NODE2_IP:8008"
echo ""
echo "📊 Monitor cluster status with:"
echo "   curl http://$NODE1_IP:8008/cluster | python3 -m json.tool"
echo ""
echo "🎯 Your zero-downtime HA cluster is ready!"
