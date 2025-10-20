#!/bin/bash
# Script de configuração do Cliente
# Deve ser executado como root

echo "[+] Atualizando pacotes e instalando ferramentas..."
apt update -y && apt upgrade -y
apt install -y net-tools network-manager vim

# ---------- Ativar DHCP automático ----------
IFACE="enp0s3"
echo "[+] Configurando $IFACE para DHCP..."
cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%F-%H%M)
cat <<EOF >> /etc/network/interfaces

auto $IFACE
iface $IFACE inet dhcp
EOF

systemctl restart NetworkManager

# ---------- Teste de conectividade ----------
echo "[+] Testando conectividade..."
ping -c 4 8.8.8.8


# ---------- Configurar proxy no cliente ----------
echo "[+] Configurando proxy no cliente..."

PROXY_IP="192.168.0.254"
PROXY_PORT="3128"

# Configurar proxy no ambiente
cat <<EOF >> /etc/environment

http_proxy="http://$PROXY_IP:$PROXY_PORT/"
https_proxy="http://$PROXY_IP:$PROXY_PORT/"
ftp_proxy="http://$PROXY_IP:$PROXY_PORT/"
no_proxy="localhost,127.0.0.1,::1"
EOF

echo "[OK] Proxy configurado para $PROXY_IP:$PROXY_PORT"
