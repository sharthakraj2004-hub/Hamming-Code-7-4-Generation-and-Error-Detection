
# PlanAhead Launch Script for Pre-Synthesis Floorplanning, created by Project Navigator

create_project -name Project_LCD -dir "C:/Users/Student.DESKTOP-7NHPTUF/Desktop/Project_LCD/planAhead_run_3" -part xc6slx9tqg144-3
set_param project.pinAheadLayout yes
set srcset [get_property srcset [current_run -impl]]
set_property target_constrs_file "top_mips_hamming.ucf" [current_fileset -constrset]
set hdlfile [add_files [list {Course_proj2.v}]]
set_property file_type Verilog $hdlfile
set_property library work $hdlfile
set_property top top_mips_hamming $srcset
add_files [list {top_mips_hamming.ucf}] -fileset [get_property constrset [current_run]]
open_rtl_design -part xc6slx9tqg144-3
