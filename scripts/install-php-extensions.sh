#!/bin/sh
# Installs PHP extensions based on composer.json requirements
# Usage: install-php-extensions.sh <path-to-composer.json>

set -e

# Validate input
if [ $# -ne 1 ]; then
    echo "Error: composer.json path required" >&2
    echo "Usage: $0 <path-to-composer.json>" >&2
    exit 1
fi

COMPOSER_JSON="$1"

if [ ! -f "$COMPOSER_JSON" ]; then
    echo "Error: composer.json not found at $COMPOSER_JSON" >&2
    exit 1
fi

echo "==> Installing PHP extensions from $COMPOSER_JSON"

# Extract ext-* requirements from composer.json
# Parse require section and filter for ext- entries
REQUIRED_EXTENSIONS=$(grep -A 200 '"require"' "$COMPOSER_JSON" | \
    grep '"ext-' | \
    sed 's/.*"ext-\([^"]*\)".*/\1/' | \
    sort -u)

echo "==> Found required extensions:"
echo "$REQUIRED_EXTENSIONS" | sed 's/^/    - /'

# Extensions that are built into PHP (skip installation)
BUILTIN_EXTENSIONS="ctype curl dom hash iconv mbstring openssl simplexml sodium"

# Filter out built-in extensions
EXTENSIONS_TO_INSTALL=""
for ext in $REQUIRED_EXTENSIONS; do
    is_builtin=0
    for builtin in $BUILTIN_EXTENSIONS; do
        if [ "$ext" = "$builtin" ]; then
            echo "    Skipping $ext (built-in)"
            is_builtin=1
            break
        fi
    done
    if [ $is_builtin -eq 0 ]; then
        EXTENSIONS_TO_INSTALL="$EXTENSIONS_TO_INSTALL $ext"
    fi
done

if [ -z "$EXTENSIONS_TO_INSTALL" ]; then
    echo "==> No extensions to install (all built-in)"
    exit 0
fi

echo "==> Extensions to install:$EXTENSIONS_TO_INSTALL"

# Map extensions to Alpine packages
RUNTIME_DEPS="linux-headers supercronic"
BUILD_DEPS=""
CONFIGURE_EXTS=""
SIMPLE_EXTS=""

for ext in $EXTENSIONS_TO_INSTALL; do
    case "$ext" in
        bcmath)
            SIMPLE_EXTS="$SIMPLE_EXTS bcmath"
            ;;
        ftp)
            SIMPLE_EXTS="$SIMPLE_EXTS ftp"
            ;;
        gd)
            RUNTIME_DEPS="$RUNTIME_DEPS freetype libjpeg-turbo libpng"
            BUILD_DEPS="$BUILD_DEPS freetype-dev libjpeg-turbo-dev libpng-dev"
            CONFIGURE_EXTS="$CONFIGURE_EXTS gd"
            ;;
        intl)
            RUNTIME_DEPS="$RUNTIME_DEPS icu"
            BUILD_DEPS="$BUILD_DEPS icu-dev"
            SIMPLE_EXTS="$SIMPLE_EXTS intl"
            ;;
        opcache)
            SIMPLE_EXTS="$SIMPLE_EXTS opcache"
            ;;
        pdo_mysql)
            SIMPLE_EXTS="$SIMPLE_EXTS pdo_mysql"
            ;;
        sockets)
            SIMPLE_EXTS="$SIMPLE_EXTS sockets"
            ;;
        soap)
            RUNTIME_DEPS="$RUNTIME_DEPS libxml2"
            BUILD_DEPS="$BUILD_DEPS libxml2-dev"
            SIMPLE_EXTS="$SIMPLE_EXTS soap"
            ;;
        xsl)
            RUNTIME_DEPS="$RUNTIME_DEPS libxslt"
            BUILD_DEPS="$BUILD_DEPS libxslt-dev"
            SIMPLE_EXTS="$SIMPLE_EXTS xsl"
            ;;
        zip)
            RUNTIME_DEPS="$RUNTIME_DEPS libzip"
            BUILD_DEPS="$BUILD_DEPS libzip-dev"
            SIMPLE_EXTS="$SIMPLE_EXTS zip"
            ;;
        *)
            echo "Warning: Unknown extension '$ext', attempting to install without dependencies" >&2
            SIMPLE_EXTS="$SIMPLE_EXTS $ext"
            ;;
    esac
done

# Install runtime dependencies
if [ -n "$RUNTIME_DEPS" ]; then
    echo "==> Installing runtime dependencies"
    apk add --update --no-cache -t .php-rundeps $RUNTIME_DEPS
fi

# Install build dependencies
if [ -n "$BUILD_DEPS" ]; then
    echo "==> Installing build dependencies"
    apk add --update --no-cache -t .build-deps $BUILD_DEPS
fi

# Configure extensions that need it (like gd)
for ext in $CONFIGURE_EXTS; do
    echo "==> Configuring $ext"
    case "$ext" in
        gd)
            docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/
            ;;
    esac
done

# Install all extensions
ALL_EXTS="$SIMPLE_EXTS $CONFIGURE_EXTS"
if [ -n "$ALL_EXTS" ]; then
    echo "==> Installing PHP extensions:$ALL_EXTS"
    docker-php-ext-install -j$(nproc) $ALL_EXTS
fi

# Clean up build dependencies
if [ -n "$BUILD_DEPS" ]; then
    echo "==> Cleaning up build dependencies"
    docker-php-source delete
    apk del --purge .build-deps
fi

# Validate all extensions are installed
echo "==> Validating extensions"
VALIDATION_FAILED=0
for ext in $REQUIRED_EXTENSIONS; do
    if php -m | grep -q "^${ext}$"; then
        echo "    ✓ $ext"
    else
        echo "    ✗ $ext (MISSING)" >&2
        VALIDATION_FAILED=1
    fi
done

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo "Error: Some extensions failed to install" >&2
    exit 3
fi

echo "==> All extensions installed successfully"
