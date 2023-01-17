#!/bin/sh

############## GLOBAL VARS ##############
RT_FILE="tokens/refresh_token"
AT_FILE="tokens/access_token"
DEBUG=true
#########################################

log() {
	[ $DEBUG == true ] && echo $*
}

############## TOKEN HANDLING #############
# prequisite for this is an existing refresh 
# token, stored in $RT_FILE 
###########################################

#check access_token for expiry and refresh if necessary
check_and_refresh_access_token() {

	if [ -f $AT_FILE ]; then
		ACCESS_TOKEN=$(<$AT_FILE)
		EXP=`echo $ACCESS_TOKEN | sed -e 's/^[^\.]*\.\(.*\)\..*$/\1/' | base64 -d | jq .exp`
		log expire time of token: $EXP

		NOW=`date +%s`
		log current time: $NOW

		DELTA=$[EXP - NOW]
		log seconds remaining: $DELTA
	else
		DELTA=0
	fi

	[ $DELTA -gt 0 ] && log access token still valid, reusing...

	[ $DELTA -le 0 ] && echo access token expired or missing, refreshing... && refresh_access_token
}

#use refresh token to update stored access token after expiry
refresh_access_token() {
	[ ! -f $RT_FILE ] && echo "refresh token file ($RT_FILE) missing. Aborting." && exit 1

	REFRESH_TOKEN=$(<$RT_FILE)
	REFRESH_DATA="{\"grant_type\": \"refresh_token\", \"client_id\": \"ownerapi\", \"refresh_token\": \"$REFRESH_TOKEN\", \"scope\": \"openid email offline_access\" }"
	log sending refresh data: $REFRESH_DATA
	REFRESH_REPLY=`curl -s -X POST -H "content-type: application/json; charset=utf-8" -d "$REFRESH_DATA" https://auth.tesla.com/oauth2/v3/token`
	ACCESS_TOKEN=`echo $REFRESH_REPLY | jq -r .access_token`
	log new access_token: $ACCESS_TOKEN
	echo $ACCESS_TOKEN > $AT_FILE
}

setBatteryTargetSoc() {
	check_and_refresh_access_token
	RESPONSE=`curl -s -X POST -H "Authorization: Bearer $ACCESS_TOKEN" -H "content-type: application/json; charset=utf-8" -d "{\"backup_reserve_percent\":$1}" https://owner-api.teslamotors.com/api/1/energy_sites/$SITE_ID/backup`
	log $RESPONSE
	TESLA_RC=`echo $RESPONSE | jq .response.code`
	[ $TESLA_RC -ne 201 ] && echo Setting TargetSoc failed. Result Code from API is $TESLA_RC. Full API response below: && echo $RESPONSE && return

	# check status to verify update was correct
	RESERVE=`curl -s -H "Authorization: Bearer $ACCESS_TOKEN" -H "content-type: application/json; charset=utf-8" https://owner-api.teslamotors.com/api/1/powerwalls/$PW_ID | jq .response.backup.backup_reserve_percent`
	[ $RESERVE -ne $1 ] && echo Setting TargetSoc failed. Requested $1% but status is $RESERVE% && return
	echo "OK (new reserve reported by API: $RESERVE%)"
}


############ MAIN ###########

[ ! -f ./settings.env ] && echo "missing settings.env file. Please copy the provided settings.env.example and adjust values." && exit 1
. ./settings.env

log "params: $*"

case $1 in
	vehicle_connected)
		echo Vehicle connect detected
		;;
	vehicle_disconnected)
		echo Vehicle disconnect detected
		;;
	charging_started)
		echo Charging started - disabling battery self consumption
		setBatteryTargetSoc 100 # effectively backup only
		;;
	charging_stopped)
		echo Charging stopped - resetting battery backup reserve to $BACKUP_RESERVE_PERCENT%
		setBatteryTargetSoc $BACKUP_RESERVE_PERCENT # reenable battery self consumption
		;;
	*)
		echo Unknown event type
		exit 1
		;;
esac

