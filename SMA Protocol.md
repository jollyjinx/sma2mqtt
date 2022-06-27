# SMA Protocol analysis

I did not find any thorough documentation on the SMA UDP Protocol, so I started analysing the packets. I sent packets to my inverters and looked at the responses. I might have things gotten wrong. If you know the protocol better let me know and I'll add the missing pieces here.

## References:

- [Speedwire Discovery Protocol](https://www.sma.de/fileadmin/content/global/Partner/Documents/sma_developer/SpeedwireDD-TI-en-10.pdf)
- Sunny Home Manger protocol 0x6069 [EMETER-Protokoll-T1-de-10.pdf](https://www.sma.de/fileadmin/content/global/Partner/Documents/SMA_Labs/EMETER-Protokoll-TI-en-10.pdf)
- SBSpot [SBSpot](https://github.com/SBFspot/SBFspot) seems to have a few things correct
- SMA old Protocol [smadat-11-ze2203.pdf](http://test.sma.de/dateien/1995/SMADAT-11-ZE2203.pdf)
- SMA [YASDI](https://www.sma.de/en/products/monitoring-control/yasdi.html)
- Objects http(s)://inverter/data/ObjectMetadata_Istl.json
- Translation http(s)://inverter/data/l10n/en-US.json


## SMA Protocol

Sma Protocol starts with 'SMA\0' and then packets in big-endian order follow.

    addr | type   | explanation
    -----------------------------------
    0x00 | U32    | 0x534D4100 == 'SMA\0'  Magic Number
    0x04 | U16    | length of packet
    0x06 | U16    | Tag     0xABBC   A = 0 , B = Tag ID, C = 0
         |        |         0x0000 = 0x00: End of packets
         |        |         0x0010 = 0x01: SMA Net Version 1
         |        |         0x0200 = 0x20: End of discovery request ?
         |        |         0x02A0 = 0x2A: Discovery Request  
         |        |         0x02C0 = 0x2C: Group number
    0x08 | U8*len | packet content



### End of packets 0x0000

    addr | type   | explanation
    -----------------------------------
    0x00 | U16    | 0x0000 end of transmission



### End of discovery 0x0200


    addr | type   | explanation
    -----------------------------------
    0x00 | U16    | 0x0200 end of discovery request ?



### Discovery Request 0x02a0

Discovery request has 4 bytes of data containing 0xff.
    
    addr | type   | explanation
    -----------------------------------
    0x00 | U32    | 0xFFFF FFFF requesting discovery reply
         |        | 0x0000 0001 normal request


    A full discovery request looks like this:
    
    addr | type   | value       | explanation
    ------------------------------------
    0x00 | U32    | 0x534D4100  | 'SMA\0'  Magic Number
    -----|--------|-------------|-------
    0x04 | U16    | 0x0004      | length of packet
    0x06 | U16    | 0x02a0      | tag ( Discovery Request )
    0x08 | U32    | 0xFFFF FFFF | requesting discovery reply
    -----|--------|-------------|-------
    0x0C | U16    | 0x0000      | length of packet
    0x0E | U16    | 0x0200      | tag ( Discovery End? )
    -----|--------|-------------|-------
    0x10 | U16    | 0x0000      | length of packet
    0x12 | U16    | 0x0000      | tag ( End of packets )


### Group Content 0x02C0

    addr | type   | explanation
    -----------------------------------
    0x00 | U32    |   Group number ( usually 0x0000 0001 )
         |        |                  0xFF03 bluethooth ?


# SMA Net Version 1 0x0010

    addr | type   | explanation
    -----|--------|--------------------
    0x00 | U16    | Protocol ID:    0x6069 Sunny Home Manger
         |        |                 0x6065 Inverter Communication
    0x02 | length | Data


## 0x6069 Protocol: Sunny Home Manger

The information on  the Sunny Home Manger protocol 0x6069 [EMETER-Protokoll-T1-de-10.pdf](https://www.sma.de/fileadmin/content/global/Partner/Documents/SMA_Labs/EMETER-Protokoll-TI-en-10.pdf) is enough to figure it out. 
Exact values I figured out can be found in [Obis.swift](Sources/sma2mqtt/Obis.swift)

    addr | type   | explanation
    -----|--------|--------------------
    0x00 |   U16  |   Source SysID
    0x02 |   U32  |   Source Serial number
    0x06 |   U32  |   Source Time in ms
    0x0A |        |   0x6069 data packets follow:


## 0x6069 data packets (Big Endian)

    addr | type    | explanation
    -----|---------|--------------------
    0x00 |   U32   |   0xAABBCCDD
         |         |   0xAA = Channel id ( default 1)
         |         |   0xBB = 0x01 :
         |         |   0xCC = Kind   0x04 = Current Value    4 Byte length
         |         |               0x0x08 = Counter          8 Byte length
         |         |   0xDD = Tarif: 0x00 = Sum tarif
    0x04 | U32|U64 |           BE: value byte length



## 0x6065 Protocol: Inverter Communication (Little Endian)

Warning this protocol uses little endian format. Requests and responses share the same header format. 
Requests to the inverter send the header followed by a command (e.g. logon, logoff, data request ).
Responses from the inverter have the same header with data then attached (e.g. ac-power values ).

### 0x6065 Protocol Header

    addr |addr | type| explanation
    ----- -----------------------------------
    0x00 | 00 | U8  | Length in 32bit words, to get length in bytes * 4
    0x01 | 01 | U8  | Type        0xA0  1010 0000b    Dest.SysID != 0xF4
         |    |     |             0xE0  1110 0000b    Dest.SysID == 0xF4 == 244 = 1111 0100
         |    |     |                    -X-- ----     0 network address ?
         |    |     |                                  1 group address ?

    0x02 | 02 | U16 | Destination SysID
    0x04 | 04 | U32 | Destination Serial number

    0x08 | 08 | U8  | 0x00                             needs to be 0x00
    0x09 | 09 | U8  | 0x00 sending does not seem to matter except for login
         |    |     |  receiving same value sent except bit 6
         |    |     |  0xA1 1010 0000b
         |    |     |  0xE0 1110 0000b          e0 means failed
         |    |     |       -X-- ----           0 ok, 1, failed


    0x0A | 10 | U16 |  Source SysID           Any: 0xFFFF
    0x0C | 12 | U32 |  Source Serial number   Any: 0xFFFF FFFF

    0x10 | 16 | U16 |  ??ctrl      0x0000              sending 0xA0 0x01 0x03
    0x12 | 18 | U16 |  Result:     0x0000 ok
         |    |     |              0x0002  0000 0010b  incorrect command ?
         |    |     |              0x0014              unkown command ?
         |    |     |              0x0015  0000 1111b  no values 
         |    |     |              0x0017  0001 0001b  not logged in
         |    |     |              0x0102              login not possible (busy)?

    0x14 |    | U16 | Bit 0-14 packet id
         |    |     | bit 15   request / bit 15 needs to be set
         |    |     |          response 0 - fail
         |    |     |                   1 - ok
    



# Requests to Inverter

## login request

    addr | type | explanation
    -----------------------------------
    0x16 | U8   | 0x0C          0000 1100b
    0x17 | U8   | 0x04          0000 0100b
    0x18 | U16  | 0xFFFD        Login
    0x2A | U32  | 0x07 | 0x0A   Usergroup 0x07 = user / 0xA installer
    0x2E | U32  | 0x384         ?? Timeout
    0x32 | U32  | unixtime
    0x36 | U32  | 0x00          ??
    0x3A | U8*12| password characters + 0x88 User / 0xBB Installer


## logout request

    addr | type | explanation
    -----------------------------------
    0x16 | U8   | 0x0C ?0e
    0x17 | U8   | 0x04 ?01
    0x18 | U16  | 0xFFFD      Logout Command
    0x2A | U32  | 0xFFFF FFFF


## command request

Normal commands seem have same size ( position 0x16 - 0x24 )

    addr | type| explanation
    -----------------------------------
    0x16 | U8  | ?? flags maybe usually 0x01 or 0x00
         |     |    flags   0000 0000b
         |     |            ---- ---Xb  0 = request
         |     |                        1 = answer
         |     |            ---- X--0b  8 -> response 9 as if adding one to the request
    0x17 | U8  | ??  send:       seems not to matter except for login
         |     |     response:   usually 02
    0x18 | U16 | Comand Request
    0x1A | U32 | Range Start
    0x20 | U32 | Range End


# Responses from inverter

I've not seen any response from a logout.

    addr | type| explanation
    -----------------------------------
    0x16 | U8  | ?? flags maybe usually 0x01, 0x0C , 0x0D,
         |     |    flags   0000 0000b
         |     |            ---- ---Xb  0 = request
         |     |                        1 = answer
         |     |            ---- X--0b  8 -> response 9 as if adding one to the request
    0x17 | U8  | values seen: 00 , 01 , 02, 04
         |     | 00 packet data directly following address 0x1A
         |     | 01 address 0x1A contains packet count
         |     | 02 address 0x1A contains start , 0x20 contains end
         |     | 04 ?
    0x18 | U16 | Command used in request 
         |     |    0x0000 keep alive ? contains no data option 1 & 2 : 0x0000 0000 & 0x0000 00ff
         |     |                        can contain 56 static bytes as well 
         |     |    0x5180 keep alive ? contains no data option 1 & 2 : 0x0021 4800 and 0x0041 4aff
         |     |    0x2800 special multicast answer ?
         |     |    
         |     |
         |     |
    0x1A | U32 | option 1  (sometimes Range Start)  does 0x4 mean only short numbers are coming ? 
    0x20 | U32 | option 2  (sometimes Range End)
         |     |
    0x24 - End of packet | Array of values 


## 0x2800, 0x6a02,0x71e0 command answer

With these commands the answer seem to differ completly and the packets are very short.

If command is 0x2800 the answers option1 is then 0x500300 and option2 contains some timer counting up - it's not milliseconds.
Maybe it's an answer to a discovery request ? it seems to contain static data but some of the data do change over time but not coherently. There seems to be more noise at the beginning of the packet when the sun is up - so maybe there is sunpower encoded in there.






## Array of values format when not 0x2800

The response data is an array of values of different length just concatinated, starting at offset zero here for easier translation to code.

Value headers:

    addr | type| explanation
    -----------------------------------
    0x00 | U8   |   number (like a string number) 
         |      |   0x00 not seen
         |      |   0x01-0x06 string
         |      |   0x07  number 0x07 no string 
         |      |
    0x01 | U16  |   kind (a number in the range specified by the request)
         |      |
    0x03 | U8   |   data format     0x00 usigned number(s)
         |      |                   0x40 signed number(s)
         |      |                   0x10 zero terminated string
         |      |                   0x08 version number
         |      |                   one caveat it seems that 0x8234 kind contains version numbers
         |      |
    0x04 | U32  |   unix timestamp  usually the timestamp of the request (when the value was calculated)
         |      |                   for aggregated values it's the time of aggregation
         |      |                   aggregation happens usually every 5 minutes
         |      |                   if the timestamp is not 0 or at the current time,
         |      |                   it's the running time in seconds


## Value format 0x00 unsigned number / serial number

### Normal number value format

     addr | type| explanation
    -----------------------------------
    0x08 | U32  |   value1, UInt32Max == NaN
    0x0C | U32  |   value2, UInt32Max == NaN, shortmarker
    0x10 | U32  |   value3, UInt32Max == NaN
    0x14 | U32  |   value4, UInt32Max == NaN
    0x18 | U32  |   value5, long marker  0x0000 0001 for 1 value only. 

    packet is long if longmarker == 1 or all content is zero
    packet is short if its not long and shortmarker = 0

### Serial Number

    addr | type| explanation
    -----------------------------------
    0x08 | U32  |   0
    0x0C | U32  |   0
    0x10 | U32  |   0xFFFF FFFE  | 0xFFFF FED8
    0x14 | U32  |   0xFFFF FFFE  | 0xFFFF FED8
    0x10 | U8   |   Serial Number Type ( 4 = release ) ( none/experimental/alpha/beta/release/special)
    0x11 | U8   |   Serial Number Build Number
    0x12 | U8   |   Serial Number Minor Version
    0x13 | U8   |   Serial Number Major Version
    0x14 | U8*4 |   Serialnumber again 
    0x18 | U32  |   0
    0x1C | U32  |   0

    

## Value format 0x40 signed number

Same format as for unsigned except that values are S32 and test for NaN is Int32Min. 


## Value format 0x10 string

Length 0x24 (40d) bytes.

    addr         | type| explanation
    -----------------------------------
    0x08....0x1C | U8  | String zero terminated

## Value format 0x08 tuple

Length 0x24 (40d) bytes. Contains tuples for requested kind.
Contains tuples (key,value) value pairs of version data appended by 0xffff fffe.

    addr         | type| explanation
    -----------------------------------
    0x08....0x1C | U16 | A: value  
                 | U16 | B: valididation bit5
                 |     |    ---0 ---- invalid
                 |     |    ---1 ---- valid
                 |     | A is valid if bit5 is set in B
                 |     | End of values if A == 00FF && B == FFFE
                 |     |  
                
                A    B    
    Example: 0x1234 0x0100    1234 set as 0x1000
             0x5678 0x0000    5678 not set
             0x8001 0x0100    8001 set
             0x00FF 0xFFFE    end of values
        
    Result: value is: 1234.8001 
    

Real world example: (Type 0x08 like system.mainmodel.1, system.type.1,... )

     SMApacket: length:458 raw:534d 4100 0004 02a0 0000 0001 01b6 0010 6065 6da0 1234 0000 4321 00a1 0011 2233 4455 0001 0000 0000 d489 0102 0058 0100 0000 0a00 0000 011e 8210 4032 1961 7375 6e6e 7962 6f79 3400 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 011f 8208 4032 1961 411f 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0120 8208 4032 1961 b924 0000 ba24 0000 bb24 0001 bc24 0000 bd24 0000 feff ff00 0000 0000 0000 0000 0121 8208 9a39 1661 5902 0001 5b02 0001 5d02 0001 5e02 0001 5f02 0000 6202 0001 6302 0001 6a02 0001 0121 8208 9a39 1661 6f02 0001 7802 0001 7902 0001 7a02 0001 7b02 0001 7c02 0001 7d02 0001 8002 0001 0121 8208 9a39 1661 8102 0001 8702 0001 8802 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0125 8200 4032 1961 0000 0000 0000 0000 d8fe ffff d8fe ffff 1847 0000 1847 0000 0000 0000 0000 0000 0128 8208 8939 1661 2e01 0001 6904 0000 6a04 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 012b 8208 8939 1661 cd01 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0134 8200 a339 1661 0000 0000 0000 0000 feff ffff feff ffff 0424 1003 0424 1003 0000 0000 0000 0000 0000 0000 
    SMApacket: Tag:0x02a0 length:4
    SMApacket: discovery type:0x00000001 NORMAL
    SMApacket: Tag:0x0010 length:438
    SMAPacket: SMAnet tag.
    SMAPacket: SMAnet packet protocol 0x6065 length:438
    SMANet Packet:command:5800 response:0000: source:001122334455 destination:123400004321 pktflg:1 pktid:0x09d4 opt1:0x00000001 opt2:0x0000000a raw:0100 0000 0a00 0000 011e 8210 4032 1961 7375 6e6e 7962 6f79 3400 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 011f 8208 4032 1961 411f 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0120 8208 4032 1961 b924 0000 ba24 0000 bb24 0001 bc24 0000 bd24 0000 feff ff00 0000 0000 0000 0000 0121 8208 9a39 1661 5902 0001 5b02 0001 5d02 0001 5e02 0001 5f02 0000 6202 0001 6302 0001 6a02 0001 0121 8208 9a39 1661 6f02 0001 7802 0001 7902 0001 7a02 0001 7b02 0001 7c02 0001 7d02 0001 8002 0001 0121 8208 9a39 1661 8102 0001 8702 0001 8802 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0125 8200 4032 1961 0000 0000 0000 0000 d8fe ffff d8fe ffff 1847 0000 1847 0000 0000 0000 0000 0000 0128 8208 8939 1661 2e01 0001 6904 0000 6a04 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 012b 8208 8939 1661 cd01 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0134 8200 a339 1661 0000 0000 0000 0000 feff ffff feff ffff 0424 1003 0424 1003 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x821e No:0x01 Type:0x10 2021-08-15T17:26:56               system.name.1                      sunnyboy4 realtype:0x10 len:40 raw: 011e 8210 4032 1961 7375 6e6e 7962 6f79 3400 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x821f No:0x01 Type:0x08 2021-08-15T17:26:56          system.mainmodel.1                         v:8001 realtype:0x08 len:40 raw: 011f 8208 4032 1961 411f 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x8220 No:0x01 Type:0x08 2021-08-15T17:26:56               system.type.1                         v:9403 realtype:0x08 len:40 raw: 0120 8208 4032 1961 b924 0000 ba24 0000 bb24 0001 bc24 0000 bd24 0000 feff ff00 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x8221 No:0x01 Type:0x08 2021-08-13T11:21:30        type.unkown.0x8221.1 v:0601.0603.0605.0606.0610.0611 realtype:0x08 len:40 raw: 0121 8208 9a39 1661 5902 0001 5b02 0001 5d02 0001 5e02 0001 5f02 0000 6202 0001 6302 0001 6a02 0001 
    001122334455 Code:0x5800-0x8221 No:0x01 Type:0x08 2021-08-13T11:21:30        type.unkown.0x8221.1 v:0623.0632.0633.0634.0635.0636.0637 realtype:0x08 len:40 raw: 0121 8208 9a39 1661 6f02 0001 7802 0001 7902 0001 7a02 0001 7b02 0001 7c02 0001 7d02 0001 8002 0001 
    001122334455 Code:0x5800-0x8221 No:0x01 Type:0x08 2021-08-13T11:21:30        type.unkown.0x8221.1               v:0641.0647.0648 realtype:0x08 len:40 raw: 0121 8208 9a39 1661 8102 0001 8702 0001 8802 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x8225 No:0x01 Type:0x00 2021-08-15T17:26:56        type.unkown.0x8225.1                      0:0:71:24 realtype:0x00 len:40 raw: 0125 8200 4032 1961 0000 0000 0000 0000 d8fe ffff d8fe ffff 1847 0000 1847 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x8228 No:0x01 Type:0x08 2021-08-13T11:21:13        type.unkown.0x8228.1                         v:0302 realtype:0x08 len:40 raw: 0128 8208 8939 1661 2e01 0001 6904 0000 6a04 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x822b No:0x01 Type:0x08 2021-08-13T11:21:13        type.unkown.0x822b.1                         v:0461 realtype:0x08 len:40 raw: 012b 8208 8939 1661 cd01 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 
    001122334455 Code:0x5800-0x8234 No:0x01 Type:0x00 2021-08-13T11:21:39    system.softwareversion.1                      3:16:36:4 realtype:0x00 len:40 raw: 0134 8200 a339 1661 0000 0000 0000 0000 feff ffff feff ffff 0424 1003 0424 1003 0000 0000 0000 0000 

