PWM_PATH="/sys/class/hwmon/hwmon1/pwm1"
PWM_ENABLE="/sys/class/hwmon/hwmon1/pwm1_enable"

MIN_TEMP=40
MAX_TEMP=75
MIN_PWM=60
MAX_PWM=255

HYSTERESIS=2      # temp hysteresis in °C
PWM_STEP=10       # round PWM to nearest 10

echo 1 > "$PWM_ENABLE"

LAST_TEMP=0
LAST_PWM=MIN_PWM

while true; do
    TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | head -n 1)

    # Only recalculate if temp changed enough
    if [[ $TEMP -ge $((LAST_TEMP + HYSTERESIS)) || $TEMP -le $((LAST_TEMP - HYSTERESIS)) ]]; then
        if [[ $TEMP -le $MIN_TEMP ]]; then
            PWM=$MIN_PWM
        elif [[ $TEMP -ge $MAX_TEMP ]]; then
            PWM=$MAX_PWM
        else
            RAW_PWM=$(( (TEMP - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
            # Round PWM to nearest PWM_STEP
            PWM=$(( (RAW_PWM + PWM_STEP / 2) / PWM_STEP * PWM_STEP ))
        fi

        echo $PWM > "$PWM_PATH"
        echo "$TEMP°C → PWM: $PWM"

        LAST_TEMP=$TEMP
        LAST_PWM=$PWM
    fi

    sleep 3
done
