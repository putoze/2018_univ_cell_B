# Read all Files
source synopsys_dc.setup
read_verilog huffman.v
current_design huffman
link

# Setting Clock Constraits
source -echo -verbose huffman.sdc

# Synthesis all design
compile -map_effort high -area_effort high
compile -map_effort high -area_effort high -inc

write -format ddc  -hierarchy -output "./Netlist/huffman_syn.ddc"
write_sdf ./Netlist/huffman_syn.sdf
write_file -format verilog -hierarchy -output ./Netlist/huffman_syn.v
report_area > ./Report/area.log
report_timing > ./Report/timing.log
report_qor > ./Report/huffman_syn.qor

#======================================================
#  Finish and Quit
#======================================================
exit

