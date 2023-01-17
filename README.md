# powerwall-backupCtrl
Shell script to control Tesla Powerwall backup percentage.

My primary use case for the script is to hook it into evcc.io as an eventhandler.
Doing so allows to prevent the powerwall to be drained by the EV charging.
(I know there's different opinions on wether this makes sense. Decide yourself.)

## How to use

### Prequisites
The script employs the Cloud API of Tesla to adjust the backup reserve percentage.
To access said API you need to provide your refresh token. Obtaining the token
is somewhat involved. The easiest way I have found was to use the script in 

https://github.com/Marky0/tesla_api_lite

Alternatively you can also log into the Tesla portal in your browser and extract
the token from the cookies. 

### Configuration
Copy the provided settings.env.example to settings.env and adjust the values specific to your powerwall setup.
The script can support you in getting your SITE_ID and PW_ID values, by fetching them from the Tesla API.
To do so, simply call the script with "getTeslaIds" as parameter.
Note that the logic for extracting value is stupid, as it only considers the first site and battery in the response.
If you operate multiple sites (or more than a single PW in a site) you will have to inspect the reply yourself for the ids.

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
