#!/usr/bin/perl

use strict;
use utf8;
use IO::Socket::INET;
use POSIX;

use constant USER_TYPE_ADMIN        => 0xBB;
use constant USER_TYPE_USER         => 0x88;
use constant MAXIMUM_PACKET_SIZE    => scalar 90000;
use constant TIMOUT_RECEIVE         => scalar 2;

if(@ARGV == 1)
{
    my($filename) = @ARGV;

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
    exit;
}

die "Usage $0 <inputfilename> or <inverter host> <password> [outputfilename]\n" unless @ARGV >= 2;

my ($hostname,$password,$filename) = @ARGV;
my $portnumber = 9522;
my $usertype   = USER_TYPE_USER;

my  $socket = new IO::Socket::INET (PeerHost => $hostname,
                                    PeerPort => $portnumber,
                                    Proto => 'udp',
                                    Timeout => 2)                                   || die "Can't open socket due to:$!\n";
    $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', TIMOUT_RECEIVE, 0))   || die "error setting SO_RCVTIMEO: $!";

my $filehandle = undef;
if( length $filename )
{
    open( $filehandle, ">>", $filename) || die "Can't open $filename for appending due to:$!";
    binmode $filehandle;
}

my $sessionid   = sprintf '1234 %04x 4321',int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';

my @commands = (
    "0C04 fdff 07000000 84030000 4c20cb51 00000000".encodePassword($password),  # login

#    "0000 0052 0000 4600 FFFF 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3

#    "0000 0051 0000 2900 ffff 2900 ",   # BatteryInfo:
#    "0000 0051 0000 2a00 ffff 2a00 ",   # BatteryInfo:
#    "0000 0051 0000 4100 ffff 4100 ",   # BatteryInfo:
#    "0000 0052 0000 4900 ffff 4900 ",   # BatteryInfo:
#    "0000 0053 0000 4900 ffff 4900 ",   # BatteryInfo:
#    "0000 0054 0000 4900 ffff 4900 ",   # BatteryInfo:

#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 0248 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 0149 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014A 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014B 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014C 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014D 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014E 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 014F 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0148 4600 0150 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3

#
    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2
    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
    "0000 0052 0077 2300 ff77 2300 ",   # InverterTemperature:
    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL
    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM
    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION
    "0000 0264 008d 6100 ff8d 6100 ",   # sbftest:
#

    #"0C04 fdff ffffffff ",   # logout, shuts down socket for quite some time
    );


for my $command (@commands)
{
    my $data;

    sendCommand($socket,$command,$sessionid,$inverterid);
	$socket->recv($data, MAXIMUM_PACKET_SIZE);

	my $size = length($data);

    if( 0 == $size )
    {
        print "no response.\n";
        next;
    }
    print $filehandle $data if $filehandle;
    printSMAPacket('recv',$data);
}

close($filehandle);
exit;

sub sendCommand
{
    my($socket,$smanet_command,$sessionid,$inverterid) = @_;

    my $smanet_prefix = "00A0"
                        .$inverterid
                        .( $inverterid eq 'ffff ffff ffff' ? '0001' : '0001')
                        .$sessionid
                        .( $inverterid eq 'ffff ffff ffff' ? '0001' : '0001')
                        .'0000 0000'
                        .'0080' # packet id
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

    sleep(1);
    my $size = $socket->send($data);
    print $filehandle $data if defined $filehandle;
    printSMAPacket('sent',$data);
}


sub prettyhexdata
{
    my ($data) = @_;
    my $prettyreceived = unpack('H*',$data);
       $prettyreceived =~ s/(....)/$1 /g;
    return $prettyreceived;
}

sub printSMAPacket
{
    my($prefix,$data) = @_;

    my $smaheader   = unpack('N',substr($data,0,4));
    my $proto       = unpack('n',substr($data,16,2));
    my $length      = unpack('C',substr($data,18,1)) * 4;
    my $expectedlen = length($data) -18 - 4;
    my $footer      = unpack('N',substr($data,-4));

    if(     $smaheader != 0x534d4100
        ||  $proto     != 0x6065
        ||  $footer    != 0x0
        ||  $length    != $expectedlen
        )
    {
        printf "%s: invalid SMA packet: %0x %0x %d=%d %0x %s\n",$prefix,$smaheader,$proto,$length,$expectedlen,$footer,prettyhexdata($data);
        return undef;
    }

    printf "\n\n%5s SMAPacket: %s\n",$prefix,prettyhexdata(substr($data,0,18));

    my $smanetdata  = substr($data,18,$length);

    printSMANetPacket($smanetdata);
}

sub printSMANetPacket
{
    my($data) = @_;

    print "      SMANet Packet:";

    {
        my $smanet_length = unpack('C',substr($data,0,1)) * 4;

        if(    length($data) < 2
            || length($data) != $smanet_length
            || $smanet_length < 32
          )
        {
            printf "Invalid SMANet packet: %d != %d < 32 :%s\n",$smanet_length,length($data),prettyhexdata($data);
            return undef;
        }
    }

    {
        my $response    = unpack('v',substr($data,18,2));
        my $command     = unpack('v',substr($data,26,2));
        my $destination = unpack('H*',substr($data,2,6));
        my $source      = unpack('H*',substr($data,10,6));
        my $packetid    = unpack('v',substr($data,22,2)) & 0x7FFF;
        my $direction   = unpack('v',substr($data,22,2)) & 0x8000 ? 'OK' : 'FAIL' ;

        printf "%s command:%04x response:%04x: source:%s destination:%s pktid:0x%04x ",$direction,$command,$response,$source,$destination,$packetid;

        if( $response != 0 || $command == 0xFFFD )
        {
            printf "raw:%s\n",prettyhexdata($data);
            return undef;
        }
    }

    {
        my $valuetype   = unpack('V',substr($data,28,4));
        my $valuecount  = unpack('V',substr($data,32,4));

        my $header = substr($data,0,36);

        printf "type:0x%08x count:0x%08x raw:%s\n",$valuetype,$valuecount,prettyhexdata($header);
    }

    my $footer  = substr($data,36);
    my $source  = unpack('H*',substr($data,10,6));

    FOOTERPARSING: while( length($footer) > 7 )
    {
        my $number = unpack('C',substr($footer,0,1));
        my $code = unpack('v',substr($footer,1,2));
        my $type = unpack('C',substr($footer,3,1));
        my $time  = unpack('V',substr($footer,4,4));
        my $timestring = POSIX::strftime('%Y-%m-%dT%H:%M:%S',localtime($time));
        my $typelength = 28;

        if( $time ne 0 && '2021' ne substr($timestring,0,4) )
        {
            printf "Weird time %s raw: %s\n",$timestring,prettyhexdata($footer);
            $footer = substr($footer,1);
            next FOOTERPARSING;
        }

        printf "%s%s Code:0x%04x No:0x%02x Type:0x%02x %s %27s",' ' x 7,$source,$code,$number,$type,$timestring,code2Name($code);

        $type = 0x08 if $code == 0x8234;

        ##### TYPE decoding

        if( $type == 0x00 || $type == 0x40 )        # integer
        {
            my $value1  = unpack('V',substr($footer,8,4));
            my $value2  = unpack('V',substr($footer,12,4));
            my $value3  = unpack('V',substr($footer,16,4));
            my $value4  = unpack('V',substr($footer,20,4));
            my $length28 = unpack('V',substr($footer,24,4));

            my  @values = ($value1,$value2,$value3,$value4);
                @values = ($value1) if '' eq join('',map { $value1 == $_ ? '' : 'ne' } @values);  # print one value if all are same

            unless( ($value1 == 0) && ($value2 == 0) && ($value3 == 0) && ($value4 == 0) && ($length28 == 0) )
            {
                $typelength = 16 if $value2 == 0 && $length28 != 1;
                $typelength = 16 if $value4 == $time;
            }

            splice(@values,1) if $typelength == 16;


            my @results;
            for my $value (@values)
            {
                if( $type == 0x00 )
                {
                    push(@results, $value != 4294967295 ? sprintf("%d",$value) : 'NaN');
                }
                else
                {
                    my $signed = unpack('l',pack('L',$value));
                    push(@results, $signed != -2147483648 ? sprintf("%d",$signed) : 'NaN');
                }
            }
            printf "%20s ",join(':',@results);
        }
        elsif( $type == 0x10 )      # string
        {
            $typelength = 40;
            my $value = unpack('Z*',substr($footer,8,32));

            printf "%20s ",$value;
        }
        elsif( $type == 0x08)      # dotted version
        {
            $typelength = 40;
            my $position = 10;
            my @values = ();

            while( $position < 38)
            {
                my $value = unpack('C',substr($footer,$position+1,1));
                my $end   = unpack('v',substr($footer,$position+2,2));

                push(@values, sprintf("%0d",$value) );

                $position += 4;

                last if $end == 0xfffe;

            }

            printf "%20s ",join('.',@values);
        }
        else
        {
            printf "TYPE %02x UNKOWN ",$type;
            $typelength = 2;
        }
        printf "realtype:0x%02x len:%d raw: %s\n",$type,$typelength,prettyhexdata(substr($footer,0,$typelength));
        $footer = substr($footer,$typelength);
    }

    if ( length( $footer ) > 0 )
    {
            printf "\tFOOTER raw:%s\n",prettyhexdata( $footer );
    }
    return undef;
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
#        printf "%s %d 0x%x %d 0x%x 0x%1X %s\n",substr($password,$index,1),$character,$character,$calculate,$calculate,$calculate,$encoded;
    }
#     print "encoded:".$encoded."\n";
    return $encoded;
}

sub code2Name
{
    my($code) = @_;

 my %codes = (
 0x2148 => 'OperationHealth                ',  #  // *08* Condition (aka INV_STATUS)
 0x2377 => 'CoolsysTmpNom                  ',  #  // *40* Operating condition temperatures
 0x251E => 'DcMsWatt                       ',  #  // *40* DC power input (aka SPOT_PDC1 / SPOT_PDC2)
 0x2601 => 'MeteringTotWhOut               ',  #  // *00* Total yield (aka SPOT_ETOTAL)
 0x2622 => 'MeteringDyWhOut                ',  #  // *00* Day yield (aka SPOT_ETODAY)
 0x263F => 'GridMsTotW                     ',  #  // *40* Power (aka SPOT_PACTOT)
 0x295A => 'bat.system.soc (%)             ',
 0x411E => 'OperationHealthSttOk           ',  #  // *00* Nominal power in Ok Mode (aka INV_PACMAX1)
 0x411F => 'OperationHealthSttWrn          ',  #  // *00* Nominal power in Warning Mode (aka INV_PACMAX2)
 0x4120 => 'OperationHealthSttAlm          ',  #  // *00* Nominal power in Fault Mode (aka INV_PACMAX3)
 0x4164 => 'OperationGriSwStt              ',  #  // *08* Grid relay/contactor (aka INV_GRIDRELAY)
 0x4166 => 'OperationRmgTms                ',  #  // *00* Waiting time until feed-in
 0x451F => 'DcMsVol                        ',  #  // *40* DC voltage input (aka SPOT_UDC1 / SPOT_UDC2)
 0x4521 => 'DcMsAmp                        ',  #  // *40* DC current input (aka SPOT_IDC1 / SPOT_IDC2)
 0x4623 => 'MeteringPvMsTotWhOut           ',  #  // *00* PV generation counter reading
 0x4624 => 'MeteringGridMsTotWhOut         ',  #  // *00* Grid feed-in counter reading
 0x4625 => 'MeteringGridMsTotWhIn          ',  #  // *00* Grid reference counter reading
 0x4626 => 'MeteringCsmpTotWhIn            ',  #  // *00* Meter reading consumption meter
 0x4627 => 'MeteringGridMsDyWhOut	       ',  #  // *00* ?
 0x4628 => 'MeteringGridMsDyWhIn           ',  #  // *00* ?
 0x462E => 'MeteringTotOpTms               ',  #  // *00* Operating time (aka SPOT_OPERTM)
 0x462F => 'MeteringTotFeedTms             ',  #  // *00* Feed-in time (aka SPOT_FEEDTM)
 0x4631 => 'MeteringGriFailTms             ',  #  // *00* Power outage
 0x4635 => 'MeteringPvMsTotWOut            ',  #  // *40* PV power generated
 0x4636 => 'MeteringGridMsTotWOut          ',  #  // *40* Power grid feed-in
 0x4637 => 'MeteringGridMsTotWIn           ',  #  // *40* Power grid reference
 0x4639 => 'MeteringCsmpTotWIn             ',  #  // *40* Consumer power
 0x463A => 'MeteringWhIn                   ',  #  // *00* Absorbed energy
 0x463B => 'MeteringWhOut                  ',  #  // *00* Released energy
 0x4640 => 'GridMsWphsA                    ',  #  // *40* Power L1 (aka SPOT_PAC1)
 0x4641 => 'GridMsWphsB                    ',  #  // *40* Power L2 (aka SPOT_PAC2)
 0x4642 => 'GridMsWphsC                    ',  #  // *40* Power L3 (aka SPOT_PAC3)
 0x4648 => 'GridMsPhVphsA                  ',  #  // *00* Grid voltage phase L1 (aka SPOT_UAC1)
 0x4649 => 'GridMsPhVphsB                  ',  #  // *00* Grid voltage phase L2 (aka SPOT_UAC2)
 0x464A => 'GridMsPhVphsC                  ',  #  // *00* Grid voltage phase L3 (aka SPOT_UAC3)
 0x464B => 'GridMsPhVphsA2B6100            ',  #
 0x464C => 'GridMsPhVphsB2C6100            ',  #
 0x464D => 'GridMsPhVphsC2A6100            ',  #
 0x4650 => 'GridMsAphsA_1                  ',  #  // *00* Grid current phase L1 (aka SPOT_IAC1)
 0x4651 => 'GridMsAphsB_1                  ',  #  // *00* Grid current phase L2 (aka SPOT_IAC2)
 0x4652 => 'GridMsAphsC_1                  ',  #  // *00* Grid current phase L3 (aka SPOT_IAC3)
 0x4653 => 'GridMsAphsA                    ',  #  // *00* Grid current phase L1 (aka SPOT_IAC1_2)
 0x4654 => 'GridMsAphsB                    ',  #  // *00* Grid current phase L2 (aka SPOT_IAC2_2)
 0x4655 => 'GridMsAphsC                    ',  #  // *00* Grid current phase L3 (aka SPOT_IAC3_2)
 0x4657 => 'GridMsHz                       ',  #  // *00* Grid frequency (aka SPOT_FREQ)
 0x46AA => 'MeteringSelfCsmpSelfCsmpWh     ',  #  // *00* Energy consumed internally
 0x46AB => 'MeteringSelfCsmpActlSelfCsmp   ',  #  // *00* Current self-consumption
 0x46AC => 'MeteringSelfCsmpSelfCsmpInc    ',  #  // *00* Current rise in self-consumption
 0x46AD => 'MeteringSelfCsmpAbsSelfCsmpInc ',  #  // *00* Rise in self-consumption
 0x46AE => 'MeteringSelfCsmpDySelfCsmpInc  ',  #  // *00* Rise in self-consumption today
 0x491E => 'BatDiagCapacThrpCnt            ',  #  // *40* Number of battery charge throughputs
 0x4922 => 'bat.cells.maxtemperature (ºdC) ',
 0x4923 => 'bat.cells.mintemperature (ºdC) ',
 0x4924 => 'bat.cells.??                   ',
 0x4933 => 'bat.cells.setcharging.voltage(cV)',
 0x4926 => 'bat.total.charge (Ah)          ',
 0x4927 => 'bat.total.discharge (Ah)       ',
 0x495B => 'bat.system.temperature (ºdC)   ',
 0x495C => 'bat.system.voltage (cV)        ',
 0x495D => 'bat.system.current (mA)        ',
 0x821E => 'system.name                    ',  #  // *10* Device name (aka INV_NAME)
 0x821F => 'NameplateMainModel             ',  #  // *08* Device class (aka INV_CLASS)
 0x8220 => 'NameplateModel                 ',  #  // *08* Device type (aka INV_TYPE)
 0x8221 => 'NameplateAvalGrpUsr            ',  #  // *  * Unknown
 0x8234 => 'NameplatePkgRev                ',  #  // *08* Software package (aka INV_SWVER)
 0x832A => 'InverterWLim                   ',  #  // *00* Maximum active power device (aka INV_PACMAX1_2) (Some inverters like SB3300/SB1200)
 );
    my $name = ''.$codes{$code};
        $name =~ s/\s*$//;
    return $name;
}
