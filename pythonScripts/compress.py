'''
By Gilson Frías, Nov. 30 2019. 
Script for compressing 11 bit resolution ECG signals. In order to be able to fit
in the 30 minutes ECG recording into the ESP32 memory flash memory, this script 
reduces the record size by 25% by storing the Most Significant Byte of two contiguous
samples in one shared byte. 

------ Uncompressed samples representation ------
                 ('*' signify )

    SampleA Byte1           SampleA Byte0
[* * * * * A10 A9 A8]   [A7 A6 A5 A4 A3 A2 A1 A0]

    SampleB Byte1           SampleB Byte0
[* * * * * B10 B9 B8]   [B7 B6 B5 B4 B3 B2 B1 B0]

------- Compressed samples representation -------
SharedByte = (SampleA Byte1) << 5 +  (SampleB Byte1)

    Sample A Byte 0                 SharedByte                Sample B Byte 0
[A7 A6 A5 A4 A3 A2 A1 A0]   [A10 A9 A8 0 0 B10 B9 B8]    [B7 B6 B5 B4 B3 B2 B1 B0]

'''

import numpy as np
import wfdb #Waveform database package

def packBytes(narray):
    packed = []
    buff = ''
    tmp = 0
    for n in range(len(narray)):
        value = narray[n]
        #Get 3 most significant bits
        msb = bin((value >> 8) & 0xFF) 
        if len(msb)<5:
            #pad with zeroes
            msb = '0'*(5-len(msb))+msb[2:] 
        else:
            msb = msb[-3:]
        #print("parsed: "+msb)
        if n%2:
            #Store 3 most significant bits
            buff = buff + "00" + msb
            #print(buff)
            packed.append(int(buff, 2))
            packed.append(value)
        else:
            #Store 8 less significant bits
            packed.append(value & 0xFF) 
            #tmp = value >> (8) & 0xff
            if(n==len(narray)-1):
                packed.append(int(msb+"00000", 2))
            buff = msb 
            #print("buffer without parsing: "+bin((value >> 8) & 0xff))
            #print("buffer after parsing: "+buff)
    return np.array(packed, dtype='uint8')

#Save array to binary file
def saveBinaryFile(file_name, darray):
    file_name = file_name + '.txt'
    fh = open(file_name, "bw")
    darray.tofile(fh, format="%08b")

if __name__ == "__main__" :
    # Read ECG record data. Each sample is given in 
    #a 'int16' data type holding the corresponding decimal value 
    #stored on the 11 bits register of the ADC register. 
    record = 221
    digital_record = wfdb.rdrecord(str(record), physical=False, return_res=16)

    #Get np array containing digital signal
    d_signal = digital_record.d_signal

    #Choose one of the channels 
    channel = 0
    signal = d_signal[:, channel].astype('uint16')

    #Compress signal
    arr = packBytes(signal)

    #Save binary file
    saveBinaryFile(str(record)+"C", arr)