FROM nginx:1.27.3-alpine AS magento2-nginx

ARG MAGENTO_VERSION=2.4.7-p3

COPY nginx/conf/default.conf.template /etc/nginx/templates/default.conf.template

WORKDIR /var/www/html

RUN set -ex; \
    wget -qO- http://pubfiles.nexcess.net/magento/ce-packages/magento2-${MAGENTO_VERSION}.tar.gz \
    | tar xzfo - ./nginx.conf.sample

# The following image creates the production environment.
FROM magento2-nginx-base

COPY --from=magento2-php-prod /var/www/html/pub/static /var/www/html/pub/static
