FROM nginx:alpine

RUN apk add --no-cache openssl

COPY nginx.conf /etc/nginx/nginx.conf
COPY generate-certs.sh /docker-entrypoint.d/generate-certs.sh

ENTRYPOINT ["/bin/sh", "-c", "sh /docker-entrypoint.d/generate-certs.sh && nginx -g 'daemon off;'"]
