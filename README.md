# Batocera-Tailscale

***Step 1: Run Tailscale in batocera with Subnet and Accept Routes, tailscale starts at boot so you can access "share folder" or "ssh" remotely***

*Batocera comes with pre-enabled ssh, login using (**username:root and password:linux**)*

***Step 2: run this script for auto-installation***

*This script will auto select your subnet and cidr*

    curl -L https://raw.githubusercontent.com/codecs02-marcher/batocera-tailscale/refs/heads/main/install.sh | bash


***Step 3: Login to your tailscale with the given link and activate your batocera machine***

***Step 4: Go to "Admin console" of tailscale and approve the newly added machine***

***Step 5: After Approval check tailscale IP in your machine***

    ip a

***Step 5:  Reboot your machine***

    reboot

***Step 6: After reboot check your machine's IP***

    ip a

***you must have tailscale ip in the list***

***Step 7: go to tailscale admin page and enable "subnet routes" by selecting your CIDR***

**now you can access your rom files, copy/paste/delete or ssh remotely if you have tailscale running in the remote computer/device using same tailscale account or by sharing your machine to your friends who has a tailscale account with every reboot**

