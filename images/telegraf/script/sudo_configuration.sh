#!/bin/bash

# Check if visudo contains S.M.A.R.T. string
# If so, there's no need for updating visudo file
if ! grep -q S.M.A.R.T. "/etc/sudoers"; then
  echo '# S.M.A.R.T. config' | sudo EDITOR='tee -a' visudo
  echo 'Cmnd_Alias SMARTCTL = /usr/bin/smartctl' | sudo EDITOR='tee -a' visudo
  echo 'telegraf  ALL=(ALL) NOPASSWD: SMARTCTL' | sudo EDITOR='tee -a' visudo
  echo 'Defaults!SMARTCTL !logfile, !syslog, !pam_session' | sudo EDITOR='tee -a' visudo

  echo '# NVME-CLI config' | sudo EDITOR='tee -a' visudo
  echo 'Cmnd_Alias NVME = /usr/bin/nvme' | sudo EDITOR='tee -a' visudo
  echo 'telegraf  ALL=(ALL) NOPASSWD: NVME' | sudo EDITOR='tee -a' visudo
  echo 'Defaults!NVME !logfile, !syslog, !pam_session' | sudo EDITOR='tee -a' visudo

  echo '# IPTABLES config' | sudo EDITOR='tee -a' visudo
  echo 'Cmnd_Alias IPTABLESSHOW = /usr/bin/iptables -nvL *' | sudo EDITOR='tee -a' visudo
  echo 'telegraf  ALL=(root) NOPASSWD: IPTABLESSHOW' | sudo EDITOR='tee -a' visudo
  echo 'Defaults!IPTABLESSHOW !logfile, !syslog, !pam_session' | sudo EDITOR='tee -a' visudo

  echo '# IPMITOOL config' | sudo EDITOR='tee -a' visudo
  echo 'Cmnd_Alias IPMITOOL = /usr/bin/ipmitool *' | sudo EDITOR='tee -a' visudo
  echo 'telegraf  ALL=(root) NOPASSWD: IPMITOOL' | sudo EDITOR='tee -a' visudo
  echo 'Defaults!IPMITOOL !logfile, !syslog, !pam_session' | sudo EDITOR='tee -a' visudo
else
  # Show info about visudo contains config, NC stands for "no color".
  GREEN='\033[1;32m'
  NC='\033[0m'
  echo -e "${GREEN}SUDO CONFIG ALREADY SET${NC}"
fi