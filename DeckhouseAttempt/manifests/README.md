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

## Next steps 

Цель была сделать возможным исходящий трафик в сеть отличную от сети кластера Deckhouse и тут были возможны несколько вариантов 
1. egress gateway cilium 
2. egress gateway istio 

Поддержка egressgateway cilium в CE версии Deckhouse не предусмотрена, поэтому оставался вариант с istio 
В Deckhouse есть поддержка istio как модуля (! не рабочий вариант так как istio не поддерживает UDP, который используется SNMP )

## istio-enable.yaml 

Включение модуля istio и установка запрета выхода трафика не через egress и передача некоторых функций CNI istio

## istio-curl.yml 

пример реализации curl с доки istio для тестирования egressgateway 

## Example egress gateway from istio doc 

```bash
sudo -i kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: cnn
spec:
  hosts:
  - edition.cnn.com
  ports:
  - number: 80
    name: http-port
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
EOF
```
```bash
sudo -i kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - edition.cnn.com
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: istio-egressgateway.default.svc.cluster.local
  subsets:
  - name: cnn
EOF
```

```bash
sudo -i kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - edition.cnn.com
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.default.svc.cluster.local
        subset: cnn
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: edition.cnn.com
        port:
          number: 80
      weight: 100
EOF
```

команда включения и выключения istio в default namespace
```bash
 sudo -i kubectl label ns default istio-injection=enabled
 sudo -i kubectl label namespace default istio-injection=disabled --overwrite
 ```



 ## Простое решение мониторинга удаленной сети

 По сути для мониторинга небольшого количества устройств с разными подсетями мб добавлены статические маршруты 
 В качестве примера был добавлен роутер Mikrotik и настроено сетевое взаимодействие с ним из мастер ноды (?вопрос будет ли пинг с воркера - нет не будет, кроме того контейнеры тоже не будут понимать что делать с этим адресом, поэтому добавляем маршруты в сеть самостоятельно на всех нодах) 
 пробуем поднять service monitor с одним snmp exporter - успех, проблема в том что все данные для прометеуса видятся как от одного устройтсва - это решается с помощью переназначения меток для устройств пример ниже

 ```bash
 ...
 relabelings:
        - sourceLabels: [__param_target]
          targetLabel: instance
        - targetLabel: device
          replacement: cisco
 ``` 
 

 ## just Cilium 

 единственным рабочим вариантом обеспечивающим масштабирование (чего нет в простом решении с добавлением статических маршрутов на каждую ноду) с поддержкой UDP (чего нет в istio) оставался Cilium, но не как модуль deckhouse (в СE не поддержки egress gateway), а как самостоятельное решение

 Тут подход был следующий
 1. Выключаем cilium как модуль (пример из официальной документации) 
 Пример выключения модуля:
с помощью ресурса ModuleConfig:
``` bash
apiVersion: deckhouse.io/v1alpha1
kind: ModuleConfig
metadata:
  name: cni-cilium
spec:
  enabled: false
```
с помощью команды deckhouse-controller (требуется kubectl, настроенный на работу с кластером):
``` bash
kubectl -ti -n d8-system exec svc/deckhouse-leader -c deckhouse -- deckhouse-controller module disable cni-cilium
```

2. Перед установкой нужно удалить webhook-handler, так как он блокирует установку

``` bash
sudo -i kubectl get pod -n d8-system
sudo -i kubectl delete pod -n d8-system webhook-handler-7f865b9dc7-9bpkp
``` 


3. Устанавливаем cilium (фициальная документация cilium)
``` bash
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
``` 

``` bash
cilium install --version 1.17.4
``` 
4. в результате установки в namespace kube-system должны появиться podы сilium 3 штуки и сilium-operator

сilium-operator поднялся не сразу ( ошибки читать в describe ) нужны были права, выдать можно 
```bash
cat cilium-operator-clusterrolebinding.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cilium-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cilium-operator
subjects:
- kind: ServiceAccount
  name: cilium-operator
  namespace: kube-system
```

cilium  тоже поднимался не сразу ниже пример решения проблемы с правами 

```bash
sudo -i cat <<EOF | sudo -i kubectl apply -f -
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata:
     name: cilium-fix
   roleRef:
     apiGroup: rbac.authorization.k8s.io
     kind: ClusterRole
     name: cluster-admin
   subjects:
   - kind: ServiceAccount
     name: cilium
     namespace: kube-system
   EOF
```
скорее всего проблема в том что они поднимаются в kube-system namespace

5. Рестарт deckhouse 

```bash
 sudo -i kubectl rollout restart deployment deckhouse -n d8-system
 sudo -i kubectl rollout restart daemonset/cilium -n kube-system
 sudo -i kubectl rollout restart deployment/cilium-operator -n kube-system
 sudo -i kubectl get pods -n kube-system
```

6. После этого можно проверить работает cilium или нет 
с помощью манифеста создаются два namespace с curl и nginx  `curl-nginx-connect.yaml`

7. cilium is ready 

## egress gateway cilium 

тут проблемы были с корректной настройкой параметров для работы egress. В доке описано два подхода с помощью ConfigMap и Helm
сначала пробовал с помощью ConfigMap, затем установил Helm

1. Собственно history пошагово делать не надо можно сразу к cilium-values.yaml после утсановки helm
```bash 
sudo -i cilium status --verbose
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

sudo -i helm repo add cilium https://helm.cilium.io/
sudo -i helm repo update
sudo -i  helm upgrade cilium cilium/cilium --version 1.17.4    --namespace kube-system    --reuse-values    --set egressGateway.enabled=true    --set bpf.masquerade=true    --set kubeProxyReplacement=true

sudo -i kubectl rollout restart ds cilium -n kube-system
sudo -i kubectl rollout restart deploy cilium-operator -n kube-system

sudo -i cilium status --verbose
sudo -i helm get values cilium -n kube-system
```

Но это не помогло кажется, ниже файл конфигурации который сработал (после отключения vxlan и утсановки routingMode: native)

```bash
sudo -i helm upgrade cilium cilium/cilium   --namespace kube-system   -f /home/ubuntu/cilium-values.yaml


USER-SUPPLIED VALUES:
bpf:
  masquerade: true
cluster:
  name: kubernetes
egressGateway:
  enabled: true
k8sServiceHost: 127.0.0.1
k8sServicePort: 6445
kubeProxyReplacement: true
nativeRoutingCIDR: 10.0.0.0/16
operator:
  replicas: 1
routingMode: native
tunnelProtocol: disabled

sudo -i kubectl rollout restart ds cilium -n kube-system
sudo -i kubectl rollout restart deploy cilium-operator -n kube-system

```

2. Создаем CiliumEgressGatewayPolicy

```bash 
egress-test.yaml

apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: egress-test
spec:
  selectors:
  - podSelector:
      matchLabels:
        app: tester
    namespaceSelector:
      matchLabels:
        name: test-tools
  egressGateway:
    nodeSelector:
      matchLabels:
        kubernetes.io/hostname: k8s-worker1
    egressIP: 10.0.200.2
  destinationCIDRs:
  - 0.0.0.0/0
```

Проверка, что создалось 
```bash
sudo -i kubectl get ciliumegressgatewaypolicy

```

Добавление метки  для namespace чтобы выделять трафик для egress 
```bash
sudo -i kubectl label namespace test-tools name=test-tools
sudo -i kubectl get ns test-tools --show-labels
```


3. Теперь тестирование 

Как понять что трафик выходит с egress gateway (вопрос в долг)
по сути  есть cilium monitor, hubble, утилиты для bpf 
Я использовал натурный способ :) 
у меня две ноды worker1 - на нем я запускаю egress gateway, сообственно говоря с этой ноды я могу попасть 
в сеть 192.168.200.0/24 , так как я вручную прописывал маршрут
и worker2 - на эту ноду биндятся pod ы (причем я не указывал это явно, хотя по-хорошему надо бы), на этой ноде соответстсвенно нет маршрутов в сеть  192.168.200.0/24, поэтому если связь есть, то получается что все работает 

```bash
tester-deployment.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: test-tools
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tester
  namespace: test-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tester
  template:
    metadata:
      annotations:
        io.cilium.egress-gateway: "true"
      labels:
        app: tester
    spec:
      containers:
      - name: tester
        image: ubuntu:22.04
        tty: true
```

exec в pod, ставим утилиты и тестим ping, ssh, snmp 

## egress gateway cilium and monitoring of two hosts

задача была скрестить работающий мониторинг двух хостов и  egress gateway 
основная проблема была в label что куда вешать

1. Создаем namespace `snmp-monitoring`
```bash
sudo -i kubectl create ns  snmp-monitoring 
sudo -i kubectl get pod -n snmp-monitoring --show-labels
``` 
2. Создаем egress gateway 

Указываем метки, целевые хосты 

egress-snmp.yaml
```bash
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: snmp-exporter-egress
spec:
  selectors:
    - podSelector:
        matchLabels:
          app: snmp-exporter
      namespaceSelector:
        matchLabels:
          name: snmp-monitoring
  egressGateway:
    nodeSelector:
      matchLabels:
        kubernetes.io/hostname: k8s-worker1  
    egressIP: 10.0.200.2                    
  destinationCIDRs:
    - 10.0.200.200/32
    - 192.168.200.100/32
```

3. snmp-exporter-deckhouse-2hosts.yaml

Создаем configmap для snmp-exporter
```bash 
sudo -i kubectl create configmap snmp-exporter-config   --from-file=/home/ubuntu/snmp.yml   -n snmp-monitoring
```

Сообственно сам ямлик с  deploy, service и двумя servicemonitor, которые должны быть namespace d8-monitoring 
поэтому тут появляется нюанс, состоящий в том что прометеус должен уметь искать в других namespace сервисы 
следующая команда `вроде бы` включает это
```bash
sudo -i kubectl label ns snmp-monitoring prometheus.deckhouse.io/monitor-watcher-enabled=true
```
Добавляем метку на namespace 
```bash
sudo -i kubectl label namespace snmp-monitoring name=snmp-monitoring
```

4. Смотрим в прометеус targets и должны увидеть два хоста 