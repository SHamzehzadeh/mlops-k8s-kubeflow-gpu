# Setting Up [Velero](https://velero.io/) on Kubernetes with [MinIO](https://min.io/) [S3](https://aws.amazon.com/s3/) Bucket
## Install Velero CLI
> https://github.com/vmware-tanzu/velero/releases/tag/v1.11.1
## Setup Kubernetes [external-snapshotter](https://github.com/kubernetes-csi/external-snapshotter)
> **_If nessecary_** - (To install csidriver) :  
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/csi-api/release-1.21/pkg/crd/manifests/csidriver.yaml  

Clone the repo:
        git clone https://github.com/kubernetes-csi/external-snapshotter.git
### Install Snapshot CRDs
> **Do this once per cluster.**  

        kubectl kustomize client/config/crd | kubectl create -f -  

> Path : ~/external-snapshotter/client/config/crd

### Install Common Snapshot Controller  
> **Do this once per cluster.**  

        kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -    

> Path : ~/external-snapshotter/deploy/kubernetes/snapshot-controller

### Install CSI Driver - _sample hostpath CSI driver_
> **_*Follow CSI Driver vendor documentation and instructions for each specific vendor_**  

        
        kubectl kustomize deploy/kubernetes/csi-snapshotter | kubectl create -f -  


> Path : ~/external-snapshotter/deploy/kubernetes/csi-snapshotter  

### Validating Webhook
        kubectl get volumesnapshots --selector=snapshot.storage.kubernetes.io/invalid-snapshot-resource  

        kubectl get volumesnapshotcontents --selector=snapshot.storage.kubernetes.io/invalid-snapshot-content-resource  

## Deploy Velero Server Components  
### Create credentials-velero file
        [default]
        aws_access_key_id = <minio tenant access-key -- encoded base64>
        aws_secret_access_key = <minio tenant secret-key -- encoded base64>
### Install  

        velero install \
        --use-node-agent \
        --provider aws \
        --features=EnableCSI \
        --plugins velero/velero-plugin-for-aws:v1.2.1,velero/velero-plugin-for-csi:v0.3.0 \
        --bucket <S3 bucket-name> \
        --secret-file ./credentials-velero \
        --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=minio.<minio tenant namespace name>.svc.cluster.local:80 \
        --snapshot-location-config region=minio

## References  
https://github.com/vmware-tanzu/velero/releases/tag/v1.11.1  
https://github.com/kubernetes-csi/external-snapshotter  
https://velero.io/  
https://min.io/  
https://aws.amazon.com/s3/  
https://medium.com/cloudnloud/velero-backups-in-kubernetes-39af7e92d992 

