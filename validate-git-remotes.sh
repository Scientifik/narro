#!/bin/bash
# Git Remote Validation Script
# Tests updated git remote URLs before making permanent changes
# Usage: ./validate-git-remotes.sh

# Don't exit on error - we want to test all repos even if some fail
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }

# Track results
PASSED=0
FAILED=0
SKIPPED=0

echo "=========================================="
echo "Git Remote Validation Script"
echo "=========================================="
echo ""
echo "This script will test updated git remote URLs"
echo "to verify they work before making permanent changes."
echo ""
echo "Checking SSH configuration..."
echo ""

# Check if SSH agent is running
if [ -z "$SSH_AUTH_SOCK" ]; then
    log_warn "SSH_AUTH_SOCK not set. SSH agent may not be running."
    log_warn "You may need to run: eval \$(ssh-agent) && ssh-add ~/.ssh/your_key"
else
    log_info "SSH agent is running: $SSH_AUTH_SOCK"
fi

# Check for SSH keys
if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_ecdsa ]; then
    log_info "SSH keys found in ~/.ssh/"
else
    log_warn "No standard SSH keys found in ~/.ssh/"
fi

# Check SSH config for gitea.com
if [ -f ~/.ssh/config ]; then
    if grep -q "gitea.com" ~/.ssh/config; then
        log_info "Found gitea.com configuration in ~/.ssh/config"
        grep -A 5 "gitea.com" ~/.ssh/config | sed 's/^/  /'
    else
        log_warn "No gitea.com configuration found in ~/.ssh/config"
    fi
else
    log_warn "No ~/.ssh/config file found"
fi

echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Function to test a git remote URL
test_remote() {
    local repo_path=$1
    local remote_name=$2
    local old_url=$3
    local new_url=$4
    
    log_test "Testing: $repo_path (remote: $remote_name)"
    echo "  Old URL: $old_url"
    echo "  New URL: $new_url"
    
    # Verify directory exists
    if [ ! -d "$repo_path" ]; then
        log_error "  ✗ Directory does not exist: $repo_path"
        ((FAILED++))
        return 1
    fi
    
    # Verify .git directory exists
    if [ ! -d "$repo_path/.git" ]; then
        log_error "  ✗ .git directory not found in: $repo_path"
        ((FAILED++))
        return 1
    fi
    
    # Change to repo directory
    local original_dir=$(pwd)
    if ! cd "$repo_path" 2>/dev/null; then
        log_error "  ✗ Cannot access directory: $repo_path"
        cd "$original_dir"
        ((FAILED++))
        return 1
    fi
    
    # Test if we can connect to the new remote
    # Use git ls-remote to test connectivity (macOS-compatible)
    # Ensure we use SSH with proper key configuration
    log_info "  Testing connectivity to new remote..."
    
    local test_output
    local test_exit_code
    
    # Use GIT_SSH_COMMAND to ensure we use SSH properly
    # This respects ~/.ssh/config settings
    export GIT_SSH_COMMAND="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=yes"
    
    # Simple approach: run git ls-remote with a timeout using a background process
    # Start git in background and kill it after 15 seconds if still running
    (git ls-remote "$new_url" --heads 2>&1 > /tmp/git_test_$$.out) &
    local git_pid=$!
    
    # Wait up to 15 seconds
    local count=0
    while [ $count -lt 15 ]; do
        if ! kill -0 $git_pid 2>/dev/null; then
            # Process finished
            break
        fi
        sleep 1
        ((count++))
    done
    
    # Check if still running
    if kill -0 $git_pid 2>/dev/null; then
        # Still running - kill it
        kill $git_pid 2>/dev/null
        wait $git_pid 2>/dev/null
        test_exit_code=124
        test_output="Connection timed out after 15 seconds"
        rm -f /tmp/git_test_$$.out
    else
        # Process finished - get the output
        wait $git_pid
        test_exit_code=$?
        test_output=$(cat /tmp/git_test_$$.out 2>/dev/null)
        rm -f /tmp/git_test_$$.out
    fi
    
    # Unset GIT_SSH_COMMAND
    unset GIT_SSH_COMMAND
    
    # Check for specific SSH authentication errors
    if echo "$test_output" | grep -qi "permission denied\|publickey\|authentication failed"; then
        log_error "  ✗ SSH authentication failed"
        echo "  Error output:"
        echo "$test_output" | sed 's/^/    /' | head -5
        log_error "  This means:"
        log_error "    - Your SSH key is not authorized for the 'narro' organization"
        log_error "    - The SSH key needs to be added to your Gitea account"
        log_error "    - Check ~/.ssh/config for gitea.com configuration"
        log_error "    - Try: ssh -T git@gitea.com to test SSH connection"
        cd "$original_dir"
        ((FAILED++))
        return 1
    fi
    
    if [ $test_exit_code -eq 0 ] && [ -n "$test_output" ] && ! echo "$test_output" | grep -qi "fatal\|error\|timed out"; then
        log_info "  ✓ Successfully connected to new remote"
        echo "  Available branches:"
        echo "$test_output" | head -5 | sed 's/^/    /' || true
        cd "$original_dir"
        ((PASSED++))
        return 0
    else
        log_error "  ✗ Failed to connect to new remote (exit code: $test_exit_code)"
        if [ -n "$test_output" ]; then
            echo "  Error output:"
            echo "$test_output" | sed 's/^/    /' | head -3
        fi
        log_error "  This could mean:"
        log_error "    - The repository doesn't exist at the new path (narro/narro_*)"
        log_error "    - SSH keys are not configured for the 'narro' organization"
        log_error "    - The repository is private and your SSH key doesn't have access"
        log_error "    - Network/authentication issues"
        log_error ""
        log_error "  Troubleshooting:"
        log_error "    1. Test SSH: ssh -T git@gitea.com"
        log_error "    2. Check ~/.ssh/config for gitea.com settings"
        log_error "    3. Verify your SSH key is added to Gitea account"
        log_error "    4. Ensure you have access to the 'narro' organization"
        cd "$original_dir"
        ((FAILED++))
        return 1
    fi
}

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo ""
log_info "Starting validation tests..."
echo ""

# Test 1: Root repository
echo "----------------------------------------"
echo "1. Root Repository"
echo "----------------------------------------"
if [ -d "$SCRIPT_DIR/.git" ]; then
    # Test gitea remote
    OLD_GITEA="git@gitea.com:Scientifik/narro_main.git"
    NEW_GITEA="git@gitea.com:narro/narro_main.git"
    test_remote "$SCRIPT_DIR" "gitea" "$OLD_GITEA" "$NEW_GITEA"
    echo ""
else
    log_warn "Root repository .git not found at $SCRIPT_DIR/.git, skipping"
    ((SKIPPED++))
fi

# Test 2: Web repository
echo "----------------------------------------"
echo "2. Web Repository"
echo "----------------------------------------"
if [ -d "$SCRIPT_DIR/web/.git" ]; then
    OLD_GITEA="git@gitea.com:Scientifik/narro_frontend.git"
    NEW_GITEA="git@gitea.com:narro/narro_frontend.git"
    test_remote "$SCRIPT_DIR/web" "gitea" "$OLD_GITEA" "$NEW_GITEA"
    echo ""
else
    log_warn "Web repository .git not found at $SCRIPT_DIR/web/.git, skipping"
    ((SKIPPED++))
fi

# Test 3: Backend repository
echo "----------------------------------------"
echo "3. Backend Repository"
echo "----------------------------------------"
if [ -d "$SCRIPT_DIR/backend/.git" ]; then
    OLD_GITEA="git@gitea.com:Scientifik/narro_backend.git"
    NEW_GITEA="git@gitea.com:narro/narro_backend.git"
    test_remote "$SCRIPT_DIR/backend" "gitea" "$OLD_GITEA" "$NEW_GITEA"
    echo ""
else
    log_warn "Backend repository .git not found at $SCRIPT_DIR/backend/.git, skipping"
    ((SKIPPED++))
fi

# Test 4: Scraper repository
echo "----------------------------------------"
echo "4. Scraper Repository"
echo "----------------------------------------"
if [ -d "$SCRIPT_DIR/scraper/.git" ]; then
    OLD_GITEA="git@gitea.com:Scientifik/narro_scraper.git"
    NEW_GITEA="git@gitea.com:narro/narro_scraper.git"
    test_remote "$SCRIPT_DIR/scraper" "gitea" "$OLD_GITEA" "$NEW_GITEA"
    echo ""
else
    log_warn "Scraper repository .git not found at $SCRIPT_DIR/scraper/.git, skipping"
    ((SKIPPED++))
fi

# Test 5: Mobile repository
echo "----------------------------------------"
echo "5. Mobile Repository"
echo "----------------------------------------"
if [ -d "$SCRIPT_DIR/mobile/.git" ]; then
    OLD_GITEA="git@gitea.com:Scientifik/narro_mobile.git"
    NEW_GITEA="git@gitea.com:narro/narro_mobile.git"
    test_remote "$SCRIPT_DIR/mobile" "gitea" "$OLD_GITEA" "$NEW_GITEA"
    echo ""
else
    log_warn "Mobile repository .git not found at $SCRIPT_DIR/mobile/.git, skipping"
    ((SKIPPED++))
fi

# Summary
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo ""

if [ $FAILED -eq 0 ]; then
    log_info "✓ All tests passed! The new remote URLs are valid."
    echo ""
    log_info "You can now proceed with updating the git remotes."
    exit 0
else
    log_error "✗ Some tests failed. Please check the errors above."
    echo ""
    log_warn "Do not update the git remotes until all tests pass."
    exit 1
fi

