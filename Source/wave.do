onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /cacheTestBench/way8D
add wave -noupdate /cacheTestBench/way7D
add wave -noupdate /cacheTestBench/way6D
add wave -noupdate /cacheTestBench/way5D
add wave -noupdate /cacheTestBench/way4D
add wave -noupdate /cacheTestBench/way3D
add wave -noupdate /cacheTestBench/way2D
add wave -noupdate -radix hexadecimal /cacheTestBench/way1D
add wave -noupdate /cacheTestBench/way4I
add wave -noupdate /cacheTestBench/way3I
add wave -noupdate /cacheTestBench/way2I
add wave -noupdate /cacheTestBench/way1I
add wave -noupdate /cacheTestBench/clk
add wave -noupdate /cacheTestBench/L1D/match1
add wave -noupdate /cacheTestBench/L1D/matchingLineLRU1
add wave -noupdate /cacheTestBench/L1D/matchingLine1
add wave -noupdate /cacheTestBench/L1D/firstLRUfound
add wave -noupdate /cacheTestBench/L1D/invalidExists
add wave -noupdate /cacheTestBench/L1D/LRUinvalidValue
add wave -noupdate /cacheTestBench/L1D/LRUinvalidLine
add wave -noupdate /cacheTestBench/L1D/victimLine1
add wave -noupdate /cacheTestBench/L1D/victimLRUvalue1
add wave -noupdate /cacheTestBench/L1D/LRUline
add wave -noupdate /cacheTestBench/L1D/LRULineValue
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {10 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 239
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {83 ps}
