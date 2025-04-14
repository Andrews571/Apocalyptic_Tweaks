#!/bin/bash

# Battery Modifications
resetprop -n persist.sys.shutdown.mode hibernate
resetprop -n persist.radio.add_power_save 1
resetprop -n wifi.supplicant_scan_interval 300 
resetprop -n ro.ril.disable.power.collapse 1
resetprop -n ro.config.hw_fast_dormancy 1
resetprop -n ro.semc.enable.fast_dormancy true
resetprop -n ro.config.hw_quickpoweron true
resetprop -n ro.mot.eri.losalert.delay 1000
resetprop -n ro.config.hw_power_saving true
resetprop -n pm.sleep_mode 1
resetprop -n ro.ril.sensor.sleep.control 1
resetprop -n power_supply.wakeup enable

# Additional Battery Optimizations
resetprop -n ro.ril.power.collapse 1
resetprop -n power.saving.enabled 1
resetprop -n battery.saver.low_level 30
resetprop -n power.saving.enable 1
resetprop -n persist.radio.apm_sim_not_pwdn 1
resetprop -n ro.ril.enable.amr.wideband 0
resetprop -n power.saving.low_screen_brightness 1
resetprop -n ro.config.hw_smart_battery 1
resetprop -n ro.config.hw_power_profile low

# Dalvik and Kernel Modifications
resetprop -n ro.setupwizard.mode DISABLED

# Miscellaneous
resetprop -n persist.sys.gmaps_hack 1