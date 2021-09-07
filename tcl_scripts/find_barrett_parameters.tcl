# Find barrett Reduction Parameters

set MODULUS [lindex $argv 0] 

if {$MODULUS < 0} {
   set k 0
} elseif {$MODULUS == 1 } { 
   set k 1
} else {
   for {set i 0} {$i < $MODULUS} {incr i} {
      if {pow(2,$i) >= $MODULUS } {
         set k $i
         break
      }
   }
}

set r [expr { floor(pow(4,$k)/$MODULUS) } ]
set k2 [expr {2*$k}]

puts "Parameter k2 = $k2"
puts "Parameter r = $r"

