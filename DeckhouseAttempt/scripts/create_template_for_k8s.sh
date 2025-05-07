#!/bin/bash

# Переменные
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_NAME="ubuntu-22.04-server-cloudimg-amd64.img"
STORAGE="local-lvm"     # Или другой, например 'local'
VMID=1200               # ID для шаблона
VMNAME="ubuntu-22.04-template"

# Шаг 1: Загрузить образ
echo "[1/5] Скачивание образа..."
#wget -O $IMAGE_NAME $IMAGE_URL

# Шаг 2: Создать пустую VM
echo "[2/5] Создание пустой VM..."
qm create $VMID --name $VMNAME --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Шаг 3: Импортировать диск в хранилище
echo "[3/5] Импорт диска в $STORAGE..."
qm importdisk $VMID $IMAGE_NAME $STORAGE --format qcow2

# Шаг 4: Присоединить диск, настроить загрузку и Cloud-Init
echo "[4/5] Настройка диска и Cloud-Init..."
qm set $VMID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-$VMID-disk-0
qm set $VMID --ide2 ${STORAGE}:cloudinit
qm set $VMID --boot c --bootdisk scsi0
#qm set $VMID --serial0 socket --vga serial0

# Шаг 5: Сделать VM шаблоном
echo "[5/5] Преобразование в шаблон..."
qm template $VMID

echo "✅ Шаблон $VMNAME (VMID $VMID) готов!"

