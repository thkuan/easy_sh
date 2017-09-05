#!/bin/sh

DEBUG=$1
TABLES="filter nat mangle"
OUT_IFACE="wlan0"
IN_IFACE="eth0"
# Goal: 192.168.112.0/255.255.255.0
# Notice the quotations making strings followed after awk: '$1 == "' + "inet" + '" ...'
SUBNET=$(ifconfig $IN_IFACE | awk '$1 == "'"inet"'" {print substr($2, 6, 12)"0/"substr($4, 6)}')
REDIRPAGE="$(ifconfig $IN_IFACE | awk '$1 == "'"inet"'" {print substr($2, 6)}'):80"

if test -z $SUBNET; then
    echo "[ERROR] SUBNET is empty!!"
    exit
fi

# iptables firewall: 
#   1) http://linux-training.be/networking/ch14.html
#   2) http://www.iptables.info/en/connection-state.html
#   3) http://web.mit.edu/rhel-doc/4/RH-DOCS/rhel-sg-zh_tw-4/ch-fw.html

# Phase 0 (clean iptables):
for tb in $TABLES 
do
    # -F ：清除所有的已訂定的規則
    iptables -t $tb -F
    # -X ：殺掉所有使用者 "自訂" 的 chain (應該說的是 tables ）囉
    iptables -t $tb -X
    # -Z ：將所有的 chain 的計數與流量統計都歸零
    iptables -t $tb -Z
done

# Phase 1 (WIRELESS ROUTER): 
# use ipatbles forwarding and masquerading for NAT, 
# and must set net.ipv4.ip_forward=1 in /etc/sysctl.conf
# 1.) Change policy on FORWARD chain of the filter table to "DROP"
iptables -t filter -P FORWARD DROP
# 2.) Select the filter table and append a rule to FOWARD chain: 
#     ACCEPT any packets with specified source from $IN_IFACE to $OUT_IFACE 
iptables -t filter -A FORWARD --source $SUBNET --in-interface $IN_IFACE --out-interface $OUT_IFACE -j ACCEPT
# 3.) Select the filter table and append a rule to FOWARD chain: 
#     ACCEPT any packets with specified destionation which matched 
#     ESTABLISHED,RELATED state from $OUT_IFACE to $IN_IFACE 
iptables -t filter -A FORWARD --destination $SUBNET --in-interface $OUT_IFACE --out-interface $IN_IFACE --match state --state ESTABLISHED,RELATED -j ACCEPT
# 4.) Select the nat table and append a rule to POSTROUTING chain: 
#     MASQUERADE any packets with specified source that is going out $OUT_IFACE 
iptables -t nat -A POSTROUTING --source $SUBNET --out-interface $OUT_IFACE -j MASQUERADE

# Phase 2 (CAPTIVE PORTAL):
# add a new user-defined chain in mangle table
##iptables -t mangle -N internet
##iptables -t mangle -A PREROUTING -i $IN_IFACE -p tcp -m tcp --dport 80 -j internet
##iptables -t mangle -A internet -j MARK --set-mark 99
##iptables -t nat -A PREROUTING -i $IN_IFACE -p tcp -m mark --mark 99 -m tcp --dport 80 -j DNAT --to-destination $REDIRPAGE
##iptables -t nat -A PREROUTING -i $IN_IFACE -p tcp -m mark --mark 99 -m tcp --dport 443 -j DNAT --to-destination $REDIRPAGE
