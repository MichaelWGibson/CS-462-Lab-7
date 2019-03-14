ruleset sensor_profile {
  meta {
    
    shares  smsNumber, sensorLocation, sensorName, threshold
    provide smsNumber, sensorLocation, sensorName, threshold
  }
  global {
    smsNumber  = function() {
      {"smsNumber" :ent:smsNumber.defaultsTo("0000000000")}
    }
    
    sensorLocation  = function() {
      {"sensorLocation" : ent:sensorLocation.defaultsTo("Provo")}
    }
    
    sensorName  = function() {
      {"sensorName" : ent:sensorName.defaultsTo("new Sensor") }
    }
    
    threshold  = function() {
      {"threshold" : ent:threshold.defaultsTo(75) }
    }
    
  }
 
  rule profile_updated {
    select when sensor profile_updated
    pre {
      smsNumber = event:attrs["smsNumber"]
      sensorLocation = event:attrs["sensorLocation"]
      sensorName = event:attrs["sensorName"]
      threshold = event:attrs["threshold"]
    }
    
    always {
      ent:smsNumber := smsNumber;
      ent:sensorLocation := sensorLocation;
      ent:sensorName := sensorName;
      ent:threshold := threshold;
    }
  }
  
  rule accept_subscriptions {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }
  
}