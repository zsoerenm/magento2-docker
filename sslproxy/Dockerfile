FROM nginx:1.15.7-alpine

ARG COMMIT="local-build"
ARG DATE="1970-01-01T00:00:00Z"
ARG URL="https://github.com/zsoerenm/magento2-docker"
ARG VERSION="dirty"

LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=$DATE \
    org.label-schema.vendor="Soeren Zorn" \
    org.label-schema.name="zsoerenm/magento2-sslproxy" \
    org.label-schema.description="A Nginx SSL-Proxy container for Magento 2" \
    org.label-schema.version="$VERSION" \
    org.label-schema.vcs-url=$URL \
    org.label-schema.vcs-ref=$COMMIT

COPY sslproxy/conf/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY sslproxy/conf/ssl-dhparams.pem /etc/nginx/ssl/ssl-dhparams.pem

RUN chmod 664 /etc/nginx/conf.d/default.conf.template

CMD envsubst '$$SERVER_NAME $$BACKEND_HOST' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'
