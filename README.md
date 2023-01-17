# powerwall-backupCtrl
Shell script to control Tesla Powerwall backup percentage.

My primary use case for the script is to hook it into [EVCC](https://evcc.io) as a [script eventhandler](https://docs.evcc.io/docs/reference/configuration/messaging#script).
On start charging events, the script will set the backup reserve of the Powerwall to 100%.
On stop charging events, the script will reset the backup reserve of the Powerwall to a configurable value (default 30%).

My motivation for doing so, is to prevent the powerwall to be drained by the EV charging, which especially in Winter tends to be the case.
I know there's different opinions on wether this makes sense. I am in the camp that I don't think it is meaningful to transfer energy from one battery to the other. Decide yourself.

## How to use

### Prequisites
The script employs the Cloud API of Tesla to adjust the backup reserve percentage.
To access said API you need to provide your ephemeral ***refresh*** token. Obtaining the token
is somewhat involved. The easiest way I have found was to use the script ```get_token.py``` provided by [Marky0/tesla_api_lite](https://github.com/Marky0/tesla_api_lite)

Alternatively you can also log into the Tesla portal in your browser and extract
the token from the cookies. #hackerman

The above step is only required once.
The script will automatically fetch access tokens as needed with the provided refresh token.
Access tokens are cached and reused until expiry.

### Configuration
Copy the provided ```settings.env.example``` to ```settings.env``` and adjust the values specific to your powerwall setup.
The script can support you in getting your ```SITE_ID``` and ```PW_ID``` values, by fetching them from the Tesla API.
To do so, simply call the script with ```getTeslaIds``` as first parameter.

Note that the logic for extracting the IDs is stupid, as it only considers the first site and battery in the response.
If you operate multiple sites (or more than a single powerwall in a single site) you will have to inspect the reply yourself for the ids.

### EVCC configuation
The script is acting based on it's first parameter, which maps to the title attribute in the EVCC messages configuration. 
The supported events are
- vehicle_connected
- vehicle_disconnected
- charging_started
- charging_stopped

(Vehicle connection events are currently no-ops.)

To integrate into EVCC, add the following configuration section to your evcc.yaml.

```
messaging:
  events:
    start:
      title: charging_started
      msg: Wallbox ${title} started charging in ${mode} mode
    stop:
      title: charging_stopped
      msg: Wallbox ${title} finished charging with ${chargedEnergy:%.1fk}kWh in ${chargeDuration}
    connect:
      title: vehicle_connected
      msg: connected on wallbox ${title} at ${pvPower:%.1fk}kW PV
    disconnect:
     title: vehicle_disconnected
     msg: disconnected of wallbox ${title} after ${connectedDuration}

  services:
  - type: script
    cmdline: /root/scripts/eventHandler.sh
    timeout: 30s
```

Please note the cmdline at the end of the above example. It needs to be ajdusted to point to your local copy of the script where evcc can call it.

### Troubleshooting
If you run into trouble, there's a debug variable in the script. Setting it to ```true``` will show API responses as received from the cloud.
Note that the debug output also contains your access and refresh tokens, so be mindful if sharing the debug output with anyone.
