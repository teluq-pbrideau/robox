text
reboot --eject
lang en_US.UTF-8
keyboard us
timezone US/Pacific
rootpw --plaintext vagrant
user --name=vagrant --password=vagrant --plaintext

zerombr
clearpart --all --initlabel
part /boot --fstype="xfs" --size=1024 --label=boot
part pv.01 --fstype="lvmpv" --grow
volgroup fedora --pesize=4096 pv.01
logvol swap --fstype="swap" --size=2048 --name=swap --vgname=fedora
logvol / --fstype="xfs" --percent=100 --label="root" --name=root --vgname=fedora

firewall --enabled --service=ssh --port=6000:tcp,6050:tcp,7000:tcp,7050:tcp,7500:tcp,7501:tcp,7550:tcp,7551:tcp,8000:tcp,8050:tcp,8500:tcp,8550:tcp,9000:tcp,9050:tcp,9500:tcp,9550:tcp,10000:tcp,10050:tcp,10500:tcp,10550:tcp
network --device eth0 --bootproto dhcp --noipv6 --hostname=magma.localdomain
bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 no_timer_check vga=792 nomodeset text"

# When this release is no longer available from mirrors, enable the archive url.
url --url=https://dl.fedoraproject.org/pub/fedora/linux/releases/36/Server/x86_64/os/
# url --url=https://mirrors.edge.kernel.org/fedora/releases/36/Everything/x86_64/os/
# url --url=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/36/Everything/x86_64/os/

%packages
net-tools
@core
-mcelog
-usbutils
-microcode_ctl
-smartmontools
-plymouth
-plymouth-core-libs
-plymouth-scripts
%end

%post

# Create the vagrant user account.
/usr/sbin/useradd vagrant
echo "vagrant" | passwd --stdin vagrant

# Make the future vagrant user a sudo master.
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
chmod 0440 /etc/sudoers.d/vagrant

VIRT=`dmesg | grep "Hypervisor detected" | awk -F': ' '{print $2}'`
if [[ $VIRT == "Microsoft HyperV" || $VIRT == "Microsoft Hyper-V" ]]; then
    dnf --assumeyes install hyperv-daemons
    systemctl enable hypervvssd.service
    systemctl enable hypervkvpd.service
fi

sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

cat <<-EOF > /etc/udev/rules.d/60-scheduler.rules
# Set the default scheduler for various device types and avoid the buggy bfq scheduler.
ACTION=="add|change", KERNEL=="sd[a-z]|sg[a-z]|vd[a-z]|hd[a-z]|xvd[a-z]|dm-*|mmcblk[0-9]*|nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
EOF

%end
