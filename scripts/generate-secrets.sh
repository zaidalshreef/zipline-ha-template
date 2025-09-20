#!/bin/bash
# Generate Zipline Secrets for Zero-Downtime HA Template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/configs/cluster.env"
ENV_EXAMPLE="$PROJECT_DIR/configs/cluster.env.example"

echo -e "${BLUE}🔐 Zipline Zero-Downtime HA - Secret Generation${NC}"
echo -e "${BLUE}===============================================${NC}"
echo ""

# Check if configuration exists
if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        echo -e "${YELLOW}📋 Creating configuration from example...${NC}"
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo -e "${GREEN}✅ Configuration file created${NC}"
    else
        echo -e "${RED}❌ No configuration template found${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}🔧 Generating secure secrets...${NC}"

# Function to generate a secure random string
generate_secret() {
    local length="${1:-32}"
    openssl rand -base64 42 | tr -dc A-Za-z0-9 | cut -c -$length | tr -d '\n'
}

# Generate CORE_SECRET for Zipline
CORE_SECRET=$(generate_secret 32)

# Update the .env file with the generated secret
if grep -q "CORE_SECRET=" "$ENV_FILE"; then
    # Update existing CORE_SECRET
    if [ "$(uname)" = "Darwin" ]; then
        # macOS
        sed -i '' "s/CORE_SECRET=.*/CORE_SECRET=$CORE_SECRET/" "$ENV_FILE"
    else
        # Linux
        sed -i "s/CORE_SECRET=.*/CORE_SECRET=$CORE_SECRET/" "$ENV_FILE"
    fi
    echo -e "${GREEN}✅ Updated CORE_SECRET in configuration${NC}"
else
    # Add CORE_SECRET to the file
    echo "" >> "$ENV_FILE"
    echo "# Generated CORE_SECRET" >> "$ENV_FILE"
    echo "CORE_SECRET=$CORE_SECRET" >> "$ENV_FILE"
    echo -e "${GREEN}✅ Added CORE_SECRET to configuration${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Secrets generated successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Generated Secrets:${NC}"
echo "   CORE_SECRET: ${CORE_SECRET:0:8}... (32 chars)"
echo ""
echo -e "${YELLOW}🔒 Security Notes:${NC}"
echo "   1. Keep your .env file secure and never commit it to version control"
echo "   2. Regenerate secrets regularly in production"
echo "   3. Use different secrets for different environments"
echo "   4. Store production secrets in a secure vault"
echo ""
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "   1. Review your configuration: nano $ENV_FILE"
echo "   2. Update NODE1_IP and NODE2_IP in the configuration"
echo "   3. Deploy your cluster: ./scripts/deploy-local.sh or ./scripts/deploy-remote.sh"
echo ""
