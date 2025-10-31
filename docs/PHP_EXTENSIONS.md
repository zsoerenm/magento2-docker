# PHP Extension Management

This project automatically installs PHP extensions based on requirements in `src/composer.json`.

## How It Works

1. **Build Time**: During Docker build, `scripts/install-php-extensions.sh` parses `src/composer.json`
2. **Extension Detection**: Extracts all `ext-*` entries from the `require` section
3. **Package Mapping**: Maps PHP extensions to required Alpine Linux packages
4. **Installation**: Installs extensions using `docker-php-ext-install`
5. **Validation**: Verifies all extensions are loaded in PHP

## Supported Extensions

The script automatically handles these Magento-required extensions:

| Extension | Alpine Packages | Notes |
|-----------|----------------|-------|
| bcmath | - | Built-in compilation |
| ftp | - | Built-in compilation |
| gd | freetype, libjpeg-turbo, libpng | Requires configure flags |
| intl | icu | Internationalization |
| opcache | - | Built-in compilation |
| pdo_mysql | - | Built-in compilation |
| sockets | - | Built-in compilation |
| soap | libxml2 | XML processing |
| xsl | libxslt | XSLT support |
| zip | libzip | Archive handling |

**Built-in extensions** (automatically skipped):
- ctype, curl, dom, hash, iconv, mbstring, openssl, simplexml, sodium

## Adding New Extensions

If Magento adds new extension requirements:

1. Add to `src/composer.json` require section: `"ext-newext": "*"`
2. Rebuild Docker image - script will attempt automatic installation
3. If build fails, add mapping to `scripts/install-php-extensions.sh`:

```bash
newext)
    RUNTIME_DEPS="$RUNTIME_DEPS package-name"
    BUILD_DEPS="$BUILD_DEPS package-name-dev"
    SIMPLE_EXTS="$SIMPLE_EXTS newext"
    ;;
```

## Troubleshooting

### Build fails with "extension not found"

Check if the extension exists in the PHP source:
```bash
docker run --rm php:8.3-fpm-alpine ls /usr/src/php/ext/
```

### Extension appears installed but not loaded

Verify with:
```bash
docker run --rm your-image php -m | grep extension_name
```

May need to add `.ini` file to enable the extension.

### Unknown Alpine package name

Search Alpine packages:
- https://pkgs.alpinelinux.org/packages

## Manual Override

To temporarily override automated installation, modify `php/Dockerfile` to skip the script and manually install extensions. Not recommended for long-term maintenance.
