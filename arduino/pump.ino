#include <Arduino.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#if defined(ESP32)
  #include <WiFi.h>
#elif defined(ESP8266)
  #include <ESP8266WiFi.h> 
#endif
#include <Firebase_ESP_Client.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// Provide the token generation process info.
#include "addons/TokenHelper.h"
// Provide the RTDB payload printing info and other helper functions.
#include "addons/RTDBHelper.h"

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 2

// Setup a oneWire instance to communicate with any OneWire devices (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to Dallas Temperature.
DallasTemperature sensors(&oneWire);

// ACS712 sensor connected to GPIO34
const int ACS712 = 34;
int mVperAmp = 185; // use 185 for 5A Module, 100 for 20A Module and 66 for 30A Module

// Relay pin
#define RELAY_PIN 5

// Insert your network credentials
#define WIFI_SSID "Infinix HOT 20S"
#define WIFI_PASSWORD "medbh95++"

// Insert Firebase project API Key
#define API_KEY "AIzaSyBUXZAJEQa-jirbvMf_MG33Ru7p3ksOs_c"

// Insert RTDB URL
#define DATABASE_URL "https://pompe-6497a-default-rtdb.firebaseio.com/" 

// Define Firebase Data object
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

unsigned long sendDataPrevMillis = 0;
bool signupOK = false;

float maxTemperature = 70.0;
float maxCurrent = 5.0;

void setup(){
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED){
    Serial.print(".");
    delay(300);
  }
  Serial.println();
  Serial.print("Connected with IP: ");
  Serial.println(WiFi.localIP());
  Serial.println();
 
  // Assign the api key (required)
  config.api_key = API_KEY;
  // Assign the RTDB URL (required)
  config.database_url = DATABASE_URL;
  // Sign up
  if (Firebase.signUp(&config, &auth, "", "")){
    Serial.println("ok");
    signupOK = true;
  } else {
    Serial.printf("%s\n", config.signer.signupError.message.c_str());
  }

  // Assign the callback function for the long running token generation task
  config.token_status_callback = tokenStatusCallback; //see addons/TokenHelper.h
  
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Start up the library
  sensors.begin();

  // Initialize the relay pin as an output
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW); // Start with relay off

  // Fetch initial max values from RTDB
  fetchMaxValues();

  FirebaseJson tokensJson;
}

void loop(){
  // Call sensors.requestTemperatures() to issue a global temperature 
  // request to all devices on the bus
  sensors.requestTemperatures(); // Send the command to get temperatures

  // Get the temperature
  float temperature = sensors.getTempCByIndex(0);
  
  // Read the current from the ACS712
  int RawValue = analogRead(ACS712);
  double Voltage = (RawValue / 4095.0) * 5000; // Gets you mV
  double Amps = ((Voltage - 2500) / mVperAmp);

  if (Firebase.ready() && signupOK && (millis() - sendDataPrevMillis > 1000 || sendDataPrevMillis == 0)){
    sendDataPrevMillis = millis();
    
    // Write the temperature on the database path test/temperature
    if (Firebase.RTDB.setFloat(&fbdo, "test/temperature", temperature)){
      Serial.print("Temperature for the device 1 (index 0) is: ");
      Serial.println(temperature, 2);
    } else {
      Serial.println("FAILED");
      Serial.println("REASON: " + fbdo.errorReason());
    }

    // Write the current on the database path test/current
    if (Firebase.RTDB.setFloat(&fbdo, "test/current", Amps)){
      Serial.print("Current for the device 1 (index 0) is: ");
      Serial.println(Amps, 2);
    } else {
      Serial.println("FAILED");
      Serial.println("REASON: " + fbdo.errorReason());
    }

    // Read the pumpstate from the database
    if (Firebase.RTDB.getInt(&fbdo, "test/pumpState")){
      int pumpState = fbdo.intData();
      Serial.print("Pump state is: ");
      Serial.println(pumpState);

      // Control the relay based on the pump state
      if (pumpState == 1){
        digitalWrite(RELAY_PIN, HIGH); // Turn on the relay
      } else {
        digitalWrite(RELAY_PIN, LOW); // Turn off the relay
      }
    } else {
      Serial.println("FAILED to read pumpstate");
      Serial.println("REASON: " + fbdo.errorReason());
    }
  }

  checkScheduleAndControlPump(temperature, Amps);
}

void fetchMaxValues() {
  if (Firebase.RTDB.getFloat(&fbdo, "test/maxTemperature")) {
    maxTemperature = fbdo.floatData();
    Serial.print("Max Temperature is: ");
    Serial.println(maxTemperature);
  } else {
    Serial.println("FAILED to read maxTemperature");
    Serial.println("REASON: " + fbdo.errorReason());
  }

  if (Firebase.RTDB.getFloat(&fbdo, "test/maxCurrent")) {
    maxCurrent = fbdo.floatData();
    Serial.print("Max Current is: ");
    Serial.println(maxCurrent);
  } else {
    Serial.println("FAILED to read maxCurrent");
    Serial.println("REASON: " + fbdo.errorReason());
  }
}

void checkScheduleAndControlPump(float temperature, float current) {
  // Fetch schedules from Firestore
  HTTPClient http;
  http.begin("https://firestore.googleapis.com/v1/projects/pompe-6497a/databases/(default)/documents/schedules"); // Replace YOUR_PROJECT_ID with your actual project ID
  int httpCode = http.GET();

  if (httpCode > 0) {
    String payload = http.getString();
    DynamicJsonDocument doc(1024);
    deserializeJson(doc, payload);

    JsonArray documents = doc["documents"];
    for (JsonObject schedule : documents) {
      bool isActive = schedule["fields"]["active"]["booleanValue"];
      if (!isActive) continue;

      JsonArray days = schedule["fields"]["days"]["arrayValue"]["values"];
      int selectedDuration = schedule["fields"]["selectedDuration"]["integerValue"];
      String startDate = schedule["fields"]["startDate"]["stringValue"];
      String startTime = schedule["fields"]["startTime"]["stringValue"];

      // Check if today is in the schedule days
      String today = getDayOfWeek();
      bool isTodayScheduled = false;
      for (JsonVariant day : days) {
        if (day["stringValue"] == today) {
          isTodayScheduled = true;
          break;
        }
      }
      if (!isTodayScheduled) continue;

      // Check if the current time is within the scheduled time range
      if (isWithinScheduledTime(startDate, startTime, selectedDuration)) {
        // Check temperature and current limits
        if (temperature < maxTemperature && current < maxCurrent) {
          Firebase.RTDB.setInt(&fbdo, "test/pumpState", 1); // Turn on the pump
        } else {
          Firebase.RTDB.setInt(&fbdo, "test/pumpState", 0); // Turn off the pump
        }
      } else {
        Firebase.RTDB.setInt(&fbdo, "test/pumpState", 0); // Turn off the pump
      }
    }
  } else {
    Serial.println("Failed to fetch schedules from Firestore");
  }
  http.end();
}

String getDayOfWeek() {
  time_t now = time(nullptr);
  struct tm *tm_struct = localtime(&now);
  int day = tm_struct->tm_wday;
  switch (day) {
    case 0: return "Sunday";
    case 1: return "Monday";
    case 2: return "Tuesday";
    case 3: return "Wednesday";
    case 4: return "Thursday";
    case 5: return "Friday";
    case 6: return "Saturday";
  }
  return "";
}

bool isWithinScheduledTime(String startDate, String startTime, int durationMinutes) {
  // Parse start date and time
  int year, month, day, hour, minute;
  sscanf(startDate.c_str(), "%d-%d-%dT%d:%d:00", &year, &month, &day, &hour, &minute);

  // Create time structs
  struct tm startStruct = {0};
  startStruct.tm_year = year - 1900;
  startStruct.tm_mon = month - 1;
  startStruct.tm_mday = day;
  startStruct.tm_hour = hour;
  startStruct.tm_min = minute;

  time_t startTimeEpoch = mktime(&startStruct);
  time_t now = time(nullptr);

  // Calculate end time
  time_t endTimeEpoch = startTimeEpoch + durationMinutes * 60;

  return now >= startTimeEpoch && now <= endTimeEpoch;
}
