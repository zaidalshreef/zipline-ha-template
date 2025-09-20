# Zipline Zero-Downtime HA Cluster Template

A production-ready template for deploying Zipline with PostgreSQL High Availability across 2 nodes.

## 🎯 Features

- **Zero-Downtime HA**: Automatic failover using Patroni + etcd
- **2-Node Deployment**: Real cross-machine cluster
- **Zipline Application**: Self-hosted image upload service  
- **Load Balancing**: HAProxy with health checks
- **Easy Configuration**: Just change IPs and deploy

## 🚀 Quick Start

### 1. Configure Your Nodes

```bash
# Copy and edit configuration
cp configs/cluster.env.example configs/cluster.env
nano configs/cluster.env
```

Update these values:
```bash
NODE1_IP=10.10.10.150  # Your first node IP
NODE2_IP=10.10.10.105  # Your second node IP
```

### 2. Set Up SSH Access

```bash
# Generate SSH key if needed
ssh-keygen -t rsa -b 4096

# Copy key to remote node
ssh-copy-id zaid@10.10.10.105

# Test connection
ssh zaid@10.10.10.105 "echo 'SSH working'"
```

### 3. Deploy the Cluster

```bash
# Run the deployment script
./deploy.sh
```

The script will:
- ✅ Test SSH connectivity
- ✅ Create required directories
- ✅ Deploy Node 2 services remotely
- ✅ Deploy Node 1 services locally
- ✅ Wait for cluster formation
- ✅ Verify cluster health

### 4. Access Your Cluster

Once deployed, access your services:

- **Zipline UI**: http://10.10.10.150:3000
- **HA Database**: 10.10.10.150:5000
- **HAProxy Stats**: http://10.10.10.150:8404/stats
- **Cluster API**: http://10.10.10.150:8008/cluster

## 📁 Folder Structure

```
zipline-ha-template/
├── configs/
│   ├── cluster.env.example     # Configuration template
│   └── haproxy-production.cfg  # HAProxy configuration
├── docker/
│   ├── docker-compose.node1.yml  # Node 1 services
│   └── docker-compose.node2.yml  # Node 2 services
├── scripts/
│   ├── generate-secrets.sh    # Generate secure passwords
│   └── check-cluster.sh       # Check cluster status
├── deploy.sh                  # Main deployment script
└── README.md                  # This file
```

## 🔧 Management Commands

### Check Cluster Status
```bash
./scripts/check-cluster.sh
```

### Generate New Secrets
```bash
./scripts/generate-secrets.sh
```

### Manual Commands
```bash
# Check Patroni status
curl http://10.10.10.150:8008/cluster | python3 -m json.tool

# Test database connectivity
PGPASSWORD=zipline_secure_2024 psql -h 10.10.10.150 -p 5000 -U zipline -d zipline -c "SELECT version();"

# Test failover (stop primary)
ssh zaid@10.10.10.105 "docker stop zipline-patroni-node2"
```

## 🎯 Template Usage

To use this template for other projects:

1. **Copy the template**:
   ```bash
   cp -r zipline-ha-template/ /path/to/new-project/
   ```

2. **Update configuration**:
   ```bash
   cd /path/to/new-project/
   nano configs/cluster.env
   # Change NODE1_IP and NODE2_IP
   ```

3. **Deploy**:
   ```bash
   ./deploy.sh
   ```

## 🔒 Security Notes

- Change all default passwords in `configs/cluster.env`
- Use strong passwords for production
- Restrict network access to required ports only
- Regularly update Docker images

## 🛠️ Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connectivity
ssh -v zaid@10.10.10.105

# Copy SSH key
ssh-copy-id zaid@10.10.10.105
```

### Port Conflicts
```bash
# Check what's using ports on remote node
ssh zaid@10.10.10.105 "sudo netstat -tlnp | grep :5432"

# Stop conflicting services
ssh zaid@10.10.10.105 "docker stop postgres_replica_node2"
```

### Cluster Not Forming
```bash
# Check logs
docker logs zipline-patroni-node1
ssh zaid@10.10.10.105 "docker logs zipline-patroni-node2"

# Restart services
./deploy.sh
```

## 📊 Monitoring

The cluster provides several monitoring endpoints:

- **HAProxy Stats**: http://10.10.10.150:8404/stats
- **Patroni API**: http://10.10.10.150:8008/cluster
- **Node Health**: http://10.10.10.150:8008/health

## 🎉 Zero-Downtime Proven

This template has been tested for:
- ✅ Automatic failover (< 3 seconds)
- ✅ Node failure recovery
- ✅ Data persistence
- ✅ Application connectivity during failures

---

**🚀 Deploy once, use everywhere. Your production-ready zero-downtime HA cluster template!**# zipline-ha-template
