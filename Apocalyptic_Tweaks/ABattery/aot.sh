#!/system/bin/sh

# Aguarda o sistema estabilizar mais um pouco
sleep 60

# Log de início
echo "[AOT] Iniciando compilação full AOT..." > /data/aot_compile.log

# Executa a compilação AOT completa
cmd package compile -m speed -f ALL >> /data/aot_compile.log 2>&1

# Marca como feito
touch /data/aot_applied.flag

# Log de fim
echo "[AOT] Compilação finalizada." >> /data/aot_compile.log
