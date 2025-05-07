#!/bin/bash

echo "🔍 Поиск VM с префиксом 'k8s-'..."

# Получаем список VM, фильтруем по имени
for vmid in $(qm list | awk '$2 ~ /^k8s-/ {print $1}'); do
  vmname=$(qm config $vmid | grep "^name:" | awk '{print $2}')
  echo "🛑 Остановка и удаление VM ID=$vmid ($vmname)..."
  qm stop $vmid
  qm destroy $vmid --purge
done

echo "✅ Все VM с префиксом 'k8s-' удалены."
