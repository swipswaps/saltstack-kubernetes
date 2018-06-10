<img src="https://i.imgur.com/SJAtDZk.png" width="460" height="125" >

# Work-in-Progress

`saltstack-kubernetes` aims to deploy and maintain a secure production ready **Kubernetes cluster** managed by:

* [Terraform](https://www.terraform.io) for cloud server deployment.
* [Saltstack](https://saltstack.io) for Kubernetes installation and configuration management.

This project is a fusion of the [valentin2105/Kubernetes-Saltstack](https://github.com/valentin2105/Kubernetes-Saltstack) and [hobby-kube](https://github.com/hobby-kube/provisionning) customized to address the following requirements:

* [ ] Single public IP support
* [ ] Segregated etcd cluster
* [ ] Proxied internet access from Kubernetes servers
* [ ] Reverse proxy with ssl offload
* [ ] Predicatble ip Adressing


## Features

- Cloud-provider **agnostic**
- Support **high-available** clusters
- Use the power of **`Saltstack`**
- Made for **`SystemD`** based Linux systems
- **Routed** networking by default (**`Calico`**)
- Latest Kubernetes release (**1.10.1**)
- Support **IPv6**
- Integrated **add-ons**
- **Composable** (CNI, CRI)
- **RBAC** & **TLS** by default

## Getting started 

Let's clone the git repo on Salt-Master and create CA & Certificates on the `certs/` directory using **`CfSSL`** tools:

```bash
git clone https://github.com/fjudith/saltstack-kubernetes
ln -s saltstack-kubernetes/salt /srv/salt
ln -s saltstack-kubernetes/pillar /srv/pillar

sudo curl -fsSL -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
sudo curl -fsSL -o /usr/local/bin/cfssl-certinfo https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64
sudo curl -fsSL -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

sudo chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson /usr/local/bin/cfssl-certinfo
```

### IMPORTANT Point

Because we need to generate our own CA and Certificates for the cluster, You MUST put **every hostnames of the Kubernetes cluster** (Master & nodes) in the `certs/kubernetes-csr.json` (`hosts` field). You can also modify the `certs/*json` files to match your cluster-name / country. (optional)  

You can use either public or private names, but they must be registered somewhere (DNS provider, internal DNS server, `/etc/hosts` file).

```bash
cd /srv/salt/certs
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Don't forget to edit kubernetes-csr.json before this point !

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```
After that, edit the `pillar/cluster_config.sls` to configure your future Kubernetes cluster :

```yaml
kubernetes:
  version: v1.10.1
  domain: cluster.local
  master:
#    count: 1
#    hostname: master.domain.tld
#    ipaddr: 10.240.0.10
    count: 3
    cluster:
      node01:
        hostname: master01.domain.tld
        ipaddr: 10.240.0.10
      node02:
        hostname: master02.domain.tld
        ipaddr: 10.240.0.20
      node03:
        hostname: master03.domain.tld
        ipaddr: 10.240.0.30
    encryption-key: 'w3RNESCMG+o3GCHTUcrCHANGEMEq6CFV72q/Zik9LAO8uEc='
    etcd:
      version: v3.3.5
  node:
    runtime:
      provider: docker
      docker:
        version: 18.03.0-ce
        data-dir: /dockerFS
    networking:
      cni-version: v0.7.1
      provider: calico
      calico:
        version: v3.1.1
        cni-version: v3.1.1
        calicoctl-version: v3.1.1
        controller-version: 3.1-release
        as-number: 64512
        token: hu0daeHais3aCHANGEMEhu0daeHais3a
        ipv4:
          range: 192.168.0.0/16
          nat: true
          ip-in-ip: true
        ipv6:
          enable: false
          nat: true
          interface: ens18
          range: fd80:24e2:f998:72d6::/64
  global:
    pod-network: 10.32.0.0/16
    helm-version: v2.8.2
    dashboard-version: v1.8.3
    admin-token: Haim8kay1rarCHANGEMEHaim8kay1rar
    kubelet-token: ahT1eipae1wiCHANGEMEahT1eipae1wi
```
##### Don't forget to change hostnames & tokens  using command like `pwgen 64` !

If you want to enable IPv6 on pod's side, you need to change `kubernetes.node.networking.calico.ipv6.enable` to `true`.

## Deployment

To deploy your Kubernetes cluster using this formula, you first need to setup your Saltstack Master/Minion.  
You can use [Salt-Bootstrap](https://docs.saltstack.com/en/stage/topics/tutorials/salt_bootstrap.html) or [Salt-Cloud](https://docs.saltstack.com/en/latest/topics/cloud/) to enhance the process. 

The configuration is done to use the Salt-Master as the Kubernetes Master. You can have them as different nodes if needed but the `post_install/script.sh` require `kubectl` and access to the `pillar` files.

#### The recommended configuration is :

- one or three Kubernetes-Master (Salt-Master & Minion)

- one or more Kubernetes-nodes (Salt-minion)

The Minion's roles are matched with `Salt Grains` (kind of inventory), so you need to define theses grains on your servers :

If you want a small cluster, a Master can be a node too. 

```bash
# Kubernetes Masters
cat << EOF > /etc/salt/grains
role: master
EOF

# Kubernetes nodes
cat << EOF > /etc/salt/grains
role: node
EOF

# Kubernetes Master & nodes
cat << EOF > /etc/salt/grains
role: 
  - master
  - node
EOF

service salt-minion restart 
```

After that, you can apply your configuration (`highstate`) :

```bash
# Apply Kubernetes Master configurations
salt -G 'role:master' state.highstate 

~# kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}

# Apply Kubernetes node configurations
salt -G 'role:node' state.highstate

~# kubectl get nodes
NAME                STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE 
k8s-salt-node01   Ready     <none>     5m       v1.10.1    <none>        Ubuntu 18.04.1 LTS 
k8s-salt-node02   Ready     <none>     5m       v1.10.1    <none>        Ubuntu 18.04.1 LTS 
k8s-salt-node03   Ready     <none>     5m       v1.10.1    <none>        Ubuntu 18.04.1 LTS 
k8s-salt-node04   Ready     <none>     5m       v1.10.1    <none>        Ubuntu 18.04.1 LTS 
```

To enable add-ons on the Kubernetes cluster, you can launch the `post_install/setup.sh` script :

```bash
/srv/salt/post_install/setup.sh

~# kubectl get pod --all-namespaces
NAMESPACE     NAME                                    READY     STATUS    RESTARTS   AGE
kube-system   calico-policy-fcc5cb8ff-tfm7v           1/1       Running   0          1m
kube-system   calico-node-bntsh                       1/1       Running   0          1m
kube-system   calico-node-fbicr                       1/1       Running   0          1m
kube-system   calico-node-badop                       1/1       Running   0          1m
kube-system   calico-node-rcrze                       1/1       Running   0          1m
kube-system   kube-dns-d44664bbd-596tr                3/3       Running   0          1m
kube-system   kube-dns-d44664bbd-h8h6m                3/3       Running   0          1m
kube-system   kubernetes-dashboard-7c5d596d8c-4zmt4   1/1       Running   0          1m
kube-system   tiller-deploy-546cf9696c-hjdbm          1/1       Running   0          1m
kube-system   heapster-55c5d9c56b-7drzs               1/1       Running   0          1m
kube-system   monitoring-grafana-5bccc9f786-f4lf2     1/1       Running   0          1m
kube-system   monitoring-influxdb-85cb4985d4-rd776    1/1       Running   0          1m
```

## Good to know

If you want to add a node on your Kubernetes cluster, just add the new **Hostname** on `kubernetes-csr.json` and run theses commands :

```bash
cd /srv/salt/certs

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

salt -G 'role:master' state.highstate
salt -G 'role:node' state.highstate
```

Last `highstate` reload your Kubernetes Master and configure automaticly new nodes.

- Tested on Debian, Ubuntu and Fedora.
- You can easily upgrade software version on your cluster by changing values in `pillar/cluster_config.sls` and apply a `state.highstate`.
- This configuration use ECDSA certificates (you can switch to `rsa` if needed in `certs/*.json`).
- You can tweak Pod's IPv4 Pool, enable IPv6, change IPv6 Pool, enable IPv6 NAT (for no-public networks), change BGP AS number, Enable IPinIP (to allow routes sharing of different cloud providers).
- If you use `salt-ssh` or `salt-cloud` you can quickly scale new nodes.


## Support on Beerpay
Hey dude! Help me out for a couple of :beers:!

[![Beerpay](https://beerpay.io/valentin2105/Kubernetes-Saltstack/badge.svg?style=beer-square)](https://beerpay.io/valentin2105/Kubernetes-Saltstack)  [![Beerpay](https://beerpay.io/valentin2105/Kubernetes-Saltstack/make-wish.svg?style=flat-square)](https://beerpay.io/valentin2105/Kubernetes-Saltstack?focus=wish)
