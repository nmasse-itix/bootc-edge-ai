##
## Environment setup
##

# Install mode: text (interactive installs) or cmdline (unattended installs)
text

# French keyboard layout
keyboard --vckeymap=fr --xlayouts='fr'

# English i18n
lang en_US.UTF-8 --addsupport fr_FR.UTF-8

# Accept the EULA
eula --agreed

# Which action to perform after install: poweroff or reboot
reboot

# Timezone is GMT
timezone Etc/GMT --utc

##
## network configuration
##

# THERE IS NOTHING HERE SINCE IT IS AN OFFLINE INSTALL

##
## partitioning
##

# Install on /dev/vda
#ignoredisk --only-use=vda

# Install Grub in the MBR of /dev/vda
#bootloader --location=mbr --boot-drive=vda

# Append kernel args to the boot command
bootloader --append="$KERNEL_CMDLINE"

# Clear the target disk
zerombr

# Remove existing partitions
clearpart --all --initlabel

# Automatically create partitions required by hardware platform
reqpart --add-boot

# Create a root and a /var partition
part / --fstype xfs --size=1 --grow --asprimary --label=root
#part /var --fstype xfs --size=1 --grow --asprimary --label=var

## 
## Installation
##

rootpw --lock
ostreecontainer --url=/run/install/repo/container --transport=oci --no-signature-verification
