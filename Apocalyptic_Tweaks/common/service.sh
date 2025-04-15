#!/system/bin/sh
MODDIR="${0%/*}"

# Aguarda o sistema inicializar
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 10
done

# Executa o script de reset da bateria
sh "$MODDIR/ABattery/ABatteryReset.sh"

# Define parâmetros do kernel
echo 3 > /proc/sys/kernel/perf_cpu_time_max_percent
echo 1 > /proc/sys/kernel/sched_autogroup_enabled
echo 0 > /proc/sys/kernel/sched_schedstats
echo 64 > /proc/sys/kernel/random/read_wakeup_threshold
echo "off" > /proc/sys/kernel/printk_devkmsg

# Ativa TTWU_QUEUE no agendador
echo TTWU_QUEUE > /sys/kernel/debug/sched_features

sleep 60

# Ajusta swappiness
echo 100 > /dev/memcg/memory.swappiness
echo 40 > /dev/memcg/system/memory.swappiness
echo 50 > /dev/memcg/apps/memory.swappiness

# Limpa processos do memcg system
while read -r pid; do
  echo "$pid" > /dev/memcg/cgroup.procs
done < /dev/memcg/system/cgroup.procs

# Move processos específicos para o memcg system
for process in system_server surfaceflinger \
  android.hardware.graphics.composer@2.0-service \
  android.hardware.graphics.composer@2.1-service \
  android.hardware.graphics.composer@2.2-service \
  android.hardware.graphics.composer@2.3-service \
  android.hardware.graphics.composer@2.4-service \
  vendor.qti.hardware.display.composer-service; do
  pid=$(pidof "$process")
  [ -n "$pid" ] && echo "$pid" > /dev/memcg/system/cgroup.procs
done

exit 0
