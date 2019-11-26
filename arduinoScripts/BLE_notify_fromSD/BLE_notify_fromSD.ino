/*
    Video: https://www.youtube.com/watch?v=oCMOYS71NIU
    Based on Neil Kolban example for IDF: https://github.com/nkolban/esp32-snippets/blob/master/cpp_utils/tests/BLE%20Tests/SampleNotify.cpp
    Ported to Arduino ESP32 by Evandro Copercini
    updated by chegewara

   Create a BLE server that, once we receive a connection, will send periodic notifications.
   The service advertises itself as: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
   And has a characteristic of: beb5483e-36e1-4688-b7f5-ea07361b26a8

   The design of creating the BLE server is:
   1. Create a BLE Server
   2. Create a BLE Service
   3. Create a BLE Characteristic on the Service
   4. Create a BLE Descriptor on the characteristic
   5. Start the service.
   6. Start advertising.

   A connect hander associated with the server starts a background task that performs notification
   every couple of seconds.
*/
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

/*Features added on March 28 to enable SD card reading
capabilities. */
#include <SPI.h>
#include <SD.h>
File myFile;
const int buff_size = 1024;
byte buff[buff_size];
int cnt = 0;




//Bluetooth related variables
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
uint32_t value = 0;  //2 ECG samples are stored on value prior to transmission
const byte value_bytes = 4; //Number of bytes to store on 'value' (32 bits = 4bytes)
byte bytes_cnt = 0;  //Keeps the count of bytes stored on 'value'


// See the following for generating UUIDs:
// https://www.uuidgenerator.net/

//#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
//#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

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
  Serial.begin(9600);  //115200
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
  //New code
  //On first connection, start reading from SD card
  if (deviceConnected){
    Serial.print("Initializing SD card...");
    if (!SD.begin(5)) {  //(!SD.begin(4)
      Serial.println("initialization failed!");
      while (1);
    }
    Serial.println("initialization done.");
    myFile = SD.open("/221.txt"); //116.txt
    if (myFile) {
      Serial.println("file successfully opened!");
      int readed_value;
      // read from the file until there's nothing else in it:
      while (myFile.available()) {
        buff[cnt] = myFile.read();
        bytes_cnt++;
        //If 2 samples has been read, pack then on 'value'
        //and notify the BT client
        if(bytes_cnt==value_bytes){ 
          //value = 0;
          value = (int)buff[cnt-3];
          for(int i=value_bytes-2; i>=0; i--){
            value = value*256+(int)buff[cnt-i];
          }
          checkStatusNotify(); //Notify changes on 'value'
          
          bytes_cnt = 0;
          value = 0;
        }
        /*
        if(cnt%2){ 
          readed_value = 0;
          readed_value = (int)buff[cnt-1];
          readed_value = value*256+(int)buff[cnt];
          Serial.println(readed_value);
        }
        */
        if(cnt==buff_size-1){
          cnt=0;
        }
        else{
          cnt++;
        }
        //delay(1);
      }
      // close the file:
      myFile.close();
    } else {
      // if the file didn't open, print an error:
      Serial.println("error opening test.txt");
    }
  }
  Serial.println("End of Setup reached");
}

void checkStatusNotify() {
    // notify changed value
    if (deviceConnected) {
        pCharacteristic->setValue((uint8_t*)&value, 4);
        pCharacteristic->notify();
        //value++;
        //Serial.println(value >> 16);
        //Serial.println(value & 0x0000FFFF);
        delay(6); // bluetooth stack will go into congestion, if too many packets are sent, in 6 hours test i was able to go as low as 3ms
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

void loop() {

}
