#!/system/bin/sh
MODDIR="${0%/*}"

# Aguarda o sistema inicializar
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 5
done

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
