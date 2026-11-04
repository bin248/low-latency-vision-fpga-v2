# 在已完成布局布线的 run 目录（含 camera_to_dsi_display_pr.db）执行：
#   td_commands_prompt -f bitgen.tcl
source ./settings.cfg
import_device $device_name -package $package_name -speed $speed
import_db ${prj_name}_pr.db
bitgen -bit ${prj_name}.bit
puts "bitgen complete: ${prj_name}.bit"
exit 0
