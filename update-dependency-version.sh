#!/bin/sh

system_requirements_url=https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/system-requirements

getValues()
{
   key=$1
   echo "`xidel -s $system_requirements_url \
        -e "<div><div>Commerce on-premises</div><div><table><tr><td>$key</td><td>{.}</td>+</tr></table>+</div></div>"`"
}

setVersion()
{
    document_package_name=$1
    renovate_package_name=$2
    magento_version_line_number=$3
    possible_versions=`getValues $document_package_name`
    version=`echo "$possible_versions" | sed "$magento_version_line_number!d" | cut -d, -f1`

    match_line=`cat renovate.json | grep -n "\"matchPackageNames\": \[\"$renovate_package_name\"\]" | cut -d : -f 1`

    if [ -z "$match_line" ]; then
        echo "Warning: Could not find package rule for '$renovate_package_name' in renovate.json"
        return 1
    fi

    renovate_line_number=$(($match_line + 1))

    sed -i "${renovate_line_number}s/.*/      \"allowedVersions\": \"<=$version\"/" renovate.json
}

magento_version=$(cat .magento-version)

possible_magento_versions=`getValues "Software Dependencies"`
line_number=`echo "$possible_magento_versions" | grep -xn $magento_version | cut -d : -f 1`

setVersion "Varnish" "varnish" $line_number
setVersion "MariaDB" "mariadb" $line_number
setVersion "PHP" "php" $line_number
setVersion "nginx" "nginx" $line_number
setVersion "Valkey" "valkey/valkey" $line_number
setVersion "OpenSearch" "opensearchproject/opensearch" $line_number
setVersion "Composer" "composer" $line_number



