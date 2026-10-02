# Lab 2

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 2 in this folder.

# Lab 2: Web Application on EC2 with systemd

## Deployment steps

1. Created my own SSH key pair (`acs730-lab2-key`) and saved the private key in `~/.ssh` on the workstation, outside the repository.
2. Created a security group (`acs730-lab2-sg`) in the default VPC with two rules: SSH from my workstation's address only, and HTTP from anywhere.
3. Launched a t3.micro Amazon Linux 2023 instance with that key and security group.
4. Connected as `ec2-user` once to create a named admin account (`acs730admin`) with sudo and my key, then used that account for everything else.
5. Created the service account `acs730web` (no home directory, no login shell).
6. Ran `lab2/scripts/deploy-web.sh` on the instance. The script:
   - installs `python3` with `dnf`
   - creates the `acs730web` user if it does not already exist
   - writes the web page to `/opt/acs730-web` and gives it to `acs730web`
   - installs the systemd unit `acs730-web.service`
   - runs `daemon-reload`, `enable`, and `restart` on the service
   - checks the site locally with `curl`
   It is safe to run more than once, because the user creation is guarded and the service is restarted rather than just started.
7. Rebooted the instance and confirmed the site came back without anyone starting it.
8. Saved evidence in `lab2/evidence/`, then terminated the instance and deleted the security group.

## start vs enable

`systemctl start` runs the service now but does not survive a reboot. `systemctl enable` links the unit into `multi-user.target` so systemd starts it at every boot, but it does not start it right away. You need both: `start` for now, and `enable` for after a restart. The reboot test is what proves `enable` worked.

## Why SSH is a /32 and HTTP is 0.0.0.0/0

SSH is administrative access, so it is limited to a single address (my workstation, written as a /32), and nobody else on the internet can even attempt a login. HTTP is the public service the web server exists to provide, so it is open to everyone. Least privilege means each port is open only to the audience that needs it, not that everything is closed.

## Which user the application runs as

The application runs as `acs730web`, a system account with no login shell and no sudo, not as root. If there were a bug in the web server, an attacker would only get that account's permissions and not full control of the machine. The unit file grants only the capability needed to bind port 80 (`AmbientCapabilities=CAP_NET_BIND_SERVICE`) and sets `NoNewPrivileges=true`.

## Notes

- `acs730admin` did not get passwordless sudo from `wheel` membership alone on this image, so I added a drop-in file in `/etc/sudoers.d/` (checked with `visudo -c`) to give it passwordless sudo.
