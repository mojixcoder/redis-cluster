
## Redis Cluster Kubernetes Helm Charts

This repository contains Redis cluster helm charts that can survive pod restarts in which the pod IPs get changed afterwards, the cluster will be recovered successfully.

![Redis-Cluster](https://s3.us-east-2.amazonaws.com/assets-university.redislabs.com/ru301/4.4/image1.png)

### Parameters

| Name | Description | Example |
|--|--|--|
 `nameOverride` | String to override `redis-cluster.name` template | `redis-cluster`
`fullnameOverride` | String to override `redis-cluster.fullname`  `template` | `redis-cluster`
`redis.image` | Redis docker image | `redis:7.2.3`
`redis.port` | Redis server port | `6379`
`redis.bus` | Redis cluster bus port | `16379`
`redis.resources` | The resources of the redis container | `{}`
`cluster.init` | A boolean to specify whether the cluster should be initialized. (Can be false when cluster is already created and maybe you just want to change the resources of the cluster) | `true`
`cluster.master` | Number of master nodes | `3`
`cluster.replicas` | Number of replicas of each master | `1`
`metrics.enabled` | Turn on/off Redis exporter | `true`
`metrics.image` | Docker image of Redis exporter | `oliver006/redis_exporter:v1.55.0`
`metrics.resources` | Resources of metrics container | `{}`
`metrics.serviceMonitor.enabled` | Create a service monitor if `metrics` is enabled | `true`
`metrics.serviceMonitor.interval` | Metrics scraping interval | `30s`
`service.enabled` | Create a service to access the cluster | `true`
`service.type` | Service type | `ClusterIP`
`persistence.storage` | volume storage | `2Gi`
`persistence.accessModes` | volume access modes | `["ReadWriteOnce"]`
`persistence.storageClassName`| Storage class name of PVC | `ceph-rdb`
`extraConfig`| Passing extra key-value configs to redis.conf | `{}`

Please see the [values.yaml](https://github.com/mojixcoder/redis-cluster/blob/main/values.yaml) see how these parameters are used.

### Deploy

Clone the repo and `cd` to the repo directory.

```
helm upgrade -i redis-cluster . -f values.yaml
```
