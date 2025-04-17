#!/system/bin/sh

# Função para aplicar resetprop com verificação silenciosa
apply_resetprop() {
  prop="$1"
  value="$2"
  if resetprop "$prop" >/dev/null 2>&1; then
    resetprop -n "$prop" "$value"
  fi
}

# Lista de propriedades e valores
props=(
  # IORap
  ro.iorapd.enable
  persist.device_config.runtime_native_boot.iorap_perfetto_enable
  persist.device_config.runtime_native_boot.iorap_readahead_enable

  # Logging/stats
  log.tag.stats_log
  log.tag.statsd

  # Thermal leves
  persist.vendor.thermal.debug.config
  ro.vendor.throttle.enable
  persist.sys.thermal.config
)

values=(
  false
  false
  false

  ERROR
  ERROR

  false
  false
  normal
)

# Aplica os resetprop com verificação segura
for i in "${!props[@]}"; do
  apply_resetprop "${props[$i]}" "${values[$i]}"
done
