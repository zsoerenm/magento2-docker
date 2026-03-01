#!/bin/sh
set -e

# Find Tailwind directories in custom themes (app/design/frontend/)
# Vendor themes (vendor/hyva-themes/) ship pre-built CSS and don't need building
TAILWIND_DIRS=$(find \
    app/design/frontend/*/*/web/tailwind \
    -maxdepth 0 -type d 2>/dev/null || true)

if [ -z "$TAILWIND_DIRS" ]; then
    echo "❌ No Tailwind themes found."
    echo "   Expected directory structure: app/design/frontend/Vendor/Theme/web/tailwind"
    exit 1
fi

MODE="${1:-watch}"

for dir in $TAILWIND_DIRS; do
    theme=$(echo "$dir" | sed 's|/web/tailwind||')
    echo "🎨 Found theme: $theme"

    if [ ! -f "$dir/package.json" ]; then
        echo "   ⚠️  Skipping — no package.json found"
        continue
    fi

    echo "   📦 Installing dependencies..."
    (cd "$dir" && npm ci --silent)

    case "$MODE" in
        watch)
            echo "   👀 Starting Tailwind watcher..."
            (cd "$dir" && npm run watch) &
            ;;
        build)
            echo "   🔨 Building Tailwind CSS..."
            (cd "$dir" && npm run build)
            echo "   ✅ Build complete"
            ;;
        *)
            echo "   ❌ Unknown mode: $MODE (use 'watch' or 'build')"
            exit 1
            ;;
    esac
done

# If watching, wait for all background processes
if [ "$MODE" = "watch" ]; then
    echo ""
    echo "👀 Watching all themes for changes... (Ctrl+C to stop)"
    wait
fi
