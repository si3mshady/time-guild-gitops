FROM nginx:1.25-alpine

# Remove default configuration files
RUN rm -f /etc/nginx/conf.d/default.conf

# Copy custom Nginx configuration files
COPY infra/docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY infra/docker/nginx/conf.d/ /etc/nginx/conf.d/

# Create SSL certs directory
RUN mkdir -p /etc/nginx/certs

# Generate self-signed SSL certificates for dev/local testing
RUN apk add --no-co-cache openssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/certs/timeguild.key \
    -out /etc/nginx/certs/timeguild.crt \
    -subj "/C=US/ST=State/L=City/O=TimeGuild/CN=*.timeguild.xyz"

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
