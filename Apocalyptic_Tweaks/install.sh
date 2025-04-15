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

on_install() {
  ui_print "- Extraindo arquivos do módulo"
  unzip -o "$ZIPFILE" 'system/*' -d "$MODPATH" >&2
  unzip -o -j "$ZIPFILE" 'common/vendor.prop' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'ABattery/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'service.sh' -d "$MODPATH" >&2
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm_recursive "$MODPATH/ABattery" 0 0 0774 0774
  set_perm "$MODPATH/service.sh" 0 0 0755
}
