# 1 Production mode

1. Modify production/config.json.

2. Build server image.

```
cd ../
bash release_build.sh -b all -l latest
```

or

```
bash ../release_build.sh --build all -label latest
```

3. Create all servers' yaml for each data center.

```
bash create_yaml.sh -p -c all
```

or

```
bash create_yaml.sh --production --create all
```

4. Deploy servers.

```
bash deploy.sh -p -t shenzhen -a all
```

or

```
bash deploy.sh --production --data_center shenzhen --create all
```

# 2 Dev mode

## 2.1 Pre Deploy

Install minikube, nginx, redis, nats, and build all server images.

```
bash dev/pre_deploy.sh -a
```

## 2.2 Deploy all servers to K8s

1. [Option] Modify dev/config.json.

2. [Option] Create all servers' yaml for each data center.

```
bash create_yaml.sh -c all
```

3. Deploy all servers to K8s.

```
bash deploy.sh -a all
```

4. Start GUI of the k8s.

```
$ lens
```

## 2.3 Start Client

```
cd xremote/client

# start remote
cargo run --release

# start vehicle
cargo run --release -- --vehicle
```

# 3 Kubectl operations

kubectl get - List one or more resources.

```
# List all pods in plain-text output format.
kubectl get pods

# List all services in plain-text output format.
kubectl get svc

# List all daemon sets in plain-text output format.
kubectl get ds

```

kubectl describe - Display detailed state of one or more resources, including the uninitialized ones by default.

```
# Display the details of all the pods that are managed by the replication controller named <rc-name>.
# Remember: Any pods that are created by the replication controller get prefixed with the name of the replication controller.
kubectl describe pods <rc-name>
```

kubectl exec - Execute a command against a container in a pod.

```
# Get an interactive TTY and run /bin/bash from pod <pod-name>. By default, output is from the first container.
kubectl exec -it <pod-name> -- /bin/bash
```
