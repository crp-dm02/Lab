#!/bin/bash

# Настройки
IMAGE_ID=1200          # ID шаблона Cloud-Init
STORAGE_NAME=local-lvm # Где хранить диски
BRIDGE=vmbr0           # Bridge-интерфейс

# Виртуалки: имя, VMID, IP
declare -A VMS=(
  ["k8s-master"]="201 10.0.200.1"
  ["k8s-worker1"]="202 10.0.200.2"
  ["k8s-worker2"]="203 10.0.200.3"
)

# Общие параметры
CPU=4
RAM=12288
DISK=60

# SSH ключ (укажи свой путь)
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo "❌ Публичный SSH-ключ не найден: $SSH_KEY_PATH"
  echo "Создайте ключ командой: ssh-keygen -t rsa -b 4096"
  exit 1
fi
SSH_KEY=$(cat "$SSH_KEY_PATH")



for NAME in "${!VMS[@]}"; do
  read -r VMID IP <<< "${VMS[$NAME]}"

  echo "Создание VM $NAME с ID $VMID и IP $IP"

  qm clone $IMAGE_ID $VMID --name $NAME
  qm set $VMID --memory $RAM --cores $CPU --net0 virtio,bridge=$BRIDGE
  qm resize $VMID scsi0 ${DISK}G

  #Здесь костыль изначально скрипт выполнялся локально на сервере, поэтому приходилось копировать ключ в папку my_key на сервере
  #Поэтому сюда надо будет поставить переменнную SSH_KEY_PATH 
  
  qm set $VMID --ciuser ubuntu --cipassword ubuntu --sshkey /root/my_key
  qm set $VMID --ipconfig0 ip=$IP/24,gw=10.0.0.2
  qm set $VMID --ide2 $STORAGE_NAME:cloudinit
  qm set $VMID --boot c --bootdisk scsi0 --scsihw virtio-scsi-pci
  qm start $VMID
done
