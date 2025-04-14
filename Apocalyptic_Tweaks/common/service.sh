#!/system/bin/sh
MODDIR="${0%/*}"

#Apocalyptic Battery
while [ -z "$(getprop sys.boot_completed)" ]; do
sleep 10
done
sh /data/adb/modules/Apocalyptic/ABattery/ABatteryReset.sh

# Definir parâmetros do kernel
echo 3 > /proc/sys/kernel/perf_cpu_time_max_percent
echo 1 > /proc/sys/kernel/sched_autogroup_enabled
echo 0 > /proc/sys/kernel/sched_schedstats
echo 64 > /proc/sys/kernel/random/read_wakeup_threshold
echo "off" > /proc/sys/kernel/printk_devkmsg

# Ativar TTWU_QUEUE no agendador
echo TTWU_QUEUE > /sys/kernel/debug/sched_features

sleep 60

echo '100' > /dev/memcg/memory.swappiness
echo '40' > /dev/memcg/system/memory.swappiness
echo '50' > /dev/memcg/apps/memory.swappiness


# Clear memg system
for clear in $(cat /dev/memcg/system/cgroup.procs); do
    echo $clear > /dev/memcg/cgroup.procs
done

# Executa o processo PID
process_name="system_server"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

process_name="surfaceflinger"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

# Reduz a carga do Composer do Android
process_name="android.hardware.graphics.composer@2.0-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

process_name="android.hardware.graphics.composer@2.1-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs


process_name="android.hardware.graphics.composer@2.2-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs


process_name="android.hardware.graphics.composer@2.3-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

process_name="android.hardware.graphics.composer@2.4-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

process_name="vendor.qti.hardware.display.composer-service"
pid_proc=$(pidof "$process_name")
echo $pid_proc > /dev/memcg/system/cgroup.procs

exit 0