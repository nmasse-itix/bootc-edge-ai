# Multi-architecture Tekton Pipeline

## Tekton configuration

```sh
oc patch configmap/feature-flags -n openshift-pipelines --type=merge -p '{"data":{"disable-affinity-assistant":"true"}}'
```

## Pipeline manifests

```sh
oc apply -k common/
oc apply -f pipeline.yaml
```

## Authentication to the registries

```sh
export REGISTRY_AUTH_FILE="$PWD/auth.json"
podman login quay.io
podman login registry.redhat.io
oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  annotations:
    tekton.dev/docker-0: https://quay.io
  name: registry-authentication
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(base64 -w0 "$PWD/auth.json")
EOF
```

## Initialize data inside the PVC

Create a Pod that uses the two previously created PVC :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rsync
  labels:
    app: rsync
spec:
  containers:
  - name: rsync
    image: registry.redhat.io/ubi9/ubi:9.6
    command: ["/bin/sleep"]
    args: ["INF"]
    volumeMounts:
    - name: bootc-caches
      mountPath: /caches
    - name: bootc-entitlements
      mountPath: /entitlements
  volumes:
  - name: bootc-caches
    persistentVolumeClaim:
      claimName: bootc-caches
  - name: bootc-entitlements
    persistentVolumeClaim:
      claimName: bootc-entitlements
```

Then copy all the data to `/caches` and `/entitlements`.

```sh
mkdir -p entitlements
cp etc-x86_64.tar entitlements/x86_64.tar
cp etc-aarch64.tar entitlements/aarch64.tar
oc rsync entitlements rsync:/
oc rsh rsync mkdir -p /caches/{x86_64,aarch64}/{rpm-ostree,dnf}
```

You can leave the Pod running or delete it with :

```sh
oc delete pod rsync
```

## Run it!

```sh
oc create -f pipelinerun.yaml
```
