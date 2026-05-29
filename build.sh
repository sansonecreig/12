#!/bin/bash
# MatrixNebulaAegis Build Script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== MatrixNebulaAegis Build ===${NC}\n"

# Check Theos
if [ -z "$THEOS" ]; then
    if [ -d "$HOME/theos" ]; then
        export THEOS="$HOME/theos"
    elif [ -d "../theos" ]; then
        export THEOS="$(cd .. && pwd)/theos"
    else
        echo -e "${RED}Error: Theos not found!${NC}"
        echo "Install: git clone https://github.com/theos/theos.git ~/theos"
        exit 1
    fi
fi
export PATH="$THEOS/bin:$PATH"

echo -e "${YELLOW}THEOS: $THEOS${NC}\n"

# Clean
if [ "$1" == "clean" ]; then
    echo -e "${YELLOW}Cleaning...${NC}"
    make clean THEOS=$THEOS 2>/dev/null || true
    rm -rf packages/*.deb 2>/dev/null || true
fi

# Build
echo -e "${GREEN}Building...${NC}\n"
make package THEOS=$THEOS

# Output
echo ""
echo -e "${GREEN}=== Done ===${NC}"
ls -lh packages/*.deb 2>/dev/null || ls -lh *.deb 2>/dev/null || echo "Check packages/ directory"
echo ""
echo "Install: dpkg -i com.matrix.aegis_4.0.0_iphoneos-arm.deb"
