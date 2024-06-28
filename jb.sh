#!/bin/bash

# 检查是否以 root 身份运行
if [ "$(id -u)" -ne 0 ]; then
  echo "请以 root 身份运行此脚本。"
  exit 1
fi

# 更新并安装 dante-server
echo "更新软件包列表并安装 dante-server..."
apt-get update
apt-get install -y dante-server

# 配置 dante-server
echo "配置 dante-server..."
cat <<EOT > /etc/danted.conf
logoutput: syslog
internal: eth0 port = 1080
external: eth0

method: username

user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
}
EOT

# 添加默认 socks 用户
DEFAULT_USER="socksuser"
DEFAULT_PASS="sockspass"
echo "添加默认 SOCKS 代理用户: $DEFAULT_USER"
useradd -m -s /usr/sbin/nologin $DEFAULT_USER
echo "$DEFAULT_USER:$DEFAULT_PASS" | chpasswd

# 配置 PAM 认证
echo "配置 PAM 认证..."
cat <<EOT > /etc/pam.d/sockd
auth    required   pam_unix.so
account required   pam_unix.so
EOT

# 启动并启用 dante-server
echo "启动并启用 dante-server 服务..."
systemctl restart danted
systemctl enable danted

# 开放防火墙端口（如果使用 UFW）
echo "配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 1080/tcp
fi

echo "SOCKS5 代理安装和配置完成。默认用户名: $DEFAULT_USER, 默认密码: $DEFAULT_PASS"
