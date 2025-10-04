# Magento 2.4.7 is compatible with varnish 7.
# See https://experienceleague.adobe.com/en/docs/commerce-operations/release/notes/magento-open-source/2-4-7
# However, it is missing the varnish7.vcl configuration file.
# Hence, let's get the configuration file from 2.4.8-beta1 for now.
FROM varnish:7.6.1-alpine AS magento2-varnish

COPY --chmod=755 varnish/entrypoint /usr/local/bin/

# renovate: datasource=github-tags depName=magento2 packageName=magento/magento2 versioning=composer
ARG MAGENTO_VERSION=2.4.8-beta2

USER root

RUN set -ex; \
    apk add --no-cache patch && \
    chown -R varnish:varnish /etc/varnish && \
    wget -qO- https://github.com/magento/magento2/archive/refs/tags/${MAGENTO_VERSION}.tar.gz \
    | tar xzfo - --strip-components=6 magento2-${MAGENTO_VERSION}/app/code/Magento/PageCache/etc/varnish7.vcl && \
    chown varnish:varnish varnish7.vcl && \
    mv varnish7.vcl varnish-template.vcl

USER varnish

ENV BACKEND_HOST=web
ENV BACKEND_PORT=8080
ENV VARNISH_HOST=web
ENV SSL_OFFLOADED_HEADER=X-Forwarded-Proto
ENV GRACE_PERIOD=0

ENTRYPOINT ["/usr/local/bin/entrypoint"]
