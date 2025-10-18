#!/usr/bin/env bash
set -e
set -x

# 配置信息（可修改）
HYSTERIA_VERSION="v2.6.3"
SERVER_PORT=${PORT:-8112}
AUTH_PASSWORD="20250930"
CERT_FILE="cert.pem"
KEY_FILE="key.pem"
SNI="www.bing.com"
ALPN="h3"

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "Hysteria2 部署脚本（Linux专用格式）"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# 检测服务器架构
arch_name() {
    machine=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [[ "$machine" == *"arm64"* || "$machine" == *"aarch64"* ]]; then
        echo "arm64"
    elif [[ "$machine" == *"x86_64"* || "$machine" == *"amd64"* ]]; then
        echo "amd64"
    else
        echo ""
    fi
}

ARCH=$(arch_name)
if [ -z "$ARCH" ]; then
  echo "❌ 不支持的CPU架构：$(uname -m)"
  exit 1
fi

BIN_NAME="hysteria-linux-${ARCH}"
BIN_PATH="./${BIN_NAME}"

# 下载Hysteria程序
if [ ! -f "$BIN_PATH" ]; then
    URL="https://github.com/apernet/hysteria/releases/download/app/${HYSTERIA_VERSION}/${BIN_NAME}"
    echo "⏳ 下载程序：$URL"
    curl -L --retry 3 --connect-timeout 30 -o "$BIN_PATH" "$URL"
    chmod +x "$BIN_PATH"
    echo "✅ 程序下载完成"
else
    echo "✅ 程序已存在，跳过下载"
fi

# 生成证书（如果没有）
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "🔑 生成自签证书..."
    openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -days 3650 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/CN=${SNI}"
    echo "✅ 证书生成成功"
else
    echo "✅ 证书已存在，跳过生成"
fi

# 生成配置文件
cat > server.yaml <<EOF
listen: ":${SERVER_PORT}"
tls:
  cert: "$(pwd)/${CERT_FILE}"
  key: "$(pwd)/${KEY_FILE}"
  alpn:
    - "${ALPN}"
auth:
  type: "password"
  password: "${AUTH_PASSWORD}"
bandwidth:
  up: "200mbps"
  down: "200mbps"
quic:
  max_idle_timeout: "10s"
  max_concurrent_streams: 4
  initial_stream_receive_window: 65536
  max_stream_receive_window: 131072
  initial_conn_receive_window: 131072
  max_conn_receive_window: 262144
EOF
echo "✅ 配置文件生成成功"

# 获取服务器IP并显示节点信息
SERVER_IP=$(curl -s --max-time 10 https://api.ipify.org || echo "请手动输入服务器IP")
echo "🎉 部署成功！节点信息如下："
echo "IP地址：$SERVER_IP"
echo "端口：$SERVER_PORT"
echo "密码：$AUTH_PASSWORD"
echo "节点链接：hysteria2://${AUTH_PASSWORD}@${SERVER_IP}:${SERVER_PORT}?sni=${SNI}&alpn=${ALPN}#Hy2-Bing"

# 启动Hysteria服务（前台运行，保持服务器在线）
echo "🚀 启动Hysteria2服务器..."
exec "$BIN_PATH" server -c server.yaml