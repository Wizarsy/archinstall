#!/usr/bin/env bash
set -e

TIMEZONE=America/Sao_Paulo
USERNAME=wizarsy
LOCALE=en_US
HOSTNAME=VM
DEVICE=/dev/sda
LANG=en_US.UTF-8
KEYMAP=us

parted "$DEVICE" --script mklabel gpt
parted "$DEVICE" --script mkpart "boot" fat32 1MiB 1025MiB 
parted "$DEVICE" --script mkpart "swap" linux-swap 1025MiB 5121MiB 
parted "$DEVICE" --script mkpart "root" ext4 5121MiB 100%
parted "$DEVICE" --script set 1 boot on

mkfs.fat -F 32 "${DEVICE}1"
mkswap "${DEVICE}2"
mkfs.ext4 "${DEVICE}3"

mount "${DEVICE}3" /mnt
mount --mkdir "${DEVICE}1" /mnt/boot
swapon "${DEVICE}2"

pacstrap -K /mnt base linux linux-firmware sudo

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "/${LOCALE}/s/^#//" /etc/locale.gen
locale-gen

echo "LANG=${LANG}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "$HOSTNAME" > /etc/hostname
cat << EOF > /etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  $HOSTNAME
EOF

useradd -m -G wheel -s /bin/bash $USERNAME
passwd root
passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/00_$USERNAME

pacman -S grub efibootmgr
grub-install "${DEVICE}1"
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S dhcpcd networkmanager resolvconf
systemctl enable dhcpcd
systemctl enable NetworkManager
systemctl enable systemd-resolved
timedatectl set-ntp true

umount /mnt/boot
umount /mnt
reboot