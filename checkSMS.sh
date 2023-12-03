#!/bin/bash


flagPressure=false
flagTemperature=false

numberRegex="^[0-9]*\.?[0-9]+$"

telegramToken="848509777:AAH838Tux-X7dcTsq8dADxiujcY-7xg4Bjk"
telegramChatID="838326370"
telegramURL="https://api.telegram.org/bot$telegramToken/sendMessage"

curl -s 192.168.1.98/emoncms/feed/timevalue.json?id=6 > /home/pi/scriptGreenhouse/airPressure.json
airPressureValue=$(jq -r '.value' /home/pi/scriptGreenhouse/airPressure.json)
airPressureTime=$(jq -r '.time' /home/pi/scriptGreenhouse/airPressure.json)
curl -s 192.168.1.98/emoncms/feed/timevalue.json?id=14 > /home/pi/scriptGreenhouse/temperature.json
temperatureValue=$(jq -r '.value' /home/pi/scriptGreenhouse/temperature.json)
temperatureTime=$(jq -r '.time' /home/pi/scriptGreenhouse/temperature.json)


time_not_updated(){
	if [ $1 == "pressure" ]
	then
		curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="CONNECTION TO AIR PRESSURE LOST"
	else
		if [$1 == "temperature"]
		then
			curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="CONNECTION TO TEMPERATURE LOST"
		fi
	fi

}


fetch_pressure(){
	curl -s 192.168.1.98/emoncms/feed/timevalue.json?id=6 > /home/pi/scriptGreenhouse/airPressure.json
	airPressureValue=$(jq -r '.value' /home/pi/scriptGreenhouse/airPressure.json)
	if [ "$airPressureTime" == $(jq -r '.time' /home/pi/scriptGreenhouse/airPressure.json) ]
	then
		time_not_updated "pressure"
	fi
	airPressureTime=$(jq -r '.time' /home/pi/scriptGreenhouse/airPressure.json)
	
}

fetch_temperature(){
	curl -s 192.168.1.98/emoncms/feed/timevalue.json?id=14 > /home/pi/scriptGreenhouse/temperature.json
	temperatureValue=$(jq -r '.value' /home/pi/scriptGreenhouse/temperature.json)
	if [ "$temperatureTime" == $(jq -r '.value' /home/pi/scriptGreenhouse/temperature.json) ]
	then
		time_not_updated "temperature"
	fi
	temperatureTime=$(jq -r '.time' /home/pi/scriptGreenhouse/temperature.json)
}

api_connection(){

	while true
	do	
		if ! [[ $airPressureValue =~ $numberRegex ]] || ! [[ $temperatureValue =~ $numberRegex ]];
		then
			echo "EMONCMS API ARE NOT WORKING"
			curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="CONNECTION TO EMONCMS API LOST"
			sleep 5m
			fetch_pressure
			fetch_temperature
		else
			return
		fi
	done


}

wait_for_restoring(){
	if [ $1 == "pressure" ]
	then
		while true
		do
			sleep 5m
			fetch_pressure
			if  [ $(echo "$airPressureValue>$(cut -f2 /home/pi/scriptGreenhouse/threshold.txt | sed '1q;d')" | bc) -eq 1 ]; # TODO in RASPBERRY ADD FULL PATH /home/pi/scriptGreenhouse/
			then
				curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="AIR PRESSURE RESTORED"
				flagPressure=false
				return			
			fi
		done
	else
		if [ $1 == "temperature" ]
		then
			while true
			do
				sleep 5m
				fetch_temperature
				if  [ $(echo "$temperatureValue<$(cut -f2 /home/pi/scriptGreenhouse/threshold.txt | sed '2q;d')" | bc) -eq 1 ]; # TODO in RASPBERRY ADD FULL PATH /home/pi/scriptGreenhouse/
				then
					curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="WATER TEMPERATURE RESTORED"
					flagTemperature=false
					return			
				fi
			done	
		fi
	fi
}

while true
do
	api_connection		# call function
	if  [ $(echo "$airPressureValue>$(cut -f2 /home/pi/scriptGreenhouse/threshold.txt | sed '1q;d')" | bc) -eq 0 ];  # TODO in RASPBERRY ADD FULL PATH /home/pi/scriptGreenhouse/
	then
		if $flagPressure;
		then
			echo "SMS: PRESSURE IS NOT GOOD"
			curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="AIR PRESSURE IS $airPressure UNDER THE THRESHOLD"
			wait_for_restoring "pressure"
		else
			flagPressure=true
		fi

	else

		flagPressure=false
	fi

	if  [ $(echo "$temperatureValue<$(cut -f2 /home/pi/scriptGreenhouse/threshold.txt | sed '2q;d')" | bc) -eq 0 ]; # TODO in RASPBERRY ADD FULL PATH /home/pi/scriptGreenhouse/
	then
		if $flagTemperature;
		then
			# send SMS
			echo "SMS: TEMPERATURE IS NOT GOOD"
			curl -s -X POST $telegramURL -d chat_id=$telegramChatID -d text="WATER TEMPERATURE IS $temperature ABOVE THE THRESHOLD"
			wait_for_restoring "temperature"
		else
			flagTemperature=true
		fi

	else

		flagTemperature=false
	fi
		sleep 5m
		fetch_pressure
		fetch_temperature
		
done
