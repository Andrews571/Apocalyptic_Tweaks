#!/system/bin/sh

# Modificações de bateria
props=(
  "persist.sys.shutdown.mode=hibernate"
  "persist.radio.add_power_save=1"
  "wifi.supplicant_scan_interval=300"
  "ro.ril.disable.power.collapse=1"
  "ro.config.hw_fast_dormancy=1"
  "ro.semc.enable.fast_dormancy=true"
  "ro.config.hw_quickpoweron=true"
  "ro.mot.eri.losalert.delay=1000"
  "ro.config.hw_power_saving=true"
  "pm.sleep_mode=1"
  "ro.ril.sensor.sleep.control=1"
  "power_supply.wakeup=enable"
  "ro.ril.power.collapse=1"
  "power.saving.enabled=1"
  "battery.saver.low_level=30"
  "power.saving.enable=1"
  "persist.radio.apm_sim_not_pwdn=1"
  "ro.ril.enable.amr.wideband=0"
  "power.saving.low_screen_brightness=1"
  "ro.config.hw_smart_battery=1"
  "ro.setupwizard.mode=DISABLED"
  "persist.sys.gmaps_hack=1"
)

for prop in "${props[@]}"; do
  key="${prop%%=*}"
  value="${prop#*=}"
  resetprop -n "$key" "$value"
done
