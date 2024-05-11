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
Kubernetes | 1.25 |
CRI-O | 1.26 |

# Deployment Steps  

## 1. Turning off the **swap**
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

## 2. Setting **SELinux** in Permissive mode

        sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config  

        sed -i 's/^SELINUX=disabled$/SELINUX=permissive/' /etc/selinux/config
Traditionally, Kubernetes had limitations in how it interacted with the host filesystem. Pod networks, for instance, require some level of access for containers.  SELinux, in enforcing mode, might block these necessary accesses by default.  Setting SELinux to permissive mode would allow the installation to proceed without these access restrictions, but with potential security risks. Permissive mode can simplify the initial setup process for Kubernetes by avoiding the need to configure SELinux policies for Kubernetes components. This can be especially attractive for getting a basic cluster up and running quickly.
> If you're new to Kubernetes or just setting up a test cluster, permissive mode might seem like an easier option initially. However, understand the security implications.  
> For production deployments, consult the documentation for your specific Kubernetes version regarding SELinux support. If using a modern version ([Kubernetes v1.28: Planternetes](https://kubernetes.io/blog/2023/08/15/kubernetes-v1-28-release/#:~:text=Announcing%20the%20release%20of%20Kubernetes,12%20have%20graduated%20to%20Stable.)), explore using Kubernetes with SELinux in enforcing mode for a more secure setup. You might need to configure some SELinux policies for Kubernetes components, but this will ultimately lead to a more secure cluster.

## 3. Configuring **Firewall**
        systemctl enable firewalld && systemctl start firewalld || true
        
        # setting firewall to use iptables instead of nftables
        sed -i 's/^FirewallBackend=nftables$/FirewallBackend=iptables/' /etc/firewalld/firewalld.conf

        systemctl restart firewalld

> Using [iptables](https://www.redhat.com/sysadmin/iptables) for the firewall can be a viable option to ensure compatibility with **kube-proxy**. However, consider migrating to [nftables](https://wiki.nftables.org/wiki-nftables/index.php/What_is_nftables%3F) when possible for a more modern and flexible firewall solution.  

The choice between iptables and nftables depends on your specific Kubernetes version, distribution, and comfort level with each tool. Newer versions of [Kubernetes](https://kubernetes.io/docs/reference/networking/virtual-ips/) and [nftables](https://wiki.nftables.org/wiki-nftables/index.php/What_is_nftables%3F) are actively being developed for better compatibility and improved functionality.

### Adding Exceptions
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


## 4. Installing and configuring prerequisites - [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

        cat <<EOF | tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOF

        modprobe overlay
        modprobe br_netfilter
 
### Setting **sysctl** params required by setup(params persist across reboots)

        cat <<EOF | tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOF
 
#### Apply **sysctl** params without reboot
        sysctl --system
 
### Checking **lsmod**

        lsmod | grep br_netfilter
        lsmod | grep overlay
 
### Checking **iptables** with bridge configuration
        sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

## 5. Installing [CRI-O](https://github.com/cri-o/cri-o/blob/main/install.md)
        export VERSION=1.26
        export OS=CentOS_8
 
        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo

        curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo

        dnf install -y cri-o

        systemctl enable crio
        systemctl start crio











#### References
[Kubernetes](https://github.com/kubernetes/kubernetes)  
[CRI-O](https://github.com/cri-o/cri-o/blob/main/install.md)  
[Install Calico networking and network policy for on-premises deployments](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises)  
[OpenEBS](https://github.com/openebs/openebs)  
[Kubeflow](https://github.com/kubeflow/kubeflow)