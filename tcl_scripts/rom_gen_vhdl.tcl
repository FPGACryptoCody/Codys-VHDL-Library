puts stdout "Running Roy NTT Root Block Memory Generator:"

set ENTITY_NAME [lindex $argv 0] 
set COE_FILE [lindex $argv 1]
set OUTPUT_FILE [lindex $argv 2] 

# Constants
set CLK "CLK"
set ADDRESS "ADDR"
set DATA "DATA"

set TAB "   "
set SPACE " "
set NATURAL ":natural:="
set STD_LOGIC "std_logic;"
set STD_LOGIC_VECTOR "std_logic_vector("
set SIGNAL "signal "

# COE file parameters
set fp_r [open $COE_FILE r]

gets $fp_r ADDRESS_WIDTH
gets $fp_r DATA_WIDTH
gets $fp_r DATA_LENGTH

# Configuration
puts stdout "Creating file"
set fp [open $OUTPUT_FILE w+]
# Start File Write
# Header
puts $fp "-- Created by: Roy Root Memory tcl script"
puts $fp "-- Author: Cody Emerson"
puts $fp "-- Version: 1"

# Libraries
puts $fp "library ieee;"
puts $fp "use ieee.std_logic_1164.all;"
puts $fp "use ieee.numeric_std.all;"

# Entity
puts $fp ""
puts $fp [append line0 "entity " $ENTITY_NAME " is"]
puts $fp [append line1 $TAB "port("]
puts $fp [append line2 $TAB $TAB $CLK $SPACE $TAB $TAB ": in " $STD_LOGIC]
puts $fp [append line3 $TAB $TAB $ADDRESS $TAB $TAB ": in " $STD_LOGIC_VECTOR $ADDRESS_WIDTH " downto 0);"]
puts $fp [append line4 $TAB $TAB $DATA $TAB $TAB ": out " $STD_LOGIC_VECTOR $DATA_WIDTH " downto 0)"]
puts $fp [append line5 $TAB ");"]
puts $fp [append line6 "end " $ENTITY_NAME ";"]

# Architecture
puts $fp ""
puts $fp [append line7 "architecture ROM of " $ENTITY_NAME " is"]
puts $fp ""
puts $fp [append line8 "constant " "LUT_LENGTH " $NATURAL $DATA_LENGTH ";"]
puts $fp [append line9 "type " "ROM_TYPE " "is array(0 to LUT_LENGTH-1) of " "std_logic_vector(" $DATA_LENGTH " downto 0);"]
puts $fp [append line11 "constant " "ROM " ":ROM_TYPE := ("]

set n 0
while { [gets $fp_r data] >= 0 } {
   puts $fp "$TAB $n => $data"
   incr n
}
puts $fp ");"


puts $fp [append line13 $SIGNAL "mem :ROM_TYPE := ROM;"]
puts $fp ""

# Process
puts $fp [append line14 "begin"]
puts $fp [append line15 $TAB "process(CLK)"]
puts $fp [append line16 $TAB "begin"]
puts $fp [append line17 $TAB $TAB "if(rising_edge(CLK)) then"]
puts $fp [append line18 $TAB $TAB $TAB "DATA <= mem(to_integer(unsigned(ADDR)));"]
puts $fp [append line19 $TAB $TAB "end if;"]
puts $fp [append line20 $TAB "end process;"]
puts $fp [append line21 "end ROM;"]

close $fp_r
close $fp