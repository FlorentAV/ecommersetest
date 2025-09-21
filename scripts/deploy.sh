#!/bin/bash
# deploy.sh - Production deployment script for Paydusa

set -e

echo "🚀 Deploying Paydusa Ecommerce Platform..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    print_error ".env.production file not found!"
    print_warning "Please copy .env.production template and configure your environment variables"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "docker-compose not found. Please install Docker Compose."
    exit 1
fi

# Load environment variables
print_status "Loading environment variables..."
export $(cat .env.production | grep -v '^#' | xargs)

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p scripts ssl

# Make scripts executable
print_status "Setting script permissions..."
chmod +x scripts/*.sh

# Build and start services
print_status "Building and starting services..."

# Option 1: Start with monitoring tools
if [ "$1" = "full" ]; then
    print_status "Starting with monitoring tools (Redis Insight, DB Viz)..."
    docker-compose --profile monitoring --profile proxy up -d --build
elif [ "$1" = "proxy" ]; then
    print_status "Starting with Nginx proxy..."
    docker-compose --profile proxy up -d --build
else
    print_status "Starting core services only..."
    docker-compose up -d --build
fi

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check service health
print_status "Checking service health..."

services=("postgres" "redis" "medusa" "storefront")
for service in "${services[@]}"; do
    if docker-compose ps $service | grep -q "Up"; then
        print_status "$service is running ✅"
    else
        print_warning "$service might have issues ⚠️"
        docker-compose logs $service --tail=20
    fi
done

# Display access information
print_status "🎉 Deployment completed!"
echo ""
echo "📋 Service Access Information:"
echo "================================"
echo "🌐 Storefront: http://localhost:3001"
echo "🔌 Medusa API: http://localhost:9001"
echo "🛡️  Medusa Admin: http://localhost:9001/app"
echo "📧 Email Service: http://localhost:3002"
echo ""
echo "💾 Database & Monitoring:"
echo "📊 DB Visualization: http://localhost:4984 (admin123)"
echo "🔴 Redis Insight: http://localhost:8002"
echo "🗄️  PostgreSQL: localhost:5433"
echo "🔴 Redis: localhost:6380"
echo ""
echo "📝 Next Steps:"
echo "1. Access Medusa Admin at http://localhost:9001/app"
echo "2. Create API keys in Settings → API Key Management"
echo "3. Add the publishable key to your .env.production file"
echo "4. Restart services: docker-compose restart storefront"
echo ""
echo "🔧 Useful Commands:"
echo "View logs: docker-compose logs -f [service_name]"
echo "Stop services: docker-compose down"
echo "Restart: docker-compose restart [service_name]"
echo ""

# Check if we need to set up publishable keys
if [ -z "$NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY" ]; then
    print_warning "NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY is not set!"
    echo "Please:"
    echo "1. Go to http://localhost:9001/app"
    echo "2. Login with your admin credentials"
    echo "3. Go to Settings → API Key Management"
    echo "4. Copy the publishable key"
    echo "5. Add it to .env.production"
    echo "6. Run: docker-compose restart storefront"
fi

print_status "Happy selling! 🛒"