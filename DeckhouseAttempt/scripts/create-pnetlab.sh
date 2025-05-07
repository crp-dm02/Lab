#!/bin/bash

# === Настройки ===
VM_ID=131
VM_NAME="pnetlab"
STORAGE="local-lvm"          # Используйте dir-based хранилище (НЕ local-lvm!)
DISK_FILE="PNET_4.2.10-disk1.vmdk"
BRIDGE="vmbr0"           # Мост для подключения к сети

# === Проверка наличия VMDK ===
if [ ! -f "$DISK_FILE" ]; then
  echo "Файл $DISK_FILE не найден в текущей директории!"
  exit 1
fi

echo "[1/6] Создание пустой VM (ID: $VM_ID)..."
qm create $VM_ID --name $VM_NAME --memory 16384 --cores 4 --cpu host --net0 virtio,bridge=$BRIDGE --ostype l26

echo "[2/6] Импорт VMDK-диска..."
qm importdisk $VM_ID $DISK_FILE $STORAGE --format qcow2

echo "[3/6] Подключение диска к VM..."
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${VM_ID}-disk-0

echo "[4/6] Назначение загрузочного диска..."
qm set $VM_ID --boot order=scsi0

echo "[5/6] Установка VGA и включение консоли..."
qm set $VM_ID --vga std --serial0 socket --bootdisk scsi0

echo "[6/6] Запуск VM..."
qm start $VM_ID

echo "✅ PNETLab VM создана и запущена! Теперь можешь подключиться через Proxmox Web Console."
