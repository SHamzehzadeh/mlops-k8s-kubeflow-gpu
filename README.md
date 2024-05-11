# **Deploying Kubeflow on a Self-Managed Bare Metal K8s Cluster with GPU Acceleration** 

This repository provides a guide for deploying Kubeflow on a self-managed Kubernetes cluster set up on bare metal hardware. This approach offers greater control and customization compared to managed services, and lets you leverage the processing power of GPUs available on worker nodes for machine learning tasks. The guide utilises CRI-O, a lightweight alternative to Docker, as the container runtime. [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

## Assumptions  

1. A Kubernetes master node must be deployed and running beforehand.  
2. Calico networking is assumed to be installed and configured on the master node for cluster networking.  
3. The necessary GPU drivers need to be pre-installed on the worker nodes.  
4. CRI-O is assumed to be installed on the master node as the container runtime engine. If Docker is used on the master node, consult the documentation for the appropriate configuration steps for deploying Kubeflow with Docker.  

|  Package  | Version |
|---|---|
OS-> RH | 8.7 |
Kubernetes | 1.25.10 |
CRI-O | 1.26 |
Kubeflow | 1.7.0 |

# Deployment Steps  

## 1. Disable **swap** Memory
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
> Disabling swap is the traditional and recommended approach for ensuring smooth operation of Kubernetes. While there's beta support for using swap ([Kubernetes v1.28: Planternetes](https://kubernetes.io/blog/2023/08/15/kubernetes-v1-28-release/#:~:text=Announcing%20the%20release%20of%20Kubernetes,12%20have%20graduated%20to%20Stable.)), it's important to be aware of the potential drawbacks.  

## 2. Put SELinux in Monitoring Mode (_Permissive mode_)

        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config  

        sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
Traditionally, Kubernetes had limitations in how it interacted with the host filesystem. Pod networks, for instance, require some level of access for containers.  SELinux, in enforcing mode, might block these necessary accesses by default.  Setting SELinux to permissive mode would allow the installation to proceed without these access restrictions, but with potential security risks. Permissive mode can simplify the initial setup process for Kubernetes by avoiding the need to configure SELinux policies for Kubernetes components. This can be especially attractive for getting a basic cluster up and running quickly.
> If you're new to Kubernetes or just setting up a test cluster, permissive mode might seem like an easier option initially. However, understand the security implications.  
> For production deployments, consult the documentation for your specific Kubernetes version regarding SELinux support. If using a modern version ([Kubernetes v1.28: Planternetes](https://kubernetes.io/blog/2023/08/15/kubernetes-v1-28-release/#:~:text=Announcing%20the%20release%20of%20Kubernetes,12%20have%20graduated%20to%20Stable.)), explore using Kubernetes with SELinux in enforcing mode for a more secure setup. You might need to configure some SELinux policies for Kubernetes components, but this will ultimately lead to a more secure cluster.

## 3. Manage Network Traffic Through Firewall Configuration
        systemctl enable firewalld && systemctl start firewalld || true
        
        sed -i 's/^FirewallBackend=nftables$/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf

        systemctl restart firewalld

> Using [iptables](https://www.redhat.com/sysadmin/iptables) for the firewall can be a viable option to ensure compatibility with **kube-proxy**. However, consider migrating to [nftables](https://wiki.nftables.org/wiki-nftables/index.php/What_is_nftables%3F) when possible for a more modern and flexible firewall solution.  

The choice between iptables and nftables depends on your specific Kubernetes version, distribution, and comfort level with each tool. Newer versions of [Kubernetes](https://kubernetes.io/docs/reference/networking/virtual-ips/) and [nftables](https://wiki.nftables.org/wiki-nftables/index.php/What_is_nftables%3F) are actively being developed for better compatibility and improved functionality.

### Manage Firewall Access: Whitelisting Ports in [firewalld](https://firewalld.org/documentation/)
        firewall-cmd --permanent --add-port=179/tcp
        firewall-cmd --permanent --add-port=443/tcp
        firewall-cmd --permanent --add-port=6443/tcp
        firewall-cmd --permanent --add-port=2379-2380/tcp
        firewall-cmd --permanent --add-port=10250/tcp
        firewall-cmd --permanent --add-port=10251/tcp
        firewall-cmd --permanent --add-port=10252/tcp
        firewall-cmd --permanent --add-port=15000-15090/tcp
        firewall-cmd --permanent --add-port=30000-32767/tcp
        firewall-cmd --permanent --add-port=9090/tcp
        firewall-cmd --permanent --add-port=8008/tcp
        firewall-cmd --permanent --add-port=8012/tcp
        firewall-cmd --permanent --add-port=8013/tcp
        
        firewall-cmd --reload


## 4. Prepare System for [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

        cat <<EOF | tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOF

        modprobe overlay
        modprobe br_netfilter
 
### Apply essential sysctl settings

        cat <<EOF | tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOF

        # reboot not needed
        sysctl --system
 
### Verify Loaded Kernel Modules


        lsmod | grep br_netfilter
        lsmod | grep overlay
 
### Verify Firewall Rules (iptables)
        sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

## 5. Install [CRI-O](https://github.com/cri-o/cri-o/blob/main/install.md)
        export VERSION=1.26
        export OS=CentOS_8
 
        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo

        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo

        dnf install -y cri-o

        systemctl enable crio
        systemctl start crio

## 6. Deploy Kubernetes Components

        cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
        [kubernetes]
        name=Kubernetes
        baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
        enabled=1
        gpgcheck=1
        repo_gpgcheck=1
        gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
        exclude=kubelet kubeadm kubectl
        EOF
 
        dnf install -y kubelet-1.25.10 kubeadm-1.25.10 kubectl-1.25.10 --disableexcludes=kubernetes

        systemctl enable kubelet
        systemctl start kubelet

## 7. Configure NetworkManager for [Calico CNI](https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements)

        cat <<EOF | tee /etc/NetworkManager/conf.d/calico.conf
        [keyfile]
        unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
        EOF

## 8. Install [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/)

        curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash

        mv kustomize /usr/local/bin

## 9. Install [Helm](https://helm.sh/docs/intro/install/)

        curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
        && chmod 700 get_helm.sh \  
        && ./get_helm.sh

## 10. Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf)
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | \
        tee /etc/yum.repos.d/nvidia-container-toolkit.repo

        yum install -y nvidia-container-toolkit

        nvidia-ctk runtime configure --runtime=crio

        systemctl restart crio

        # generate GPUs
        nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

        # verify
        podman run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi -L

## 11. Install [NVIDIA Device Plugin for Kubernetes](https://github.com/NVIDIA/k8s-device-plugin)
        helm upgrade -i nvdp nvdp/nvidia-device-plugin --namespace nvidia-device-plugin --create-namespace --version 0.14.0

## 12. Install [NVIDIA gpu-operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html)
        helm install --version 23.3.2 --values gpu_operator_values.yaml --create-namespace --namespace gpu-operator --devel nvidia/gpu-operator --set driver.enabled=False --set driver.repository='nvcr.io/nvidia',driver.imagePullSecrets[0]=registry-secret,driver.licensingConfig.configMapName=licensing-config,driver.version='545.23.08' --wait --generate-name

## 13. Integrating Worker Node with Existing Cluster
        1. Copy ~/.kube/config file to the worker node's $HOME/.kube directory
        2. Retrieve kubernetes worker node join command

            kubeadm token create --print-join-command

        3. Run the command provided by the previous step
        4. Verify

            kubectl get nodes -o wide

## 14. Deploy [Kubeflow](https://github.com/kubeflow/manifests)

        export KUBEFLOW_VERSION=v1.7.0
        
        git clone https://github.com/kubeflow/manifests.git $HOME/kubeflow
        cd $HOME/kubeflow && git checkout $KUBEFLOW_VERSION        

        while ! kustomize build example | awk '!/well-defined/' | kubectl apply -f -; do echo "Retrying to apply resources"; sleep 10; done

        # Verify

            kubectl get pods -n kubeflow -o wide




## References
https://github.com/kubernetes/kubernetes  
https://github.com/cri-o/cri-o/blob/main/install.md  
https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises  
https://github.com/kubeflow/kubeflow  
https://github.com/kubeflow/manifests 
https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/getting-started.html  
https://github.com/NVIDIA/k8s-device-plugin  
https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf  
https://helm.sh/docs/intro/install/  
https://kubectl.docs.kubernetes.io/installation/kustomize/binaries/  
https://docs.tigera.io/calico/latest/getting-started/kubernetes/requirements  
https://github.com/cri-o/cri-o/blob/main/install.md  
https://kubernetes.io/docs/setup/production-environment/container-runtimes/  
https://firewalld.org/documentation/  
https://www.redhat.com/sysadmin/iptables  
https://wiki.nftables.org/wiki-nftables/index.php/What_is_nftables%3F  
https://kubernetes.io/docs/reference/networking/virtual-ips/  
https://kubernetes.io/blog/2023/08/15/kubernetes-v1-28-release/#:~:text=Announcing%20the%20release%20of%20Kubernetes,12%20have%20graduated%20to%20Stable  
