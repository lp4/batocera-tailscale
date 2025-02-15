#!/bin/bash

rm -rf /userdata/system/custom.sh
touch /userdata/system/custom.sh
cat << 'EOF' > /userdata/system/custom.sh
#!/bin/bash

case "$1" in
    start)

        # Restart logic: Loop to check time
        (
            while true; do
                current_time=$(date +%H:%M)  # Get current time HH:MM

                if [[ "$current_time" == "20:00" ]]; then
                    echo "Scheduled shutdown at $current_time"
                    shutdown -h now
                fi

                sleep 60  # Check every minute
            done
        ) &
        ;;
    stop)
        ;;
esac

EOF

chmod +x /userdata/system/custom.sh
reboot
