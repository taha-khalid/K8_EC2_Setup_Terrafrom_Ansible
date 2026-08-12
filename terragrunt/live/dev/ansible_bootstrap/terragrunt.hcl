include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

# Depend on the Master node output
dependency "master" {
  config_path = "../master_node"

  mock_outputs = {
    public_ips   = ["1.1.1.1"]
    private_ips  = ["10.0.1.10"]
    instance_ids = ["i-mockmaster00000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Depend on the Worker nodes output
dependency "worker" {
  config_path = "../worker_node"

  mock_outputs = {
    public_ips   = ["1.1.1.1"]
    private_ips  = ["10.0.1.10"]
    instance_ids = ["i-mockworker00000000"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Use a dummy source so Terraform doesn't expect EC2 variables
terraform {
  # Double slash // defines the module path, ?ref=main defines the branch
  source = "git::https://github.com/taha-khalid/Terraform_Modules.git//null?ref=v1.0.0"

  after_hook "run_ansible" {
    commands = ["apply"]
    execute = [
      "bash",
      "-c",
      <<-EOT
            # 1. Terragrunt renders HCL functions (\$\{join(...)\}) into bash variable values
            MASTER_IPS="${join(" ", dependency.master.outputs.public_ips)}"
            WORKER_IPS="${join(" ", dependency.worker.outputs.public_ips)}"
            
            ANSIBLE_DIR="/home/taha/projects/K8_EC2_Setup_Terrafrom_Ansible/ansible"
            INVENTORY="$ANSIBLE_DIR/inventory.ini"
            PLAYBOOK="$ANSIBLE_DIR/site.yml"

            # 2. Write inventory.ini using the $INVENTORY variable
            cat <<INI > "$INVENTORY"
            [masters]
            $(i=1; for ip in $MASTER_IPS; do echo "master-$i ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=~/K8s-ssh/k8s-bare-metal.pem"; i=$((i+1)); done)

            [workers]
            $(i=1; for ip in $WORKER_IPS; do echo "worker-$i ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=~/K8s-ssh/k8s-bare-metal.pem"; i=$((i+1)); done)

            [k8s_cluster:children]
            masters
            workers

            INI

            # 3. Wait for SSH port 22 to be reachable on ALL nodes (Master + Workers)
            ALL_IPS="$MASTER_IPS $WORKER_IPS"
            for ip in $ALL_IPS; do
                echo "Waiting for SSH to become ready on $ip..."
                until nc -z -v -w5 "$ip" 22 2>/dev/null; do
                    echo "Waiting for SSH daemon on $ip..."
                    sleep 5
                done
                echo "SSH is ready on $ip!"
            done

            # 4. Execute Ansible Playbook
            echo "Starting Ansible deployment..."
            ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i "$INVENTORY" "$PLAYBOOK"
        EOT
    ]
  }
}