#! /bin/sh
# 测试系统: Debian 10

# 我的配置
trojan_go_download_url="https://github.com/p4gefau1t/trojan-go/releases/download/v0.10.6/trojan-go-linux-amd64.zip" #trojan-go下载链接
fallback_web_download_url="https://templated.live/snapshot/download/snapshot.zip" #一个能够下载静态网站的链接
password="******"
websocket_host="***.***.***"
websocket_path="/****"
cert_content="-----BEGIN CERTIFICATE-----
****************************************************************
****************************************************************
****************************************************************
****************************************************************
-----END CERTIFICATE-----"
cert_private_key_content="-----BEGIN PRIVATE KEY-----
****************************************************************
****************************************************************
****************************************************************
****************************************************************
-----END PRIVATE KEY-----"

# clear old
systemctl stop trojan-go
systemctl disable trojan-go

rm /usr/lib/systemd/system/trojan-go.service
rm -rf /trojan-go
rm -rf /var/www/html/*
rm /etc/nginx/conf.d/fallback.conf

#update
apt update -y && apt install curl unzip nginx -y

curl -L $trojan_go_download_url -o trojan-go.zip
curl -L $fallback_web_download_url -o web.zip

mkdir /trojan-go
unzip -d /trojan-go trojan-go.zip && rm trojan-go.zip
unzip -d /var/www/html web.zip && rm web.zip

cd /trojan-go
mkdir conf

# trojan server.json
echo "{
    \"run_type\": \"server\",
    \"local_addr\": \"0.0.0.0\",
    \"local_port\": 443,
    \"remote_addr\": \"127.0.0.1\",
    \"remote_port\": 80,
    \"password\": [
        \"$password\"
    ],
    \"ssl\": {
        \"cert\": \"/trojan-go/conf/trojan.crt\",
        \"key\": \"/trojan-go/conf/trojan.key\",
        \"fallback_port\": 81
    },
    \"websocket\": {
        \"enabled\": true,
        \"path\": \"$websocket_path\",
        \"host\": \"$websocket_host\"
    }
}" > conf/server.json

# cert.crt
echo "$cert_content" > conf/trojan.crt

# private.key
echo "$cert_private_key_content" > conf/trojan.key

# fallback config
echo 'server {
	listen 81;
	listen [::]:81;
	server_name localhost;
	location / {
        return 400;
    }
}' > /etc/nginx/conf.d/fallback.conf
systemctl restart nginx

# setup trojan-go.service
echo "[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/trojan-go/trojan-go -config /trojan-go/conf/server.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target" > conf/trojan-go.service
cp conf/trojan-go.service /usr/lib/systemd/system/ && chmod 664 /usr/lib/systemd/system/trojan-go.service
systemctl enable trojan-go
systemctl daemon-reload
systemctl start trojan-go

# 设置时区(没有必要设置)
# timedatectl set-timezone Asia/Shanghai

# 定时脚本
# echo '0 5 * * * echo "reboot: `date`" >> /root/reboot.log' >> /var/spool/cron/crontabs/root

# warp 选择性开启，解决谷歌搜索人机验证问题
# curl -fsSL git.io/warp.sh | bash -s wg
# curl -fsSL git.io/warp.sh | bash -s 6

# bbr开启
echo net.core.default_qdisc=fq >> /etc/sysctl.conf && echo net.ipv4.tcp_congestion_control=bbr >> /etc/sysctl.conf && sysctl -p && sysctl net.ipv4.tcp_available_congestion_control && lsmod | grep bbr

# 配置防火墙
apt install ufw -y
ufw allow ssh
ufw allow https
ufw enable

# reboot
#/sbin/reboot

# 其他脚本
# BBR： bash <(curl -Lso- https://git.io/kernel.sh)
# WRAP： bash <(curl -fsSL git.io/warp.sh) menu