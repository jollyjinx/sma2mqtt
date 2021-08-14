#!/usr/bin/perl
#
# author:   @jollyjinx (Patrick Stein)
# purpose:  trying to figure out the udp based sma inverter protocol
#

use strict;
use utf8;
use IO::Socket::INET;
use POSIX;

use constant USER_TYPE_ADMIN        => 0xBB;
use constant USER_TYPE_USER         => 0x88;
use constant MAXIMUM_PACKET_SIZE    => scalar 90000;
use constant TIMOUT_RECEIVE         => scalar 2;

if( @ARGV == 1 )
{
    dumpFile(@ARGV);
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


my $sessionid   = sprintf '1234 %04x 4321',0; # int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';

my @commands = (
#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3

#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3

#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2

#    "0000 0052 0048 4600 ffff 4600 ",   # multivalues if first
#    "0000 0051 0048 4600 ffff 4600 ",   # values over time

 #   "0000 0053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
#    "0000 0053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2


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
#    "0000 0264 008d 6100 ff8d 6100 ",   # sbftest: logout


    #"0C04 fdff ffffffff ",   # logout, shuts down socket for quite some time
    );



my $loggedin = 0;

#while(1)
{
    my @work = @commands;

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
            my $command = shift @work;

            $response = sendReceiveCommand($socket,$command,$sessionid,$inverterid);

            if( $response == 0x0017 || $response == 0x0102 )
            {
                # unshift(@work,$command);
                $loggedin = 0;
            }
        }

        jnxsleep(.5);
    }
    jnxsleep(5);
}
exit;


sub sendReceiveCommand
{
    my($socket,$command,$sessionid,$inverterid) = @_;
    my $data;

    sendCommand($socket,$command,$sessionid,$inverterid);
	$socket->recv($data, MAXIMUM_PACKET_SIZE);

    if( 0 == length($data) )
    {
        print "no response.\n";
        return undef;
    }

    writeDataToFile($data);
    my $response = printSMAPacket('recv',$data);

    print "\n\n";
    return $response;
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
                        .'0000 0000'
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

    my $size = $socket->send($data);

    writeDataToFile($data);
    printSMAPacket('sent',$data);
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

    printf "%5s SMAPacket: %s\n",$prefix,prettyhexdata(substr($data,0,18));

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
        my $packetflag  = unpack('v',substr($data,22,2)) & 0x8000 ? '1' : '0';

        printf "command:%04x response:%04x: source:%s destination:%s pktflg:%s pktid:0x%04x ",$command,$response,$source,$destination,$packetflag,$packetid;

        if( $response != 0 || $command == 0xFFFD )
        {
            printf "raw:%s\n",prettyhexdata($data);
            return $response;
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
    my $command = unpack('v',substr($data,26,2));

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

        printf "%s%s Code:0x%04x-0x%04x No:0x%02x Type:0x%02x %s %27s ",' ' x 7,$source,$command,$code,$number,$type,$timestring,code2Name($code);

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
            printf "%30s ",join(':',@results);
        }
        elsif( $type == 0x10 )      # string
        {
            $typelength = 40;
            my $value = unpack('Z*',substr($footer,8,32));

            printf "%30s ",$value;
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

            printf "%30s ",join('.',@values);
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

sub code2Name
{
    my($code) = @_;

 my %codes = (
 0x2148 => 'system.status',
 0x2377 => 'system.temperature',
 0x251E => 'dc.power (W)',
 0x2601 => 'counter.total.yield (Wh)',
 0x2622 => 'counter.day.yield (Wh)',
 0x263F => 'counter.total.feedin',
 0x295A => 'bat.system.soc (%)',
 0x411E => 'system.nominalpowerstatus',
 0x411F => 'system.warning',
 0x4120 => 'system.powerfault',
 0x4164 => 'grid.contactstatus',
 0x4166 => 'grid.feedinwaittime',
 0x451F => 'cd.voltage (cV)',
 0x4521 => 'cd.amperage (mA)',
 0x4623 => 'counter.total.generation (Wh)',
 0x4624 => 'counter.total.feedin (Wh)',
 0x4625 => 'counter.total.usage (Wh)',
 0x4626 => 'counter.total.consumption (Wh)',
 0x4627 => 'counter.day,feedin',
 0x4628 => 'counter.day.usage',
 0x462E => 'counter.operatingtime',
 0x462F => 'counter.feedintime',
 0x4631 => 'grid.failure',
 0x4635 => 'grid.total.generation (W)',
 0x4636 => 'grid.total.feedin (W)',
 0x4637 => 'grid.total.usage (W)',
 0x4639 => 'grid.total.consumption (W)',
 0x463A => 'grid.power.feedin (Wh)',
 0x463B => 'grid.power.usage (Wh)',
 0x4640 => 'grid.power.phaseA (W)',
 0x4641 => 'grid.power.phaseB (W)',
 0x4642 => 'grid.power.phaseC (W)',
 0x4648 => 'grid.voltage.phaseA (cV)',
 0x4649 => 'grid.voltage.phaseB (cV)',
 0x464A => 'grid.voltage.phaseC (cV)',
 0x464B => 'grid.cosphi.phaseA (%)',
 0x464C => 'grid.cosphi.phaseB (%)',
 0x464D => 'grid.cosphi.phaseC (%)',
 0x4650 => 'grid.current.phaseA (mA)',
 0x4651 => 'grid.current.phaseB (mA)',
 0x4652 => 'grid.current.phaseC (mA)',
 0x4653 => 'grid.current.phaseA2 (mA)',
 0x4654 => 'grid.current.phaseB2 (mA)',
 0x4655 => 'grid.current.phaseC2 (mA)',
 0x4657 => 'grid.frequency (cHz)',
 0x46AA => 'counter.ownconsumption (Wh)',
 0x46AB => 'power.ownconsumption',
 0x491E => 'bat.counter.charges',
 0x4922 => 'bat.cells.maxtemperature (ºdC) ',
 0x4923 => 'bat.cells.mintemperature (ºdC) ',
 0x4924 => 'bat.cells.type.unkown          ',
 0x4933 => 'bat.cells.setcharging.voltage(cV)',
 0x4926 => 'bat.total.charge (Ah)          ',
 0x4927 => 'bat.total.discharge (Ah)       ',
 0x495B => 'bat.system.temperature (ºdC)   ',
 0x495C => 'bat.system.voltage (cV)        ',
 0x495D => 'bat.system.current (mA)        ',
 0x821E => 'system.name',
 0x821F => 'system.mainmodel',
 0x8220 => 'system.type',
 0x8234 => 'system.softwareversion',
 0x832A => 'system.maximumpoweroutput',
 );
    my $name = ''.$codes{$code};
       $name =~ s/\s*$//;
    return $name || 'type.unkown';
}
