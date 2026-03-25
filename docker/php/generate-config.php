#!/usr/bin/env php
<?php
/**
 * Generate app/etc/config.php without a running database.
 *
 * Scans the filesystem for modules and themes, generates the standard
 * single-store scopes, and writes a clean config.php identical to what
 * `bin/magento app:config:dump scopes themes` would produce.
 *
 * Usage: php generate-config.php [magento-root]
 *        Default magento-root is the current directory.
 */

error_reporting(E_ALL);
ini_set('display_errors', '1');

$magentoRoot = rtrim($argv[1] ?? getcwd(), '/');

if (!is_file("$magentoRoot/composer.json")) {
    fwrite(STDERR, "Error: $magentoRoot does not look like a Magento root (no composer.json)\n");
    exit(1);
}

// ─── Modules ─────────────────────────────────────────────────────────────────

/**
 * Discover all modules by scanning for etc/module.xml files.
 * Returns ['Vendor_Module' => 1, ...] sorted alphabetically.
 */
function discoverModules(string $root): array
{
    $modules = [];

    // Paths where modules live (various directory layouts)
    $searchPaths = [
        "$root/app/code/*/*/etc/module.xml",
        "$root/vendor/*/*/etc/module.xml",
        "$root/vendor/*/*/src/etc/module.xml",
    ];

    foreach ($searchPaths as $pattern) {
        foreach (glob($pattern) ?: [] as $moduleXml) {
            $xml = @simplexml_load_file($moduleXml);
            if ($xml && isset($xml->module['name'])) {
                $modules[(string)$xml->module['name']] = 1;
            }
        }
    }

    ksort($modules);
    return $modules;
}

// ─── Themes ──────────────────────────────────────────────────────────────────

/**
 * Discover all themes by scanning for theme.xml files.
 * Returns theme data in the same format as Magento's InitialThemeSource.
 */
function discoverThemes(string $root): array
{
    $themes = [];

    // Paths where themes live
    $searchPaths = [
        "$root/app/design/*/*/*/theme.xml",       // app/design/area/Vendor/theme/theme.xml
        "$root/vendor/*/*/theme.xml",              // vendor/vendor/theme-package/theme.xml
        "$root/vendor/*/*/*/theme.xml",            // vendor/vendor/package/area/theme.xml (rare)
    ];

    foreach ($searchPaths as $pattern) {
        foreach (glob($pattern) ?: [] as $themeXml) {
            // Skip test fixtures
            if (strpos($themeXml, '/tests/') !== false || strpos($themeXml, '/Test/') !== false) {
                continue;
            }
            $theme = parseTheme($themeXml, $root);
            if ($theme) {
                $key = $theme['area'] . '/' . $theme['theme_path'];
                $themes[$key] = $theme;
            }
        }
    }

    ksort($themes);
    return $themes;
}

/**
 * Parse a single theme.xml + its registration.php to extract theme metadata.
 */
function parseTheme(string $themeXmlPath, string $root): ?array
{
    $xml = @simplexml_load_file($themeXmlPath);
    if (!$xml) {
        return null;
    }

    $themeDir = dirname($themeXmlPath);

    // Try to determine area and theme_path from registration.php
    $registrationFile = "$themeDir/registration.php";
    $area = null;
    $themePath = null;

    if (is_file($registrationFile)) {
        $content = file_get_contents($registrationFile);
        // Match: ComponentRegistrar::register(ComponentRegistrar::THEME, 'frontend/Vendor/theme', ...)
        if (preg_match("/::register\s*\(\s*ComponentRegistrar::THEME\s*,\s*['\"]([^'\"]+)['\"]/", $content, $m)) {
            $fullPath = $m[1]; // e.g. "frontend/Hyva/default"
            $parts = explode('/', $fullPath, 2);
            if (count($parts) === 2) {
                $area = $parts[0];
                $themePath = $parts[1];
            }
        }
    }

    // Fallback: derive from directory structure (app/design/area/Vendor/theme/)
    if (!$area || !$themePath) {
        $relPath = str_replace($root . '/', '', $themeDir);
        if (preg_match('#app/design/(\w+)/(.+)#', $relPath, $m)) {
            $area = $m[1];
            $themePath = $m[2];
        } else {
            // vendor themes without registration.php — skip
            return null;
        }
    }

    $title = isset($xml->title) ? (string)$xml->title : $themePath;
    $parent = isset($xml->parent) ? (string)$xml->parent : null;

    return [
        'parent_id' => $parent,
        'theme_path' => $themePath,
        'theme_title' => $title,
        'is_featured' => '0',
        'area' => $area,
        'type' => '0',
        'code' => $themePath,
    ];
}

// ─── Scopes ──────────────────────────────────────────────────────────────────

/**
 * Standard single-store scopes — identical to a fresh Magento install.
 */
function defaultScopes(): array
{
    return [
        'websites' => [
            'admin' => [
                'website_id' => '0',
                'code' => 'admin',
                'name' => 'Admin',
                'sort_order' => '0',
                'default_group_id' => '0',
                'is_default' => '0',
            ],
            'base' => [
                'website_id' => '1',
                'code' => 'base',
                'name' => 'Main Website',
                'sort_order' => '0',
                'default_group_id' => '1',
                'is_default' => '1',
            ],
        ],
        'groups' => [
            0 => [
                'group_id' => '0',
                'website_id' => '0',
                'name' => 'Default',
                'root_category_id' => '0',
                'default_store_id' => '0',
                'code' => 'default',
            ],
            1 => [
                'group_id' => '1',
                'website_id' => '1',
                'name' => 'Main Website Store',
                'root_category_id' => '2',
                'default_store_id' => '1',
                'code' => 'main_website_store',
            ],
        ],
        'stores' => [
            'admin' => [
                'store_id' => '0',
                'code' => 'admin',
                'website_id' => '0',
                'group_id' => '0',
                'name' => 'Admin',
                'sort_order' => '0',
                'is_active' => '1',
            ],
            'default' => [
                'store_id' => '1',
                'code' => 'default',
                'website_id' => '1',
                'group_id' => '1',
                'name' => 'Default Store View',
                'sort_order' => '0',
                'is_active' => '1',
            ],
        ],
    ];
}

// ─── Main ────────────────────────────────────────────────────────────────────

$modules = discoverModules($magentoRoot);
$themes = discoverThemes($magentoRoot);
$scopes = defaultScopes();

if (empty($modules)) {
    fwrite(STDERR, "Error: no modules found. Is vendor/ installed? Run composer install first.\n");
    exit(1);
}

$config = [
    'modules' => $modules,
    'scopes' => $scopes,
    'themes' => $themes,
];

$configFile = "$magentoRoot/app/etc/config.php";
$content = "<?php\nreturn " . varExportShort($config, true) . ";\n";

file_put_contents($configFile, $content);

/**
 * var_export with short array syntax and proper formatting.
 */
function varExportShort($var, bool $return = false, int $indent = 0): ?string
{
    $spaces = str_repeat('    ', $indent);
    $innerSpaces = str_repeat('    ', $indent + 1);

    if (is_array($var)) {
        $isAssoc = array_keys($var) !== range(0, count($var) - 1);
        $lines = [];
        foreach ($var as $key => $value) {
            $exportedKey = $isAssoc ? var_export($key, true) . ' => ' : '';
            $lines[] = $innerSpaces . $exportedKey . varExportShort($value, true, $indent + 1);
        }
        $result = "[\n" . implode(",\n", $lines) . "\n{$spaces}]";
    } elseif (is_null($var)) {
        $result = 'null';
    } else {
        $result = var_export($var, true);
    }

    if ($return) {
        return $result;
    }
    echo $result;
    return null;
}

$moduleCount = count($modules);
$themeCount = count($themes);
$scopeCount = count($scopes['websites']) + count($scopes['groups']) + count($scopes['stores']);
fwrite(STDERR, "Generated $configFile ($moduleCount modules, $themeCount themes, $scopeCount scopes)\n");
