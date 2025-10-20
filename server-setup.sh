#!/bin/bash
# Script de configuração do Servidor NAT + DHCP + Cockpit
# ATENÇÃO: deve ser executado como root

# ---------- Atualização e pacotes ----------
echo "[+] Atualizando pacotes e instalando dependências..."
apt update -y && apt upgrade -y
apt install -y net-tools network-manager vim nftables kea-dhcp4-server cockpit

# ---------- Configuração da interface ----------
IFACE_LAN="enp0s8"
IFACE_WAN="enp0s3"
IP_LAN="192.168.0.254"
NETMASK="255.255.255.0"

echo "[+] Configurando interface $IFACE_LAN com IP estático..."
cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%F-%H%M)
cat <<EOF >> /etc/network/interfaces

auto $IFACE_LAN
iface $IFACE_LAN inet static
    address $IP_LAN
    netmask $NETMASK
EOF

systemctl restart NetworkManager

# ---------- Ativar roteamento ----------
echo "[+] Ativando IP Forwarding..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ipforward.conf
sysctl --system

# ---------- Configuração do NAT com nftables ----------
echo "[+] Configurando NAT no nftables..."
cp /etc/nftables.conf /etc/nftables.conf.bak.$(date +%F-%H%M)
cat <<EOF > /etc/nftables.conf
flush ruleset

table ip nat {
    chain prerouting {
        type nat hook prerouting priority 0;
    }

    chain postrouting {
        type nat hook postrouting priority 100;
        oif "$IFACE_WAN" masquerade
    }
}

table ip filter {
    chain forward {
        type filter hook forward priority 0;

        # permitir tráfego da LAN para a internet
        iif "$IFACE_LAN" oif "$IFACE_WAN" accept

        # permitir respostas da internet para a LAN
        iif "$IFACE_WAN" oif "$IFACE_LAN" ct state related,established accept
    }
}
EOF

systemctl restart nftables
systemctl enable nftables

# ---------- Configuração do DHCP ----------
echo "[+] Configurando servidor DHCP (Kea)..."
cd /etc/kea || exit 1
mv kea-dhcp4.conf kea-dhcp4.conf.old.$(date +%F-%H%M)
cat <<EOF > kea-dhcp4.conf
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": ["$IFACE_LAN"]
    },
    "subnet4": [
      {
        "id": 1,
        "subnet": "192.168.0.0/24",
        "pools": [
          { "pool": "192.168.0.1 - 192.168.0.253" }
        ]
      }
    ],
    "option-data": [
      { "name": "routers", "data": "$IP_LAN" },
      { "name": "domain-name-servers", "data": "8.8.8.8, 8.8.4.4" }
    ]
  }
}
EOF

systemctl restart kea-dhcp4-server.service
systemctl enable kea-dhcp4-server.service

# ---------- Instalar e configurar Squid ----------
echo "[+] Instalando e configurando Squid..."
apt install -y squid

# Backup da configuração original
cp /etc/squid/squid.conf /etc/squid/squid.conf.bak.$(date +%F-%H%M)

# Criação de lista de bloqueios
cat <<EOF > /etc/squid/blocked-sites.acl
.facebook.com
.instagram.com
.youtube.com
.tiktok.com
EOF

# Nova configuração do Squid
cat <<EOF > /etc/squid/squid.conf
# Configuração básica do Squid Proxy
http_port 3128
visible_hostname servidor-proxy

# Permitir acesso da LAN
acl rede_local src 192.168.0.0/24
acl bloqueados dstdomain "/etc/squid/blocked-sites.acl"

# Negar o restante
http_access deny bloqueados
http_access allow rede_local
http_access deny all

# Logs
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log
EOF

systemctl restart squid
systemctl enable squid

echo "[OK] Squid instalado e sites bloqueados."



# ---------- Ativar Cockpit ----------
echo "[+] Habilitando Cockpit..."
systemctl enable --now cockpit.socket

echo "[OK] Servidor configurado com sucesso!"
echo "Acesse Cockpit em: https://$IP_LAN:9090"

