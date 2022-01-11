#!/bin/bash

mkcert_ver="1.4.3"
vaultwarden_srv_ver="1.23.1"
vaultwarden_web_ver="2.25.0"
vaultwarden_admin_token=$(openssl rand -base64 48)
rpi_hostname=$(hostname -f)
rpi_ip=$(ip route get 8.8.8.8 | sed -n '/src/{s/.*src *\([^ ]*\).*/\1/p;q}')


apt-get update
apt-get install -y --no-install-recommends libssl-dev pkgconf 

wget https://github.com/dani-garcia/vaultwarden/archive/refs/tags/${vaultwarden_srv_ver}.tar.gz
tar -xzf ${vaultwarden_srv_ver}.tar.gz
cd vaultwarden-${vaultwarden_srv_ver}
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --profile minimal --default-toolchain $(cat ./rust-toolchain) -y
source $HOME/.cargo/env
cargo install cargo-cache
cargo cache -a
rm ~/.cargo/config
echo '[target.armv7-unknown-linux-gnueabihf]' >> ~/.cargo/config
echo 'linker = "arm-linux-gnueabihf-gcc"' >> ~/.cargo/config
echo 'rustflags = ["-L/usr/lib/arm-linux-gnueabihf"]' >> ~/.cargo/config

cargo build --features "sqlite" --target=armv7-unknown-linux-gnueabihf --release

mkdir -p /opt/vaultwarden
addgroup --system vaultwarden
adduser --system --home /opt/vaultwarden --shell /usr/sbin/nologin --no-create-home --gecos 'vaultwarden' --ingroup vaultwarden --disabled-login --disabled-password vaultwarden

systemctl stop vaultwarden.service
mkdir -p /opt/vaultwarden/bin
mkdir -p /opt/vaultwarden/data
cp target/armv7-unknown-linux-gnueabihf/release/vaultwarden /opt/vaultwarden/bin/

rm -rf /opt/vaultwarden/web-vault/
curl -fsSLO https://github.com/dani-garcia/bw_web_builds/releases/download/v${vaultwarden_web_ver}/bw_web_v${vaultwarden_web_ver}.tar.gz
tar -zxf bw_web_v${vaultwarden_web_ver}.tar.gz -C /opt/vaultwarden/
rm -f bw_web_v${vaultwarden_web_ver}.tar.gz

rm -f /opt/vaultwarden/.env
cat > /opt/vaultwarden/.env <<EOF
DATA_FOLDER=/opt/vaultwarden/data/
DATABASE_MAX_CONNS=10
WEB_VAULT_FOLDER=/opt/vaultwarden/web-vault/
WEB_VAULT_ENABLED=true
ROCKET_ENV=staging
ROCKET_ADDRESS=${rpi_ip}
ROCKET_PORT=8000
ROCKET_TLS={certs="/opt/vaultwarden/cert/rocket.pem",key="/opt/vaultwarden/cert/rocket-key.pem"}
ADMIN_TOKEN=${vaultwarden_admin_token}
DISABLE_ADMIN_TOKEN=false
INVITATIONS_ALLOWED=false
WEBSOCKET_ENABLED=true
WEBSOCKET_ADDRESS=${rpi_ip}
WEBSOCKET_PORT=3012
IP_HEADER=none
ORG_CREATION_USERS=local@admin
DOMAIN=https://${rpi_ip}:8000
SHOW_PASSWORD_HINT=false
ICON_CACHE_TTL=86400
DISABLE_ICON_DOWNLOAD=true
ICON_BLACKLIST_NON_GLOBAL_IPS=true
SIGNUPS_ALLOWED=false
EOF

chown -R vaultwarden:vaultwarden /opt/vaultwarden/
chown root:root /opt/vaultwarden/bin/vaultwarden
chmod +x /opt/vaultwarden/bin/vaultwarden
chown -R root:root /opt/vaultwarden/web-vault/
chmod +r /opt/vaultwarden/.env


curl -fsSL https://github.com/FiloSottile/mkcert/releases/download/v${mkcert_ver}/mkcert-v${mkcert_ver}-linux-arm -o /usr/local/bin/mkcert
chmod +x /usr/local/bin/mkcert
mkcert -install
update-ca-certificates
mkdir /opt/vaultwarden/cert
mkcert -cert-file /opt/vaultwarden/cert/rocket.pem -key-file /opt/vaultwarden/cert/rocket-key.pem ${rpi_hostname} ${rpi_ip}
chown -R vaultwarden:vaultwarden /opt/vaultwarden/cert
openssl verify -verbose -CAfile ~/.local/share/mkcert/rootCA.pem /opt/vaultwarden/cert/rocket.pem

rm -f /etc/systemd/system/vaultwarden.service
cat > /etc/systemd/system/vaultwarden.service <<EOF
[Unit]
Description=Vaultwarden Server
Documentation=https://github.com/dani-garcia/vaultwarden
After=network.target

[Service]
User=vaultwarden
Group=vaultwarden
EnvironmentFile=-/opt/vaultwarden/.env
ExecStart=/opt/vaultwarden/bin/vaultwarden
LimitNOFILE=65535
LimitNPROC=4096
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict
DevicePolicy=closed
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictNamespaces=yes
RestrictRealtime=yes
MemoryDenyWriteExecute=yes
LockPersonality=yes
WorkingDirectory=/opt/vaultwarden
ReadWriteDirectories=/opt/vaultwarden/data
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vaultwarden.service
systemctl start vaultwarden.service
systemctl status vaultwarden.service
tail /var/log/syslog

