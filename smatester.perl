#!/usr/bin/perl
#
# author:   @jollyjinx (Patrick Stein)
# purpose:  trying to figure out the udp based sma inverter protocol
#

use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin","$FindBin::Bin/JNX";
use utf8;
use IO::Socket::INET;
use POSIX;
use Data::Dumper;
use Net::MQTT::Simple;
use Time::HiRes qw ( time alarm sleep );

use constant USER_TYPE_ADMIN        => 0xBB;
use constant USER_TYPE_USER         => 0x88;
use constant MAXIMUM_PACKET_SIZE    => scalar 90000;
use constant TIMEOUT_RECEIVE        => scalar 2;

# perl smatester.perl Temp/Reverseengineering/sb4.out |perl -ne 'print "$2  $4$3  $5  $9$8$7$6 $10\n" if /(len:\d+ raw: (..)(..) (..)(..) (..)(..) (..)(..) (.*))/'  |perl -ne 'if( /^\S\S  (\S\S\S\S)  / ){ $v=$1;$l=length($_); print "Match: $l $v $_"; if( exists($p{$v}{l}) && $p{$v}{l} != $l){ print "$l != $p{$v}{l}\n\t$p{$v}{v}\t$_";} $p{$v}{l} = $l;$p{$v}{v} = $_;}' |grep -v Match |grep -v ' != ' |sort -u -k 2
my $mqttsender = undef;

if( @ARGV == 1 )
{
    dumpFile(@ARGV);
    exit;
}
die "Usage $0 <inputfilename> or <inverter host> <password> [outputfilename]\n" unless @ARGV >= 2;

my ($hostname,$password,$filename) = @ARGV;
my $portnumber = 9522;
my $usertype   = USER_TYPE_USER;

print "hostname:$hostname\n";
# $mqttsender = lc((split(/\./,$hostname))[0]);



my $mqtt = Net::MQTT::Simple->new("10.112.10.3") || die "Can't create mqtt client";
my $mqttprefix = "test";



my  $socket = new IO::Socket::INET (PeerHost => $hostname,
                                    PeerPort => $portnumber,
                                    Proto => 'udp',
                                    Timeout => 3)                                   || die "Can't open socket due to:$!\n";
    $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', TIMEOUT_RECEIVE, 0))  || die "error setting SO_RCVTIMEO: $!";


my $sessionid   = sprintf '1234 %04x 4321',int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';
    my $commandconversion = 'V*';
    $commandconversion =~ s/ //g;

#    "0000 0052 0048 4600 ffff 4600 ",   # multivalues if first
#    "0000 0051 0048 4600 ffff 4600 ",   # normal values
# 0x52000200, 0x00237700, 0x002377FF inverter temp

my $timenow = time(); # unpack('V',pack('N',time()));
my $time1day = time() - time()%86400 - 7200; # unpack('V',pack('N',time() - time()%86400 ));
my $time2day = $time1day - (4*86400); # unpack('V',pack('N',time() - time()%86400 ));
my @commandarguments = (

#[0x70200000,0x4, $time1day,$timenow],

#[0x70200000, $timenow, $time1day],
#[0x70000000, $time1day, $time1day ],

#[0x61000000, 0x40263F00, 0x40263FFF],
[0x68000000, 0x088A4D00, 0x088A4DFF],
#[0x61800000, 0x084A9600, 0x084A96FF],
#[0x61020000, 0x40633E00, 0x40633EFF],
#[0x62000000, 0x40263F00, 0x40263FFF],
#[0x61000000, 0x40652B00, 0x40652BFF],
#
#[0x61000000, 0x402F1E00, 0x402F1EFF],
#[0x61000000, 0x402F2000, 0x402F20FF],
#[0x61000000, 0x40652B00, 0x40652BFF],
#
#[0x68000000, 0x088F2000, 0x088F20FF],
#[0x68000000, 0x088F2100, 0x088F21FF],
#
#[0x52000000, 0x00237700, 0x002377FF],


#[0x61000000, 0x00495C00, 0x00495CFF],
#[0x68000000, 0x00832A00, 0x00832AFF],
#[0x68000000, 0x00A21E00 ,0x00A21EFF], # low high  val

#/*
#       sbs|Code:0x6800|0xa21e|No:0x07|Type:0x00|len:40|2022-06-17T06:36:49|                type.unknown.0xa21e.7|0:0:NaN:NaN:3005625197:3005625197:0:0 |typ:uint|raw: 071e a200 e104 ac62 0000 0000 0000 0000 ffff ffff ffff ffff 6d33 26b3 6d33 26b3 0000 0000 0000 0000
#
#            "6800_00A21E00": {
#                "7": [
#                    {
#                        "low": 0,
#                        "high": null,
#                        "val": 3005625197
#                    }
#                ]
#
#*/
#
#[0x70000000, $timenow-3600, $timenow], # discharge in interval 5
#[0x54000000, 0x00496700, 0x004967FF], # charge 2day ?
##[0x70200000, $timenow-(86400*7000), $timenow],
#[0x51000000,  0x00464000, 0x004642ff ],#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
#
#[0x51000000, 0x00230000, 0x0023FFFF],
#[0x52000000, 0x00237700, 0x002377FF],
#[0x52000200, 0x00237700, 0x002377FF],
#	{0x5200, 0x00237700, 0x002377FF, 0x00, 0x2377, DeviceTemperature, 0.01},

#[0x70000000, $timenow-180, $timenow ],
#[0x70200000, $time2day, $timenow ],
#[0x70000000, $time1day,$timenow],
#[0x70200000,0x8, $timenow,$time1day],
#[0x70200000,0x8, $timenow,$time2day],
#[0x70200000,0x8, $time1day,$timenow],
#[0x53800000,  0x00251E00, 0x00251EFF],

#[0x51000000, 0x00460000, 0x0046ffff],


#       sbs|Code:0x5100|0x46f0|No:0x07|Type:0x40|len:28|2022-06-10T17:00:07|                type.unknown.0x46f0.7|                     90:90:90:90:1 |typ: int|raw: 07f0 4640 775c a362 5a00 0000 5a00 0000 5a00 0000 5a00 0000 0100 0000
#       sbs|Code:0x5100|0x46f0|No:0x07|Type:0x40|len:28|2022-06-12T06:54:17|                type.unknown.0x46f0.7|                     92:92:92:92:1 |typ: int|raw: 07f0 4640 7971 a562 5c00 0000 5c00 0000 5c00 0000 5c00 0000 0100 0000
#       sbs|Code:0x5200|0x46f0|No:0x07|Type:0x40|len:28|2021-08-14T07:30:00|                type.unknown.0x46f0.7|                     69:83:76:76:1 |typ: int|raw: 07f0 4640 d854 1761 4500 0000 5300 0000 4c00 0000 4c00 0000 0100 0000

#[0x51000000, 0x00460000, 0x0046ffff],
#[0x51800000, 0x00460000, 0x0046ffff],
#[0x52000000, 0x00460000, 0x0046ffff],

#[0x53800000, 0x00251E00, 0x00251EFF],
#[0x51800000, 0x00251E00, 0x00251EFF],
#[0x51008000,  0x00214800, 0x002148ff ],#    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
#[0x51000000,  0x00263f00, 0x00263fff ],#    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
#[0x51000000,  0x00295a00, 0x00295aff ],#    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
#[0x51000000,  0x00411e00, 0x004120ff ],#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
#[0x51008000,  0x00416400, 0x004164ff ],#    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
#[0x51000000,  0x00463600, 0x004637ff ],#    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
#[0x51000000,  0x00464000, 0x004642ff ],#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
#[0x51000000,  0x00464800, 0x004655ff ],#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#[0x51000000,  0x00464800, 0x0046ffff ],
#[0x51000000,  0x00465700, 0x004657ff ],#    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
#[0x51000000,  0x00491e00, 0x00495dff ],#    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
#[0x51000000,  0x00495b00, 0x00495bff ],#    "0000 0051 005B 4900 ff5b 4900 ",   # temperature battery:
#[0x51000000,  0x00832a00, 0x00832aff ],#    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2
#
#[0x52000000,  0x00237700, 0x00237702 ],
#[0x52000000,  0x00237700, 0x002377ff ],#    "0000 0052 0077 2300 ff77 2300 ",   # external inverter temperature
#[0x52000000,  0x00464800, 0x0046ffff ],
#
#[0x53000000,  0x00251e00, 0x00251eff ],
#[0x53008000,  0x00251e00, 0x00251eff ],#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
#[0x53008000,  0x00251e01, 0x00251e01 ],
#[0x53008000,  0x00251e02, 0x00251e02 ],
#[0x53000000,  0x00251e02, 0x00251eff ],
#[0x53008000,  0x00451f00, 0x004521ff ],#    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
#
#[0x54000000,  0x00260100, 0x002622ff ],#    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL daily yield
#[0x54000000,  0x00462e00, 0x00462fff ],#    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM
#
#[0x58000000,  0x00821e00, 0x008220ff ],#    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
#[0x58000000,  0x00823400, 0x008234ff ],#    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION
#[0x64000200,  0x00618d00, 0x00618dff ],
#	{0x5100, 0x00263F00, 0x00263FFF, 0x00, 0x263F, ActivePowerPlus, 0},
#	{0x5100, 0x00295A00, 0x00295AFF, 0x00, 0x295A, BatteryCharge, 0},
#	{0x5100, 0x00411E00, 0x004120FF, 0x00, 0x411E, ActivePowerMax, 0},
#	{0x5100, 0x00464000, 0x004642FF, 0x00, 0x4640, ActivePowerPlusL1, 0},
#	{0x5100, 0x00464000, 0x004642FF, 0x00, 0x4641, ActivePowerPlusL2, 0},
#	{0x5100, 0x00464000, 0x004642FF, 0x00, 0x4642, ActivePowerPlusL3, 0},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x4648, VoltageL1, 0.01},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x4649, VoltageL2, 0.01},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x464a, VoltageL3, 0.01},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x4653, CurrentL1, 0.001},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x4654, CurrentL2, 0.001},
#	{0x5100, 0x00464800, 0x004655FF, 0x00, 0x4655, CurrentL3, 0.001},
#	{0x5100, 0x00465700, 0x004657FF, 0x00, 0x4657, UtilityFrequency, 0.01},
#	{0x5100, 0x00491E00, 0x00495DFF, 0x00, 0x495B, BatteryTemperature, 0.1},
#
#	// TODO more decoding for device_status & device_grid_relay
#	{0x5180, 0x00214800, 0x002148FF, 0x00, 0x2148, DeviceStatus, 0},
#	{0x5180, 0x00416400, 0x004164FF, 0x00, 0x4164, DeviceGridRelay, 0},
#
#	{0x5200, 0x00237700, 0x002377FF, 0x00, 0x2377, DeviceTemperature, 0.01},
#
#	{0x5380, 0x00251E00, 0x00251EFF, 0x01, 0x251E, PowerS1, 0},
#	{0x5380, 0x00251E00, 0x00251EFF, 0x02, 0x251E, PowerS2, 0},
#	{0x5380, 0x00451F00, 0x004521FF, 0x01, 0x451F, VoltageS1, 0.01},
#	{0x5380, 0x00451F00, 0x004521FF, 0x02, 0x451F, VoltageS2, 0.01},
#	{0x5380, 0x00451F00, 0x004521FF, 0x01, 0x4521, CurrentS1, 0.001},
#	{0x5380, 0x00451F00, 0x004521FF, 0x02, 0x4521, CurrentS2, 0.001},
#
#	{0x5400, 0x00260100, 0x002622FF, 0x00, 0x2601, ActiveEnergyPlus, 3600},
#	{0x5400, 0x00260100, 0x002622FF, 0x00, 0x2622, ActiveEnergyPlusToday, 3600},
#	{0x5400, 0x00462E00, 0x00462FFF, 0x00, 0x462E, TimeOperating, 0},
#	{0x5400, 0x00462E00, 0x00462FFF, 0x00, 0x462F, TimeFeed, 0},
#
#	{0x5800, 0x00821E00, 0x008220FF, 0x00, 0x821E, DeviceName, 0},
#	{0x5800, 0x00821E00, 0x008220FF, 0x00, 0x821F, DeviceClass, 0},
#	{0x5800, 0x00821E00, 0x008220FF, 0x00, 0x8220, DeviceType, 0},
#
);

my @commandarguments2 = (
[0x00, 0x00, 0x80, 0x51, 0x00214800, 0x002148ff ],#    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
[0x00, 0x00, 0x00, 0x51, 0x00263f00, 0x00263fff ],#    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
[0x00, 0x00, 0x00, 0x51, 0x00295a00, 0x00295aff ],#    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
[0x00, 0x00, 0x00, 0x51, 0x00411e00, 0x004120ff ],#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
[0x00, 0x00, 0x80, 0x51, 0x00416400, 0x004164ff ],#    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
[0x00, 0x00, 0x00, 0x51, 0x00463600, 0x004637ff ],#    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
[0x00, 0x00, 0x00, 0x51, 0x00464000, 0x004642ff ],#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
[0x00, 0x00, 0x00, 0x51, 0x00464800, 0x004655ff ],#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
[0x00, 0x00, 0x00, 0x51, 0x00464800, 0x0046ffff ],
[0x00, 0x00, 0x00, 0x51, 0x00465700, 0x004657ff ],#    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
[0x00, 0x00, 0x00, 0x51, 0x00491e00, 0x00495dff ],#    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
[0x00, 0x00, 0x00, 0x51, 0x00495b00, 0x00495bff ],#    "0000 0051 005B 4900 ff5b 4900 ",   # temperature battery:
[0x00, 0x00, 0x00, 0x51, 0x00832a00, 0x00832aff ],#    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2

[0x00, 0x00, 0x00, 0x52, 0x00237700, 0x00237702 ],
[0x00, 0x00, 0x00, 0x52, 0x00237700, 0x002377ff ],#    "0000 0052 0077 2300 ff77 2300 ",   # external inverter temperature
[0x00, 0x00, 0x00, 0x52, 0x00464800, 0x0046ffff ],

[0x00, 0x00, 0x00, 0x53, 0x00251e00, 0x00251eff ],
[0x00, 0x00, 0x80, 0x53, 0x00251e00, 0x00251eff ],#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
[0x00, 0x00, 0x80, 0x53, 0x00251e01, 0x00251e01 ],
[0x00, 0x00, 0x80, 0x53, 0x00251e02, 0x00251e02 ],
[0x00, 0x00, 0x00, 0x53, 0x00251e02, 0x00251eff ],
[0x00, 0x00, 0x80, 0x53, 0x00451f00, 0x004521ff ],#    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2

[0x00, 0x00, 0x00, 0x54, 0x00260100, 0x002622ff ],#    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL daily yield
[0x00, 0x00, 0x00, 0x54, 0x00462e00, 0x00462fff ],#    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM

[0x00, 0x00, 0x00, 0x58, 0x00821e00, 0x008220ff ],#    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
[0x00, 0x00, 0x00, 0x58, 0x00823400, 0x008234ff ],#    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION
[0x00, 0x00, 0x02, 0x64, 0x00618d00, 0x00618dff ],
);

my @commands = (
    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2
    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
    "0000 0051 0040 4600 FF42 4600 ",   # grid power phases
    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
    "0000 0051 0048 4600 ffff 4600 ",   # normal values
    "0000 0051 0057 4600 FF57 4600 ",
    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
    "0000 0051 005B 4900 ff5b 4900 ",   # temperature battery:
    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
    "0000 0052 0048 4600 ffff 4600 ",   # multivalues if first
    "0000 0052 0077 2300 1077 2300 ",   # InverterTemperature:
    "0000 0052 0077 2300 ff77 2300 ",   # InverterTemperature:
    "0000 0052 0077 2300 ff77 2300 ",   # external inverter temperature
    "0000 0053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
    "0000 0053 021E 2500 FF1E 2500 ",   # current power 0
    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL
    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM
    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION
    "0000 0264 008d 6100 ff8d 6100 ",   # sbftest: logout
    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
    "0000 8053 011E 2500 011E 2500 ",   # current power 1
    "0000 8053 021E 2500 021E 2500 ",   # current power 0


#    "0C04 fdff ffffffff ",   # logout, shuts down socket for quite some time
    );

#
#for my $command (0x51 .. 0x60)
#{
#    for my $cmdtype (0x20 .. 0x80)
#    {
#        for my $range (0x00 .. 0xFF)
#        {
#            push(@commands,''.sprintf("0000 00%02x 00%02x %02x00 FF%02x %02x00 ",$command,$range,$cmdtype,$range,$cmdtype));
#        }
#    }
#}
#print join("\n",@commands);
#

if(0)
{
    my @work = @commands;

    while( scalar @work )
    {
        my $command = lc shift @work;

        my @bla = string2command($command);
        my $retcommand = command2string(@bla);

        $command =~ s/\s//g;
        if( $retcommand ne $command )
        {
            print "Differ:\n\t$command\n\t$retcommand\n";
            exit;
        }

        print "\n";

    }
    exit;
}

if( scalar @commandarguments )
{
    my $loop     = 1;
    my $looptime = 5;

    do
    {
        my @work = @commandarguments;
        doWork(@work);

        jnxsleep($looptime) if $loop;
    }
    while( $loop );

    exit;
}

for my $a ( 0x51..0x54,0x58,0x5d,0x61..0x64,0x68,0xf0,0xff )
{
for my $b ( 0x00,0x02,0x22,0x80,0x82,0xfd )
{
for my $c ( 0x00 )
{
for my $d ( 0x00 )
{
    my $command = ($a << 24) | ($b << 16) | ($c << 8) | $d;

    for my $address (0x24..0x99 )
    {
        my $start   = ($address << 16) | 0x0000;
        my $end     = ($address << 16) | 0xffff;

        my @cmd = [$command, $start, $end ];

        doWork( @cmd );
    }
}
}
}
}
exit;


sub string2command
{
    my($string) = @_;
    $string =~ s/\s//g;

    my $data = pack('H*',$string);

    print "string2command $string -> ";
    return data2command($data,$commandconversion);
}

sub data2command
{
    my($data,$convertstring,$oneline) = @_;

    $convertstring =~ s/\s+//g;
    $convertstring .= 'H*' if !$oneline;
    my @command = unpack($convertstring,$data);
    push(@command, pack('H*',pop(@command))) if !$oneline;

    my @commandcopy = @command;

    print "[";

    while( $convertstring =~ /([HCvnVN]{1}(?:\d+|\*)?)/g )
    {
        my $type = $1;
        my $value = shift @commandcopy;
#         print "\n".'Type:'.$type." ";

        if(    $type eq 'C' ) { printf "0x%02x, ",$value }
        elsif( $type eq 'v' ) { printf "0x%04x, ",$value }
        elsif( $type eq 'n' ) { printf "0x%04x, ",$value }
        elsif( $type eq 'V' ) { printf "0x%08x, ",$value }
        elsif( $type eq 'N' ) { printf "0x%08x, ",$value }
        elsif( $type eq 'H*') { printf "<len=%4d:  %s>",length($value),prettyhexdata( $value ) }
        else
        {
            print "type: $type unknown\n";
            exit;
        }
    }

    print "]";
    print "\n" if !$oneline;
    #printf "string2command $string -> %02x %02x %02x %02x %08x %08x\n",@command;

#    printf "[0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%08x, 0x%08x ],\n",@command;
    return @command;
}

sub command2string
{
    my @command = @_;

    my $commandpacket = pack($commandconversion,@command);
    my $string = unpack('H*',$commandpacket);

    printf "command2string %02x %02x %02x %02x %08x %08x -> $string\n",@command;

    return $string;
}


sub doWork
{
    my @work = @_;
    my $loggedin = 0;
    my $commandwaittime = 0.1;

    while( scalar @work )
    {
        my $response;

        if( !$loggedin )
        {
            print "NOT LOGGED IN \n";
            my $logincommand = "0C04 fdff 07000000 84030000 4c20cb51 00000000".encodePassword($password);
            $response = sendReceiveCommand($socket,$logincommand,$sessionid,$inverterid);

            if( $response == 0x0000 )
            {
                $loggedin = 1;
            }
            else
            {
                sleep(5);
            }
        }
        else
        {
            my $arguments = shift @work;
            my $command = command2string(@{$arguments});

            $response = sendReceiveCommand($socket,$command,$sessionid,$inverterid);

            if( $response == 0x0017 || $response == 0x0102 )
            {
                # unshift(@work,$command);
                $loggedin = 0;
            }
        }

        jnxsleep($commandwaittime);
    }
}


sub sendReceiveCommand
{
    my($socket,$command,$sessionid,$inverterid) = @_;
    my $data;

    sendCommand($socket,$command,$sessionid,$inverterid);

    my $response = receiveData($socket);

    return $response;

}

sub receiveData
{
    my($socket) = @_;

    my $data;
    my $response = undef;
    my $moretocome = undef;
    my $responsecounter = 0;

    while(1)
    {
        my $starttime = time();
        $socket->recv($data, MAXIMUM_PACKET_SIZE);
        my $endtime = time();

        printf "Responsetime = %.3f ms\n",($endtime - $starttime) * 1000;
        if( 0 == length($data) )
        {
            print "no response.\n" if undef == $response;
            return $response;
        }
        writeDataToFile($data);

        $responsecounter++;

        print "RESPONSECOUNTER:$responsecounter\n";

        ($response,$moretocome) = printSMAPacket('recv',$data);
        print "\n\n";

        return $response if 0==$moretocome;
    }
}


{
    my $counter = 0;
    sub packetcounter { return ++$counter }
    sub jnxsleep { select(undef, undef, undef, @_[0] ) }
}

sub sendCommand
{
    my($socket,$smanet_command,$sessionid,$inverterid) = @_;

    my $packetcounter = packetcounter();
    my $smanet_prefix = "00A0"
                        .$inverterid
                        .( $inverterid eq 'ffff ffff ffff' ? '0001' : '0001')
                        .$sessionid
                        .( $inverterid eq 'ffff ffff ffff' ? '0001' : '0001')
                        .'0000' # status
                        .'0000' # 2come
                        .sprintf("%02x%02x",($packetcounter & 0xFF),(($packetcounter & 0xFF00) >> 8 |0x80))
                        ;


    my $smanet_packet = $smanet_prefix.$smanet_command;
       $smanet_packet =~ s/ //g;
    my $smanet_length = length($smanet_packet)/2;
    substr($smanet_packet,0,2) = sprintf("%02x",$smanet_length / 4);

    my $sma_header = "534d4100" . "0004 02a0 00000001";
    my $sma_footer = "0000 0000";
    my $sma_prefix = "0000 0010 6065";
    substr($sma_prefix,0,4) = sprintf("%04x",$smanet_length + 2);


    my $hexstring =  $sma_header
                    .$sma_prefix.$smanet_packet
                    .$sma_footer;
    $hexstring  =~ s/ //g;

    my $data = pack "H*",$hexstring;

    writeDataToFile($data);

    printSMAPacket('sending',$data);

    my $size = $socket->send($data);
}

sub writeDataToFile
{
    my ($data) = @_;

    return if !length $filename;

    my $filehandle = undef;

    open( $filehandle, ">>", $filename) || die "Can't open $filename for appending due to:$!";
    binmode $filehandle;
    print $filehandle $data;
    close($filehandle);
}


sub prettyhexdata
{
    my ($data,$splitlength) = @_;
    my $hexstring = unpack('H*',$data);

    if( $splitlength )
    {
        my $linesize = $splitlength * 2;
        $hexstring =~ s/(\S{$linesize})/\1\n/g;
    }
    $hexstring =~ s/(\S{4})/\1 /g;
    return $hexstring;
}

sub printSMAPacket
{
    my($prefix,$data) = @_;

    my $smaheader   = unpack('N',substr($data,0,4));
    my $proto       = unpack('n',substr($data,16,2));
    my $length      = unpack('C',substr($data,18,1)) * 4;

    $data = substr($data,0,18 + 4 + $length);


    if( $smaheader != 0x534d4100 )
    {
        printf "%s: invalid packet: prefix:%0x header:%0x len:%d data:%s\n",$prefix,$smaheader,$proto,$length,prettyhexdata($data);
        return (undef,0);
    }

    if( $proto != 0x6065 )
    {
        printf "%s SMA packet: prefix:%0x header:%0x len:%d data:%s\n",$prefix,$smaheader,$proto,$length,prettyhexdata($data);
        return (undef,0);
    }

    printf "Complete Packet:\n".prettyhexdata($data)."\n";

    my $footer  = unpack('N',substr($data,-4));

    if( $footer != 0x0 )
    {
        print "invalid footer\n";
        return (undef,0);
    }
    #printf "%5s SMAPacket: %s\n",$prefix,prettyhexdata(substr($data,0,18));

    my $smanetdata  = substr($data,18,$length);

    return printSMANetPacket($smanetdata);
}



sub counttimeswrong
{
    my($valuesdata,$valuesize,$warn) = @_;


    my %validtypes = (
            0 => 1,
            0x40 => 1,
            0x10 => 1,
            0x08 => 1,
            0x51 => 1,
    );

    my $timesnotok = 0;

    my $invalidtypes = 0;

    while( length($valuesdata) )
    {
        my $time    = unpack('V',substr($valuesdata,4 , 8));
        my $type    = unpack('C',substr($valuesdata,3 , 1));

        $valuesdata = substr($valuesdata,$valuesize);

        $timesnotok += 1000 if 1 != $validtypes{$type};

        $invalidtypes++ if 1 != $validtypes{$type};

        next if $time == 0;

        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);

        if( $year < 2010 ||  $year > 2022 )
        {
            $timesnotok += 10;
        }
        elsif( $year < 2021 )
        {
            $timesnotok += 1;
        }
    }

    if($warn)
    {
        printf " typeok:%d",0 == $invalidtypes;
    }

    return $timesnotok;
}

sub checkSMANetPacketCompleteness
{
    my($data) = @_;

    my $smanet_length = unpack('C',substr($data,0,1)) * 4;
    my $remaining = $smanet_length - 36;

    if( $smanet_length != length($data) )
    {
        printf "invalid SMANetPacket length $smanet_length != ".length($data)." data:".prettyhexdata($data)."\n";
        return undef;
    }
    return 1;
}


sub printSMANetPacket       # return ( $result, $moretocome )
{
    my($data) = @_;

    return (undef,undef) if !checkSMANetPacketCompleteness($data);


    my @header =  data2command($data ,
       'C             C            n      N           C   C    n      N           C    C     v       v               v          C     C           v');
       #0             1            2      4           8   9    10     12          16   17    18      20              22         24    25          26
    my ($quaterlength,$packettype, $dstid,$dstserial, $p8,$p9, $srcid,$srcserial, $p16,$p17 ,$result,$packetstocome ,$pktidflg, $p24, $p25, $command, $remaining) = @header;

    printf "SMANet:";

    my $packetid    = $pktidflg & 0x7FFF;
    my $direction   = $pktidflg & 0x8000 ? 1 : 0;



#    print $result != 0 ? ' ok ': 'fail';

    my $srchostid = sprintf("%02x%04x",$srcid,$srcserial);
    my $dsthostid = sprintf("%02x%04x",$dstid,$dstserial);


    printf "".hostid2name($srchostid);
    printf "-".hostid2name($dsthostid);

    printf "|p1:0x%02x",$packettype,$packettype;

#    printf "|p8:0x%02x %08b",$p8,$p8;     # always zero
#    printf "|p9:0x%02x %08b",$p9,$p9;
    printf "|p9:0x%02x",$p9,$p9;

#    printf "|p16:0x%02x %08b",$p16,$p16;   # always zero
    printf "|p17:0x%02x",$p17,$p17;
#    printf "|reslt:%04x %016b",$result,$result;
    printf "|reslt:%04x",$result;
    printf "|2come:0x%02x",$packetstocome;

    printf "|%s",$direction ? "res" : "req";
    printf "|pktid:0x%04x",$packetid;
    printf "|p24:0x%02x",$p24,$p24;
    printf "|p25:0x%02x",$p25,$p25;
#    printf "|p25-p24:0x%02x-0x%02x",$p25,$p24;
#    printf "|p24:0x%02x %08b",$p24,$p24;
    printf "|cmd:%04x",$command;


    my $remainingsize = length($remaining);
    printf "|len:%03x-%03d",$remainingsize,$remainingsize;
    printf "|head:%s%s\n",prettyhexdata(substr($remaining,0,62)),($remainingsize > 62 ? '..' : '');

#for i in $(cat ~/Desktop/values |grep '^SMANet:sb'|perl -e 'while(<>){$count{$1}++ if /\|(p25.*?)\|/o;} while( my($a,$b) = each %count ) {print "$a\n" }'|sort|perl -pe 's/\n/ /')                                                                                                                      (6:52:36)
#do
#echo $i ;
#b=`cat ~/Desktop/values|grep "$i"|perl -ne 'print $1."\n" if /len:(\d+) /;'|sort -nu|perl -pe 's/\n/ /g;'`
#echo "b:$b";for c in $(echo "$b")
#do
#cat ~/Desktop/values|grep "$i" |grep "len:$c"|head -10
#done
#done


#    p25:0x00 cnt:256312    cmd=2800, sb3 only, len 12 weird , or 52 ( start 0003 5000 x*16 bytes normal
#                                               len 12 0100 3001 time 201c 0000
#
#    p25:0x01 cnt:437139    cmd 6a02, len 20 , 0400 0000 | x* 16 bytes normal , cmd fffd len 4 , data ffff ffff
#                           cmd fffd ,len 16 0000 0000 | 12 bytes weird

#SMANet:sbs-any|p1:0xa0|p9:0x03|p17:0x03|..........|..........|...|............|p24:0x0e|p25:0x01|cmd:fffd|len:004-004|head:ffff|ffff
#SMANet:sh1-any|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....
#SMANet:sb3-sh1|p1:0xe0|.......|........|..........|..........|...|............|p24:0x0d|p25:0x01|........|len:010-016|head:0000|0000|4c4f|434b|4544|....|0000|0000


#SMANet:sh1-sb4|p1:0xe0|p9:0x01|.||.|.|.|p24:0x0e|p25:0x01|cmd:6a02|len:014-020|head:0400|0000|0149|9240|0000|2061|a00f|0000|3a00|fec4
#SMANet:sh1-sb3|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|....|....|b80b|....|....|068a
#SMANet:sh1-sb4|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|....|2161|a00f|....|....|4145
#SMANet:sh1-sb3|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|....|....|b80b|....|....|b90b
#..............|.......|.......|.||.|.|.|........|........|........|len:034-052|.........|....|0745|9208|0429|2061|....|....|....|9d8b|0744|9240|0429|2061|00|074|200|3a00|f9df
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|1829|....|....|....|....|7a80|....|....|1829|....|....|....|....|a960|....|....|1829|....|....|....|....|1ed4
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|83ae|ab62|....|....|....|4b04|....|....|83ae|ab62|....|....|....|98e4|....|....|83ae|ab62|....|....|....|2f50
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|97ae|....|....|....|....|8566|....|....|97ae|....|....|....|....|5686|....|....|97ae|....|....|....|....|e132
#..............|.......|.......|.||.|.|.|........|........|........|len:064-100|.........|....|0760|8908|0035|ac62|7809|....|....|dbc3|0761|8900|0035|ac62|....|....|....|e1cf|0762|8900|0035|ac62|....|....|....|16c1|0763|8900|0035|ac62|0000|..
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|0044|....|....|....|....|e860|....|....|0044|....|....|....|....|d26c|....|....|0044|....|....|....|....|2562|....|....|0044|....|....|..
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|0087|1f61|....|....|....|8f90|....|....|0087|1f61|....|....|....|b59c|....|....|0087|1f61|....|....|....|4292|....|....|0087|1f61|....|..
#..............|.......|.......|.||.|.|.|........|........|........|...........|.........|....|....|....|00ae|ab62|....|....|....|5bcd|....|....|00ae|ab62|....|....|....|61c1|....|....|00ae|ab62|....|....|....|96cf|....|....|00ae|ab62|....|..
#


#    p25:0x02 cnt:604718    normal
#    p25:0x03 cnt:26        cmd 68*, len 12 weird 0100 0000 xxxx 0000 xxxx xxxx

#SMANet:sb3-sh1|p1:0xe8|p9:0x00|p17:0x00|reslt:0000|2come:0x00|res|pktid:0x....|p24:0x00|p25:0x03|cmd:6800|len:00c-012|head:0100|0000|5601|0000|2b7f|bc76
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|6901|....|6d33|26b3
#SMANet:sh1-sb3|.......|.......|........|..........|..........|...|............|p24:0x01|........|........|...........|.........|....|7401|....|10e7|f0b2
#SMANet:sh1-sbs|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|p24:0x00|........|cmd:6802|...........|.........|....|6901|....|6d33|26b3
#SMANet:sh1-sbs|.......|.......|........|..........|..........|...|............|p24:0x01|........|........|...........|.........|....|7401|....|10e7|f0b2
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|p24:0x00|........|........|...........|head:0101|0001|6901|....|6d33|26b3
#

#
#    p25:0x04 cnt:15        cmnd fffd , 0a00 0000 | x* 16 bytes normal

#SMANet:sb3-jnx|p1:0xe0|p9:0x00|p17:0x00|reslt:0018|2come:0x00|res|pktid:0x....|p24:0x0d|p25:0x04|cmd:fffd|len:010-016|head:0700|0000|8403|0000|4c20|cb51|0000|0000
#..............|.......|p9:0x01|p17:0x01|reslt:0000|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|.......|........|reslt:0102|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|p9:0x02|p17:0x02|reslt:0018|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sb4-jnx|.......|p9:0x00|p17:0x00|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|p9:0x01|........|reslt:0000|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|.......|p17:0x01|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|.......|........|reslt:0102|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sbs-jnx|.......|.......|........|reslt:0000|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|.......|........|reslt:0102|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sbt-jnx|.......|.......|........|reslt:0000|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sb3-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|head:0a00|....|....|....|5fae|ab62|....|....
#SMANet:sb4-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sb3-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|6704|ac62|....|....
#SMANet:sb4-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|9504|....|....|....
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|b004|....|....|....
#..............|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|b1ef|2061|....|....
#SMANet:sb3-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|d328|....|....|....
#SMANet:sb4-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#SMANet:sbs-sh1|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|....|....|....|....
#..............|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|d5ef|....|....|....
#..............|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|df04|ac62|....|....
#SMANet:sh1-any|p1:0xa0|.......|........|..........|..........|...|............|p24:0x0c|........|........|len:01c-028|.........|....|....|....|5fae|ab62|....|....|0b07|0feb|1a0e|2a27|1c2d|bbbb
#SMANet:sh1-sb3|p1:0xe0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|6704|ac62|....|....|....|....|....|....|....|....
#SMANet:sh1-sb4|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|9504|....|....|....|....|....|....|....|....|....
#SMANet:sh1-sbs|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|b004|....|....|....|....|....|....|....|....|....
#..............|.......|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|b1ef|2061|....|....|....|....|....|....|....|....
#SMANet:sh1-any|p1:0xa0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|d328|....|....|....|....|....|....|....|....|....
#SMANet:sh1-sbs|p1:0xe0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|d5ef|....|....|....|....|....|....|....|....|....
#SMANet:sbs-any|p1:0xa0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|d9ef|....|....|....|....|....|....|....|....|....
#SMANet:sh1-sbs|p1:0xe0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|df04|ac62|....|....|....|....|....|....|....|....
#SMANet:sbs-any|p1:0xa0|.......|........|..........|..........|...|............|........|........|........|...........|.........|....|....|....|e404|....|....|....|....|....|....|....|....|....







#    p25-p24:0x00-0x0c
#    p25-p24:0x00-0x0e  0003 5000 | x*16 bytes normal
#    p25-p24:0x01-0x0d
#    p25-p24:0x01-0x0e  0400 0000 | x* 16 bytes normal
#    p25-p24:0x02-0x00
#    p25-p24:0x02-0x01  normal
#    p25-p24:0x02-0x0a  normal
#    p25-p24:0x03-0x00  normal ? (8 only)
#    p25-p24:0x04-0x0c  normal ? (8 only)
#    p25-p24:0x04-0x0d  0a00 0000 | x*16 bytes normal
#                       0700 0000 | x*16 bytes normal

#   02 0a normal
#   02 01 normal
#   03 00 normal ? (8 only)
#   04 00 normal ? (8 only)
#
#   00 0e 0003 5000 | 12 bytes time ? | 16 bytes ? | 4bytes 0 | 16 bytes
#
#   01 0e 0400 0000 | x* 16 bytes normal
#
#   04 0d 0a00 0000 | x*16 bytes normal
#         0700 0000 | x*16 bytes normal


#





    if( $remainingsize > 0)
    {
        if( 0x02 == $p25 )
        {
            if( 0x0000 == $command )
            {
                print " data:".prettyhexdata($remaining);
            }
            else
            {
                print " invalid:".prettyhexdata($data) if length($remaining) < 8;

                my $valuesheader = substr($remaining,0,8);
                my $valuesdata   = substr($remaining,8);

                my ($from,$to)  = unpack('VV',$valuesheader);
                my $valuescount = $to - $from + 1;

                printf " start:0x%08x end:0x%08x valcnt:%2d",$from,$to,$valuescount;

                if( $valuescount > 0)
                {
                    my $valuelength = length($valuesdata) / $valuescount;

                    printValues($srchostid,$command,$valuelength,$valuesdata);
                }
            }
        }
        elsif( 0x01 == $p25 || 0x04 == $p25 )
        {
            print " invalid:".prettyhexdata($data) if length($remaining) < 4;

            my $valuesheader = substr($remaining,0,4);
            my $valuesdata   = substr($remaining,4);

            my ($unknown)  = unpack('V',$valuesheader);

            my $valueslength = length($valuesdata);
            my $valuelength  = 0x01 == $p25 ? 16 : $valueslength;

            printf " valhead:0%08x vallen=%2d",$unknown,$valuelength;

            printValues($srchostid,$command,$valuelength,$valuesdata);
        }
        elsif( 0x00 == $p25 )
        {
            print " keepalivepacket:".prettyhexdata($remaining);
        }
        else
        {
            print " typeunknown: ",prettyhexdata($remaining);
        }
    }
    print "\n\n";

    return ($result,$packetstocome);
}


sub printValues
{
    my($srchostid,$command,$valuelength,$valuesdata) = @_;

    my $valueslength = length($valuesdata);

    if( $valueslength > 0)
    {
        printf " lenisvalid=%d\n",length($valueslength % $valuelength == 0);

        while( length($valuesdata) >= $valuelength )
        {
            my $data = substr($valuesdata,0,$valuelength);

            SMANetPacketValueParsing($srchostid,$command,$data);
            $valuesdata = substr($valuesdata,$valuelength);
        }
   }
   return undef;
}



sub hostid2name
{
    my($source) = @_;

    my %knownsources = (    '69016d3326b3' => 'sbs',
                            '56012b7fbc76' => 'sb3',
                            '9901f6a22fb3' => 'sb4',
                            '7a01d39c05b3' => 'sbt',
                            '740110e7f0b2' => 'sh1',
                            '57012b7fbc76' => 'sh2',
                            '3701ffffffff' => 'sh3',
                            'ffffffffffff' => 'any',
                            'fdffffffffff' => 'an2',
                            'e70064063a2e' => 'jn2',
                        );

    my $newsource = $knownsources{$source};

    if( !$newsource )
    {
        if( substr($source,0,4) eq '1234' && substr($source,-4) == '4321' )
        {
            $newsource = 'jnx';
        }
        else
        {
            $newsource = 'unk'.$source;
        }
    }

    return $newsource;
}

sub SMANetPacketValueParsing
{
    my($source,$command,$footer) = @_;

    if($command == 0x7020 || $command == 0x7000)
    {
        my $time  = unpack('V',substr($footer,0,4));
        my $value = unpack('V',substr($footer,4,4));
        printf "time:".localtime($time)."value:".$value."\n";
    }

    my $number = unpack('C',substr($footer,0,1));
    my $code = unpack('v',substr($footer,1,2));
    my $type = unpack('C',substr($footer,3,1));
    my $time  = unpack('V',substr($footer,4,4));
    my $timestring = POSIX::strftime('%Y-%m-%dT%H:%M:%S',localtime($time));

    my  $typeinformation = code2Typeinformation($code);
    my  $name = $$typeinformation{path};

    my  $unit = $$typeinformation{unit};
    my  $factor = $$typeinformation{factor}|| 1;
    my  $title = $$typeinformation{title};
    my  $path = $name.'.'.$number;

    $name .= '.'.$number ;# if $number > 0 && $number <7;
    $name .= ' ('.$$typeinformation{unit}.')' if $$typeinformation{unit};

    printf "%10s|Code:0x%04x|0x%04x|No:0x%02x|Type:0x%02x|len:%2d|%s|%37s|",hostid2name($source),$command,$code,$number,$type,length($footer),$timestring,$name;

    ##### TYPE decoding

    if( $type == 0x00 || $type == 0x40 )    # integer
    {
        my  @values = unpack('V*',substr($footer,8));

        if(         @values[0] == 0x0       # version number scheme
                &&  @values[1] == 0x0
                &&  @values[2] == 0xFFFFFFFE
                &&  @values[3] == 0xFFFFFFFE
                &&  @values[4] == @values[5]
                &&  @values[6] == 0x0
                &&  @values[7] == 0x0
            )
        {
            @values = unpack('C*',pack('N',@values[4]));
        }

        my @results;

        VALUE_LOOP: for my $value (@values)
        {
            if( $type == 0x00 )
            {
#                last VALUE_LOOP if $value == 0xFFFFFFFF
                push(@results, $value != 4294967295 ? sprintf("%d",$value) : 'NaN');
            }
            else
            {
#                last VALUE_LOOP if $value == 0x80000000
                my $signed = unpack('l',pack('L',$value));
                push(@results, $signed != -2147483648 ? sprintf("%d",$signed) : 'NaN');
            }
        }
        printf "%34s ",join(':',@results);

        sendMQTT($path,$unit,$factor,$title,@results);

    }
    elsif( $type == 0x10 )      # string
    {
        my $value = unpack('Z*',substr($footer,8,32));

        printf "%34s ",$value;
    }
    elsif( $type == 0x08)      # dotted version
    {
        my $position = 8;
        my @values = ();

        while( $position < 36)
        {
            my $valueA   = unpack('v',substr($footer,$position,2));
            my $valueB   = unpack('v',substr($footer,$position+2,2));

            last if $valueB == 0xFFFE && $valueA == 0x00FF;

            push(@values, sprintf("%04d",$valueA) ) if $valueB & 0x100  ;

            $position += 4;
        }

        printf "%34s ",join('.',@values);
    }
    else
    {
        printf "type unknown ";
    }

    my %types = ( 0x00 => 'uint',
                  0x40 => ' int',
                  0x10 => ' str',
                  0x08 => ' dot',
                );
    my $realtype = defined $types{$type} ? $types{$type} : sprintf('0x%02d',$type);


    printf "|typ:%s|raw: %s\n",$realtype,prettyhexdata($footer);
}



sub sendMQTT
{
    my($path,$unit,$factor,$title,@values) = @_;

    return if !$mqttsender;
    my $topic = join('/', ($mqttprefix,$mqttsender,split(/\./,$path)) );

    $topic =~ s/\/(\d+)$/_$1/;

    my @outvalues = map { $_ eq 'NaN' ? 'null' : $_ * $factor } @values;


    print "\nMqtt: device:$mqttsender path:$path topic:$topic unit:$unit value:@values @outvalues\n";


    if( @outvalues > 1 )
    {
        $mqtt->publish($topic => '{"unit":"'.$unit.'","value":"'.join(':',@outvalues).'","title","'.$title.'"}' );
    }
    else
    {
        $mqtt->publish($topic => '{"unit":"'.$unit.'","value":'.@outvalues[0].'","title","'.$title.'"}' );
    }

}


sub encodePassword
{
    my($password) = @_;

    my $encoded = '';

    for my $index (0..11)
    {
        my $character = ord(substr($password,$index,1));
        my $calculate = ($character + $usertype);
        $encoded .= unpack('H*',chr($calculate));
#        printf "%s %d 0x%x %d 0x%x 0x%1X %s\n",substr($password,$index,1},$character,$character,$calculate,$calculate,$calculate,$encoded;
    }
#     print "encoded:".$encoded."\n";
    return $encoded;
}

sub dumpFile
{
    my($filename) = @_;

    open(FILE,'<'.$filename) || die "Can't open $filename for reading due to:$!";
    binmode FILE;
    my $seperator = pack('N',0x534d4100);
    $/ = $seperator;

    while( my $data = <FILE> )
    {
        chomp $data;
        next if length($data) < 10;

        printSMAPacket('FILE:',$seperator.$data);
    }
    close(FILE);
}

sub code2Typeinformation
{
    my($number) = @_;

 my $battery = {
 0x295A => { path => 'immediate.soc', unit => '%' , title => "Battery State of Charge"},
 0x2622 => { path => 'counter.dailydischarge', unit => 'kWh', factor => 0.001 , title => "Daily Discharge" },
 0x495B => { path => 'immediate.batterytemperature', unit => 'ºC' , factor => 0.1 , title => "Battery Temperature" },
 0x263F => { path => 'immediate.gridusage', unit => 'W' , title => "Grid Usage"},

 0x251E => { path => 'immediate.dc.power', unit => 'W', title => "Power DC"},

 };


 my $typeInformation = {

 0x2148 => { path => 'immediate.system.status'},
 0x2377 => { path => 'immediate.system.externaltemperature'},
 0x251E => { path => 'immediate.dc.power', unit => 'W', title => "Power DC"},
 0x2601 => { path => 'counter.totaldischarge', unit => 'kWh', factor => 0.001 },
 0x2622 => { path => 'counter.dailydischarge', unit => 'kWh', factor => 0.001 , title => "Daily Discharge" },
 0x263F => { path => 'immediate.gridusage', unit => 'W' , title => "Grid Usage"},
 0x295A => { path => 'immediate.soc', unit => '%' , title => "Battery State of Charge"},
 0x411E => { path => 'system.nominalpowerstatus'},
 0x411F => { path => 'immediate.system.warning'},
 0x4120 => { path => 'immediate.system.powerfault'},
 0x4164 => { path => 'immediate.ac.contactstatus'},
 0x4166 => { path => 'immediate.ac.feedinwaittime', unit => 's'},
 0x451F => { path => 'immediate.dc.voltage', unit => 'V', factor => 0.01 },
 0x4521 => { path => 'immediate.dc.amperage', unit => 'A', factor => 0.001 },
 0x4623 => { path => 'unknown.counter.total.generation', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4624 => { path => 'unknown.counter.total.feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4625 => { path => 'unknown.counter.total.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4626 => { path => 'unknown.counter.total.consumption', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4627 => { path => 'unknown.counter.day,feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4628 => { path => 'unknown.counter.day.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x462E => { path => 'immediate.operatingtime',unit => 's'},
 0x462F => { path => 'counter.feedintime',unit => 's'},
 0x4631 => { path => 'unknown.grid.failure'},
 0x4635 => { path => 'unknown.grid.total.generation', unit => 'W'},
 0x4636 => { path => 'counter.total.feedin', unit => 'W'},
 0x4637 => { path => 'counter.total.usage', unit => 'W'},
 0x4639 => { path => 'unknown.grid.total.consumption', unit => 'W'},
 0x463A => { path => 'unknown.grid.power.feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x463B => { path => 'unknown.grid.power.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4640 => { path => 'immediate.ac.power.phaseA', unit => 'W'},
 0x4641 => { path => 'immediate.ac.power.phaseB', unit => 'W'},
 0x4642 => { path => 'immediate.ac.power.phaseC', unit => 'W'},
 0x4648 => { path => 'immediate.ac.voltage.phaseA', unit => 'V', factor => 0.01 },
 0x4649 => { path => 'immediate.ac.voltage.phaseB', unit => 'V', factor => 0.01 },
 0x464A => { path => 'immediate.ac.voltage.phaseC', unit => 'V', factor => 0.01 },
 0x464B => { path => 'immediate.ac.powerfactor.phaseA', unit => '%'},
 0x464C => { path => 'immediate.ac.powerfactor.phaseB', unit => '%'},
 0x464D => { path => 'immediate.ac.powerfactor.phaseC', unit => '%'},
 0x464E => { path => 'unknown.something', unit => '?'},
 0x4650 => { path => 'unknown.grid.current.phaseA', unit => 'A', factor => 0.001 },
 0x4651 => { path => 'unknown.grid.current.phaseB', unit => 'A', factor => 0.001 },
 0x4652 => { path => 'unknown.grid.current.phaseC', unit => 'A', factor => 0.001 },
 0x4653 => { path => 'immediate.ac.current.phaseA', unit => 'A', factor => 0.001 },
 0x4654 => { path => 'immediate.ac.current.phaseB', unit => 'A', factor => 0.001 },
 0x4655 => { path => 'immediate.ac.current.phaseC', unit => 'A', factor => 0.001 },
 0x4657 => { path => 'immediate.ac.frequency', unit => 'Hz', factor => 0.01 },
 0x46AA => { path => 'unknown.counter.ownconsumption', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x46AB => { path => 'unknown.power.ownconsumption'},
 0x491E => { path => 'unknown.battery.counter.charges'},
 0x4922 => { path => 'battery.cells.maxtemperature', unit => 'ºC', factor => 0.1 },
 0x4923 => { path => 'battery.cells.mintemperature', unit => 'ºC', factor => 0.1 },
 0x4924 => { path => 'unknown.battery.cells'},
 0x4926 => { path => 'unknown.battery.total.charge', unit => 'Ah'},
 0x4927 => { path => 'unknown.battery.total.discharge', unit => 'Ah'},
 0x4933 => { path => 'battery.cells.setcharging.voltage', unit => 'V', factor => 0.01 },
 0x495B => { path => 'immediate.batterytemperature', unit => 'ºC' , factor => 0.1 , title => "Battery Temperature" },
 0x495C => { path => 'battery.system.voltage', unit => 'V', factor => 0.01 },
 0x495D => { path => 'battery.system.current', unit => 'A', factor => 0.001 },
 0x821E => { path => 'settings.system.name'},
 0x821F => { path => 'static.mainmodel'},
 0x8220 => { path => 'static.systemtype'},
 0x8234 => { path => 'static.softwareversion'},
 0x832A => { path => 'unknown.system.maximumpoweroutput'},

 };
    my $code = $$typeInformation{$number} || { path => 'type.unknown.'.sprintf("0x%04x",$number) };

    return $code;
}
