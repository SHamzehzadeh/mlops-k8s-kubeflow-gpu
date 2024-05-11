# **Deploying Kubeflow on a Self-Managed Bare Metal K8s Cluster with GPU Acceleration** 

This repository provides a guide for deploying Kubeflow on a self-managed Kubernetes cluster set up on bare metal hardware. This approach offers greater control and customization compared to managed services, and lets you leverage the processing power of GPUs available on worker nodes for machine learning tasks. The guide utilises CRI-O, a lightweight alternative to Docker, as the container runtime. [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

## Assumptions  

1. A Kubernetes master node must be deployed and running beforehand.  
2. Calico networking is assumed to be installed and configured on the master node for cluster networking.  
3. The necessary GPU drivers need to be pre-installed on the worker nodes.  
4. CRI-O is assumed to be installed on the master node as the container runtime engine. If Docker is used on the master node, consult the documentation for the appropriate configuration steps for deploying Kubeflow with Docker.  
  
# Deployment Steps  

## 1. Turning off the swap
        swapoff -a
        
>Following command finds any lines in **/etc/fstab** that mention _**"swap"**_ and comments them out by adding a _**"#"**_ character at the beginning of the line. This effectively disables any swap entries listed in the file.  

        sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab     

> Kubernetes traditionally requires disabling swap on your system for a few key reasons
>
>> _**Predictability**_  
>> Kubernetes relies on accurately predicting memory usage for pods. Swap makes this difficult because it introduces uncertainty about how much memory is truly available. The scheduler wouldn't know if free memory is actually usable or just swapped out data.
>
>> _**Performance**_  
>> Accessing swap is significantly slower than accessing real RAM. This can lead to performance issues for your applications running in Kubernetes pods.
>
>> _**Isolation**_  
>> Swap can undermine the isolation between pods on a shared machine. If one pod starts using swap heavily, it can impact the performance of other pods. 
> 
> Disabling swap is the traditional and recommended approach for ensuring smooth operation of Kubernetes. While there's beta support for using swap, it's important to be aware of the potential drawbacks.  






#### References
[Kubernetes](https://github.com/kubernetes/kubernetes)  
[CRI-O](https://github.com/cri-o/cri-o/blob/main/install.md)  
[Install Calico networking and network policy for on-premises deployments](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)  
[OpenEBS](https://github.com/openebs/openebs)  
[Kubeflow](https://github.com/kubeflow/kubeflow)