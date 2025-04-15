SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

print_modname() {
  ui_print "  "
  ui_print "   ΩΔApocalyptic TweaksΔΩ   "
  ui_print "  Faça seu MediaTek ser otimizado e competente.  "
  ui_print "  Créditos: Andrews Gabriel(@Miel11s)  "
  ui_print "  "
  ui_print "  !Reinicie e Aproveite!  "
  ui_print "  "
}

ui_print "- Verificando compatibilidade com MediaTek..."

CHIP_INFO="$(grep -Ei 'Hardware|Processor|model name' /proc/cpuinfo | uniq | cut -d ':' -f2 | tr -d '[:blank:]')"
CHIP_INFO="$CHIP_INFO $(getprop ro.board.platform) $(getprop ro.hardware) $(getprop ro.hardware.chipname)"

if echo "$CHIP_INFO" | grep -qi "mt"; then
  ui_print "- Dispositivo MediaTek detectado, prosseguindo com a instalação..."
else
  ui_print "********************************************"
  ui_print "! Este módulo é exclusivo para dispositivos"
  ui_print "! com chipset MediaTek."
  ui_print "! Instalação abortada."
  ui_print "********************************************"
  abort
fi

# Essas funções só serão chamadas se passar no if acima.

on_install() {
  ui_print "- Extraindo arquivos do módulo"
  unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2
  unzip -o -j "$ZIPFILE" 'common/vendor.prop' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'ABattery/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'service.sh' -d "$MODPATH" >&2
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm_recursive "$MODPATH/ABattery/ABatteryReset.sh" 0 0 0775 0775
  set_perm "$MODPATH/service.sh" 0 0 0755
}
