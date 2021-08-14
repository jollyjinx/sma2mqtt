# SMA Protocol analysis

I did not find any thorough documentation on the SMA UDP Protocol, so I started analysing the packets. I sent packets to my inverters and looked at the responses. I might have things gotten wrong. If you know the protocol better let me know and I'll add the missing pieces here.

## References:

- Sunny Home Manger protocol 0x6069 [EMETER-Protokoll-T1-de-10.pdf](https://www.sma.de/fileadmin/content/global/Partner/Documents/SMA_Labs/EMETER-Protokoll-TI-en-10.pdf)
- SBSpot [SBSpot](https://github.com/SBFspot/SBFspot) seems to have a few things correct
- SMA old Protocol [smadat-11-ze2203.pdf](http://test.sma.de/dateien/1995/SMADAT-11-ZE2203.pdf)
- SMA [YASDI](https://www.sma.de/en/products/monitoring-control/yasdi.html)

## SMA Protocol

Sma Protocol starts with 'SMA\0' and then packets in big-endian order follow.

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

    addr | type   | explanation
    -----------------------------------
    0x00 | U32    |   Group number ( usually 0x0000 0001 )
         |        |                  0xFF03 bluethooth ?

SMA Net Version 1 Content
===============

    addr | type   | explanation
    -----|--------|--------------------
    0x00 | U16    |       Protocol ID:    0x6069 Sunny Home Manger
         |        |                       0x6065 Inverter Communication
    0x02 | length |     Data


## 0x6069 Protocol: Sunny Home Manger

    addr | type   | explanation
    -----|--------|--------------------
    0x00 |   U16  |   Source SysID
    0x02 |   U32  |   Source Serial number
    0x06 |   U32  |   Source Time in ms
    0x0A |        |   0x6069 data packets follow:

## 0x069 data packets

    addr | type    | explanation
    -----|---------|--------------------
    0x00 |   U32   |   0xAABBCCDD
         |         |   0xAA = Channel id ( default 1)
         |         |   0xBB = 0x01 :
         |         |   0xCC = Kind   0x04 = Current Value    4 Byte length
         |         |               0x0x08 = Counter          8 Byte length
         |         |   0xDD = Tarif: 0x00 = Sum tarif
    0x04 | U32|U64 |           BE: value byte length


## 0x6065 Protocol: Inverter Communication
=========================================

Warning this protocol uses little endian format. Requests and responses share the same header format. 
Requests to the inverter send the header followed by a command (e.g. logon, logoff, data request ).
Responses from the inverter have the same header with data then attached (e.g. ac-power values ).

### 0x6065 Protocol Header

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

    0x10 | U16 |  ??ctrl      0x0000              sending 0xA0 0x01 0x03
    0x12 | U16 |  Result:     0x0000 ok
         |     |              0x0002  0000 0010b  incorrect command ?
         |     |              0x0014              unkown command ?
         |     |              0x0015  0000 1111b  no values
         |     |              0x0017  0001 1111b  not logged in
         |     |              0x0102              login not possible (busy)?

    0x14 | U16 | Bit 0-14 packet id
         |     | bit 15   request / bit 15 needs to be set
         |     |          response 0 - fail
         |     |                    1 - ok


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
    0x16 | U8  | ?? flags maybe usually 0x01
         |     |    flags   0000 0000b
         |     |            ---- ---Xb  0 = request
         |     |                        1 = answer
         |     |            ---- X--0b  8 -> response 9 as if adding one to the request
    0x17 | U8  | ?? usually 02
    0x18 | U16 | Command used
    0x1A | U32 | option 1  / Range Start
    0x20 | U32 | option 2  / Range End
    0x24 - End of packet | Array of values 


## Array of values format

The response data is an array of values of different length just concatinated, starting at offset zero here for easier translation to code.

## Value header

    addr | type| explanation
    -----------------------------------
    0x00 | U8   |   number
    0x01 | U16  |   kind (a number in the range specified by the request)
    0x03 | U8   |   data format     0x00 usigned number(s)
         |      |                   0x40 signed number(s)
         |      |                   0x10 zero terminated string
         |      |                   0x08 version number
         |      |                   one caveat it seems that 0x8234 kind contains version numbers
    0x04 | U32  |   unix timestamp


## Value format 0x00 unsigned number

Length 0x10 (16d) or 0x20 (24d) bytes. Can either contain one value or multiple values.

     addr | type| explanation
    -----------------------------------
    0x08 | U32  |   value1, UInt32Max == NaN
    0x0C | U32  |   value2, UInt32Max == NaN
    optional values3 and value4
    0x10 | U32  |   value3, UInt32Max == NaN
    0x14 | U32  |   value4, UInt32Max == NaN
    0x18 | U32  |   0x0000 0001 marker for 4 values


## Value format 0x40 signed number

Same format as for unsigned except that values are S32 and test for NaN is Int32Min


## Value format 0x10 string

Length 0x24 (40d) bytes.

    addr | type| explanation
    -----------------------------------
    0x08....0x1C | U8  | String zero terminated

## Value format 0x08 version

Length 0x24 (40d) bytes. Contains the version for requested kind.
Contains key value pairs of version data appended by 0xffff fffe.
