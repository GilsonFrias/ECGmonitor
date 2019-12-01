/*
Based on the BLE libraries available on Espressif's github
repository: https://github.com/espressif/arduino-esp32/tree/master/libraries/BLE
More specifically, the BLE_server example by Neil Kolban and chegewara: https://github.com/espressif/arduino-esp32/blob/master/libraries/BLE/examples/BLE_server/BLE_server.ino
and the BLE_notify example by Neil Kolban, Evandro Copercini and chegewara: https://github.com/espressif/arduino-esp32/blob/master/libraries/BLE/examples/BLE_notify/BLE_notify.ino
*/
/*
ECG samples are read from the ESP32's flash memory and then decompressed and notified to the central BT device.
Samples are streamed at around 330 Hz. 
*/

#include "FS.h"
#include "SPIFFS.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define FORMAT_SPIFFS_IF_FAILED true



const int buff_size = 1024;
byte buff[buff_size];
unsigned int cnt = 0;
byte tmp = 0;

//Bluetooth related variables
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
uint32_t value = 0;  //2 ECG samples are stored on value prior to transmission
const byte value_bytes = 4; //Number of bytes to store on 'value' (32 bits = 4bytes)
byte bytes_cnt = 0;  //Keeps the count of bytes stored on 'value'


void checkStatusNotify() {
    // notify changed value
    if (deviceConnected) {
        pCharacteristic->setValue((uint8_t*)&value, 4);
        pCharacteristic->notify();
        //value++;
        //Serial.println(value >> 16);
        //Serial.println(value & 0x0000FFFF);
        delay(6); 
    }
    // disconnecting
    if (!deviceConnected && oldDeviceConnected) {
        delay(500); // give the bluetooth stack the chance to get things ready
        pServer->startAdvertising(); // restart advertising
        Serial.println("start advertising");
        oldDeviceConnected = deviceConnected;
    }
    // connecting
    if (deviceConnected && !oldDeviceConnected) {
        // do stuff here on connecting
        oldDeviceConnected = deviceConnected;
    }
}

void listDir(fs::FS &fs, const char * dirname, uint8_t levels){
    Serial.printf("Listing directory: %s\r\n", dirname);

    File root = fs.open(dirname);
    if(!root){
        Serial.println("- failed to open directory");
        return;
    }
    if(!root.isDirectory()){
        Serial.println(" - not a directory");
        return;
    }

    File file = root.openNextFile();
    while(file){
        if(file.isDirectory()){
            Serial.print("  DIR : ");
            Serial.println(file.name());
            if(levels){
                listDir(fs, file.name(), levels -1);
            }
        } else {
            Serial.print("  FILE: ");
            Serial.print(file.name());
            Serial.print("\tSIZE: ");
            Serial.println(file.size());
        }
        file = root.openNextFile();
    }
}

void readFile(fs::FS &fs, const char * path){
    Serial.printf("Reading file: %s\r\n", path);

    File file = fs.open(path);
    if(!file || file.isDirectory()){
        Serial.println("- failed to open file for reading");
        return;
    }

    Serial.println("- read from file:");
    while(file.available()){
        //Serial.write(file.read());
        //buff[cnt] = file.read();
        //bytes_cnt++;
        //Serial.println("cnt:");
        //Serial.println(cnt);
        //Serial.println(cnt%2); 
        Serial.println("*****");
        if(bytes_cnt%2==0){
          buff[cnt+1] = file.read();
          Serial.println(buff[cnt+1]);
          //buff[cnt] = file.read();
        }else{
          tmp = file.read();
          Serial.println("tmp:");
          Serial.println(tmp);
          buff[cnt-1] = tmp >> 5;
          buff[cnt+1] = tmp & 0x07;
          //buff[cnt] = tmp >> 5;
          //buff[cnt+2] = tmp & 0x07;
          Serial.println(buff[cnt-1]);
          Serial.println(buff[cnt+1]);
        }
        //delay(500);
        bytes_cnt++;  
        //If 2 samples have been read, pack then on 'value'
        //and notify the BT client
        if(bytes_cnt==value_bytes-1){ 
          //value = 0;
          cnt++;
          value = (int)buff[cnt-3];
          for(int i=value_bytes-2; i>=0; i--){
            value = value*256+(int)buff[cnt-i];
          }
          Serial.println("sample 1:");
          Serial.println((value & 0xFFFF0000)>>16);
          Serial.println("sample 2:");
          Serial.println(value & 0x0000FFFF);
          Serial.println("value: ");
          Serial.println(value);
          checkStatusNotify(); //Notify changes on 'value'
          bytes_cnt = 0;
          value = 0;
        }
        if(cnt==buff_size-1){
          cnt=0;
        }
        else{
          cnt++;
        }
        //delay(1);
      }
}

void deleteFile(fs::FS &fs, const char * path){
    Serial.printf("Deleting file: %s\r\n", path);
    if(fs.remove(path)){
        Serial.println("- file deleted");
    } else {
        Serial.println("- delete failed");
    }
}

//Heart Rate UUIDs
#define HR_SERVICE_UUID                    "0000180D-4d5f-11e9-8646-d663bd873d93"
#define HR_MEASUREMENT_CHARACTERISTIC_UUID "00002A37-4d5f-11e9-8646-d663bd873d93"


class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  delay(5000);
  //Bluetooth configuration
  pinMode(5, OUTPUT); //VSPI SS
  // Create the BLE Device
  BLEDevice::init("ESP32");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(HR_SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      HR_MEASUREMENT_CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  // https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.descriptor.gatt.client_characteristic_configuration.xml
  // Create a BLE Descriptor
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(HR_SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);  // set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  //delay(3000);
  while(!deviceConnected){
    //digitalWrite(5, HIGH);
    delay(250);
    //digitalWrite(5, LOW);
    Serial.println("Waiting a client connection to notify...");
    //delay(250); //delete after pilot test
  }
  //Read ECG data from flash memory
  Serial.println("start");
  if (deviceConnected){
     if(!SPIFFS.begin(FORMAT_SPIFFS_IF_FAILED)){
        Serial.println("SPIFFS did not mount!");
        return;
     }
     Serial.println("File found!");
     //delay(2000);
     listDir(SPIFFS, "/", 0);
     readFile(SPIFFS, "/221C.txt");
     //deleteFile(SPIFFS, "/test.txt");
  }
}

void loop() {
  // put your main code here, to run repeatedly:
  delay(1000);
  Serial.println("*");
}
