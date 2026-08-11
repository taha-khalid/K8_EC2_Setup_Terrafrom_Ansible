# Kubernetes Multi-Node Cluster & Cilium CNI Automation with Ansible

An automated **Ansible-based Kubernetes cluster deployment** that bootstraps a multi-node Kubernetes cluster on bare-metal or cloud infrastructure using **kubeadm**, **containerd**, and **Cilium CNI**.

The project automates the complete lifecycle of preparing the nodes, initializing the Kubernetes control plane, joining worker nodes, and deploying Cilium as the cluster networking solution.

---

## 🏛️ Project Architecture & Scope

This project automates the end-to-end configuration and initialization of a Kubernetes cluster consisting of a control-plane node and one or more worker nodes.

The playbook automates:

* System-level prerequisites and kernel tuning across all nodes
* Hostname configuration and cloud-init persistence
* Containerd runtime installation and systemd cgroup configuration
* Kubernetes package installation (`kubeadm`, `kubelet`, and `kubectl`)
* Kubernetes control-plane initialization
* Dynamic generation and distribution of the `kubeadm join` command
* Automated worker-node joining
* Cilium CLI installation
* Cluster-wide Cilium CNI deployment
* Post-deployment cluster verification

### Architecture

```text
                         ┌───────────────────────────┐
                         │    Ansible Control Node    │
                         │    WSL2 / Linux / macOS   │
                         └─────────────┬─────────────┘
                                       │
                             SSH (Port 22)
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                     │
                    ▼                                     ▼
        ┌───────────────────────────┐       ┌───────────────────────────┐
        │     Kubernetes Master     │       │    Kubernetes Worker(s)   │
        │      / Control Plane      │       │                           │
        │                           │       │                           │
        │ ┌───────────────────────┐ │       │ ┌───────────────────────┐ │
        │ │ Common System Config  │ │       │ │ Common System Config  │ │
        │ ├───────────────────────┤ │       │ ├───────────────────────┤ │
        │ │ Containerd Runtime    │ │       │ │ Containerd Runtime    │ │
        │ ├───────────────────────┤ │       │ ├───────────────────────┤ │
        │ │ Kubernetes Tools      │ │       │ │ Kubernetes Tools      │ │
        │ ├───────────────────────┤ │       │ ├───────────────────────┤ │
        │ │ Kubeadm Init          │ │       │ │ Kubeadm Join          │ │
        │ ├───────────────────────┤ │       │ └───────────────────────┘ │
        │ │ Cilium CNI Deployment │ │       └───────────────────────────┘
        │ └───────────────────────┘ │
        └───────────────────────────┘
```

---

# 📂 Repository Structure

```text
.
├── inventory.ini           # Host definitions, SSH configuration, and node groups
├── site.yml                # Main Ansible playbook entrypoint
└── roles/
    ├── common/             # OS, network, and kernel configuration
    ├── containerd/         # Containerd runtime installation and configuration
    ├── k8s_tools/          # Kubernetes package installation
    ├── master/             # Control-plane initialization and join-token generation
    ├── worker/             # Worker-node cluster joining
    └── cilium/             # Cilium CLI installation and CNI deployment
```

---

# 🚀 Key Engineering & Idempotency Features

## Dynamic Join Token Passing

The control-plane node generates the `kubeadm join` command during cluster initialization.

The generated command is registered as an Ansible fact and made available to worker nodes through `hostvars`.

This avoids hard-coding cluster join tokens in the inventory or repository.

```text
Master
  │
  │ kubeadm init
  │
  ▼
Generate join command
  │
  │ Ansible fact
  ▼
hostvars
  │
  ▼
Worker nodes
  │
  │ kubeadm join
  ▼
Kubernetes cluster
```

---

## Decoupled CNI Deployment

Cilium deployment is intentionally separated from the control-plane and worker-node provisioning stages.

Cilium is deployed only after all worker nodes have successfully joined the cluster.

This provides a clear separation between:

1. Node preparation
2. Kubernetes cluster initialization
3. Worker-node registration
4. Cluster networking deployment

The approach also ensures that the Cilium agents can be deployed across the complete cluster rather than only the initial control-plane node.

---

## Systemd Cgroup Driver Alignment

Containerd is configured with:

```toml
SystemdCgroup = true
```

This aligns the container runtime's cgroup driver with kubelet's systemd-based cgroup configuration.

Using a consistent cgroup driver helps avoid runtime and node-management issues caused by mismatched cgroup configurations.

---

## Cloud-Init Hostname Persistence

The playbook configures cloud-init to preserve the hostname across reboots by setting:

```yaml
preserve_hostname: true
```

This prevents cloud-init from overwriting the hostname configured by Ansible when the node restarts.

---

# 📋 Prerequisites

## Ansible Control Node

The machine running Ansible should have:

* Ansible **2.15+**
* Linux, WSL2, or macOS
* OpenSSH client
* SSH key-based authentication
* Network connectivity to all Kubernetes nodes

## Target Hosts

The Kubernetes nodes should have:

* Ubuntu Server **22.04 LTS** or **24.04 LTS**
* Python 3
* Passwordless `sudo` privileges
* SSH access from the Ansible control node
* Network connectivity between control-plane and worker nodes
* Sufficient CPU, memory, disk, and network resources for Kubernetes

---

# 🛠️ Installation & Usage

## 1. Clone the Repository

```bash
git clone <YOUR_REPOSITORY_URL>
cd <YOUR_REPOSITORY_DIRECTORY>
```

---

## 2. Configure the Inventory

Edit `inventory.ini` and define the Kubernetes control-plane and worker nodes.

Example:

```ini
[masters]
master1 ansible_host=10.0.0.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/k8s-key.pem

[workers]
worker1 ansible_host=10.0.0.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/k8s-key.pem
worker2 ansible_host=10.0.0.12 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/k8s-key.pem
```

### Inventory Groups

| Group     | Purpose                        |
| --------- | ------------------------------ |
| `masters` | Kubernetes control-plane nodes |
| `workers` | Kubernetes worker nodes        |

---

## 3. Verify Connectivity

Before running the deployment, verify that Ansible can connect to all nodes:

```bash
ansible -i inventory.ini all -m ping
```

Expected result:

```text
master1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

worker1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

worker2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

---

## 4. Run the Playbook

Execute the complete multi-stage Kubernetes deployment:

```bash
ansible-playbook -i inventory.ini site.yml
```

The playbook executes the stages sequentially to ensure that dependencies between the control plane, worker nodes, and Cilium networking are respected.

---

# 🔄 Execution Flow

The `site.yml` playbook executes four distinct stages.

```text
┌─────────────────────────────────────────────────────────────┐
│ STAGE 1: Prepare All Nodes                                 │
│                                                             │
│ Hosts: all                                                 │
│ Roles: common → containerd → k8s_tools                     │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 2: Provision Control Plane                           │
│                                                             │
│ Hosts: masters                                              │
│ Role: master                                                │
│                                                             │
│ Runs kubeadm init and generates the worker join command.    │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 3: Provision Worker Nodes                            │
│                                                             │
│ Hosts: workers                                              │
│ Role: worker                                                │
│                                                             │
│ Retrieves the join command through hostvars and executes    │
│ kubeadm join on the worker nodes.                           │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ STAGE 4: Deploy Cilium CNI                                 │
│                                                             │
│ Hosts: masters                                              │
│ Role: cilium                                                │
│                                                             │
│ Installs the Cilium CLI and deploys Cilium across the      │
│ Kubernetes cluster.                                         │
└─────────────────────────────────────────────────────────────┘
```

---

# 🧪 Verification

Once the playbook completes successfully, connect to the Kubernetes control-plane node and verify the cluster.

## Connect to the Master

```bash
ssh -i ~/.ssh/k8s-key.pem ubuntu@<MASTER_IP>
```

---

## Check Node Status

Run:

```bash
kubectl get nodes -o wide
```

Expected output:

```text
NAME      STATUS   ROLES           AGE   VERSION   INTERNAL-IP
master1   Ready    control-plane   5m    v1.35.0   10.0.0.10
worker1   Ready    <none>          3m    v1.35.0   10.0.0.11
worker2   Ready    <none>          3m    v1.35.0   10.0.0.12
```

All nodes should eventually report:

```text
STATUS: Ready
```

---

## Check Cilium Status

Verify the Cilium installation:

```bash
cilium status
```

You can also inspect the Cilium pods:

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

For a healthy deployment, Cilium agent pods should be running on the Kubernetes nodes.

---

# ⚙️ Role Responsibilities

| Role         | Target    | Responsibilities                                                                                                         |
| ------------ | --------- | ------------------------------------------------------------------------------------------------------------------------ |
| `common`     | All nodes | Hostname configuration, kernel modules (`overlay`, `br_netfilter`), sysctl networking configuration, and swap disabling. |
| `containerd` | All nodes | Containerd runtime installation and systemd cgroup configuration.                                                        |
| `k8s_tools`  | All nodes | Kubernetes APT repository configuration and installation of `kubeadm`, `kubelet`, and `kubectl`.                         |
| `master`     | Masters   | Runs `kubeadm init`, configures the non-root `~/.kube/config`, and registers the worker join command as an Ansible fact. |
| `worker`     | Workers   | Retrieves the join command from the control-plane node through `hostvars` and executes `kubeadm join`.                   |
| `cilium`     | Masters   | Installs the Cilium CLI and deploys Cilium CNI across the Kubernetes cluster.                                            |

---

# 📈 Project Status

| Component                                   | Status     |
| ------------------------------------------- | ---------- |
| System prerequisites & kernel configuration | ✅ Complete |
| Containerd & systemd cgroup configuration   | ✅ Complete |
| Kubernetes package installation             | ✅ Complete |
| Control-plane initialization                | ✅ Complete |
| Dynamic join-token distribution             | ✅ Complete |
| Worker-node joining automation              | ✅ Complete |
| Decoupled Cilium CNI deployment             | ✅ Complete |
| Terraform infrastructure integration        | 🚧 Planned |
| Automated cluster teardown                  | 🚧 Planned |

---

# 🔐 Security Considerations

This project is intended for learning, development, and infrastructure automation purposes.

For production environments, consider implementing additional security controls such as:

* Restricting SSH access to trusted IP ranges.
* Restricting Kubernetes API server access.
* Limiting etcd access to control-plane nodes only.
* Using private networking for cluster-internal communication.
* Avoiding unnecessary exposure of Kubernetes node ports to the public Internet.
* Rotating Kubernetes bootstrap tokens and credentials.
* Managing SSH keys and secrets outside of the Git repository.
* Using network policies to control pod-to-pod communication.
* Enabling appropriate Kubernetes authentication and authorization controls.

---

# 🔗 Infrastructure Integration

The Ansible automation can be combined with Terraform to create a complete infrastructure-to-cluster provisioning workflow.

```text
┌──────────────────────┐
│      Terraform       │
│                      │
│  VPC                 │
│  Subnets             │
│  Security Groups     │
│  EC2 Instances       │
└──────────┬───────────┘
           │
           │ Infrastructure
           ▼
┌──────────────────────┐
│       Ansible        │
│                      │
│  OS Configuration    │
│  Containerd          │
│  Kubernetes Tools    │
│  kubeadm init        │
│  kubeadm join        │
│  Cilium CNI          │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Kubernetes Cluster   │
│                      │
│ Control Plane        │
│ Worker Nodes         │
│ Cilium CNI           │
└──────────────────────┘
```

This separation follows the principle of using **Terraform for infrastructure provisioning** and **Ansible for configuration management and cluster bootstrapping**.

---

# 🚧 Future Improvements

Potential improvements include:

* Terraform integration for automated infrastructure provisioning.
* Automated cluster teardown and reset.
* Support for multiple control-plane nodes.
* High-availability Kubernetes control plane.
* Automated certificate management.
* Configurable Kubernetes versions.
* Configurable Cilium versions.
* Worker-node scaling.
* Private subnet deployment.
* Automated kubeconfig retrieval.
* Kubernetes cluster health checks.
* Cilium network-policy automation.
* CI/CD pipeline for Ansible linting and validation.
* Ansible Molecule tests for role validation.

---

# 👨‍💻 Author

**Taha Khalid**

Cloud & Platform Engineer