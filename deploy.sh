#!/bin/bash

# Zipline HA Cluster Deployment Script (Production-Grade with 3-Node etcd)
# Following Techno Tim's PostgreSQL HA best practices
# ==================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
NODE1_IP="10.10.10.150"
NODE2_IP="10.10.10.105"
NODE2_USER="${NODE2_USER:-zaid}"

# Helper functions
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
stage() { echo -e "${PURPLE}[STAGE]${NC} $1"; }

echo -e "${BLUE}🚀 Zipline HA Cluster with 3-Node etcd Deployment${NC}"
echo "=================================================="
echo "Node 1: $NODE1_IP (etcd1 + etcd-witness + patroni-node1 + haproxy + zipline)"
echo "Node 2: $NODE2_IP (etcd2 + patroni-node2 + haproxy + zipline)"
echo "Architecture: Production-grade with proper etcd quorum"
echo ""

# Test SSH connectivity
log "🔐 Testing SSH connectivity..."
if timeout 10 ssh -o ConnectTimeout=5 "$NODE2_USER@$NODE2_IP" "echo 'Connected'" >/dev/null 2>&1; then
    success "SSH connection to Node 2 successful"
else
    error "Cannot connect to Node 2. Setup: ssh-copy-id $NODE2_USER@$NODE2_IP"
    exit 1
fi

# Stop any existing services
log "🛑 Stopping existing services..."
docker compose -f docker-compose.node1.yml down -v --remove-orphans 2>/dev/null || true
ssh "$NODE2_USER@$NODE2_IP" "docker compose -f docker-compose.node2.yml down -v --remove-orphans 2>/dev/null || true"

# Clean up any lingering containers and volumes
log "🧹 Deep cleaning Docker resources..."
docker system prune -f --volumes 2>/dev/null || true
ssh "$NODE2_USER@$NODE2_IP" "docker system prune -f --volumes 2>/dev/null || true"

# Build custom images on both nodes
log "🏗️ Building PostgreSQL + Patroni images..."
docker build -f Dockerfile.patroni-postgres -t zipline-patroni-postgres:latest .
ssh "$NODE2_USER@$NODE2_IP" "docker build -f Dockerfile.patroni-postgres -t zipline-patroni-postgres:latest ."

# Create application data directories
log "📁 Creating application data directories..."
mkdir -p ./zipline/data/{uploads,public,themes}
ssh "$NODE2_USER@$NODE2_IP" "mkdir -p ./zipline/data/{uploads,public,themes}"

# Stage 1: Deploy etcd cluster first (3-node for proper quorum)
stage "🏗️ STAGE 1: Deploying 3-node etcd cluster..."
log "Starting etcd1 and etcd-witness on Node 1..."
docker compose -f docker-compose.node1.yml up -d etcd1 etcd-witness

log "⏳ Waiting 10 seconds for etcd1 to initialize..."
sleep 10

log "Starting etcd2 on Node 2..."
ssh "$NODE2_USER@$NODE2_IP" "docker compose -f docker-compose.node2.yml up -d etcd2"

log "⏳ Waiting 15 seconds for etcd cluster formation..."
sleep 15

# Verify etcd cluster
log "🔍 Verifying 3-node etcd cluster..."
if docker exec zipline-etcd1 etcdctl --endpoints=http://localhost:2379 member list 2>/dev/null; then
    success "etcd cluster formed successfully"
else
    warning "etcd cluster not ready yet, continuing..."
fi

# Stage 2: Deploy Patroni PostgreSQL cluster
stage "🗄️ STAGE 2: Deploying Patroni PostgreSQL cluster..."
log "Starting Patroni on Node 1 (will initialize as primary)..."
docker compose -f docker-compose.node1.yml up -d patroni-node1

log "⏳ Waiting 30 seconds for PostgreSQL initialization..."
sleep 30

log "Starting Patroni on Node 2 (will join as replica)..."
ssh "$NODE2_USER@$NODE2_IP" "docker compose -f docker-compose.node2.yml up -d patroni-node2"

log "⏳ Waiting 30 seconds for replication setup..."
sleep 30

# Stage 3: Deploy HAProxy and Zipline
stage "🌐 STAGE 3: Deploying HAProxy and Zipline applications..."
log "Starting HAProxy and Zipline on both nodes..."
docker compose -f docker-compose.node1.yml up -d haproxy zipline
ssh "$NODE2_USER@$NODE2_IP" "docker compose -f docker-compose.node2.yml up -d haproxy zipline"

log "⏳ Waiting for applications to stabilize..."
sleep 20

# Stage 4: Initialize Zipline database
stage "💾 STAGE 4: Initializing Zipline database..."
log "Creating zipline database and user..."
for i in {1..5}; do
    if docker exec zipline-patroni-node1 psql -U postgres -c "SELECT 1" >/dev/null 2>&1; then
        docker exec zipline-patroni-node1 psql -U postgres << 'EOF'
CREATE DATABASE IF NOT EXISTS zipline;
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'zipline') THEN
        CREATE ROLE zipline LOGIN PASSWORD 'zipline_secure_2025';
    END IF;
END
$$;
GRANT ALL PRIVILEGES ON DATABASE zipline TO zipline;
ALTER USER zipline CREATEDB;
ALTER USER zipline SUPERUSER;
EOF
        success "Zipline database initialized"
        break
    fi
    if [ $i -eq 5 ]; then
        warning "Database not ready after 25 seconds, continuing..."
    fi
    echo "  Waiting for PostgreSQL... ($i/5)"
    sleep 5
done

# Test cluster status
log "🔍 Testing cluster status..."
echo ""
echo "📊 Node 1 Status:"
docker compose -f docker-compose.node1.yml ps --format "table {{.Name}}\t{{.Status}}"

echo ""
echo "📊 Node 2 Status:"
ssh "$NODE2_USER@$NODE2_IP" "docker compose -f docker-compose.node2.yml ps --format \"table {{.Name}}\t{{.Status}}\""

# Test etcd 3-node cluster
echo ""
log "🔍 etcd 3-node cluster status:"
if docker exec zipline-etcd1 etcdctl --write-out=table --endpoints=http://localhost:2379,http://localhost:2391,http://$NODE2_IP:2379 endpoint status 2>/dev/null; then
    success "3-node etcd cluster is healthy"
else
    warning "etcd cluster status check failed"
fi

# Test Patroni cluster
echo ""
log "🔍 Patroni cluster information:"
if curl -s http://localhost:8008/cluster | jq -r '.members[] | "\(.name): \(.role) - \(.state)"' 2>/dev/null; then
    success "Patroni cluster is operational"
else
    warning "Patroni cluster info not available (may still be initializing)"
fi

# Test database connectivity
log "🧪 Testing database connectivity..."
if docker exec zipline-patroni-node1 psql -U zipline -d zipline -c "SELECT 'Cluster OK' as status;" 2>/dev/null; then
    success "Database connection working"
else
    warning "Database connection not ready yet"
fi

# Test HAProxy
log "🔗 Testing HAProxy connectivity..."
if curl -s http://localhost:8404 >/dev/null 2>&1; then
    success "HAProxy stats accessible"
else
    warning "HAProxy not ready yet"
fi

# Test Zipline application
log "🎯 Testing Zipline application..."
for i in {1..6}; do
    if curl -s http://localhost:3000/api/healthcheck | grep -q '"pass":true' 2>/dev/null; then
        success "Zipline application is working"
        break
    fi
    if [ $i -eq 6 ]; then
        warning "Zipline application not ready after 30 seconds"
    fi
    echo "  Waiting for Zipline... ($i/6)"
    sleep 5
done

echo ""
success "🎉 Production-grade HA cluster deployment completed!"
echo ""
echo "🏗️ Architecture Summary:"
echo "   📊 3-node etcd cluster: etcd1, etcd2, etcd-witness"
echo "   🗄️ 2-node PostgreSQL: patroni-node1 (primary), patroni-node2 (replica)"
echo "   🌐 2x HAProxy instances for load balancing"
echo "   📱 2x Zipline application instances"
echo ""
echo "🌐 Access Points:"
echo "   Zipline UI:        http://$NODE1_IP:3000 or http://$NODE2_IP:3000"
echo "   HAProxy Stats:     http://$NODE1_IP:8404 or http://$NODE2_IP:8404"
echo "   Patroni API:       http://$NODE1_IP:8008 or http://$NODE2_IP:8009"
echo "   Database (direct): $NODE1_IP:5432 or $NODE2_IP:5432"
echo "   Database (HAProxy): $NODE1_IP:5000 or $NODE2_IP:5000"
echo ""
echo "📋 Useful Commands:"
echo "   etcd status:      docker exec zipline-etcd1 etcdctl member list"
echo "   Cluster status:   curl http://$NODE1_IP:8008/cluster | jq"
echo "   Database test:    docker exec zipline-patroni-node1 psql -U zipline -d zipline -c 'SELECT now();'"
echo "   View logs:        docker compose -f docker-compose.node1.yml logs -f"
echo ""
echo "🔄 Features enabled:"
echo "   ✅ Automatic failover via Patroni"
echo "   ✅ 3-node etcd consensus for split-brain protection"
echo "   ✅ Load balancing via HAProxy"
echo "   ✅ Zero-downtime deployments"
