#!/bin/bash
set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "🏥 Running System Health Checks..."

# Helper
check_service() {
    local name=$1
    local cmd=$2
    
    echo -n "Checking $name... "
    if eval "$cmd"; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

check_service "MariaDB" "docker compose exec -T mariadb mysqladmin ping -h localhost --silent > /dev/null 2>&1"
check_service "Redis" "docker compose exec -T cache redis-cli ping > /dev/null 2>&1"
check_service "Panel Web" "curl -s -f http://localhost:80 > /dev/null 2>&1"
check_service "Wings Daemon" "curl -s -f http://localhost:8080 > /dev/null 2>&1"
check_service "Keep-Alive" "curl -s -f http://localhost:3000/ping > /dev/null 2>&1"

# Check Wings Connection to Panel (via Logs or status)
# Hard to check externally without API token. 
# But we can check if wings container is up.
check_service "Wings Container" "docker compose ps wings | grep -q 'Up'"
