#!/bin/bash

# Zipline Zero-Downtime HA Cluster Status Checker
# ===============================================

# Load configuration
if [ ! -f "configs/cluster.env" ]; then
    echo "❌ Configuration file configs/cluster.env not found!"
    exit 1
fi

source configs/cluster.env

echo "🔍 Zipline HA Cluster Status"
echo "============================"
echo "Project: $PROJECT_NAME"
echo "Node 1: $NODE1_IP"
echo "Node 2: $NODE2_IP"
echo ""

echo "📊 Node Health:"
echo "Node 1: $(curl -s http://$NODE1_IP:8008/health | python3 -c "import sys,json; data=json.load(sys.stdin); print(f\"{data['role']} - {data['state']}\")" 2>/dev/null || echo "❌ not responding")"
echo "Node 2: $(curl -s http://$NODE2_IP:8008/health | python3 -c "import sys,json; data=json.load(sys.stdin); print(f\"{data['role']} - {data['state']}\")" 2>/dev/null || echo "❌ not responding")"
echo ""

echo "🗄️ Cluster Overview:"
curl -s "http://$NODE1_IP:8008/cluster" | python3 -c "
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
    else:
        print('  No members found')
except:
    print('❌ Cluster info not available')
" 2>/dev/null

echo ""
echo "🌐 Application Status:"
echo "Zipline UI: $(curl -s -o /dev/null -w "HTTP %{http_code}" http://$NODE1_IP:3000)"
echo "HAProxy: $(curl -s http://$NODE1_IP:8404/stats | head -1 | grep -q "Statistics Report" && echo "✅ responding" || echo "❌ not responding")"
echo "Database: $(PGPASSWORD=$POSTGRES_APP_PASSWORD psql -h $NODE1_IP -p 5000 -U $POSTGRES_APP_USER -d $POSTGRES_DB -c "SELECT 'OK';" 2>/dev/null | tail -1 || echo "❌ not accessible")"
