#!/bin/sh

# Substitute environment variables in the nginx configuration
envsubst '$NGINX_PORT $NGINX_READ_ONLY_PASS $NGINX_FULL_ACCESS_PASS $BW_API_PORT $NGINX_CERT $NGINX_CERT_PRIVATE $NGINX_HOSTNAME' < /etc/nginx/conf.d/reverse-proxy.conf.template > /etc/nginx/conf.d/reverse-proxy.conf

# Generate a self-signed SSL certificate if it doesn't exist
if [ ! -f /certs/$NGINX_CERT ] || [ ! -f /certs/$NGINX_CERT_PRIVATE ]; then
  echo "[INFO] Generating self-signed SSL certificate"
  mkdir -p /certs
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout /certs/$NGINX_CERT_PRIVATE -out /certs/$NGINX_CERT -subj "/CN=$NGINX_HOSTNAME" > /dev/null 2>&1
  echo "---"
fi

# Start nginx
echo "[INFO] Launching nginx"
nginx -g 'daemon off;' &
echo "---"

# Start Fail2Ban
if $F2B_ENABLE; then
  # Substitute environment variables in the Fail2Ban jail configuration
  envsubst '$F2B_BANTIME $F2B_FINDTIME $F2B_MAXRETRY' < /etc/fail2ban/jail.d/nginx-auth.local.template > /etc/fail2ban/jail.d/nginx-auth.local

  echo "[INFO] Launching fail2ban"
  fail2ban-server -b
  echo "---"
fi

# Launch bwapitool
/usr/local/bin/bwapitool
