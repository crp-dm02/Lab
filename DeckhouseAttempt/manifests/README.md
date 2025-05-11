# manifests
тут лежат все нужные ямлы
## config.yml
этот файл содержит настройки модулей при setup кластера, в целом все согласно документации
среди особенностей 
1. Выбор доменного имени 
2. Задание сети в которой будет разворачиваться кластер `StaticClusterConfiguration`
3. Была проблема с локальной директорией .ssh при установке, решилось путем очистки папки known_hosts
4. Существует проблема с сертификатами letsencrypt при попытке добавить с помошью kubeconfig себе локально конфигурации
для kubectl, они не подптсываются, либо проблема с конфигурацией модуля `user-authn` и короче решение временное это настройка самоподписанного для этого необходимо было вносить правки в конфиг `user-authn` и генерировать сертификат 
```bash
    `kubectl -n d8-user-authn get secrets kubernetes-api-ca-key-pair -oyaml`
```
и в user-authn изменить SelfSigned но это не решит проблему в долгосрок 
```bash
    `kubectl edit mc user-authn -oyaml`
 ```

```yaml
    apiVersion: deckhouse.io/v1alpha1
    kind: ModuleConfig
    metadata:
        creationTimestamp: "2025-04-29T16:02:30Z"
        finalizers:
        - modules.deckhouse.io/module-config
        generation: 3
        name: user-authn
        resourceVersion: "203919"
        uid: 84e72f12-c23b-41d9-851f-d2642af05206
    spec:
        enabled: true
        settings:
            controlPlaneConfigurator:
                dexCAMode: FromIngressSecret
            publishAPI:
            enabled: true
            https:
                mode: SelfSigned
        version: 2
    status:
        message: ""
        version: "2"
```

## user.yml
этот yaml  создает пользователя для доступа в веб-интерфейсы кластера на мастере

## ingress-nginx-controller.yml
установка ingress контроллера на мастере

## подготовка и добавление workers
на worker нодах надо выполнить команды 

```bash
export KEY=''
sudo useradd -m -s /bin/bash caps
sudo usermod -aG sudo caps
sudo echo 'caps ALL=(ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo
sudo mkdir /home/caps/.ssh
sudo echo "$KEY" | sudo tee -a /home/caps/.ssh/authorized_keys > /dev/null
sudo chown -R caps:caps /home/caps
sudo chmod 700 /home/caps/.ssh
sudo chmod 600 /home/caps/.ssh/authorized_keys
sudo cat  /home/caps/.ssh/authorized_keys 
```

на мастере согласно доке https://deckhouse.ru/products/kubernetes-platform/gs/bm/step5.html

исключение 
если добавлять еще одну worker ноду, то в NodeGroup указываем количество StaticInstances 
```bash
sudo -i d8 k create -f - << EOF
apiVersion: deckhouse.io/v1
kind: NodeGroup
metadata:
  name: worker
spec:
  nodeType: Static
  staticInstances:
    count: <your>
    labelSelector:
      matchLabels:
        role: worker
EOF
```
и создавать соответствующее количество staticinstances
```bash
# Укажите IP-адрес узла, который необходимо подключить к кластеру.
export NODE=<NODE-IP-ADDRESS>
sudo -i d8 k create -f - <<EOF
apiVersion: deckhouse.io/v1alpha1
kind: StaticInstance
metadata:
  name: d8cluster-worker<your number>
  labels:
    role: worker
spec:
  address: "$NODE"
  credentialsRef:
    kind: SSHCredentials
    name: caps
EOF
```

##  curl-runner.yml

Deployment и service c curl для проверки доступности любого адреса указанного в качестве параметра 

## ssh-runner.yml

Pod c проверкой подключения по ssh к  vm с pnetlab в одной сети без egress gateway

## ssh-cisco.yml

Pod c проверкой подключения по ssh к  cisco роутеру в pnetlab в одной сети без egress gateway

## snmp-exporter-deckhouse.yaml

Yaml создает Deployment, Service, ServiceMonitor для экспорта данных с роутера в pnetlab в одной сети без egress gateway
кроме того предварительно необходимо создать ConfigMap из файла snmp-lite.yml (ограничение 1 Mb), либо подключать файл snmp.yml (1,5 Mb) отдельно.

```bash
sudo -i kubectl create configmap snmp-exporter-config   --from-file=/home/ubuntu/snmp.yml   -n d8-monitoring
```