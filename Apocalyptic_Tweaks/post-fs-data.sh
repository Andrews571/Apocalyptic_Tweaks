#!/system/bin/sh

# Detecta se o sistema usa EAS ou HMP
if [ -d /dev/stune ] || [ -d /sys/fs/cgroup/schedtune ]; then
  # Sistema com EAS
  echo 0 > /data/ApocSchedMode
else
  # Sistema com HMP
  echo 1 > /data/ApocSchedMode
fi

chmod 644 /data/ApocSchedMode
chown root:root /data/ApocSchedMode

# Função segura para aplicar resetprop
apply_resetprop() {
  prop="$1"; value="$2"
  if resetprop "$prop" >/dev/null 2>&1; then
    resetprop -n "$prop" "$value"
  fi
}

# FSTRIM básico
fstrim -v /data; fstrim -v /cache; fstrim -v /metadata 2>/dev/null

# === PROPS migradas de system.prop e vendor.prop ===
all_props=(

  # GPU Tuner
  "FPSTUNER_SWITCH=true"
  "GPUTUNER_SWITCH=true"
  "CPUTUNER_SWITCH=true"
  "NV_POWERMODE=true"
  "debug.gpurend.vsync=true"
  "debug.cpurend.vsync=true"
  "hw.accelerated=1"
  "video.accelerated=1"
  "game.accelerated=1"
  "touch.accelerated=1"
  "ui.accelerated=1"
  "enable_hardware_accelerated=true"
  "enable_optimize_refresh_rate=true"
  "persist.service.lgospd.enable=0"
  "persist.service.pcsync.enable=0"
  "persist.sys.dalvik.hyperthreading=true"
  "persist.sys.dalvik.multithread=true"

  # Skia/OpenGL
  "ro.config.hw_high_perf=true"
  "ro.hwui.hardware.vulkan=false"
  "ro.hwui.use_vulkan=false"
  "debug.performance.tuning=1"
  "logcat.live=disable"
  "ro.config.hw_quickpoweron=true"
  "gsm.lte.ca.support=1"
  "debug.composition.type=gpu"
  "persist.sys.composition.type=gpu"
  "persist.sys.gpu_perf_mode=1"
  "persist.sys.disable_skia_path_ops=false"
  "debug.vulkan.layers.enable=0"
  "persist.sys.gpu.working_thread_priority=1"
  "renderthread.skia.reduceopstasksplitting=true"
  "persist.sys.perf.topAppRenderThreadBoost.enable=true"
  "debug.skia.threaded_mode=true"
  "ro.product.gpu.driver=1"
  "ro.config.enable.hw_accel=true"

  # Textura e cache
  "ro.sys.fw.use_trimlog=true"
  "debug.hwui.disable_scissor_opt=false"
  "ro.hwui.texture_cache_size=24"
  "ro.hwui.texture_cache_flushrate=0.5"
  "ro.sf.disable_smooth_effect=true"

  # HWC e Backpressure
  "debug.sf.disable_backpressure=1"
  "debug.sf.enable_gl_backpressure=0"
  "debug.sf.enable_hwc_vds=1"
  "debug.sf.predict_hwc_composition_strategy=1"

  # Latch / tracing / idle
  "debug.sf.latch_unsignaled=false"
  "debug.sf.auto_latch_unsignaled=false"
  "debug.sf.enable_transaction_tracing=false"

  # LMK Core
  "sys.lmk.reportkills=0"
  "persist.sys.lmk.reportkills=false"
  "ro.lmk.debug=false"

  # HWUI / GLES
  "ro.opengles.version=196610"
  "debug.hwui.show_dirty_regions=false"
  "debug.hwui.fps_divisor=1"
  "debug.hwui.use_hint_manager=false"
  "debug.hwui.target_cpu_time_percent=0"
  "debug.hwui.skia_tracing_enabled=false"
  "debug.hwui.skia_use_perfetto_track_events=false"
  "debug.hwui.capture_skp_enabled=false"
  "debug.hwui.trace_gpu_resources=false"
  "debug.hwui.show_layers_updates=false"
  "debug.hwui.skip_empty_damage=true"
  "debug.hwui.use_buffer_age=false"
  "debug.hwui.use_partial_updates=true"
  "debug.hwui.use_gpu_pixel_buffers=false"
  "debug.hwui.filter_test_overhead=false"
  "debug.hwui.overdraw=false"
  "debug.hwui.skp_filename=false"
  "debug.hwui.level=0"
  "debug.hwui.clip_surfaceviews=false"
  "debug.hwui.nv_profiling=false"
  "debug.hwui.disable_draw_defer=false"
  "debug.hwui.disable_draw_reorder=false"
  "debug.hwui.app_memory_policy=false"
  "ro.hwui.disable_scissor_opt=false"
  "persist.sys.ui.hw=1"
  "debug.sf.hw=1"
  "ro.sf.compbypass.enable=1"
  "ro.surface_flinger.use_content_detection_for_refresh_rate=true"
  "ro.surface_flinger.enable_frame_rate_override=true"
  "windowsmgr.max_events_per_sec=150"
  "ro.min_pointer_dur=8"
  "ro.max.fling_velocity=12000"
  "ro.min.fling_velocity=8000"
  "persist.sys.scrollingcache=3"
  "persist.sys.smartpower.display.enable=false"
  "persist.sys.smartpower.limit.max.refresh.rate=120"
  "persist.sys.multithreaded.dexloader.enable=true"

  # Internet
  "net.tcp.buffersize.default=4096,87380,256960,4096,16384,256960"
  "net.tcp.buffersize.wifi=4096,87380,256960,4096,16384,256960"
  "net.tcp.buffersize.umts=4096,87380,256960,4096,16384,256960"
  "net.tcp.buffersize.gprs=4096,87380,256960,4096,16384,256960"
  "net.tcp.buffersize.edge=4096,87380,256960,4096,16384,256960"
  "net.rmnet0.dns1=8.8.8.8"
  "net.rmnet0.dns2=8.8.4.4"
  "net.dns1=8.8.8.8"
  "net.dns2=8.8.4.4"
  "net.tcp.default_init_rwnd=60"
  "net.ipv4.tcp_ecn=0"
  "net.ipv4.tcp_congestion_control=bbr"
  "net.core.default_qdisc=fq"
  "net.core.netdev_max_backlog=16384"
  "net.core.rmem_max=26214400"
  "net.core.wmem_max=26214400"
  "net.ipv4.tcp_rmem=4096 87380 26214400"
  "net.ipv4.tcp_wmem=4096 65536 26214400"
  "net.ipv4.tcp_fack=1"
  "net.ipv4.tcp_fastopen=3"
  "net.ipv4.tcp_tw_reuse=1"
  "net.ipv4.tcp_sack=1"
  "net.ipv4.tcp_slow_start_after_idle=0"
  "net.tcp.fastopen.override=1"
  "net.rmem_max=4194304"

  # Media
  "media.stagefright.enable-player=true"
  "media.stagefright.enable-meta=true"
  "media.stagefright.enable-scan=true"
  "media.stagefright.enable-http=true"
  "media.stagefright.enable-rtsp=true"
  "media.stagefright.enable-record=true"

  # Frame Pacing
  "debug.sf.use_phase_offsets_as_durations=1"
  "debug.sf.set_idle_timer_ms=4000"
  "debug.sf.idle_frame_refresh_rate=60"
  "ro.surface_flinger.set_touch_timer_ms=1"
  "ro.surface_flinger.use_smart_90_for_video=false"
  "ro.surface_flinger.set_idle_timer_ms=4000"
  "ro.surface_flinger.refresh_rate=60"
  "ro.surface_flinger.frame_rate_multiple_threshold=60"

  # schedtune props
  "schedtune.boost=50"
  "schedtune.prefer_idle=1"
  "schedtune.sched_boost=1"
  "schedtune.util_est=1"
  "schedtune.boost_top_app=70"
  "schedtune.boost_group=30"

  # Quiet logs
  "log.tag.statsd=ERROR"
  "log.tag.stats_log=ERROR"
  "log.tag.stats=ERROR"
  "log.tag.APM=ERROR"

  # OpenGL
  "persist.graphics.vulkan.disable=true"
  "persist.sys.force_sw_gles=1"
  "debug.hwui.swap_with_damage=0"
  "persist.sys.sf.native_mode=1"
  "persist.sys.textureview_optimization.enable=true"
  "sys.hwc.gpu_perf_mode=1"
  "ro.config.hw_power_saving=false"
  "dalvik.vm.checkjni=false"
  "persist.sys.touch.presampling=1"
  "persist.sys.touch.size.scale=0.01"
  "persist.sys.touch.size.bias=0.01"
)

# Aplica todos os props
for kv in "${all_props[@]}"; do
  key="${kv%%=*}"
  val="${kv#*=}"
  apply_resetprop "$key" "$val"
done

# Heap Dalvik/ART baseado na RAM
total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$total_ram_kb" -lt 3000000 ]; then
  apply_resetprop dalvik.vm.heapgrowthlimit 256m
  apply_resetprop dalvik.vm.heapsize         384m
elif [ "$total_ram_kb" -lt 6000000 ]; then
  apply_resetprop dalvik.vm.heapgrowthlimit 384m
  apply_resetprop dalvik.vm.heapsize         512m
else
  apply_resetprop dalvik.vm.heapgrowthlimit 512m
  apply_resetprop dalvik.vm.heapsize         768m
  apply_resetprop dalvik.vm.heapstartsize    256m
fi
apply_resetprop dalvik.vm.heaptargetutilization 0.75
apply_resetprop dalvik.vm.heapminfree 4m
apply_resetprop dalvik.vm.heapmaxfree 16m

# Ajustes básicos de CPU
for gov in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor; do
  [ -w "$gov" ] && echo "schedutil" > "$gov"
done

# scaling_min_freq nos LITTLE
declare -A MAXF
for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*; do
  mf="$cpu_dir/cpufreq/cpuinfo_max_freq"
  [ -f "$mf" ] && MAXF["$cpu_dir"]="$(cat "$mf")"
done
MIN_MAXF=$(printf "%s\n" "${MAXF[@]}" | sort -n | head -n1)
for cpu_dir in "${!MAXF[@]}"; do
  if [ "${MAXF[$cpu_dir]}" -eq "$MIN_MAXF" ]; then
    avail="$cpu_dir/cpufreq/scaling_available_frequencies"
    min2="$(tr ' ' '\n' < "$avail" 2>/dev/null | sort -n | head -n2 | tail -n1)"
    [ -n "$min2" ] && echo "$min2" > "$cpu_dir/cpufreq/scaling_min_freq"
  fi
done

# Ajustes GPU
for gpu_path in /sys/class/devfreq/*gpu*; do
  echo performance > "$gpu_path/governor" 2>/dev/null
done

# Ajustes de topologia e corectl
[ -f /sys/module/msm_core_ctl/parameters/enable ] && echo 1 > /sys/module/msm_core_ctl/parameters/enable
echo 1 > /sys/devices/system/cpu/sched_mc_power_savings 2>/dev/null
[ -f /sys/devices/system/cpu/cpu0/topology/thread_siblings ] && echo 0 > /sys/devices/system/cpu/cpu0/topology/thread_siblings 2>/dev/null

# Ajustes avançados de VM tuning
min_free_kb=16384  # Padrão para dispositivos com 2-3 GB

if [ "$total_ram_kb" -ge 3145728 ]; then
    min_free_kb=32768
fi
if [ "$total_ram_kb" -ge 6144000 ]; then
    min_free_kb=65536
fi
if [ "$total_ram_kb" -ge 8388608 ]; then
    min_free_kb=98304
fi

# Aplica os parâmetros
sysctl -w vm.page-cluster=0 2>/dev/null
sysctl -w vm.vfs_cache_pressure=70 2>/dev/null
sysctl -w vm.overcommit_ratio=30 2>/dev/null
sysctl -w vm.min_free_kbytes=$min_free_kb 2>/dev/null

# Sysctl tuning
sysctl -w kernel.sched_latency_ns=6000000 2>/dev/null
sysctl -w kernel.sched_min_granularity_ns=750000 2>/dev/null
sysctl -w kernel.sched_wakeup_granularity_ns=1000000 2>/dev/null
sysctl -w kernel.sched_child_runs_first=0 2>/dev/null
sysctl -w vm.dirty_expire_centisecs=200 2>/dev/null
sysctl -w vm.dirty_writeback_centisecs=500 2>/dev/null
sysctl -w kernel.nmi_watchdog=0 2>/dev/null
sysctl -w vm.dirty_ratio=10 2>/dev/null
sysctl -w vm.dirty_background_ratio=5 2>/dev/null

# Ajustes HMP fallback
HMP_FALLBACK=$(cat /data/ApocSchedMode 2>/dev/null | grep -o 1)
if [ "$HMP_FALLBACK" = "1" ]; then
  echo 95 > /sys/devices/system/cpu/cpufreq/interactive/boost 2>/dev/null
  echo 1 > /sys/devices/system/cpu/cpufreq/interactive/io_is_busy 2>/dev/null
  echo 1 > /sys/devices/system/cpu/cpufreq/interactive/use_sched_load 2>/dev/null
  echo 1 > /sys/devices/system/cpu/cpufreq/interactive/use_migration_notif 2>/dev/null
  echo 1 > /sys/devices/system/cpu/cpufreq/interactive/align_windows 2>/dev/null
  echo 20000 > /sys/devices/system/cpu/cpufreq/interactive/timer_rate 2>/dev/null
  echo 40000 > /sys/devices/system/cpu/cpufreq/interactive/timer_slack 2>/dev/null
#else
#  echo 100 > /dev/stune/top-app/schedtune.boost 2>/dev/null
#  echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
fi

# LMK avançado para 8GB+
if [ "$total_ram_kb" -ge 8388608 ]; then
  echo "RAM >= 8GB: Aplicando LMK avançado"
  apply_resetprop "ro.lmk.use_psi" "true"
  apply_resetprop "ro.lmk.use_minfree_levels" "false"
  apply_resetprop "ro.lmk.thrashing_limit_decay" "15"
  apply_resetprop "ro.lmk.psi_partial_stall_ms" "70"
  apply_resetprop "ro.lmk.thrashing_limit" "20"
  apply_resetprop "ro.lmk.downgrade_pressure" "35"
  apply_resetprop "ro.lmk.swap_free_low_percentage" "10"
fi

# Aguarda /sys/block
while [ ! -d /sys/block ]; do
  sleep 1
done

# Ajustes I/O globais finais
for blk in /sys/block/*; do
  queue_path="$blk/queue"
  [ -d "$queue_path" ] || continue
  echo 0 > "$queue_path/add_random" 2>/dev/null
  echo 0 > "$queue_path/iostats" 2>/dev/null
  echo 2 > "$queue_path/nomerges" 2>/dev/null
  echo 0 > "$queue_path/rotational" 2>/dev/null
  echo 1 > "$queue_path/rq_affinity" 2>/dev/null

  # read_ahead adaptativo
  io_val=128
  [ "$total_ram_kb" -ge 3145728 ] && io_val=256
  echo $io_val > "$queue_path/read_ahead_kb" 2>/dev/null
  echo $io_val > "$queue_path/nr_requests" 2>/dev/null
done

# Ajustes adicionais do EAS (Energy Aware Scheduling)
for rate_limit in /sys/devices/system/cpu/cpufreq/policy*/schedutil/up_rate_limit_us; do
    echo 500 > $rate_limit 2>/dev/null
done

for rate_limit_down in /sys/devices/system/cpu/cpufreq/policy*/schedutil/down_rate_limit_us; do
    echo 10000 > $rate_limit_down 2>/dev/null
done

# ====== Aceleração de Boot com Governor Performance ======
DEFAULT_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
sleep 45
echo $DEFAULT_GOV | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Ativa políticas do PPM (MediaTek)
if [ -d /proc/ppm ]; then
  echo "1 1" > /proc/ppm/policy_status 2>/dev/null
  echo "2 1" > /proc/ppm/policy_status 2>/dev/null
  echo "3 1" > /proc/ppm/policy_status 2>/dev/null
  echo "4 1" > /proc/ppm/policy_status 2>/dev/null
fi

echo 2 > /sys/kernel/fpsgo/common/force_onoff 2>/dev/null
echo 0 > /proc/cpufreq/cpufreq_cci_mode 2>/dev/null
echo 0 > /proc/cpufreq/cpufreq_power_mode 2>/dev/null
echo 0 > /sys/devices/platform/boot_dramboost/dramboost/dramboost 2>/dev/null
echo 0 > /proc/gpufreq/gpufreq_opp_freq 2>/dev/null
echo -1 > /proc/gpufreqv2/fix_target_opp_index 2>/dev/null
echo "stop 0" > /proc/pbm/pbm_stop 2>/dev/null
echo "stop 0" > /proc/mtk_batoc_throttling/battery_oc_protect_stop 2>/dev/null
echo -1 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp 2>/dev/null
echo -1 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp 2>/dev/null
[ -e /sys/class/devfreq/mtk-dvfsrc-devfreq ] && chattr -i /sys/class/devfreq/mtk-dvfsrc-devfreq 2>/dev/null
echo 1 > /sys/kernel/eara_thermal/enable 2>/dev/null
echo 1 > /sys/devices/system/cpu/cpu1/online 2>/dev/null

# ────────────────┤ High FPS Device Spoof ├────────────────
BRAND=$(getprop ro.product.brand | tr '[:upper:]' '[:lower:]')

case "$BRAND" in
  samsung)
    ui_print "• Spoof: Galaxy S23 Ultra"
	resetprop ro.product.model SM-S938B
	resetprop ro.product.device pa3q
	resetprop ro.product.brand samsung
	resetprop ro.product.name pa3q
	resetprop ro.product.manufacturer samsung

	resetprop ro.product.vendor.model SM-S938B
	resetprop ro.product.vendor.device pa3q
	resetprop ro.product.vendor.brand samsung
	resetprop ro.product.vendor.name pa3q
	resetprop ro.product.vendor.manufacturer samsung

	resetprop ro.product.system.model SM-S938B
	resetprop ro.product.system.device pa3q
	resetprop ro.product.system.brand samsung
	resetprop ro.product.system.name pa3q
	resetprop ro.product.system.manufacturer samsung

	resetprop ro.product.bootimage.model SM-S938B
	resetprop ro.product.bootimage.device pa3q
	resetprop ro.product.bootimage.brand samsung
	resetprop ro.product.bootimage.name pa3q
	resetprop ro.product.bootimage.manufacturer samsung

	resetprop ro.product.odm.model SM-S938B
	resetprop ro.product.odm.device pa3q
	resetprop ro.product.odm.brand samsung
	resetprop ro.product.odm.name pa3q
	resetprop ro.product.odm.manufacturer samsung

	resetprop ro.product.system_ext.model SM-S938B
	resetprop ro.product.system_ext.device pa3q
	resetprop ro.product.system_ext.brand samsung
	resetprop ro.product.system_ext.name pa3q
	resetprop ro.product.system_ext.manufacturer samsung

	resetprop ro.product.product.model SM-S938B
	resetprop ro.product.product.device pa3q
	resetprop ro.product.product.brand samsung
	resetprop ro.product.product.name pa3q
	resetprop ro.product.product.manufacturer samsung
    ;;
  
  xiaomi)
	ui_print "• Spoof: Xiaomi 15 Pro"
	resetprop ro.product.model 24101PNB7C
	resetprop ro.product.device haotian
	resetprop ro.product.brand Xiaomi
	resetprop ro.product.name haotian
	resetprop ro.product.manufacturer Xiaomi

	resetprop ro.product.vendor.model 24101PNB7C
	resetprop ro.product.vendor.device haotian
	resetprop ro.product.vendor.brand Xiaomi
	resetprop ro.product.vendor.name haotian
	resetprop ro.product.vendor.manufacturer Xiaomi

	resetprop ro.product.system.model 24101PNB7C
	resetprop ro.product.system.device haotian
	resetprop ro.product.system.brand Xiaomi
	resetprop ro.product.system.name haotian
	resetprop ro.product.system.manufacturer Xiaomi

	resetprop ro.product.bootimage.model 24101PNB7C
	resetprop ro.product.bootimage.device haotian
	resetprop ro.product.bootimage.brand Xiaomi
	resetprop ro.product.bootimage.name haotian
	resetprop ro.product.bootimage.manufacturer Xiaomi

	resetprop ro.product.odm.model 24101PNB7C
	resetprop ro.product.odm.device haotian
	resetprop ro.product.odm.brand Xiaomi
	resetprop ro.product.odm.name haotian
	resetprop ro.product.odm.manufacturer Xiaomi

	resetprop ro.product.system_ext.model 24101PNB7C
	resetprop ro.product.system_ext.device haotian
	resetprop ro.product.system_ext.brand Xiaomi
	resetprop ro.product.system_ext.name haotian
	resetprop ro.product.system_ext.manufacturer Xiaomi

	resetprop ro.product.product.model 24101PNB7C
	resetprop ro.product.product.device haotian
	resetprop ro.product.product.brand Xiaomi
	resetprop ro.product.product.name haotian
	resetprop ro.product.product.manufacturer Xiaomi
    ;;
  
  motorola)
    ui_print "• Spoof: Moto Edge 50 Ultra"
	resetprop ro.product.model PB0Y0016SE
	resetprop ro.product.device edge_50_ultra
	resetprop ro.product.brand motorola
	resetprop ro.product.name edge_50_ultra
	resetprop ro.product.manufacturer motorola

	resetprop ro.product.vendor.model PB0Y0016SE
	resetprop ro.product.vendor.device edge_50_ultra
	resetprop ro.product.vendor.brand motorola
	resetprop ro.product.vendor.name edge_50_ultra
	resetprop ro.product.vendor.manufacturer motorola

	resetprop ro.product.system.model PB0Y0016SE
	resetprop ro.product.system.device edge_50_ultra
	resetprop ro.product.system.brand motorola
	resetprop ro.product.system.name edge_50_ultra
	resetprop ro.product.system.manufacturer motorola

	resetprop ro.product.bootimage.model PB0Y0016SE
	resetprop ro.product.bootimage.device edge_50_ultra
	resetprop ro.product.bootimage.brand motorola
	resetprop ro.product.bootimage.name edge_50_ultra
	resetprop ro.product.bootimage.manufacturer motorola

	resetprop ro.product.odm.model PB0Y0016SE
	resetprop ro.product.odm.device edge_50_ultra
	resetprop ro.product.odm.brand motorola
	resetprop ro.product.odm.name edge_50_ultra
	resetprop ro.product.odm.manufacturer motorola

	resetprop ro.product.system_ext.model PB0Y0016SE
	resetprop ro.product.system_ext.device edge_50_ultra
	resetprop ro.product.system_ext.brand motorola
	resetprop ro.product.system_ext.name edge_50_ultra
	resetprop ro.product.system_ext.manufacturer motorola

	resetprop ro.product.product.model PB0Y0016SE
	resetprop ro.product.product.device edge_50_ultra
	resetprop ro.product.product.brand motorola
	resetprop ro.product.product.name edge_50_ultra
	resetprop ro.product.product.manufacturer motorola
    ;;
  
  *)
    ui_print "• Nenhum spoof aplicado (marca: $BRAND)"
    ;;
esac

