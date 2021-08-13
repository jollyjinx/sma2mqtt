# SMA Protocol analysis

I did not find any thorough documentation on the SMA UDP Protocol, so I started analysing the packetes. I sent packets to my inverters and looked at the responses. I might have things gotten wrong. If you the protocol better let me know and I'll add the missing pieces here.

## References:

- Sunny Home Manger protocol 0x6069 [EMETER-Protokoll-T1-de-10.pdf](https://www.sma.de/fileadmin/content/global/Partner/Documents/SMA_Labs/EMETER-Protokoll-TI-en-10.pdf)
- SBSpot [SBSpot](https://github.com/SBFspot/SBFspot) seems to have a lot of things wrong
- SMA old Protocol [smadat-11-ze2203.pdf](http://test.sma.de/dateien/1995/SMADAT-11-ZE2203.pdf)
- SMA [YASDI](https://www.sma.de/en/products/monitoring-control/yasdi.html)

## SMA Protocol

Sma Protocol starts with 'SMA\0' and then packets follow.

addr | type   | explanation
-----------------------------------
0x00 | U32    | 0x534D4100 == 'SMA\0'  Magic Number
0x04 | U16    | length of packet
0x06 | U16    | Tag     0xABBC   A = 0 , B = Tag ID, C = 0
     |        |         0x02C0 = 0x2C: Group number
     |        |         0x0010 = 0x01: SMA Net Version 1
     |        |         0x0000 = 0x00: End of packet
0x08 | U8*len | packet content



Group Content
=============

0x00  4           BE:     Group number ( usually 0x0000 0001 )
                                            0xFF03 bluethooth ?

SMA Net Version 1 Content
===============
0000    2           BE:             Protocol ID:    0x6069 Sunny Home Manger
                                                    0x6065 Inverter Communication
0002 -  length       Protocol Content


## 0x6069 Protocol: Sunny Home Manger

0000    U16     Source SysID
0002    U32     Source Serial number
0006    U32     Source Time in ms

000A    - 0x6069 Packets follow:
0000    U32     0xAABBCCDD
                        AA = Channel id ( default 1)
                        BB = 0x01 :
                        CC = Kind   0x04 = Current Value    4 Byte length
                                    0x08 = Counter          8 Byte length
                        DD = Tarif: 0x00 = Sum tarif
0004    4 | 8           BE: value byte length


## 0x6065 Protocol: Inverter Communication
=========================================

Warning this protocol uses little endian format. It has a header followed by one command.

### Header

addr | type| explanation
-----------------------------------
0x00 | U8  | Length in 32bit words, to get length in bytes * 4
0x01 | U8  | Type        0xA0  1010 0000b    Dest.SysID != 0xF4
     |     |             0xE0  1110 0000b    Dest.SysID == 0xF4 // 244 = 1111 0100
     |     |                    -X-- ----     0 network address ?
     |     |                                  1 group address ?

0x02 | U16 | Source SysID
0x04 | U32 | Source Serial number

0x08 | U8  | 0x00                        needs to be 0x00
0x09 | U8  | 0x00 sending does not seem to matter except for login
     |     |  receiving same value sent except bit 6
     |     |  0xA1 1010 0000b
     |     |  0xE0 1110 0000b          e0 means failed
     |     |       -X-- ----           0 ok, 1, failed


0x0A | U16 |  Destination SysID           Any: 0xFFFF
0x0C | U32 |  Destination Serial number   Any: 0xFFFF FFFF

0x10 | U16 |  ??ctrl      0x0000          sending 0xA0 0x01 0x03
0x12 | U16 |  Result:     0x0000 ok
     |     |              0x0002  0000 0010b  incorrect command ?
     |     |              0x0014              unkown command ?
     |     |              0x0015  0000 1111b  no values
     |     |              0x0017  0001 1111b  not logged in

0x14 | U16 | Bit 0-14 packet id
     |     | bit 15   request / bit 15 needs to be set
     |     |          response 0 - fail
     |     |                    1 - ok


### Request login

addr | type | explanation
-----------------------------------
0x16 | U8   | 0x0C
0x17 | U8   | 0x04
0x18 | U16  | 0xFFFD        Login
0x2A | U32  | 0x07 | 0x0A   Usergroup 0x07 = user / 0xA installer
0x2E | U32  | 0x384         ?? Timeout
0x32 | U32  | unixtime
0x36 | U32  | 0x00          ??
0x3A | U8*12| password characters + 0x88 User / 0xBB Installer


### Request logout

addr | type | explanation
-----------------------------------
0x16 | U8   | 0x0C ?0e
0x17 | U8   | 0x04 ?01
0x18 | U16  | 0xFFFD      Logout Command
0x2A | U32  | 0xFFFF FFFF


### Other Requests

Other commands seem have same size ( 0x16 - 0x25 )

addr | type| explanation
-----------------------------------
0x16 | U8  | ?? flags maybe usually 0x01 or 0x00
     |     |    flags   0000 0000b
     |     |            ---- ---Xb  0 = request
     |     |                        1 = answer
     |     |            ---- X--0b  8 -> response 9 as if adding one to the request
0x17 | U8  | ??  send:       seems not to matter except for login
     |     |     response:   usually 02
0x18 | U16 | Requests
0x1A | U32 | option 1  / Range Start
0x20 | U32 | option 2  / Range End


### Responses



