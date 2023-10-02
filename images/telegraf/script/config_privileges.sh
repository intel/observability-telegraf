#!/bin/bash

# Check if visudo contains S.M.A.R.T. string
# If so, there's no need for updating visudo file
if ! grep -q S.M.A.R.T. "/etc/sudoers"; then
  printf '# S.M.A.R.T. config\nCmnd_Alias SMARTCTL = /usr/sbin/smartctl\ntelegraf  ALL=(ALL) NOPASSWD: SMARTCTL\nDefaults!SMARTCTL !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# NVME-CLI config\nCmnd_Alias NVME = /usr/sbin/nvme\ntelegraf  ALL=(ALL) NOPASSWD: NVME\nDefaults!NVME !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# IPTABLES config\nCmnd_Alias IPTABLESSHOW = /sbin/iptables -nvL *\ntelegraf  ALL=(root) NOPASSWD: IPTABLESSHOW\nDefaults!IPTABLESSHOW !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# IPTABLES-NFT config\nCmnd_Alias IPTABLESNFTSHOW = /sbin/iptables-nft -nvL *\ntelegraf  ALL=(root) NOPASSWD: IPTABLESNFTSHOW\nDefaults!IPTABLESNFTSHOW !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# IPMITOOL config\nCmnd_Alias IPMITOOL = /usr/sbin/ipmitool *\ntelegraf  ALL=(root) NOPASSWD: IPMITOOL\nDefaults!IPMITOOL !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# PQOS config\nCmnd_Alias PQOS = /usr/local/bin/pqos *\ntelegraf  ALL=(root) NOPASSWD: PQOS\nDefaults!PQOS !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo
else
  # Show info about visudo contains config, NC stands for "no color".
  GREEN='\033[1;32m'
  NC='\033[0m'
  echo -e "${GREEN}SUDO CONFIG ALREADY SET${NC}"
fi
