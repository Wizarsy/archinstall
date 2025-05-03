#!/usr/bin/env bash
set -e

export __TIMEZONE=America/Sao_Paulo \
  __USERNAME=wizarsy \
  __LOCALE=en_US \
  __HOSTNAME=VM \
  __DEVICE=/dev/sda \
  __LANG=en_US.UTF-8 \
  __KEYMAP=us

parted "$__DEVICE" --script mklabel gpt
parted "$__DEVICE" --script mkpart "boot" fat32 1MiB 1025MiB 
parted "$__DEVICE" --script mkpart "swap" linux-swap 1025MiB 5121MiB 
parted "$__DEVICE" --script mkpart "root" ext4 5121MiB 100%
parted "$__DEVICE" --script set 1 boot on

mkfs.fat -F 32 "${__DEVICE}1"
mkswap "${__DEVICE}2"
mkfs.ext4 "${__DEVICE}3"

mount "${__DEVICE}3" /mnt
mount --mkdir "${__DEVICE}1" /mnt/boot
swapon "${__DEVICE}2"

pacstrap -K /mnt base linux linux-firmware sudo

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/"$__TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "/${__LOCALE}/s/^#//" /etc/__LOCALE.gen
__LOCALE-gen

echo "__LANG=${__LANG}" > /etc/__LOCALE.conf
echo "__KEYMAP=${__KEYMAP}" > /etc/vconsole.conf

echo "$__HOSTNAME" > /etc/__HOSTNAME
cat << EOF > /etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  $__HOSTNAME
EOF

useradd -m -G wheel -s /bin/bash $__USERNAME
passwd root
passwd $__USERNAME
echo "$__USERNAME ALL=(ALL) ALL" > /etc/sudoers.d/00_$__USERNAME

pacman -S --noconfirm grub efibootmgr
grub-install "${__DEVICE}1" --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

pacman -S --noconfirm dhcpcd networkmanager resolvconf
systemctl enable dhcpcd
systemctl enable NetworkManager
systemctl enable systemd-resolved
timedatectl set-ntp true

umount /mnt/boot
umount /mnt
reboot