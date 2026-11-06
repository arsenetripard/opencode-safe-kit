#!/usr/bin/env bash
# =============================================================================
#  Default-deny egress. Only ALLOWED_HOSTS (LLM gateway + internal artifact
#  mirrors) and the configured DNS resolver are reachable.
#  Pattern derived from the public Claude Code / opencode devcontainer firewalls.
# =============================================================================
set -euo pipefail

ALLOWED_HOSTS="${ALLOWED_HOSTS:-<llmaas.gateway.internal> <artifactory.internal>}"

iptables -F OUTPUT
iptables -F INPUT
ipset destroy allowed 2>/dev/null || true
ipset create allowed hash:ip

# DNS: only to the resolvers from resolv.conf (limits DNS exfiltration)
for ns in $(awk '/^nameserver/{print $2}' /etc/resolv.conf); do
  iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
  iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
done

# Loopback + established
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT  -i lo -j ACCEPT
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Resolve allowlisted hosts
for h in $ALLOWED_HOSTS; do
  ips=$(dig +short A "$h" | grep -E '^[0-9.]+$' || true)
  [[ -z "$ips" ]] && { echo "[firewall] WARN cannot resolve $h"; continue; }
  for ip in $ips; do ipset add allowed "$ip" -exist; done
  echo "[firewall] allow $h -> $(echo $ips | tr '\n' ' ')"
done
iptables -A OUTPUT -m set --match-set allowed dst -p tcp --dport 443 -j ACCEPT

# Everything else: reject (fast failure, visible to the user)
iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

# Self-test
if timeout 5 bash -c 'exec 3<>/dev/tcp/1.1.1.1/443' 2>/dev/null; then
  echo "[firewall] FAIL: arbitrary egress still possible"; exit 1
fi
echo "[firewall] OK: default-deny egress active"
