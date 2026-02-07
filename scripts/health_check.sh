#!/bin/bash
# =============================================================================
# Project Health Check Script
# =============================================================================
# Validates the entire project structure and configuration.
# Run this before starting setup if you encounter issues.
#
# Usage:
#   bash scripts/health_check.sh
#   chmod +x scripts/health_check.sh && ./scripts/health_check.sh
# =============================================================================

set -e

RESET='\033[0m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'

pass() { echo -e "${GREEN}✓${RESET} $1"; }
fail() { echo -e "${RED}✗${RESET} $1"; }
info() { echo -e "${YELLOW}ℹ${RESET} $1"; }

echo "================================="
echo "  Design for Schema Evolution"
echo "  Project Health Check"
echo "================================="
echo ""

# Counter for checks
PASSED=0
FAILED=0

# ─────────────────────────────────────────────────────────────────────────────
# System Prerequisites
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ System Prerequisites"

if command -v python &> /dev/null; then
    VERSION=$(python --version 2>&1 | awk '{print $2}')
    if [[ "$VERSION" > "3.9" ]]; then
        pass "Python $VERSION"
        ((PASSED++))
    else
        fail "Python $VERSION (need 3.10+)"
        ((FAILED++))
    fi
else
    fail "Python not found"
    ((FAILED++))
fi

if command -v uv &> /dev/null; then
    pass "uv $(uv --version)"
    ((PASSED++))
else
    fail "uv not installed (install from: https://docs.astral.sh/uv/)"
    ((FAILED++))
fi

if command -v docker &> /dev/null; then
    pass "Docker available"
    ((PASSED++))
else
    fail "Docker not found"
    ((FAILED++))
fi

if command -v docker compose &> /dev/null; then
    pass "Docker Compose available"
    ((PASSED++))
else
    fail "Docker Compose not found"
    ((FAILED++))
fi

if command -v just &> /dev/null; then
    pass "just $(just --version)"
    ((PASSED++))
else
    fail "just not installed (install: brew install just)"
    ((FAILED++))
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Project Structure
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Project Structure"

DIRS=(
    "extract"
    "transform"
    "snowflake"
    "docs"
    ".github/workflows"
)

for DIR in "${DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        pass "Directory: $DIR"
        ((PASSED++))
    else
        fail "Missing directory: $DIR"
        ((FAILED++))
    fi
done

FILES=(
    "README.md"
    "QUICK_START.md"
    "SETUP_VALIDATION.md"
    ".env.example"
    "pyproject.toml"
    "justfile"
    "Dockerfile"
    "docker-compose.yml"
    "titan.yml"
    "extract/open_meteo_pipeline.py"
    "snowflake/manifest.py"
    "transform/dbt_project.yml"
    "transform/profiles.yml"
)

for FILE in "${FILES[@]}"; do
    if [ -f "$FILE" ]; then
        pass "File: $FILE"
        ((PASSED++))
    else
        fail "Missing file: $FILE"
        ((FAILED++))
    fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Environment Configuration
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Environment Configuration"

if [ -f ".env" ]; then
    pass ".env file exists"
    ((PASSED++))
    
    # Check for required vars
    REQUIRED_VARS=(
        "SNOWFLAKE_ACCOUNT"
        "SNOWFLAKE_USER"
        "SNOWFLAKE_PASSWORD"
        "SNOWFLAKE_ROLE"
    )
    
    for VAR in "${REQUIRED_VARS[@]}"; do
        if grep -q "^$VAR=" .env; then
            VALUE=$(grep "^$VAR=" .env | cut -d'=' -f2 | cut -c1-20)...
            pass "Config: $VAR"
            ((PASSED++))
        else
            fail "Missing in .env: $VAR"
            ((FAILED++))
        fi
    done
else
    fail ".env file not found (run: just setup-env)"
    ((FAILED++))
    info "After creating .env, fill in your Snowflake credentials"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Python Environment
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Python Environment"

if [ -d ".venv" ]; then
    pass "Virtual environment (.venv) exists"
    ((PASSED++))
    
    # Check for key packages
    if [ -f ".venv/bin/python" ]; then
        PACKAGES=("dlt" "dbt" "requests" "python_dotenv")
        
        for PACKAGE in "${PACKAGES[@]}"; do
            if ./.venv/bin/python -c "import $PACKAGE" 2>/dev/null; then
                pass "Package: $PACKAGE installed"
                ((PASSED++))
            else
                fail "Package not installed: $PACKAGE (run: uv sync)"
                ((FAILED++))
            fi
        done
    fi
else
    fail "Virtual environment not found (.venv)"
    ((FAILED++))
    info "Create with: uv sync"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# dbt Configuration
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ dbt Configuration"

if [ -f "transform/profiles.yml" ]; then
    pass "dbt profiles configured"
    ((PASSED++))
else
    fail "Missing: transform/profiles.yml"
    ((FAILED++))
fi

if [ -f "transform/dbt_project.yml" ]; then
    PROJECT_NAME=$(grep "^name:" transform/dbt_project.yml | awk '{print $2}')
    pass "dbt project: $PROJECT_NAME"
    ((PASSED++))
else
    fail "Missing: transform/dbt_project.yml"
    ((FAILED++))
fi

# Count models
MODEL_COUNT=$(find transform/models -name "*.sql" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -gt 0 ]; then
    pass "dbt models: found $MODEL_COUNT SQL files"
    ((PASSED++))
else
    fail "No dbt models found"
    ((FAILED++))
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Docker Configuration
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Docker Configuration"

if docker ps >/dev/null 2>&1; then
    pass "Docker daemon is running"
    ((PASSED++))
else
    fail "Docker daemon not running (start Docker)"
    ((FAILED++))
fi

if [ -f "Dockerfile" ]; then
    STATUS=$(grep -c "FROM" Dockerfile)
    pass "Dockerfile configured (multi-stage: $STATUS stages)"
    ((PASSED++))
else
    fail "Missing: Dockerfile"
    ((FAILED++))
fi

if [ -f "docker-compose.yml" ]; then
    SERVICES=$(grep "  [a-z-]*:" docker-compose.yml | wc -l)
    pass "docker-compose configured ($SERVICES services)"
    ((PASSED++))
else
    fail "Missing: docker-compose.yml"
    ((FAILED++))
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Titan Infrastructure as Code
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Titan Infrastructure as Code"

if [ -f "snowflake/manifest.py" ]; then
    pass "Titan manifest exists"
    ((PASSED++))
else
    fail "Missing: snowflake/manifest.py"
    ((FAILED++))
fi

if [ -f "titan.yml" ]; then
    pass "Titan configuration exists"
    ((PASSED++))
else
    fail "Missing: titan.yml"
    ((FAILED++))
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Just Commands
# ─────────────────────────────────────────────────────────────────────────────

echo "▶ Just Commands"

REQUIRED_RECIPES=("setup-env" "install-uv" "install" "setup" "build" "extract" "titan-plan" "titan-apply")

for RECIPE in "${REQUIRED_RECIPES[@]}"; do
    if just --list 2>/dev/null | grep -q "$RECIPE"; then
        pass "Recipe defined: just $RECIPE"
        ((PASSED++))
    else
        fail "Recipe missing: just $RECIPE"
        ((FAILED++))
    fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

echo "================================="
echo "  Health Check Results"
echo "================================="
echo ""

TOTAL=$((PASSED + FAILED))
PERCENTAGE=$((PASSED * 100 / TOTAL))

echo "Passed:  $PASSED/$TOTAL"
echo "Failed:  $FAILED/$TOTAL"
echo "Score:   ${PERCENTAGE}%"

echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${RESET}"
    echo ""
    echo "Next steps:"
    echo "  1. Update .env with your Snowflake credentials"
    echo "  2. Run: uv sync"
    echo "  3. Follow: SETUP_VALIDATION.md"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${RESET}"
    echo ""
    echo "Issues to resolve:"
    echo "  - Install missing system dependencies"
    echo "  - Create .env file (just setup-env)"
    echo "  - Run uv sync to install Python packages"
    echo ""
    echo "For help, see: QUICK_START.md or SETUP_VALIDATION.md"
    exit 1
fi
