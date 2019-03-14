ruleset manage_sensors {
  meta {
    shares __testing, sensors, getTemps
    use module io.picolabs.lesson_keys
    use module io.picolabs.subscription alias subscriptions
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    
    threshold = 75
    smsNumber = "17072801566"
    location = "Provo, UT"
    
    sensors = function() {
      //ent:sensors
      subscriptions:established().filter(function(sub){sub["Tx_role"] == "sensor"})
    }
    
    getTemps = function() {
      subscriptions:established().filter(function(sub){sub["Tx_role"] == "sensor"}).map(function(sub){Wrangler:skyQuery(sub["Tx"],"temperature_store", "temperatures")})
    }
    
    
  }
  
  
  rule create_sensor {
    select when sensor new_sensor
    pre {
      name = event:attrs["sensor_name"]
      exists = ent:sensors >< name
    }
    if not exists
    then
      noop()
    fired {
      raise wrangler event "child_creation"
      attributes { "name": name,
                   "color": "#ffff00",
                   "rids": ["temperature_store", "wovyn_base", "sensor_profile"] }
    }
  }
  
  rule install_sensor {
    select when wrangler child_initialized
    pre {
      the_sensor = {"id": event:attrs["id"], "eci": event:attrs["eci"]}
      sensor_name = event:attrs["rs_attrs"]["name"]
    }
    if sensor_name.klog("Created new sensor: ")
    then 
      event:send({ "eci" : the_sensor["eci"], "eid" : "profile_updated", "domain": "sensor", "type": "profile_updated", "attrs" : { "smsNumber" : smsNumber, "sensorLocation" : location, "sensorName": sensor_name, "threshold" : threshold }});
    fired {
      raise wrangler event "subscription" attributes {
        "name" : sensor_name,
        "Rx_role": "manager",
        "Tx_role": "sensor",
        "Tx_host": meta:host,
        "channel_type": "subscription",
        "wellKnown_Tx" : the_sensor{"eci"}
      };
       ent:sensors := ent:sensors.defaultsTo({});
       ent:sensors{[sensor_name]} := the_sensor;
       the_sensor{"eci"}.klog("Subrequest sent: ")
    }
  }
  
  rule register_sensor {
    select when wrangler subscription_added
    pre {
      sensor_name = event:attrs["name"]
      sensor_tx = event:attrs["wellKnown_Tx"]
    }
    fired {
      ent:subs := ent:subs.defaultsTo({});
      ent:subs{[sensor_name]} := sensor_tx.klog("New Subscription added!!! ");
    }
  }
  
  rule threshold_notification {
    select when sensor threshold_violation
    pre {
      to = event:attrs["to"]
      from = event:attrs["from"]
      message = event:attrs["message"]
    }
    twilio:send_sms(to, from, message)
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attrs["sensor_name"]
      exists = ent:sensors >< name
    }
    if exists then 
      send_directive("Removing sensor", {"sensor_name" : name})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name" : name};
      clear ent:sensors{[name]};
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
}
