#!/bin/bash

# Check if visudo contains S.M.A.R.T. string
# If so, there's no need for updating visudo file
if ! grep -q S.M.A.R.T. "/etc/sudoers"; then
  printf '# S.M.A.R.T. config\nCmnd_Alias SMARTCTL = /usr/bin/smartctl\ntelegraf  ALL=(ALL) NOPASSWD: SMARTCTL\nDefaults!SMARTCTL !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# NVME-CLI config\nCmnd_Alias NVME = /usr/bin/nvme\ntelegraf  ALL=(ALL) NOPASSWD: NVME\nDefaults!NVME !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# IPTABLES config\nCmnd_Alias IPTABLESSHOW = /usr/bin/iptables -nvL *\ntelegraf  ALL=(root) NOPASSWD: IPTABLESSHOW\nDefaults!IPTABLESSHOW !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo

  printf '# IPMITOOL config\nCmnd_Alias IPMITOOL = /usr/bin/ipmitool *\ntelegraf  ALL=(root) NOPASSWD: IPMITOOL\nDefaults!IPMITOOL !logfile, !syslog, !pam_session\n' | sudo EDITOR='tee -a' visudo
else
  # Show info about visudo contains config, NC stands for "no color".
  GREEN='\033[1;32m'
  NC='\033[0m'
  echo -e "${GREEN}SUDO CONFIG ALREADY SET${NC}"
fi
