# Batocera-Tailscale
**Run Tailscale in batocera with Subnet and Accept Routes, tailscale starts at boot so you can access "share folder" or "ssh" remotely**

*Batocera comes with pre-enabled ssh, login using (**username:root and password:linux**)*

**run this script for auto-installation**

    curl -L https://raw.githubusercontent.com/codecs02-marcher/batocera-tailscale/refs/heads/main/install.sh | bash


***Login to your tailscale with the given link and activate your batocera machine***

***Go to "Admin console" of tailscale and approve the newly added machine***

***After login check tailscale IP in your machine***

    ip a

**Now Reboot your machine**

    reboot

**Wait for the machine to start and check your machine's IP**

    ip a

***you must have tailscale ip in the list***

**go to tailscale admin page and enable "subnet routes" by selecting your CIDR**

**now you can access your rom files, copy/paste/delete or ssh remotely if you have tailscale running in the remote computer/device using same tailscale account or by sharing your machine to your friends who has a tailscale account with every reboot**

