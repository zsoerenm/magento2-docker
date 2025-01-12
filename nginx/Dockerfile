FROM nginx:1.27.3-alpine AS magento2-nginx

# renovate: datasource=github-tags depName=magento2 packageName=magento/magento2 versioning=composer
ARG MAGENTO_VERSION=2.4.7-p3

COPY nginx/conf/default.conf.template /etc/nginx/templates/

WORKDIR /var/www/html

RUN set -ex; \
    apk --update add tar && \
    wget -qO magento2.tar.gz http://pubfiles.nexcess.net/magento/ce-packages/magento2-${MAGENTO_VERSION}.tar.gz && \
    tar xzfo magento2.tar.gz ./nginx.conf.sample && \
    # Also copy php files from pub folder so that nginx thinks index.php, get.php, etc exists
    # This could probably be done more efficiently by editing the nginx.conf.sample
    # (so that it doesn't check for existence anymore)
    # Media files need to shared via a named volume (see docker-compose file)
    tar xzfo magento2.tar.gz --wildcards ./pub/*.php && \
    tar xzfo magento2.tar.gz --wildcards ./pub/**/*.php && \
    rm magento2.tar.gz && \
    chown -R 1000:nginx pub

# The following image creates the production environment.
FROM magento2-nginx

COPY --from=magento2-php-prod /var/www/html/pub/static /var/www/html/pub/static
