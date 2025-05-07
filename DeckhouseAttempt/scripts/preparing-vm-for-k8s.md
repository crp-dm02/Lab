 # Инструкция  подготовки виртуальных машин на proxmox для кластера k8s 
 1. Создание шаблона виртуальной машины  (cloud-init-template) c помошью скрипта /Lab/DeckhouseAttempt/scripts/create_template_for_k8s.sh, нюанс в использовании cloud-image, с обычным iso алгоритм изменится 
 2. Количество и параметры вм задаются в скрипте /Users//Lab/DeckhouseAttempt/scripts/create-k8s-vms.sh
 Нюанс с ключами описан внутри в комментариях 
 3. С помощью скрипта /Lab/DeckhouseAttempt/scripts/delete-k8s-vms.sh можно удалить виртуальные машины по префиксу 
 4. Для конкретной заадчи необходимо было использование сетевого оборудования в среде pnetlab.
 распространяется в виде ova образа, поэтому нужно закинуть образ на сервер, разархивировать `tar -xvf PNETLab.ova`, и использовать образ диска .vmdk  в скрипте /Lab/DeckhouseAttempt/scripts/create-pnetlab.sh