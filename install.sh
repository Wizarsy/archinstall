#!/usr/bin/env bash
set -e

export __TIMEZONE=America/Sao_Paulo \
  __USERNAME=wizarsy \
  __LOCALE=en_US \
  __HOSTNAME=VM \
  __DEVICE=/dev/sda \
  __LANG=en_US.UTF-8 \
  __KEYMAP=us


onNewRoot(){
  arch-chroot /mnt bash -c "$@"
}

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

pacstrap -K /mnt base linux linux-firmware sudo dhcpcd networkmanager resolvconf grub efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab

onNewRoot ln -sf /usr/share/zoneinfo/"$__TIMEZONE" /etc/localtime
onNewRoot hwclock --systohc

sed -i "/${__LOCALE}/s/^#//" /mnt/etc/locale.gen
onNewRoot locale-gen

echo "LANG=${__LANG}" > /mnt/etc/locale.conf
echo "KEYMAP=${__KEYMAP}" > /mnt/etc/vconsole.conf

echo "$__HOSTNAME" > /mnt/etc/hostname
cat << EOF > /mnt/etc/hosts
127.0.0.1  localhost
::1        localhost
127.0.1.1  $__HOSTNAME
EOF

onNewRoot useradd -m -G wheel -s /bin/bash "$__USERNAME"
"$__USERNAME ALL=(ALL) ALL" > /mnt/etc/sudoers.d/"00_${__USERNAME}"

# echo -n "password for root: "
# read -r __ROOTPASS
onNewRoot echo "${__ROOTPASS:-"teste"}" | passwd -s root

# echo -n "password for ${__USERNAME}: "
# read -r __USERPASS
onNewRoot echo "${__USERPASS:-"teste"}" | passwd -s "$__USERNAME"

onNewRoot grub-install "${__DEVICE}1" --bootloader-id=GRUB
onNewRoot grub-mkconfig -o /boot/grub/grub.cfg

onNewRoot systemctl enable dhcpcd
onNewRoot systemctl enable NetworkManager
onNewRoot systemctl enable systemd-resolved
onNewRoot timedatectl set-ntp true

# umount /mnt/boot
# umount /mnt
# reboot