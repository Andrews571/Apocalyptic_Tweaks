#!/system/bin/sh
MODDIR="${0%/*}"

# Aguarda o sistema inicializar
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

# ───── Verificação de suporte ao core_ctl ou variantes ─────

CORE_CTL_PATHS="
/sys/devices/system/cpu/cpu0/core_ctl
/sys/devices/system/cpu/cpu0/core-control
/sys/devices/system/cpu/cpu0/corectrl
/sys/module/msm_core_ctl
/sys/module/core_ctl
/sys/module/core_control
/sys/devices/system/cpu/core_ctl
"

for path in $CORE_CTL_PATHS; do
  if [ -d "$path" ] || [ -f "$path" ]; then
    CORE_CTL_FOUND=1
	break
  fi
done

export PATH=$MODPATH/bin:$PATH

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
#__list_thermal_services() {
#__    find /system/etc/init /vendor/etc/init /odm/etc/init -type f -name '*.rc' 2>/dev/null | while read -r rc; do
#__        grep -E "^service\s" "$rc" | awk '{print $2}' | grep -Ei 'thermal'
#__    done
#__}
#__for svc in $(list_thermal_services); do
#__    echo "Stopping $svc"
#__    stop "$svc"
#__done

# Desativa modos térmicos leves
for zone_mode in /sys/class/thermal/thermal_zone*/mode; do
  zone_dir=$(dirname "$zone_mode")
  zone_type=$(cat "$zone_dir/type" 2>/dev/null)

  if echo "$zone_type" | grep -qiE 'gpu|vdd|skin'; then
    lock_val "disabled" "$zone_mode"
  fi
done

# Remove limites de CPU em thermal_message
if [ -f /sys/devices/virtual/thermal/thermal_message/cpu_limits ]; then
    for i in 0 2 4 6 7; do
        maxfreq="$(cat /sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq 2>/dev/null)"
        [ "$maxfreq" -gt "0" ] && lock_val "cpu$i $maxfreq" /sys/devices/virtual/thermal/thermal_message/cpu_limits
    done
fi

# Desativa políticas do PPM (MediaTek)
#if [ -d /proc/ppm ]; then
#    for idx in $(awk -F'[][]' '/PWR_THRO|THERMAL/{print $2}' /proc/ppm/policy_status 2>/dev/null); do
#        lock_val "$idx 0" /proc/ppm/policy_status
#    done
#fi

# Desativa limitações da GPU (MediaTek)
if [ -f /proc/gpufreq/gpufreq_power_limited ]; then
    lock_val "ignore_batt_oc 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_batt_percent 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_low_batt 1" /proc/gpufreq/gpufreq_power_limited
#   lock_val "ignore_thermal_protect 1" /proc/gpufreq/gpufreq_power_limited
    lock_val "ignore_pbm_limited 1" /proc/gpufreq/gpufreq_power_limited
fi

# Override thermalservice
#__cmd thermalservice override-status 0 2>/dev/null

# Permissões contra throttling
#__find /sys/devices/virtual/thermal -type f -exec chmod 000 {} +
#__chmod 000 /sys/devices/*mali*/tmu
#__chmod 000 /sys/devices/*mali*/throttling*
#__chmod 000 /sys/devices/*mali*/tripping

lock_val 0 /sys/class/thermal/thermal_zone0/thm_enable
lock_val "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

# GPU DVFS & PerfMgr
echo -n Y > /sys/module/ged/parameters/gpu_dvfs
echo -n 0 > /proc/hps/enabled
echo -n 0 > /proc/perfmgr_enable

# Desativa Joyose (telemetria da Xiaomi)
if getprop ro.product.manufacturer | grep -iq "xiaomi"; then
    JOYOSE_SERVICE="$(pidof joyose)"
    if [ -n "$JOYOSE_SERVICE" ]; then
        echo "Parando Joyose..."
        stop joyose
        killall joyose
    fi

    # Tenta impedir reinicialização do serviço
    for path in /system/priv-app/Joyose /vendor/priv-app/Joyose /system_ext/priv-app/Joyose /product/priv-app/Joyose; do
        if [ -d "$path" ]; then
            chmod 000 "$path"/* 2>/dev/null
        fi
    done

    # Também bloqueia possíveis binários do Joyose se existirem
    for binpath in /system/bin/joyose /vendor/bin/joyose /system_ext/bin/joyose /product/bin/joyose; do
        if [ -f "$binpath" ]; then
            chmod 000 "$binpath" 2>/dev/null
        fi
    done
fi

# Desativa GOS (Game Optimizing Service - Samsung)
if getprop ro.product.manufacturer | grep -iq "samsung"; then
    GOS_PKG="com.samsung.android.game.gos"

    # Parar serviço (caso esteja rodando via init)
    stop gos 2>/dev/null
    killall gos 2>/dev/null

    # Força encerramento via pm
    pm disable "$GOS_PKG" 2>/dev/null
    pm uninstall -k --user 0 "$GOS_PKG" 2>/dev/null

    # Bloqueia pasta do app (caso não tenha sido removido)
    for path in /system*/app/ /system*/priv-app/ /product/app/ /product/priv-app/; do
        gos_dir=$(find "$path" -type d -iname "*gos*" 2>/dev/null | head -n 1)
        [ -n "$gos_dir" ] && chmod 000 "$gos_dir"/* 2>/dev/null
    done

    # Bloqueia binário diretamente (se existir)
    for bin in /system*/bin/gos* /vendor*/bin/gos*; do
        [ -f "$bin" ] && chmod 000 "$bin" 2>/dev/null
    done

    # Aplica propriedade para mascarar existência (opcional)
    setprop ro.game.gos 0
fi

# Ajustes SKIA (menos latência visual)
settings put global skia_enable_msaa 0 2>/dev/null
settings put global skia_use_shader_float 1 2>/dev/null
settings put global skia_use_vulkan 0 2>/dev/null
settings put global enable_gpu_debug_layers 0 2>/dev/null

# Pipeline GL mais estável
setprop debug.hwui.skip_empty_frames 1
setprop debug.hwui.force_draw_frame 1

# Fixar frame pacing (VSYNC)
settings put global min_refresh_rate 60 2>/dev/null
settings put global peak_refresh_rate 120 2>/dev/null
settings put system min_refresh_rate 60 2>/dev/null
settings put system peak_refresh_rate 120 2>/dev/null
setprop ro.surface_flinger.set_touch_timer_ms 1 2>/dev/null
setprop ro.surface_flinger.set_idle_timer_ms 4000 2>/dev/null

#FPS em jogos
#settings put global game_mode 3 2>/dev/null
#settings put global game_mode_config 3 2>/dev/null
#settings put global game_driver_all_apps 1 2>/dev/null
#settings put global game_driver 1 2>/dev/null

sleep 3

# Remove logs ANR, tombstone e dropbox
rm -rf /data/anr /data/tombstones /data/system/dropbox
mkdir /data/anr /data/tombstones /data/system/dropbox
chmod 000 /data/anr /data/tombstones /data/system/dropbox

# GPU governor performance (Mali)
GPU_PATH=$(find /sys/class/devfreq -type d -name "*mali*" | head -n 1)
[ -d "$GPU_PATH" ] && echo simple_ondemand > "$GPU_PATH/governor" 2>/dev/null

# Ultra Low Latency Touch
for touch_dev in /sys/class/input/input*/device; do
    echo 500 > "$touch_dev/report_rate" 2>/dev/null
    echo 0 > "$touch_dev/filter_size" 2>/dev/null
    echo 0 > "$touch_dev/jitter" 2>/dev/null
    echo 1 > "$touch_dev/raw_mode" 2>/dev/null
    echo 99 > "$touch_dev/priority" 2>/dev/null
done

# Forçar GPU rendering
settings put global force_gpu_rendering 1

# Reset bateria (ABattery)
sh "$MODDIR/ABattery/ABatteryReset.sh"

# Kernel tuning
echo 3 > /proc/sys/kernel/perf_cpu_time_max_percent
echo 1 > /proc/sys/kernel/sched_autogroup_enabled
echo 0 > /proc/sys/kernel/sched_schedstats
echo 64 > /proc/sys/kernel/random/read_wakeup_threshold
echo "off" > /proc/sys/kernel/printk_devkmsg

# schedtune para background
STUNE="/dev/stune"
if [ -d "$STUNE" ]; then
    [ -f "$STUNE/background/schedtune.prefer_idle" ] && echo 1 > "$STUNE/background/schedtune.prefer_idle"
    [ -f "$STUNE/system-background/schedtune.prefer_idle" ] && echo 1 > "$STUNE/system-background/schedtune.prefer_idle"
fi

# Ativa TTWU_QUEUE
[ -e /sys/kernel/debug/sched_features ] && echo TTWU_QUEUE > /sys/kernel/debug/sched_features

sleep 5

# Aguarda a montagem correta dos blocos
TIMEOUT=15
while [ ! -e /sys/block/mmcblk0/queue/scheduler ] && [ $TIMEOUT -gt 0 ]; do
    sleep 1
    TIMEOUT=$((TIMEOUT - 1))
done

# I/O reforçado em blocos principais
for blkdev in /sys/block/mmcblk* /sys/block/zram0 /sys/block/dm-0 /sys/block/dm-1; do
  echo 0 > "$blkdev/queue/add_random" 2>/dev/null
  echo 0 > "$blkdev/queue/iostats" 2>/dev/null
  echo 2 > "$blkdev/queue/nomerges" 2>/dev/null
  echo 0 > "$blkdev/queue/rotational" 2>/dev/null
  echo 1 > "$blkdev/queue/rq_affinity" 2>/dev/null
done

# FPSGO e GED (MediaTek)
echo 90 > /sys/module/mtk_fpsgo/parameters/uboost_enhance_f 2>/dev/null
echo 0 > /sys/module/mtk_fpsgo/parameters/isolation_limit_cap 2>/dev/null
echo 1 > /sys/pnpmgr/fpsgo_boost/boost_enable 2>/dev/null
echo 1 > /sys/pnpmgr/fpsgo_boost/boost_mode 2>/dev/null
echo 1 > /sys/pnpmgr/install 2>/dev/null
echo 90 > /sys/kernel/ged/hal/gpu_boost_level 2>/dev/null

ged_params="ged_smart_boost 1
boost_upper_bound 100
enable_gpu_boost 1
enable_cpu_boost 1
ged_boost_enable 1
boost_gpu_enable 1
gpu_dvfs_enable 1
gx_frc_mode 1
gx_dfps 1
gx_force_cpu_boost 1
gx_boost_on 1
gx_game_mode 1
gx_3D_benchmark_on 1
gx_fb_dvfs_margin 100
gx_fb_dvfs_threshold 100
cpu_boost_policy 1
boost_extra 1
is_GED_KPI_enabled 0
ged_force_mdp_enable 1
force_fence_timeout_dump_enable 0"

echo "$ged_params" | while read -r param value; do
    path="/sys/module/ged/parameters/$param"
    [ -f "$path" ] && echo "$value" > "$path" 2>/dev/null
done

for param in adjust_loading boost_affinity boost_LR gcc_hwui_hint; do
    path="/sys/module/mtk_fpsgo/parameters/$param"
    [ -f "$path" ] && echo "1" > "$path" 2>/dev/null
done

# Kill redundante
for svc in thermal-engine vendor.thermal-engine thermald vendor.thermald thermal \
            thermal_manager mi_thermald samsung.thermal vendor.samsung.thermal thermal_qcom; do
  stop $svc 2>/dev/null
done
for daemon in thermal-engine thermald thermal thermal_manager \
               vendor.thermal-engine vendor.thermald; do
  [ "$(getprop init.svc.$daemon)" ] && stop $daemon
done

# I/O scheduler seguro
for blk in /sys/block/*/queue/scheduler; do
    scheds=$(cat "$blk")
    if echo "$scheds" | grep -qw 'row'; then
        echo row > "$blk" 2>/dev/null
    elif echo "$scheds" | grep -qw 'deadline'; then
        echo deadline > "$blk" 2>/dev/null
    elif echo "$scheds" | grep -qw 'cfq'; then
        echo cfq > "$blk" 2>/dev/null
    fi
done

# Ajustes adicionais do EAS (Energy Aware Scheduling)
for rate_limit in /sys/devices/system/cpu/cpufreq/policy*/schedutil/up_rate_limit_us; do
    echo 500 > $rate_limit 2>/dev/null
done

for rate_limit_down in /sys/devices/system/cpu/cpufreq/policy*/schedutil/down_rate_limit_us; do
    echo 10000 > $rate_limit_down 2>/dev/null
done

sleep 30

# Reforça prioridade de processos vitais do sistema (melhora fluidez geral)
for proc in system_server surfaceflinger; do
  PID=$(pidof "$proc")
  if [ -n "$PID" ]; then
    renice -n -20 -p $PID 2>/dev/null
  fi
done

# AOT Compilation
if [ ! -f /data/aot_applied.flag ]; then
  sh "$MODDIR/ABattery/aot.sh" &
fi

# swappiness
[ -f /dev/memcg/memory.swappiness ] && echo 100 > /dev/memcg/memory.swappiness
[ -f /dev/memcg/system/memory.swappiness ] && echo 40 > /dev/memcg/system/memory.swappiness
[ -f /dev/memcg/apps/memory.swappiness ] && echo 50 > /dev/memcg/apps/memory.swappiness

# Reorganiza processos
if [ -f /dev/memcg/system/cgroup.procs ] && [ -f /dev/memcg/cgroup.procs ]; then
  while read -r pid; do
    echo "$pid" > /dev/memcg/cgroup.procs
  done < /dev/memcg/system/cgroup.procs
fi

#Processos e Prioridades Movidos.

vip_processes=(
  system_server
  surfaceflinger
  android.hardware.graphics.composer@2.0-service
  android.hardware.graphics.composer@2.1-service
  android.hardware.graphics.composer@2.2-service
  android.hardware.graphics.composer@2.3-service
  android.hardware.graphics.composer@2.4-service
)

apply_cgroup_v1() {
  log -p i -t memcg "Usando cgroup v1"
  for process in "${vip_processes[@]}"; do
    for pid in $(pidof "$process"); do
      echo "$pid" > /dev/memcg/system/cgroup.procs 2>/dev/null
    done
  done
}

apply_cgroup_v2() {
  log -p i -t memcg "Usando cgroup v2"
  for process in "${vip_processes[@]}"; do
    for pid in $(pidof "$process"); do
      echo "$pid" > /sys/fs/cgroup/cgroup.procs 2>/dev/null
    done
  done
}

if [ -f /dev/memcg/system/cgroup.procs ]; then
  apply_cgroup_v1
elif [ -f /sys/fs/cgroup/cgroup.procs ]; then
  apply_cgroup_v2
else
  log -p w -t memcg "Nenhum cgroup compatível encontrado"
fi

# CPU topo ajustes finais
echo 1 > /sys/devices/system/cpu/sched_mc_power_savings 2>/dev/null
[ -f /sys/devices/system/cpu/cpu0/topology/thread_siblings ] && echo 0 > /sys/devices/system/cpu/cpu0/topology/thread_siblings 2>/dev/null

# Ajustes GPU
for gpu_path in /sys/class/devfreq/*gpu*; do
  available=$(cat "$gpu_path/available_governors" 2>/dev/null)
  if echo "$available" | grep -qw "simple_ondemand"; then
    echo simple_ondemand > "$gpu_path/governor"
  elif echo "$avaliable" | grep -qw "ondemand"; then
	echo ondemand > "$gpu_path/governor"
  fi
done

LOCK_FILE="/dev/tmp/apoc_corewatch.lock"

if [ "$CORE_CTL_FOUND" = "1" ] && [ ! -f "$LOCK_FILE" ]; then
	touch "$LOCK_FILE"
	(
		log -p i -t ApocTweaks "Iniciando watcher de núcleos com inotifywait..."

		# Detecta caminhos válidos
		paths_to_watch=""

		for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
			online_path="$cpu_dir/online"
			if [ -f "$online_path" ]; then
				paths_to_watch="$paths_to_watch $online_path"
			fi
		done

		if [ -z "$paths_to_watch" ]; then
			log -p e -t ApocTweaks "Nenhum caminho válido para watcher encontrado."
			rm -f "$LOCK_FILE"
			exit 1
		fi

		# Inicia o watcher
		echo "$paths_to_watch" | xargs inotifywait -m -e modify 2>/dev/null | while read -r path _; do
			cpu_name=$(basename "$(dirname "$path")")
			log -p i -t ApocTweaks "Detectado religamento de $cpu_name"

			governor_path="/sys/devices/system/cpu/$cpu_name/cpufreq/scaling_governor"
			freq_path="/sys/devices/system/cpu/$cpu_name/cpufreq/scaling_available_frequencies"
			minfreq_path="/sys/devices/system/cpu/$cpu_name/cpufreq/scaling_min_freq"

			# Reaplica governor
			[ -f "$governor_path" ] && echo schedutil > "$governor_path"

			# Segunda menor frequência
			if [ -f "$freq_path" ] && [ -f "$minfreq_path" ]; then
				min2=$(tr ' ' '\n' < "$freq_path" | sort -n | head -n2 | tail -n1)
				[ -n "$min2" ] && echo "$min2" > "$minfreq_path"
			fi

			cpu_limits_path="/sys/devices/virtual/thermal/thermal_message/cpu_limits"
			[ -f "$cpu_limits_path" ] && {
				freqs=($(tr ' ' '\n' < "$freq_path" | sort -n))
				fcount=${#freqs[@]}
				if [ "$fcount" -ge 2 ]; then
					target=${freqs[$((fcount - 2))]}
					echo "$cpu_name $target" > "$cpu_limits_path"
				fi
			}

			# Rate limits — autodetecta qual caminho usar
			schedutil_paths=(
				"/sys/devices/system/cpu/$cpu_name/cpufreq/schedutil"
				"/sys/devices/system/cpu/cpufreq/${cpu_name/cpu/policy}/schedutil"
			)

			for sched_path in "${schedutil_paths[@]}"; do
				if [ -d "$sched_path" ]; then
					[ -f "$sched_path/up_rate_limit_us" ] && echo 500 > "$sched_path/up_rate_limit_us"
					[ -f "$sched_path/down_rate_limit_us" ] && echo 10000 > "$sched_path/down_rate_limit_us"
				fi
			done

			log -p i -t ApocTweaks "$cpu_name reconfigurado com sucesso."
		done

		# Finaliza lock se o watcher parar por algum motivo
		rm -f "$LOCK_FILE"
	) &
fi

# ───── Apoc: Simplified Throttle Limiter ─────

cpu_limits_path="/sys/devices/virtual/thermal/thermal_message/cpu_limits"
[ ! -f "$cpu_limits_path" ] && exit 0

for cpu_path in /sys/devices/system/cpu/cpu[0-9]*; do
  cpu_id=$(basename "$cpu_path" | grep -o '[0-9]\+')
  freq_list_path="$cpu_path/cpufreq/scaling_available_frequencies"
  max_freq_path="$cpu_path/cpufreq/cpuinfo_max_freq"

  [ ! -f "$freq_list_path" ] || [ ! -f "$max_freq_path" ] && continue

  freqs=($(tr ' ' '\n' < "$freq_list_path" | sort -n))
  fcount=${#freqs[@]}
  [ "$fcount" -lt 2 ] && continue  # Precisa de pelo menos 2 opções

  max_freq=$(cat "$max_freq_path" 2>/dev/null)

  if [ "$max_freq" -gt 3000000 ] && [ "$fcount" -ge 3 ]; then
    # CPUs acima de 3GHz → terceira maior
    target=${freqs[$((fcount - 3))]}
  else
    # Demais CPUs → segunda maior
    target=${freqs[$((fcount - 2))]}
  fi

  echo "cpu$cpu_id $target" > "$cpu_limits_path"
done

# ───── Apoc: Elevação de trip points térmicos da CPU em +2°C ─────

for zone_path in /sys/class/thermal/thermal_zone*; do
    type_path="$zone_path/type"
    [ ! -f "$type_path" ] && continue

    zone_type=$(cat "$type_path" 2>/dev/null | tr '[:upper:]' '[:lower:]')

    # Considera apenas zonas relacionadas à CPU
    if echo "$zone_type" | grep -q "cpu"; then
        for trip in "$zone_path"/trip_point_*_temp; do
            [ -f "$trip" ] || continue

            current=$(cat "$trip" 2>/dev/null)
            if [ -n "$current" ] && [ "$current" -ge 30000 ]; then
                new=$((current + 2000))  # +2°C
                echo "$new" > "$trip" 2>/dev/null
            fi
        done
    fi
done

exit 0
