#!/system/bin/sh
MODDIR="${0%/*}"

# Aguarda o sistema inicializar
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# Função para aplicar valor e travar arquivo
lock_val() {
    for p in $2; do
        [ ! -f "$p" ] && continue
        chown root:root "$p"
        chmod 644 "$p"
        echo "$1" >"$p"
        chmod 444 "$p"
    done
}

# Desativa serviços thermal conhecidos
list_thermal_services() {
    for rc in $(find /system/etc/init /vendor/etc/init /odm/etc/init -type f 2>/dev/null); do
        grep -r "^service" "$rc" | awk '{print $2}'
    done | grep -E "thermal|Thermal"
}

for svc in $(list_thermal_services); do
    echo "Stopping $svc"
    stop "$svc"
done

# Aplica limites máximos falsos nas zonas de thermal
for zone in /sys/class/thermal/thermal_zone*/mode; do
    lock_val "disabled" "$zone"
done

# Remove CPU limits (Mediatek comum)
if [ -f /sys/devices/virtual/thermal/thermal_message/cpu_limits ]; then
    echo "Removing CPU limits"
    for i in 0 2 4 6 7; do
        maxfreq="$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq 2>/dev/null)"
        [ "$maxfreq" -gt "0" ] && lock_val "cpu$i $maxfreq" /sys/devices/virtual/thermal/thermal_message/cpu_limits
    done
fi

# Desativa políticas de thermal no PPM (MediaTek)
if [ -d /proc/ppm ]; then
    echo "Disabling PPM thermal policies"
    for idx in $(awk -F'[][]' '/PWR_THRO|THERMAL/{print $2}' /proc/ppm/policy_status 2>/dev/null); do
        lock_val "$idx 0" /proc/ppm/policy_status
    done
fi

# GPU thermal hacks (MediaTek específicos)
if [ -f /proc/gpufreq/gpufreq_power_limited ]; then
    lock_val "ignore_batt_oc 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_batt_percent 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_low_batt 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_thermal_protect 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_pbm_limited 1" /proc/gpufreq/gpufreq_power_limited
fi

# Tenta usar override de thermalservice
cmd thermalservice override-status 0 2>/dev/null

# Bloqueia caminhos adicionais (opcional)
find /sys/devices/virtual/thermal -type f -exec chmod 000 {} +
chmod 000 /sys/devices/*mali*/tmu
chmod 000 /sys/devices/*mali*/throttling*
chmod 000 /sys/devices/*mali*/tripping

lock_val 0 /sys/class/thermal/thermal_zone0/thm_enable
lock_val 0 /sys/kernel/msm_thermal/enabled /sys/class/kgsl/kgsl-3d0/throttling
lock_val N /sys/module/msm_thermal/parameters/enabled
lock_val "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

sleep 3

# Executa o script de reset da bateria
sh "$MODDIR/ABattery/ABatteryReset.sh"

# Define parâmetros do kernel
echo 3 > /proc/sys/kernel/perf_cpu_time_max_percent
echo 1 > /proc/sys/kernel/sched_autogroup_enabled
echo 0 > /proc/sys/kernel/sched_schedstats
echo 64 > /proc/sys/kernel/random/read_wakeup_threshold
echo "off" > /proc/sys/kernel/printk_devkmsg

# Ajustar prefer_idle para background tasks
STUNE="/dev/stune"
if [ -d "$STUNE" ]; then
    [ -f "$STUNE/background/schedtune.prefer_idle" ] && echo 1 > "$STUNE/background/schedtune.prefer_idle"
    [ -f "$STUNE/system-background/schedtune.prefer_idle" ] && echo 1 > "$STUNE/system-background/schedtune.prefer_idle"
fi

# Ativa TTWU_QUEUE no agendador
[ -e /sys/kernel/debug/sched_features ] && echo TTWU_QUEUE > /sys/kernel/debug/sched_features

sleep 60

# Ajusta swappiness
[ -f /dev/memcg/memory.swappiness ] && echo 100 > /dev/memcg/memory.swappiness
[ -f /dev/memcg/system/memory.swappiness ] && echo 40 > /dev/memcg/system/memory.swappiness
[ -f /dev/memcg/apps/memory.swappiness ] && echo 50 > /dev/memcg/apps/memory.swappiness

# Limpa processos do memcg system
if [ -f /dev/memcg/system/cgroup.procs ] && [ -f /dev/memcg/cgroup.procs ]; then
  while read -r pid; do
    echo "$pid" > /dev/memcg/cgroup.procs
  done < /dev/memcg/system/cgroup.procs
fi

# Move processos específicos para o memcg system
for process in system_server surfaceflinger \
  android.hardware.graphics.composer@2.0-service \
  android.hardware.graphics.composer@2.1-service \
  android.hardware.graphics.composer@2.2-service \
  android.hardware.graphics.composer@2.3-service \
  android.hardware.graphics.composer@2.4-service \
  vendor.qti.hardware.display.composer-service; do

  pid_list=$(pidof "$process")
  for pid in $pid_list; do
    [ -n "$pid" ] && echo "$pid" > /dev/memcg/system/cgroup.procs
  done
done

exit 0
