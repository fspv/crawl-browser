#!/bin/bash
set -ex

# Test matrix execution script
# Runs all combinations of runtime, proxy, and extension configurations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Arrays to track results
declare -a PASSED_TESTS
declare -a FAILED_TESTS

# Function to run a single test configuration
run_test() {
    local runtime=$1
    local proxy=$2
    local extensions=$3
    local test_name="${runtime}-${proxy}-${extensions}"
    
    echo -e "${YELLOW}Running test: $test_name${NC}"
    echo "================================================"
    
    # Build compose command
    local COMPOSE_CMD
    if [ "$runtime" = "docker" ] && [ "${DOCKER_SUDO:-0}" = "1" ]; then
        COMPOSE_CMD="sudo docker compose"
    elif [ "$runtime" = "docker" ]; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="${runtime}-compose"
    fi
    
    local COMPOSE_FILES="-f docker-compose/base.yml"
    COMPOSE_FILES+=" -f docker-compose/runtime/${runtime}.yml"
    COMPOSE_FILES+=" -f docker-compose/proxy/${proxy}.yml"
    COMPOSE_FILES+=" -f docker-compose/extensions/${extensions}.yml"
    
    # Create unique project name to avoid conflicts
    local PROJECT_NAME="crawl-test-${test_name//[^a-zA-Z0-9]/}"
    
    # Run the test
    if $COMPOSE_CMD -p "$PROJECT_NAME" $COMPOSE_FILES up --abort-on-container-exit --exit-code-from test-runner; then
        echo -e "${GREEN}✓ Test passed: $test_name${NC}"
        PASSED_TESTS+=("$test_name")
        EXIT_CODE=0
    else
        echo -e "${RED}✗ Test failed: $test_name${NC}"
        FAILED_TESTS+=("$test_name")
        EXIT_CODE=1
    fi
    
    # Cleanup
    echo "Cleaning up containers for $test_name..."
    $COMPOSE_CMD -p "$PROJECT_NAME" $COMPOSE_FILES down -v || true
    
    # Save test results to a specific directory
    if [ -d "test-results" ]; then
        mkdir -p "test-results/matrix/${test_name}"
        if [ -f "test-results/results.json" ]; then
            cp "test-results/results.json" "test-results/matrix/${test_name}/"
        fi
        if [ -d "test-results/reports" ]; then
            cp -r "test-results/reports" "test-results/matrix/${test_name}/"
        fi
    fi
    
    echo ""
    return $EXIT_CODE
}

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -r, --runtime RUNTIME      Run tests for specific runtime (docker|podman)"
    echo "  -p, --proxy PROXY          Run tests for specific proxy config (no-proxy|with-proxy)"
    echo "  -e, --extensions EXT       Run tests for specific extension config (default|single-extra|all-extras)"
    echo "  -h, --help                 Display this help message"
    echo ""
    echo "If no options specified, runs all test combinations"
}

# Parse command line arguments
FILTER_RUNTIME=""
FILTER_PROXY=""
FILTER_EXTENSIONS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--runtime)
            FILTER_RUNTIME="$2"
            shift 2
            ;;
        -p|--proxy)
            FILTER_PROXY="$2"
            shift 2
            ;;
        -e|--extensions)
            FILTER_EXTENSIONS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Define test matrix
RUNTIMES=(docker podman)
PROXIES=(no-proxy with-proxy)
EXTENSIONS=(default single-extra all-extras)

# Apply filters if specified
if [ -n "$FILTER_RUNTIME" ]; then
    RUNTIMES=("$FILTER_RUNTIME")
fi
if [ -n "$FILTER_PROXY" ]; then
    PROXIES=("$FILTER_PROXY")
fi
if [ -n "$FILTER_EXTENSIONS" ]; then
    EXTENSIONS=("$FILTER_EXTENSIONS")
fi

# Check if required commands exist
for runtime in "${RUNTIMES[@]}"; do
    if [ "$runtime" = "docker" ]; then
        # Check for docker compose (v2) or docker-compose (v1)
        if [ "${DOCKER_SUDO:-0}" = "1" ]; then
            if ! sudo docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
                echo -e "${RED}Error: docker compose not found (tried with sudo)${NC}"
                exit 1
            fi
        else
            if ! docker compose version &> /dev/null && ! command -v docker-compose &> /dev/null; then
                echo -e "${RED}Error: docker compose not found${NC}"
                exit 1
            fi
        fi
    else
        if ! command -v "${runtime}-compose" &> /dev/null; then
            echo -e "${RED}Error: ${runtime}-compose not found${NC}"
            exit 1
        fi
    fi
done

# Create test results directory
mkdir -p test-results/matrix

# Display test plan
TOTAL_TESTS=$((${#RUNTIMES[@]} * ${#PROXIES[@]} * ${#EXTENSIONS[@]}))
echo -e "${YELLOW}Test Matrix Plan${NC}"
echo "================"
echo "Runtimes: ${RUNTIMES[*]}"
echo "Proxies: ${PROXIES[*]}"
echo "Extensions: ${EXTENSIONS[*]}"
echo "Total tests: $TOTAL_TESTS"
if [ "${DOCKER_SUDO:-0}" = "1" ]; then
    echo "Docker sudo: enabled"
fi
echo ""

# Run all test combinations
START_TIME=$(date +%s)

for runtime in "${RUNTIMES[@]}"; do
    for proxy in "${PROXIES[@]}"; do
        for extensions in "${EXTENSIONS[@]}"; do
            run_test "$runtime" "$proxy" "$extensions" || true
        done
    done
done

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Display summary
echo ""
echo -e "${YELLOW}Test Matrix Summary${NC}"
echo "==================="
echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]}${NC}"
if [ ${#PASSED_TESTS[@]} -gt 0 ]; then
    printf '%s\n' "${PASSED_TESTS[@]}" | sed 's/^/  ✓ /'
fi

echo -e "${RED}Failed: ${#FAILED_TESTS[@]}${NC}"
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    printf '%s\n' "${FAILED_TESTS[@]}" | sed 's/^/  ✗ /'
fi

echo ""
echo "Total duration: ${DURATION}s"

# Generate HTML summary report
generate_summary_report() {
    cat > test-results/matrix/summary.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Test Matrix Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }
        th { background-color: #f2f2f2; }
        .pass { background-color: #d4edda; color: #155724; }
        .fail { background-color: #f8d7da; color: #721c24; }
        .summary { margin: 20px 0; font-size: 18px; }
    </style>
</head>
<body>
    <h1>Test Matrix Results</h1>
    <div class="summary">
        <p>Total Tests: $TOTAL_TESTS</p>
        <p>Passed: ${#PASSED_TESTS[@]}</p>
        <p>Failed: ${#FAILED_TESTS[@]}</p>
        <p>Duration: ${DURATION}s</p>
    </div>
    <table>
        <tr>
            <th>Runtime</th>
            <th>Proxy</th>
            <th>Extensions</th>
            <th>Result</th>
        </tr>
EOF

    for runtime in "${RUNTIMES[@]}"; do
        for proxy in "${PROXIES[@]}"; do
            for extensions in "${EXTENSIONS[@]}"; do
                local test_name="${runtime}-${proxy}-${extensions}"
                local result="fail"
                local status="FAILED"
                
                if [[ " ${PASSED_TESTS[@]} " =~ " ${test_name} " ]]; then
                    result="pass"
                    status="PASSED"
                fi
                
                echo "        <tr>" >> test-results/matrix/summary.html
                echo "            <td>$runtime</td>" >> test-results/matrix/summary.html
                echo "            <td>$proxy</td>" >> test-results/matrix/summary.html
                echo "            <td>$extensions</td>" >> test-results/matrix/summary.html
                echo "            <td class=\"$result\">$status</td>" >> test-results/matrix/summary.html
                echo "        </tr>" >> test-results/matrix/summary.html
            done
        done
    done

    cat >> test-results/matrix/summary.html <<EOF
    </table>
</body>
</html>
EOF
}

generate_summary_report

echo ""
echo "Summary report generated: test-results/matrix/summary.html"

# Exit with failure if any tests failed
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    exit 1
fi

exit 0
