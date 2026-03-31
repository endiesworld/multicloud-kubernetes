# Access Worker Nodes Via The Control Plane

This file explains how to reach the private worker nodes through the control-plane node in the current Azure Kubernetes VM design.

## Why This Works

In the current setup:

- the control plane has a public IP
- the workers do not have public IPs
- all three nodes are in the same subnet
- worker nodes are reachable by private IP from the control plane

That means the admin path is:

`Laptop -> control-plane public IP -> control-plane VM -> worker private IP`

This is a standard jump-host pattern.

## Useful Terraform Outputs

After `terraform apply`, use these outputs:

```bash
terraform output control_plane_public_ip
terraform output control_plane_ssh_target
terraform output worker_private_ips
```

Expected shape:

```text
control_plane_public_ip = "x.x.x.x"
control_plane_ssh_target = "azureuser@x.x.x.x"
worker_private_ips = {
  "worker_node_1" = "10.0.1.x"
  "worker_node_2" = "10.0.1.y"
}
```

## Option 1: SSH To Control Plane, Then SSH To Worker

This is the simplest method.

Before using this method from your laptop, make sure your SSH agent is running and has your private key loaded.

On your laptop:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/azure/kubernetes
ssh-add -L
```

If `ssh-add -L` shows your public key, agent forwarding is ready to use.

From your laptop:

```bash
ssh -A -i ~/.ssh/azure/kubernetes azureuser@<control-plane-public-ip>
```

Then from the control plane:

```bash
ssh azureuser@<worker-private-ip>
```

Example:

```bash
ssh -A -i ~/.ssh/azure/kubernetes azureuser@20.119.59.214
ssh azureuser@10.0.1.4
```

Repeat for the other worker:

```bash
ssh azureuser@10.0.1.6
```

## Option 2: Use ProxyJump From Your Laptop

This avoids opening an interactive shell on the control plane first.

From your laptop:

```bash
ssh -A -J azureuser@<control-plane-public-ip> -i ~/.ssh/azure/kubernetes azureuser@<worker-private-ip>
```

Example:

```bash
ssh -A -J azureuser@20.119.59.214 -i ~/.ssh/azure/kubernetes azureuser@10.0.1.4
```

And for the second worker:

```bash
ssh -J azureuser@20.119.59.214 azureuser@10.0.1.6
```

## Copy A Script To A Worker

If you have a Kubernetes install script on your laptop:

```bash
scp -o ProxyJump=azureuser@<control-plane-public-ip> install-worker.sh azureuser@<worker-private-ip>:~
```

Example:

```bash
scp -o ProxyJump=azureuser@20.119.59.214 install-worker.sh azureuser@10.0.1.4:~
```

Then run it:

```bash
ssh -J azureuser@20.119.59.214 azureuser@10.0.1.4
chmod +x install-worker.sh
./install-worker.sh
```

## Run A Single Remote Command On A Worker

You can also execute commands directly:

```bash
ssh -J azureuser@<control-plane-public-ip> azureuser@<worker-private-ip> 'hostname && ip a'
```

Example:

```bash
ssh -J azureuser@20.119.59.214 azureuser@10.0.1.6 'hostname'
```

## If SSH To A Worker Fails

Check these items:

1. The worker is powered on and provisioned.
2. `sshd` is installed and running on the worker.
3. The same SSH public key was installed on the worker VM.
4. Your SSH agent is running locally and has the private key loaded.
5. You connected to the control plane with agent forwarding enabled.
6. The control plane can reach the worker private IP.
7. The worker guest OS firewall is not blocking `22/TCP`.

From the control plane, useful checks are:

```bash
ssh-add -L
ping 10.0.1.4
ping 10.0.1.6
ssh azureuser@10.0.1.4
ssh azureuser@10.0.1.6
```

### Common Failure: `Permission denied (publickey)`

If you can SSH to the control plane, but the control plane cannot SSH to the worker, and the worker responds with:

```text
Permission denied (publickey)
```

that usually means:

- the network path is working
- the worker SSH service is reachable
- but the private key is not available on the control plane for the second hop

In this setup, the recommended fix is **not** to copy your private key onto the control plane.

Instead:

1. Start `ssh-agent` on your laptop.
2. Load your private key with `ssh-add`.
3. Connect to the control plane using `ssh -A`.
4. SSH from the control plane to the worker.

Working example:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/azure/kubernetes
ssh -A -i ~/.ssh/azure/kubernetes azureuser@20.119.59.214
ssh azureuser@10.0.1.4
```

Once connected to the control plane, confirm the forwarded key is visible:

```bash
ssh-add -L
```

If that command prints your public key, agent forwarding is active.

## Mental Model

Do not think:

- "I need public IPs on workers so I can manage them."

Instead think:

- "The control plane is my public admin entry point."
- "The workers stay private."
- "Management traffic to workers flows through the control plane over private networking."

That model keeps the worker nodes off the public internet while still allowing administration.
