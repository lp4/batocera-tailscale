#!/bin/bash

batocera-services start tailscale    #This will take care of the tailscale not starting at boot

case "$1" in
    start)
        (
            while true; do
                current_day=$(date +%u)  
                current_time=$(date +%H:%M)  

                if [[ "$current_day" -eq 2 && "$current_time" == "05:30" ]]; then  # This will reboot batocera every tuesday at 5:30 
                    batocera-es-swissknife --reboot
                fi

                sleep 60  #Check every minute/60s
            done
        ) &
        ;;
    stop)
        # No specific stop logic needed
        ;;
esac
