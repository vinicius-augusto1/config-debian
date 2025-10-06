#!/bin/bash
# Script de configuração do Cliente
# Deve ser executado como root

echo "[+] Atualizando pacotes e instalando ferramentas..."
apt update -y && apt upgrade -y
apt install -y net-tools network-manager vim

# ---------- Ativar DHCP automático ----------
IFACE="enp0s8"
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

