connect -url tcp:localhost:3121
targets -set -filter {name =~ "ARM Cortex-A9 MPCore #0"}
con
after 30000
stop
puts "DONE"
exit
