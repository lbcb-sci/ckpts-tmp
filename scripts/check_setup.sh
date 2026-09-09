#!/usr/bin/env bash

# Co-AI Workshop #1
# Pre-workshop setup validation
#
# Usage:
#   bash scripts/check_setup.sh
#
# The script exits with:
#   0  if all required checks pass
#   1  if one or more required checks fail

set -u

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
    printf 'PASS  %s\n' "$1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

warn() {
    printf 'WARN  %s\n' "$1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

section() {
    printf '\n%s\n' "$1"
    printf '%s\n' "----------------------------------------"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}


section "Co-AI Workshop setup check"

# ----------------------------------------------------------------------
# Operating system
# ----------------------------------------------------------------------

section "1. Operating system"

OS="$(uname -s)"

case "$OS" in
    Linux)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            IS_WSL=1
            pass "Running inside WSL"
        else
            IS_WSL=0
            pass "Running on native Linux"
        fi
        ;;
    Darwin)
        IS_WSL=0
        pass "Running on macOS"
        ;;
    *)
        IS_WSL=0
        fail "Unsupported operating system: $OS"
        ;;
esac


# ----------------------------------------------------------------------
# Repository location
# ----------------------------------------------------------------------

section "2. Workshop repository"

if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    pass "Git repository found: $REPO_ROOT"
else
    REPO_ROOT="$(pwd)"
    fail "Current directory is not inside a Git repository"
fi

if [ "$IS_WSL" -eq 1 ]; then
    case "$REPO_ROOT" in
        /mnt/*)
            fail "Repository is under $REPO_ROOT"
            printf '      Clone it under ~/workshops instead of /mnt/c or another Windows-mounted path.\n'
            ;;
        /home/*)
            pass "Repository is stored in the WSL Linux filesystem"
            ;;
        *)
            warn "Repository is outside /home: $REPO_ROOT"
            ;;
    esac
fi

if git remote get-url origin >/dev/null 2>&1; then
    ORIGIN="$(git remote get-url origin)"
    printf 'INFO  Git remote: %s\n' "$ORIGIN"

    case "$ORIGIN" in
        *lbcb-sci/coAI-workshop-building-workflows*)
            pass "Workshop repository remote looks correct"
            ;;
        *)
            warn "Repository remote differs from the workshop repository"
            ;;
    esac
else
    warn "No Git origin remote found"
fi


# ----------------------------------------------------------------------
# Base command-line tools
# ----------------------------------------------------------------------

section "3. Command-line tools"

for cmd in git curl conda; do
    if command_exists "$cmd"; then
        VERSION="$("$cmd" --version 2>/dev/null | head -n 1)"
        pass "$cmd is available: $VERSION"
    else
        fail "$cmd is not available"
    fi
done

if command_exists unzip; then
    pass "unzip is available"
else
    if [ "$OS" = "Darwin" ]; then
        warn "unzip was not found"
    else
        fail "unzip is not available"
    fi
fi


# ----------------------------------------------------------------------
# Conda
# ----------------------------------------------------------------------

section "4. Conda"

if command_exists conda; then
    CONDA_BASE="$(conda info --base 2>/dev/null)"

    if [ -n "$CONDA_BASE" ]; then
        pass "Conda base installation found: $CONDA_BASE"
    else
        fail "conda info --base did not return an installation path"
    fi

    # The workshop environment is intentionally NOT checked here.
    # Claude Code will create/configure it during the workshop.
    printf 'INFO  Workshop Conda environment is not required at this stage.\n'
else
    fail "Conda cannot be checked because the conda command is unavailable"
fi


# ----------------------------------------------------------------------
# VS Code
# ----------------------------------------------------------------------

section "5. Visual Studio Code"

if command_exists code; then
    CODE_VERSION="$(code --version 2>/dev/null | head -n 1)"

    if [ -n "$CODE_VERSION" ]; then
        pass "VS Code command is available: $CODE_VERSION"
    else
        fail "VS Code command exists but its version could not be determined"
    fi
else
    fail "code command is not available"
fi

if command_exists code; then
    if code --list-extensions 2>/dev/null \
        | grep -Fixq "anthropic.claude-code"; then
        pass "Anthropic Claude Code VS Code extension is installed"
    else
        fail "Anthropic Claude Code VS Code extension is not installed"
    fi
fi

if [ "$IS_WSL" -eq 1 ]; then
    if [ -n "${WSL_DISTRO_NAME:-}" ]; then
        pass "WSL distribution detected: $WSL_DISTRO_NAME"
    else
        warn "Could not determine the WSL distribution name"
    fi

    printf 'INFO  In VS Code, confirm the lower-left status indicator shows WSL: Ubuntu.\n'
fi


# ----------------------------------------------------------------------
# Claude Code
# ----------------------------------------------------------------------

section "6. Claude Code"

# The standalone Claude CLI is optional in the setup guide.
if command_exists claude; then
    CLAUDE_VERSION="$(claude --version 2>/dev/null | head -n 1)"

    if [ -n "$CLAUDE_VERSION" ]; then
        pass "Optional Claude CLI is available: $CLAUDE_VERSION"
    else
        warn "Claude CLI exists but its version could not be determined"
    fi
else
    printf 'INFO  Standalone Claude CLI is not installed. This is optional.\n'
fi

printf 'INFO  Confirm manually that Claude Code browser sign-in succeeds in VS Code.\n'


# ----------------------------------------------------------------------
# Claude download endpoint
# ----------------------------------------------------------------------

section "7. Network access"

HTTP_STATUS="$(
    curl \
        --silent \
        --show-error \
        --head \
        --location \
        --max-time 15 \
        --output /dev/null \
        --write-out '%{http_code}' \
        https://downloads.claude.ai/claude-code-releases/latest \
        2>/dev/null
)"

if [ "$HTTP_STATUS" = "200" ]; then
    pass "Claude download endpoint is reachable"
elif [ -n "$HTTP_STATUS" ] && [ "$HTTP_STATUS" != "000" ]; then
    warn "Claude download endpoint returned HTTP $HTTP_STATUS"
else
    warn "Could not reach the Claude download endpoint"
    printf '      This may indicate a proxy, firewall, DNS, TLS, or network issue.\n'
fi


# ----------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------

section "Setup summary"

printf 'Passed:   %d\n' "$PASS_COUNT"
printf 'Warnings: %d\n' "$WARN_COUNT"
printf 'Failed:   %d\n' "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf '\nSETUP CHECK FAILED\n'
    printf 'Fix the failed checks above before the workshop.\n'
    exit 1
fi

printf '\nSETUP CHECK PASSED\n'

if [ "$WARN_COUNT" -gt 0 ]; then
    printf 'Review the warnings above, but no required setup checks failed.\n'
fi

exit 0
