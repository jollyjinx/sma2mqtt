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

use constant USER_TYPE_ADMIN        => 0xBB;
use constant USER_TYPE_USER         => 0x88;
use constant MAXIMUM_PACKET_SIZE    => scalar 90000;
use constant TIMEOUT_RECEIVE        => scalar 2;

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
my $mqttsender = lc((split(/\./,$hostname))[0]);

my $mqtt = Net::MQTT::Simple->new("10.112.10.3") || die "Can't create mqtt client";
my $mqttprefix = "test";



my  $socket = new IO::Socket::INET (PeerHost => $hostname,
                                    PeerPort => $portnumber,
                                    Proto => 'udp',
                                    Timeout => 2)                                   || die "Can't open socket due to:$!\n";
    $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', TIMEOUT_RECEIVE, 0))  || die "error setting SO_RCVTIMEO: $!";


my $sessionid   = sprintf '1234 %04x 4321',int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';

#    "0000 0052 0048 4600 ffff 4600 ",   # multivalues if first
#    "0000 0051 0048 4600 ffff 4600 ",   # normal values

my @commandarguments = (

[0x00, 0x00, 0x00, 0x51, 0x00410000, 0x0041ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00420000, 0x0042ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00430000, 0x0043ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00440000, 0x0044ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00450000, 0x0045ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00460000, 0x0046ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00470000, 0x0047ffff ],
#[0x00, 0x00, 0x00, 0x51, 0x00480000, 0x0048ffff ],
);

my @commandarguments2 = (

[0x00, 0x00, 0x00, 0x51, 0x00263f00, 0x00263fff ],#    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
[0x00, 0x00, 0x00, 0x51, 0x00295a00, 0x00295aff ],#    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
[0x00, 0x00, 0x00, 0x51, 0x00411e00, 0x004120ff ],#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
[0x00, 0x00, 0x00, 0x51, 0x00463600, 0x004637ff ],#    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
[0x00, 0x00, 0x00, 0x51, 0x00464000, 0x004642ff ],#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
[0x00, 0x00, 0x00, 0x51, 0x00464800, 0x004655ff ],#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#[0x00, 0x00, 0x00, 0x51, 0x00464800, 0x0046ffff ],
[0x00, 0x00, 0x00, 0x51, 0x00465700, 0x004657ff ],#    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
[0x00, 0x00, 0x00, 0x51, 0x00491e00, 0x00495dff ],#    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
[0x00, 0x00, 0x00, 0x51, 0x00495b00, 0x00495bff ],#    "0000 0051 005B 4900 ff5b 4900 ",   # temperature battery:
[0x00, 0x00, 0x00, 0x51, 0x00832a00, 0x00832aff ],#    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2
[0x00, 0x00, 0x00, 0x52, 0x00237700, 0x00237702 ],
[0x00, 0x00, 0x00, 0x52, 0x00237700, 0x002377ff ],#    "0000 0052 0077 2300 ff77 2300 ",   # external inverter temperature
[0x00, 0x00, 0x00, 0x52, 0x00464800, 0x0046ffff ],
[0x00, 0x00, 0x00, 0x53, 0x00251e00, 0x00251eff ],
[0x00, 0x00, 0x00, 0x53, 0x00251e02, 0x00251eff ],
[0x00, 0x00, 0x00, 0x54, 0x00260100, 0x002622ff ],#    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL daily yield
[0x00, 0x00, 0x00, 0x54, 0x00462e00, 0x00462fff ],#    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM
[0x00, 0x00, 0x00, 0x58, 0x00821e00, 0x008220ff ],#    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
[0x00, 0x00, 0x00, 0x58, 0x00823400, 0x008234ff ],#    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION
[0x00, 0x00, 0x80, 0x51, 0x00214800, 0x002148ff ],#    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
[0x00, 0x00, 0x80, 0x51, 0x00416400, 0x004164ff ],#    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
[0x00, 0x00, 0x80, 0x53, 0x00251e00, 0x00251eff ],#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
[0x00, 0x00, 0x80, 0x53, 0x00251e01, 0x00251e01 ],
[0x00, 0x00, 0x80, 0x53, 0x00251e02, 0x00251e02 ],
[0x00, 0x00, 0x80, 0x53, 0x00451f00, 0x004521ff ],#    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
#[0x00, 0x00, 0x02, 0x64, 0x00618d00, 0x00618dff ],
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

if(1)
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

sub string2command
{
    my($string) = @_;
    $string =~ s/\s//g;

    my $commandpacket = pack('H*',$string);
    my @command = unpack('CCCCVV',$commandpacket);

    #printf "string2command $string -> %02x %02x %02x %02x %08x %08x\n",@command;

    printf "[0x%02x, 0x%02x, 0x%02x, 0x%02x, 0x%08x, 0x%08x ],\n",@command;
    return @command;
}

sub command2string
{
    my @command = @_;

    my $commandpacket = pack('CCCCVV',@command);
    my $string = unpack('H*',$commandpacket);

#    printf "command2string %02x %02x %02x %02x %08x %08x -> $string\n",@command;

    return $string;
}


my $loggedin = 0;
my $loop     = 1;
my $commandwaittime = 0.1;
my $looptime = 5;
do
{
    my @work = @commandarguments;

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

    jnxsleep($looptime) if $loop;
}
while( $loop );

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

    $data = substr($data,0,18 + 4 + $length);


    if(     $smaheader != 0x534d4100
        )
    {
        printf "%s: invalid packet: prefix:%0x header:%0x len:%d data:%s\n",$prefix,$smaheader,$proto,$length,prettyhexdata($data);
        return undef;
    }


    if(     $proto     != 0x6065
        )
    {
        printf "%s SMA packet: prefix:%0x header:%0x len:%d data:%s\n",$prefix,$smaheader,$proto,$length,prettyhexdata($data);
        return undef;
    }

    my $footer      = unpack('N',substr($data,-4));

    if( $footer    != 0x0 )
    {
        print "Invalid footer\n";
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

    my $resultnumber = 0;
    FOOTERPARSING: while( length($footer) > 7 )
    {
        print "\n";
        my $number = unpack('C',substr($footer,0,1));
        my $code = unpack('v',substr($footer,1,2));
        my $type = unpack('C',substr($footer,3,1));
        my $time  = unpack('V',substr($footer,4,4));
        my $timestring = POSIX::strftime('%Y-%m-%dT%H:%M:%S',localtime($time));
        my $typelength = 40;

        my $year = substr($timestring,0,4);
        if( $time ne 0 && $year !~ m/^(?:1970|2021|2022)$/o )
        {
            printf "Weird time %s raw: %s\n",$timestring,prettyhexdata( substr($footer,0,60) ).'...';
#            $footer = substr($footer,1);
#            next FOOTERPARSING;
        }

        my  $typeinformation = code2Typeinformation($code);
        my  $name = $$typeinformation{name};

        my  $unit = $$typeinformation{unit};
        my  $factor = $$typeinformation{factor}|| 1;
        my  $path = $name.'.'.$resultnumber;
        $resultnumber++;

            $name .= '.'.$number if $number > 0 && $number <7;
            $name .= ' ('.$$typeinformation{unit}.')' if $$typeinformation{unit};


#        print "\nFooter DATA:".prettyhexdata(substr($footer,0,40))."\n";

        printf "%s%s Code:0x%04x-0x%04x No:0x%02x Type:0x%02x %s %27s ",' ' x 7,$source,$command,$code,$number,$type,$timestring,$name;

        ##### TYPE decoding

        if( $type == 0x00 || $type == 0x40 )    # integer
        {
            my  @values = map { unpack('V',substr($footer,8+(4*$_),4)) } (0..8);
            my $shortmarker = @values[1];
            my $longmarker = @values[4];

            if(         @values[0] == 0x0       # version number scheme
                    &&  @values[1] == 0x0
                    &&  @values[2] == 0xFFFFFFFE
                    &&  @values[3] == 0xFFFFFFFE
                    &&  @values[4] == @values[5]
                    &&  @values[6] == 0x0
                    &&  @values[7] == 0x0
                )
            {
                $typelength = 40;
                @values = unpack('C*',pack('N',@values[4]));
            }
            elsif(      $longmarker == 1
                    ||  ($longmarker == 0 && @values[2] == 0 && @values[3] == 0)
                )
            {
                $typelength = 28;
                splice(@values,4);
                splice(@values,1)  if '' eq join('',map { @values[$_-1] == @values[0] ? '' : 'somevalue' } (1..@values) );  # print one value if all are same
            }
            elsif(      $shortmarker == 0
#                    &&  @values[0] == @values[1]
#                    &&  @values[0] == @values[2]
#                    &&  @values[0] == @values[3]
                )
            {
                splice(@values,1);
                $typelength = 16;
            }
            else
            {
               print "\nFooter DATA:".prettyhexdata(substr($footer,0,40))."\n";
               print "Weird";
                $footer = substr($footer,1);
            }

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

            sendMQTT($path,$unit,$factor,@results);

        }
        elsif( $type == 0x10 )      # string
        {
            my $value = unpack('Z*',substr($footer,8,32));

            printf "%30s ",$value;
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

sub sendMQTT
{
    my($path,$unit,$factor,@values) = @_;

    return if !$mqttsender;
    my $topic = join('/', ($mqttprefix,$mqttsender,split(/\./,$path)) );

    $topic =~ s/\/(\d+)$/_$1/;

    my @outvalues = map { $_ eq 'NaN' ? 'null' : $_ * $factor } @values;


    print "\nMqtt: device:$mqttsender path:$path topic:$topic unit:$unit value:@values @outvalues\n";


    if( @outvalues > 1 )
    {
        $mqtt->publish($topic => '{"unit":"'.$unit.'","value":"'.join(':',@outvalues).'"}' );
    }
    else
    {
        $mqtt->publish($topic => '{"unit":"'.$unit.'","value":'.@outvalues[0].'}' );
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

 my $typeInformation = {

 0x2148 => { name => 'immediate.system.status'},
 0x2377 => { name => 'immediate.system.externaltemperature'},
 0x251E => { name => 'immediate.dc.power', unit => 'W'},
 0x2601 => { name => 'counter.totaldischarge', unit => 'kWh', factor => 0.001 },
 0x2622 => { name => 'counter.dailyyield', unit => 'kWh', factor => 0.001 },
 0x263F => { name => 'immediate.gridusage', unit => 'W' },
 0x295A => { name => 'immediate.soc', unit => '%' },
 0x411E => { name => 'system.nominalpowerstatus'},
 0x411F => { name => 'immediate.system.warning'},
 0x4120 => { name => 'immediate.system.powerfault'},
 0x4164 => { name => 'immediate.ac.contactstatus'},
 0x4166 => { name => 'immediate.ac.feedinwaittime', unit => 's'},
 0x451F => { name => 'immediate.dc.voltage', unit => 'V', factor => 0.01 },
 0x4521 => { name => 'immediate.dc.amperage', unit => 'A', factor => 0.001 },
 0x4623 => { name => 'unknown.maybe.counter.total.generation', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4624 => { name => 'unknown.maybe.counter.total.feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4625 => { name => 'unknown.maybe.counter.total.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4626 => { name => 'unknown.maybe.counter.total.consumption', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4627 => { name => 'unknown.maybe.counter.day,feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4628 => { name => 'unknown.maybe.counter.day.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x462E => { name => 'immediate.operatingtime',unit => 's'},
 0x462F => { name => 'counter.feedintime',unit => 's'},
 0x4631 => { name => 'type.unknown.maybe.grid.failure'},
 0x4635 => { name => 'type.unknown.maybe.grid.total.generation', unit => 'W'},
 0x4636 => { name => 'counter.total.feedin', unit => 'W'},
 0x4637 => { name => 'counter.total.usage', unit => 'W'},
 0x4639 => { name => 'unknown.maybe.grid.total.consumption', unit => 'W'},
 0x463A => { name => 'unknown.maybe.grid.power.feedin', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x463B => { name => 'unknown.maybe.grid.power.usage', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x4640 => { name => 'immediate.ac.power.phaseA', unit => 'W'},
 0x4641 => { name => 'immediate.ac.power.phaseB', unit => 'W'},
 0x4642 => { name => 'immediate.ac.power.phaseC', unit => 'W'},
 0x4648 => { name => 'immediate.ac.voltage.phaseA', unit => 'V', factor => 0.01 },
 0x4649 => { name => 'immediate.ac.voltage.phaseB', unit => 'V', factor => 0.01 },
 0x464A => { name => 'immediate.ac.voltage.phaseC', unit => 'V', factor => 0.01 },
 0x464B => { name => 'immediate.ac.powerfactor.phaseA', unit => '%'},
 0x464C => { name => 'immediate.ac.powerfactor.phaseB', unit => '%'},
 0x464D => { name => 'immediate.ac.powerfactor.phaseC', unit => '%'},
 0x464E => { name => 'unknown.maybe.something', unit => '?'},
 0x4650 => { name => 'unknown.maybe.grid.current.phaseA', unit => 'A', factor => 0.001 },
 0x4651 => { name => 'unknown.maybe.grid.current.phaseB', unit => 'A', factor => 0.001 },
 0x4652 => { name => 'unknown.maybe.grid.current.phaseC', unit => 'A', factor => 0.001 },
 0x4653 => { name => 'immediate.ac.current.phaseA', unit => 'A', factor => 0.001 },
 0x4654 => { name => 'immediate.ac.current.phaseB', unit => 'A', factor => 0.001 },
 0x4655 => { name => 'immediate.ac.current.phaseC', unit => 'A', factor => 0.001 },
 0x4657 => { name => 'immediate.ac.frequency', unit => 'Hz', factor => 0.01 },
 0x46AA => { name => 'type.unknown.maybe.counter.ownconsumption', unit => 'kWh', factor => ( 1.0 / 3600000 ) },
 0x46AB => { name => 'type.unknown.maybe.power.ownconsumption'},
 0x491E => { name => 'type.unknown.maybe.battery.counter.charges'},
 0x4922 => { name => 'battery.cells.maxtemperature', unit => 'ºC', factor => 0.1 },
 0x4923 => { name => 'battery.cells.mintemperature', unit => 'ºC', factor => 0.1 },
 0x4924 => { name => 'type.unknown.maybe.battery.cells'},
 0x4926 => { name => 'type.unknown.maybe.battery.total.charge', unit => 'Ah'},
 0x4927 => { name => 'type.unknown.maybe.battery.total.discharge', unit => 'Ah'},
 0x4933 => { name => 'battery.cells.setcharging.voltage', unit => 'V', factor => 0.01 },
 0x495B => { name => 'immediate.batterytemperature', unit => 'ºC' , factor => 0.1 },
 0x495C => { name => 'battery.system.voltage', unit => 'V', factor => 0.01 },
 0x495D => { name => 'battery.system.current', unit => 'A', factor => 0.001 },
 0x821E => { name => 'settings.system.name'},
 0x821F => { name => 'static.mainmodel'},
 0x8220 => { name => 'static.systemtype'},
 0x8234 => { name => 'static.softwareversion'},
 0x832A => { name => 'unknown.maybe.system.maximumpoweroutput'},

 };
    my $code = $$typeInformation{$number} || { name => 'type.unkown.'.sprintf("0x%04x",$number) };

    return $code;
}
