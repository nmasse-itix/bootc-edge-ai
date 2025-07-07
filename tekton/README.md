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

## Authentication to Pypi

```sh
oc create secret generic pypi-mirror '--from-literal=PYPI_MIRROR_URL=https://login:password@artifactory-host/artifactory/api/pypi/pypi-virtual/simple'
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

```sh
oc create configmap registries-conf --from-file=/etc/containers/registries.conf
```

## Authentication to GitHub

```sh
cat > gitconfig <<EOF
[credential]
  helper=store
EOF
oc create secret generic github-authentication --from-literal=.git-credentials=https://user:password@github.com --from-file=.gitconfig=gitconfig
```

## Rclone config for AWS S3

**rclone.conf**:

```ini
[aws]
type = s3
provider = AWS
access_key_id = REDACTED
secret_access_key = REDACTED
region = eu-west-3
```

Note: in **rclone.conf**, set **endpoint** to the hostname of your S3 gateway when on-premise.

Create the secret:

```sh
oc create secret generic rclone-config --from-file=rclone.conf
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
    - name: bootc-rpms
      mountPath: /rpms
  volumes:
  - name: bootc-caches
    persistentVolumeClaim:
      claimName: bootc-caches
  - name: bootc-entitlements
    persistentVolumeClaim:
      claimName: bootc-entitlements
  - name: bootc-rpms
    persistentVolumeClaim:
      claimName: bootc-rpms
```

Then copy all the data to `/caches`, `/rpms` and `/entitlements`.

```sh
mkdir -p entitlements
cp etc-x86_64.tar entitlements/x86_64.tar
cp etc-aarch64.tar entitlements/aarch64.tar
oc rsync entitlements rsync:/
oc rsh rsync mkdir -p /caches/{x86_64,aarch64}/{rpm-ostree,dnf}
tar -c -C /path/to/rpms | oc rsh rsync tar -x -C /rpms
```

You can leave the Pod running or delete it with :

```sh
oc delete pod rsync
```

## Run it!

```sh
oc create -f pipelinerun.yaml
```
