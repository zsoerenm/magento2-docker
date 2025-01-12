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

    renovate_line_number=$((`cat renovate.json | grep -n $renovate_package_name | cut -d : -f 1` + 1))

    sed -i "${renovate_line_number}s/.*/      \"allowedVersions\": \"<=$version\"/" renovate.json
}

magento_version_docker_line=$(cat php/Dockerfile | grep "ARG MAGENTO_VERSION")
magento_version=${magento_version_docker_line#"ARG MAGENTO_VERSION="}

possible_magento_versions=`getValues "Software Dependencies"`
line_number=`echo "$possible_magento_versions" | grep -xn $magento_version | cut -d : -f 1`

setVersion "Varnish" "varnish" $line_number
setVersion "MariaDB" "mariadb" $line_number
setVersion "PHP" "php" $line_number
setVersion "nginx" "nginx" $line_number
setVersion "Redis" "redis" $line_number
setVersion "OpenSearch" "opensearch" $line_number



