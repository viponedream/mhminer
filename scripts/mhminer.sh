#!/bin/bash



killall mhminer

cd /root/mhminer
chmod +x *

./mhminer


# log_file=mhminer.log




# while true  #same to while :
# do
#     killall mhminer
    
#     cd /root/mhminer
#     chmod +x *
#     nohup ./mhminer >> $log_file 2>&1 &

#     time=$(date +%Y%m%d%H%M%S)
#     echo "$time=================== 启动 ==================="    >> $log_file
#     sleep 3600s
# done




