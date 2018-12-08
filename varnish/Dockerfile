FROM cooptilleuls/varnish:4.1.10-alpine3.8

ARG COMMIT="local-build"
ARG DATE="1970-01-01T00:00:00Z"
ARG URL="https://github.com/zsoerenm/magento2-docker"
ARG VERSION="dirty"

LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=$DATE \
    org.label-schema.vendor="Soeren Zorn" \
    org.label-schema.name="zsoerenm/magento2-varnish" \
    org.label-schema.description="A Varnish container for Magento 2" \
    org.label-schema.version="$VERSION" \
    org.label-schema.vcs-url=$URL \
    org.label-schema.vcs-ref=$COMMIT

ENV COMMIT "$COMMIT"
ENV DATE "$DATE"
ENV VERSION "$VERSION"

COPY varnish/varnish-template.vcl /usr/local/etc/varnish/
COPY varnish/docker-varnish-entrypoint /usr/local/bin/

RUN chmod 755 /usr/local/bin/docker-varnish-entrypoint

ENV BACKEND_HOST web
ENV BACKEND_PORT 80
ENV VARNISH_HOST web
ENV SSL_OFFLOADED_HEADER X-Forwarded-Proto
ENV GRACE_PERIOD 0
