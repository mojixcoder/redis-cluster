
## Redis Cluster Kubernetes Helm Charts

This repository contains Redis cluster helm charts that can survive pod restarts in which the pod IPs get changed afterwards, the cluster will be recovered successfully.

![Redis-Cluster](https://s3.us-east-2.amazonaws.com/assets-university.redislabs.com/ru301/4.4/image1.png)

### Parameters

| Name | Description | Example |
|--|--|--|
 `nameOverride` | String to override `redis-cluster.name` template | `redis-cluster`
`fullnameOverride` | String to override `redis-cluster.fullname`  `template` | `redis-cluster`
`securityContext.enabled` | Whether to enable pod's container security context or not | `false`
`securityContext` | Pod's security context | `{}`
`minReadySeconds` | minimum number of seconds for which a newly created Pod should be running and ready without any of its containers crashing, for it to be considered available | `10`
`priorityClassName` | Priority indicates the importance of a Pod relative to other Pods | `high-priority`
`serviceAccount.enabled` | Enable or disable service account | `false`
`serviceAccount.name` | Name of the service account | `default`
`redis.image` | Redis docker image | `redis:8.10`
`redis.port` | Redis server port | `6379`
`redis.bus` | Redis cluster bus port | `16379`
`redis.securityContext.enabled` | Whether to enable the Redis container security context or not | `false`
`redis.securityContext` | Redis container security context | `{}`
`redis.resources` | The resources of the redis container | `{}`
`redis.extraEnvs` | Extra environment variables for the Redis container; supports `value` and `valueFrom` | `[{"name":"MY_VAR","value":"value"}]`
`cluster.init` | A boolean to specify whether the cluster should be initialized. (Can be false when cluster is already created and maybe you just want to change the resources of the cluster) | `true`
`cluster.master` | Number of master nodes | `3`
`cluster.replicas` | Number of replicas of each master | `1`
`cluster.waitImage` | Image used by the init job to wait for all Redis nodes before creating the cluster | `atkrad/wait4x:3.7.3`
`auth.enabled` | Require a password for the `default` user. The password is also used for replication (`masterauth`), the cluster init job and the metrics exporter | `false`
`auth.password` | Password of the `default` user; stored in a chart-managed Secret named `<name>-auth`. Ignored when `auth.existingSecret.name` is set | `""`
`auth.existingSecret.name` | Name of an existing Secret holding the `default` user password | `""`
`auth.existingSecret.key` | Key inside `auth.existingSecret.name` | `redis-password`
`auth.acl.enabled` | Define additional Redis ACL users (requires `auth.enabled`) | `false`
`auth.acl.users` | List of ACL users. Each entry has `name`, `rules` and either `password` or `existingSecret.name`/`existingSecret.key` | `[]`
`metrics.enabled` | Turn on/off Redis exporter | `true`
`metrics.image` | Docker image of Redis exporter | `oliver006/redis_exporter:v1.96.0`
`metrics.securityContext.enabled` | Whether to enable metrics container security context | `false`
`metrics.securityContext` | Metric's container security context | `{}`
`metrics.resources` | Resources of metrics container | `{}`
`metrics.extraEnvs` | Extra environment variables for the metrics container; supports `value` and `valueFrom` | `[{"name":"REDIS_EXPORTER_LOG_FORMAT","value":"json"}]`
`metrics.serviceMonitor.enabled` | Create a service monitor if `metrics` is enabled | `true`
`metrics.serviceMonitor.interval` | Metrics scraping interval | `30s`
`service.enabled` | Create a service to access the cluster | `true`
`service.type` | Service type | `ClusterIP`
`persistence.storage` | volume storage | `2Gi`
`persistence.accessModes` | volume access modes | `["ReadWriteOnce"]`
`persistence.storageClassName`| Storage class name of PVC | `ceph-rdb`
`extraConfig`| Passing extra key-value configs to redis.conf | `{}`

Please see the [values.yaml](https://github.com/mojixcoder/redis-cluster/blob/main/values.yaml) to see how the parameters are used.

### Authentication and ACL

Set `auth.enabled: true` to protect the cluster with a password. The `default` user gets the password, replicas use it to authenticate against their masters, the init job passes it to `redis-cli` through `REDISCLI_AUTH`, and the metrics exporter receives it as `REDIS_PASSWORD`. When enabling auth on an already initialized cluster, set `cluster.init: false` (the init Job is immutable and cannot be upgraded) and let the StatefulSet roll; replication converges once every node has restarted with the password.

```yaml
auth:
  enabled: true
  existingSecret:
    name: my-redis-secret   # Secret with the key below
    key: redis-password
```

`auth.password` can be used instead of `existingSecret` for quick setups; the chart then creates a Secret named `<name>-auth`. Never commit real passwords to a values file.

ACL users are added on top of the `default` user:

```yaml
auth:
  enabled: true
  password: "<default-user-password>"
  acl:
    enabled: true
    users:
      - name: app
        rules: "~app:* &* +@all -@dangerous"
        existingSecret:
          name: app-redis-secret
          key: password
      - name: reader
        rules: "~* +@read"
        password: "<reader-password>"
```

How it works:

- Each user's password is injected into the Redis container as `REDIS_ACL_PASSWORD_<NAME>` (upper-cased, non-alphanumeric characters replaced by `_`).
- On start-up `run.sh` writes `/data/redis/users.acl` containing the `default` user and every ACL user, with passwords stored as SHA-256 hashes, and `redis.conf` points `aclfile` at it. Plain-text passwords never land in a ConfigMap or on disk.
- `rules` is written verbatim into the ACL file, so any [Redis ACL rule syntax](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/) is supported.
- The `default` user keeps full access (`~* &* +@all`) because the cluster init job, replication and the metrics exporter authenticate with it. Define it through `auth.password`/`auth.existingSecret`, not in `auth.acl.users`.
- Changing a password or rule requires a rolling restart of the StatefulSet, because the ACL file is generated at container start.

If you previously passed `REDIS_PASSWORD` through `redis.extraEnvs` or `metrics.extraEnvs`, remove it once `auth.enabled` is set, otherwise the variable is defined twice.

### Installation

You should add this package as a dependency in `Charts.yaml` file:

```yaml
dependencies:
  - name: redis-cluster
    version: 0.6.0
    repository: oci://registry.hub.docker.com/mojixcoder
```

To learn more about adding dependencies to your Helm charts, please follow this [link](https://helm.sh/docs/helm/helm_dependency/).
