#!/user/bin/bash

#Run this script to get a snapshot of your current GPU utilization.
#This script leverages the nvidia-smi command to provide real-time utilization for 4 NVIDIA GPUs.

D=$(date)
G=(10 11 12 13)

for k in {0..3}
do
	nvidia-smi pmon -c 1 -i $k  > gpu.txt
	awk '!/#/' gpu.txt > temp.txt && mv temp.txt gpu.txt
	GPU=$(awk '// {print $1}' gpu.txt)
	UTIL=$(awk '// {print $4}' gpu.txt)
	if [ $UTIL != '-' ]; then
			G[k]=$(echo ' The GPU ' $GPU 'is under process, and the utilization is %'$UTIL)
	else
			G[k]=$(echo ' No one is using GPU ' $GPU)
	fi
done
whiptail --title "GPUs Status" --msgbox "$D \n  $G[0] \n  $G[1] \n  $G[2] \n  $G[3] " 20 60