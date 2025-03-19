FROM debian:bookworm-slim

LABEL maintainer="Misterbabou"

RUN apt-get update && apt-get install -y curl unzip jq nginx gettext-base fail2ban iptables openssl

# CLI VERSION
ARG CLI_VERSION="2025.2.0"
# Download Bitwarden CLI
RUN curl -L https://github.com/bitwarden/clients/releases/download/cli-v${CLI_VERSION}/bw-linux-${CLI_VERSION}.zip -o /tmp/bw.zip

# Unzip the downloaded file
RUN unzip /tmp/bw.zip -d /tmp

# Make the Bitwarden CLI executable
RUN chmod +x /tmp/bw

# Move the Bitwarden CLI to /usr/local/bin
RUN mv /tmp/bw /usr/local/bin/

# Copy the application code
COPY bwapitool /usr/local/bin/

# Make the script executable
RUN chmod +x /usr/local/bin/bwapitool

COPY conf.d/reverse-proxy.conf.template /etc/nginx/conf.d/reverse-proxy.conf.template
COPY conf.d/reverse-proxy.conf.cert-template /etc/nginx/conf.d/reverse-proxy.conf.cert-template
RUN rm /etc/nginx/sites-enabled/default

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy Fail2Ban filter and jail configurations
COPY fail2ban/nginx-auth.conf /etc/fail2ban/filter.d/nginx-auth.conf
COPY fail2ban/nginx-auth.local.template /etc/fail2ban/jail.d/nginx-auth.local.template
RUN rm /etc/fail2ban/jail.d/defaults-debian.conf 
# Update the fail2ban.conf
RUN sed -i 's#^logtarget = .*#logtarget = /proc/1/fd/1#' /etc/fail2ban/fail2ban.conf
RUN sed -i 's/^#allowipv6 = auto/allowipv6 = auto/' /etc/fail2ban/fail2ban.conf


# Set default environment variables
ENV NGINX_PORT=443 \
    NGINX_AUTH_MODE=password \
    NGINX_READ_ONLY_PASS=changeme \
    NGINX_FULL_ACCESS_PASS=superchangeme \
    NGINX_CERT=nginx-selfsigned.crt \
    NGINX_CERT_PRIVATE=nginx-selfsigned.key \
    NGINX_AUTH_CA_CERT=selfsigned-ca.crt \
    NGINX_AUTH_CA_DEPTH=1 \
    NGINX_AUTHORIZED_CLIENTS_DN="CN=Client1,OU=Dev,O=Company,L=City,ST=State,C=US;CN=Client2,OU=Dev,O=Company,L=City,ST=State,C=US" \
    NGINX_HOSTNAME=your.server.domain \
    NGINX_ERROR_LOG_LEVEL=error \
    BW_API_PORT=8087 \
    BW_REMOTE_SERVER=https://vault.bitwarden.com \
    BW_DISABLE_EVENTS=false \
    F2B_ENABLE=true \
    F2B_BANTIME=600 \
    F2B_FINDTIME=600 \
    F2B_MAXRETRY=3

# start App
ENTRYPOINT ["/entrypoint.sh"]
