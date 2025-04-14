SKIPMOUNT=false
PROPFILE=true
POSTFSDATA=false
LATESTARTSERVICE=true

##########################################################################################
# Replace list
##########################################################################################

# List all directories you want to directly replace in the system
# Check the documentations for more info why you would need this

# Construct your list in the following format
# This is an example
REPLACE_EXAMPLE="
/system/app/Youtube
/system/priv-app/SystemUI
/system/priv-app/Settings
/system/framework
"

# Construct your own list here
REPLACE="
"

# Set what you want to display when installing your module

print_modname() {
  ui_print "  "
  ui_print "   ΩΔApocalyptic TweaksΔΩ   "
  ui_print "  Faça seu MediaTek ser otimizado e competente.  "
  ui_print "  Créditos: Andrews Gabriel(@Miel11s)  "
  ui_print "."
  ui_print "."
  ui_print "."
  ui_print "."
  ui_print "."
  ui_print "  !Reinicie e Aproveite!  "
  ui_print "."
}

# Copy/extract your module files into $MODPATH in on_install.

on_install() {
  # The following is the default implementation: extract $ZIPFILE/system to $MODPATH
  # Extend/change the logic to whatever you want
  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
  unzip -o -j "$ZIPFILE" 'common/vendor.prop' -d $MODPATH >&2
  
}

# Only some special files require specific permissions
# This function will be called after on_install is done
# The default permissions should be good enough for most cases

ui_print "- ABattery Descompactado -"
unzip -o "$ZIPFILE" 'ABattery/*' -d $MODPATH >&2

ui_print "- service.sh Descompactado -"
unzip -o "$ZIPFILE" 'service.sh' -d  $MODPATH >&2


ui_print "- Permissões concedidas com exito.!"
set_permissions() {
  # The following is the default rule, DO NOT remove
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm_recursive "$MODPATH/ABattery" 0 0 0774 0774
  set_perm "$MODPATH/service.sh" 0 0 0755

}