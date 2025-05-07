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
