onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /cacheTestBench/way4I
add wave -noupdate -radix hexadecimal /cacheTestBench/way3I
add wave -noupdate -radix hexadecimal /cacheTestBench/way2I
add wave -noupdate -radix binary /cacheTestBench/way1I
add wave -noupdate /cacheTestBench/way8D
add wave -noupdate /cacheTestBench/way7D
add wave -noupdate /cacheTestBench/way6D
add wave -noupdate /cacheTestBench/way5D
add wave -noupdate /cacheTestBench/way4D
add wave -noupdate /cacheTestBench/way3D
add wave -noupdate /cacheTestBench/way2D
add wave -noupdate -radix binary /cacheTestBench/way1D
add wave -noupdate /cacheTestBench/writeI
add wave -noupdate /cacheTestBench/write
add wave -noupdate /cacheTestBench/processingI
add wave -noupdate /cacheTestBench/processingD
add wave -noupdate /cacheTestBench/processing
add wave -noupdate /cacheTestBench/counter
add wave -noupdate /cacheTestBench/clk
add wave -noupdate /cacheTestBench/address
add wave -noupdate /cacheTestBench/L1I/LRUline1
add wave -noupdate /cacheTestBench/L1I/LRULineLRU
add wave -noupdate -radix decimal -childformat {{{/cacheTestBench/L1I/lineArray[2]} -radix decimal} {{/cacheTestBench/L1I/lineArray[1]} -radix decimal} {{/cacheTestBench/L1I/lineArray[0]} -radix decimal}} -expand -subitemconfig {{/cacheTestBench/L1I/lineArray[2]} {-height 15 -radix decimal} {/cacheTestBench/L1I/lineArray[1]} {-height 15 -radix decimal} {/cacheTestBench/L1I/lineArray[0]} {-height 15 -radix decimal}} /cacheTestBench/L1I/lineArray
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {21 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 196
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
