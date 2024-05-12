#!/user/bin/bash

#This script monitors Kubernetes pods for the 'CrashLoopBackOff' state,
#and sends an email notification if any pods are found in this critical condition.
#To schedule automated checks, create a cronjob that runs this script at desired intervals.

rm mail.txt pods.txt
kubectl get pods -A > pods.txt

file_name="pods.txt"

while IFS= read -r line; do
  ER=0
  CHECK=$(echo "$line" | cut -d' ' -f4)
  if [[ "$CHECK" == 'CrashLoopBackOff' ]]; then
    ER=$CHECK
    NS=$(echo "$line" | cut -d' ' -f1)
    POD=$(echo "$line" | cut -d' ' -f2)
  fi
  if [ ER ]; then
        echo '#################################################### ' >> mail.txt
        date >> mail.txt
        echo '#################################################### ' >> mail.txt
        echo 'Namespace : '$NS >> mail.txt
        echo 'Pod : '$POD  >> mail.txt
        echo '#################################################### ' >> mail.txt
        kubectl describe pod -n $NS $POD | grep "Warning\|Error\|warning\|error" >> mail.txt
        echo '#################################################### ' >> mail.txt
        echo '**************************************************** ' >> mail.txt
        kubectl get events -n $NS | grep "Warning\|Error\|warning\|error" >> mail.txt
        echo '#################################################### ' >> mail.txt
        cat mail.txt | mail -s "CrashLoopBackOff notification" user@example.com
  fi
done < "$file_name" 
