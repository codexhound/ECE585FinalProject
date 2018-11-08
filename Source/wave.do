onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /cacheTestBench/way8
add wave -noupdate /cacheTestBench/way7
add wave -noupdate /cacheTestBench/way6
add wave -noupdate /cacheTestBench/way5
add wave -noupdate /cacheTestBench/way4
add wave -noupdate /cacheTestBench/way3
add wave -noupdate /cacheTestBench/way2
add wave -noupdate /cacheTestBench/way1
add wave -noupdate /cacheTestBench/setRead
add wave -noupdate /cacheTestBench/processing
add wave -noupdate /cacheTestBench/mode
add wave -noupdate /cacheTestBench/command
add wave -noupdate /cacheTestBench/address
add wave -noupdate /cacheTestBench/L2message
add wave -noupdate /cacheTestBench/L1/total
add wave -noupdate /cacheTestBench/L1/tag1
add wave -noupdate /cacheTestBench/L1/reads
add wave -noupdate /cacheTestBench/L1/processing
add wave -noupdate /cacheTestBench/L1/misses
add wave -noupdate /cacheTestBench/L1/matchingLineWriteFirst
add wave -noupdate /cacheTestBench/L1/matchingLineTag
add wave -noupdate /cacheTestBench/L1/matchingLineMESI
add wave -noupdate /cacheTestBench/L1/matchingLineLRU
add wave -noupdate /cacheTestBench/L1/matchingLine1
add wave -noupdate /cacheTestBench/L1/match1
add wave -noupdate /cacheTestBench/L1/lineSetMU
add wave -noupdate /cacheTestBench/L1/index1
add wave -noupdate /cacheTestBench/L1/hits
add wave -noupdate /cacheTestBench/L1/command1
add wave -noupdate /cacheTestBench/L1/byte_sel1
add wave -noupdate /cacheTestBench/L1/LRUupdatecount
add wave -noupdate /cacheTestBench/L1/LRUupdate
add wave -noupdate /cacheTestBench/L1/LRUline1
add wave -noupdate /cacheTestBench/L1/LRUcompValue
add wave -noupdate /cacheTestBench/L1/LRULineWriteFirst
add wave -noupdate /cacheTestBench/L1/LRULineTag
add wave -noupdate /cacheTestBench/L1/LRULineMESI
add wave -noupdate /cacheTestBench/L1/LRULineLRU
add wave -noupdate /cacheTestBench/L1/L2message
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 195
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
WaveRestoreZoom {0 ps} {39 ps}
run -all
