#!/usr/bin/perl
#
# author:   @jollyjinx (Patrick Stein)
# purpose:  trying to figure out the udp based sma inverter protocol
#

use strict;
use utf8;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin/JNX","$FindBin::Bin";

use IO::Socket::INET;
use IO::Socket::Multicast;
use POSIX;
use Data::Dumper;

use constant USER_TYPE_ADMIN        => 0xBB;
use constant USER_TYPE_USER         => 0x88;
use constant MAXIMUM_PACKET_SIZE    => scalar 9000;
use constant TIMOUT_RECEIVE         => scalar 2;

my $historyfile = 0;
if( @ARGV == 1 )
{
    $historyfile = 1;
    dumpFile(@ARGV);
    exit;
}
die "Usage $0 <inputfilename> or <inverter host> <password> [outputfilename]\n" unless @ARGV >= 2;

my ($hostname,$password,$filename) = @ARGV;
my $usertype   = USER_TYPE_USER;



    my $broadcastpacket = "534d4100" . "0004" . "02a0" . "FFFF FFFF 0000 0020" . "0000 0000";
       $broadcastpacket =~ s/ //g;
    my $broadcastdata = pack "H*",$broadcastpacket;




my $multicastgroup      = '239.12.255.254';
my $multicastreceive    = '239.12.255.255';
my $portnumber          = 9522;

#my  $receivesocket = new IO::Socket::INET(
##                                    LocalAddr   => '10.112.16.115',
##                                    LocalAddr => '0.0.0.0',
##                                    LocalAddr   => $multicastgroup,
#                                    LocalAddr => $multicastreceive,
#                                    LocalPort => 9522,
#                                    Proto => 'udp',
#                                    ReuseAddr => 1,
#                                    Broadcast => 0,
#                                    Timeout => 2
#                                    )                                   || die "Can't open socket due to:$!\n";


    my $receivesocket = IO::Socket::Multicast->new(Proto=>'udp',
#                                    PeerHost => $multicastgroup,
#                                    PeerPort => $portnumber,
#                                    LocalAddr   => '10.112.16.115',
                                    LocalAddr => '0.0.0.0',
#                                    LocalAddr   => $multicastgroup,
#                                    LocalAddr => $multicastreceive,
                                    LocalPort => $portnumber,
                                    Timeout => 2,
                                    ReuseAddr => 1,
#                                    Broadcast => 1,
) || die "error creating mcast socket: $!" ;
    $receivesocket->mcast_if('vlan2') || die "no vlan access $!";
    $receivesocket->mcast_ttl(4);

#
#        if( ! fork() )
#        {
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
#            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastgroup:$portnumber");
##            my $size = $receivesocket->mcast_send($broadcastdata,"$multicastreceive:$portnumber");
##            my $size = $receivesocket->send($broadcastdata,0,"$multicastgroup:$portnumber");
#            print "sent $multicastgroup:$portnumber -> size:$size\n";
#
#            exit;
#        }
#    exit;
    $receivesocket->mcast_add($multicastreceive) || die "Couldn't add group: $!\n";
    $receivesocket->mcast_add('239.12.1.87') || die "Couldn't add group: $!\n";
    $receivesocket->mcast_add($multicastgroup) || die "Couldn't add group: $!\n";
    $receivesocket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', TIMOUT_RECEIVE, 0))   || die "error setting SO_RCVTIMEO: $!";

    for my $counter (1..10)
    {
#        $receivesocket->mcast_add($multicastreceive) || die "Couldn't set group: $!\n";

 #       $receivesocket->setsockopt(SOL_SOCKET,SO_BROADCAST,1);
        while( receiveCommand($receivesocket) ){}
    }
exit;



my  $socket = new IO::Socket::INET(
                                    PeerHost => $hostname, # 239.12.255.254
                                    PeerPort => $portnumber,
                                    Proto => 'udp',
                                    Timeout => 2)                                   || die "Can't open socket due to:$!\n";
    $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', TIMOUT_RECEIVE, 0))   || die "error setting SO_RCVTIMEO: $!";


my $sessionid   = sprintf '1234 %04x 4321',0; # int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';


my @commands = (



#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
#    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
#    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2


#    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
#    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
#    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
#    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
#    "0000 0052 0077 2300 ff77 2300 ",   # InverterTemperature:
#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
#    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
#    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL
#    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM



#    "0000 0051 001e 4100 ff20 4100 ",   # MaxACPower:     // INV_PACMAX1, INV_PACMAX2, INV_PACMAX3
#    "0000 0051 001e 4900 ff5d 4900 ",   # BatteryInfo:
#    "0000 0051 002a 8300 ff2a 8300 ",   # MaxACPower2:   // INV_PACMAX1_2
#    "0000 0051 0036 4600 ff37 4600 ",   # MeteringGridMsTotW:
#    "0000 0051 003f 2600 ff3f 2600 ",   # SpotACTotalPower  // SPOT_PACTOT
#    "0000 0051 0040 4600 FF42 4600 ",   # SpotACPower:    // SPOT_PAC1, SPOT_PAC2, SPOT_PAC3
#    "0000 0051 0048 4600 FF55 4600 ",   # SpotACVoltage: // SPOT_UAC1, SPOT_UAC2, SPOT_UAC3, SPOT_IAC1, SPOT_IAC2, SPOT_IAC3
#    "0000 0051 0057 4600 FF57 4600 ",   # SpotGridFrequency // SPOT_FREQ
#    "0000 0051 005a 2900 ff5a 2900 ",   # BatteryChargeStatus:
#    "0000 8051 0048 2100 ff48 2100 ",   # DeviceStatus:   // INV_STATUS
#    "0000 8051 0064 4100 ff64 4100 ",   # GridRelayStatus:   // INV_GRIDRELAY
#    "0000 0052 0077 2300 ff77 2300 ",   # InverterTemperature:
#    "0000 8053 001E 2500 FF1E 2500 ",   # SpotDCPower      // SPOT_PDC1, SPOT_PDC2
#    "0000 8053 001F 4500 FF21 4500 ",   # SpotDCVoltage   // SPOT_UDC1, SPOT_UDC2, SPOT_IDC1, SPOT_IDC2
#    "0000 0054 0001 2600 FF22 2600 ",   # EnergyProduction // SPOT_ETODAY, SPOT_ETOTAL
#    "0000 0054 002e 4600 ff2F 4600 ",   # OperationTime:    // SPOT_OPERTM, SPOT_FEEDTM
#    "0000 0058 001e 8200 ff20 8200 ",   # TypeLabel:    // INV_NAME, INV_TYPE, INV_CLASS
#    "0000 0058 0034 8200 ff34 8200 ",   # SoftwareVersion:  // INV_SWVERSION


#    "0000 0264 008d 6100 ff8d 6100 ",   # sbftest: logout


    #"0C04 fdff ffffffff ",   # logout, shuts down socket for quite some time
);

for my $command (0x51 .. 0x60)
{
    for my $cmdtype (0x20 .. 0x80)
    {
        for my $range (0x00 .. 0xFF)
        {
            push(@commands,''.sprintf("0000 00%02x 00%02x %02x00 FF%02x %02x00 ",$command,$range,$cmdtype,$range,$cmdtype));
        }
    }
}
print join("\n",@commands);
#exit;

my $loggedin = 0;
my $loop     = 0;

do
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

        jnxsleep(.3);
    }

    jnxsleep(5) if $loop;
}
while( $loop );

exit;


sub sendReceiveCommand
{
    my($socket,$command,$sessionid,$inverterid) = @_;
    my $data;

    sendCommand($socket,$command,$sessionid,$inverterid);

    return receiveCommand($socket)
}

sub receiveCommand
{
    my($socket) = @_;

    my $data;

    my $srcpaddr = $socket->recv($data, MAXIMUM_PACKET_SIZE);

    if( 0 == length($data) )
    {
        print "no response.\n";
        return undef;
    }

    if( $srcpaddr )
    {
        my ($port, $ipaddr) = sockaddr_in($srcpaddr);
        print "Read " . (gethostbyaddr($ipaddr, AF_INET) || "UNKNOWN") . ", + " . inet_ntoa($ipaddr) ."\n";
    }
    writeDataToFile($data);
    my $response = printSMAPacket('recv',$data);

    print "\n\n";
    return 1;
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
    if($smaheader != 0x534d4100)
    {
        printf "SMApacket: SMA prefix missing data:%s\n",prettyhexdata($data);
        return undef;
    }

    printf "%s SMApacket: length:%d raw:%s\n",$prefix,length($data),prettyhexdata($data);

    my $smadata = substr($data,4);

    SMADATA: while( length($smadata) >= 4 )
    {
        my $length      = unpack('n',substr($smadata,0,2));
        my $tag         = unpack('n',substr($smadata,2,2));

        printf "SMApacket: Tag:0x%04x length:%d\n",$tag,$length;

        $smadata = substr($smadata,4);

        if( $length > length($smadata) )
        {
            printf "SMApacket: Invalid remaining size:%d\n",length($smadata);
            next SMADATA;
        }

        my $tagdata = substr($smadata,0,$length);
        $smadata = substr($smadata,$length);


        if( $tag == 0x2a0 )  # discovery request
        {
            my $expectedlength = $length;

            if( length($tagdata) < $expectedlength)
            {
                printf "SMApacket: discovery type too short: %d < expected:%d %s\n",length($tagdata),$expectedlength,prettyhexdata($tagdata);
                next SMADATA;
            }

            my $value = unpack('N',substr($tagdata,0,4));

            my %knownvalues = ( 0xffffffff => 'DISCOVERY', 0x0000001 => 'NORMAL' );

            printf "SMApacket: discovery type:0x%08x %s\n",$value, $knownvalues{$value} || 'UNKNOWN.'.$value;

            next SMADATA;
        }

        if( $tag == 0x02C0 )  # group content
        {
            print "SMAPacket: group tag.\n";

            if( length($tagdata) >=4 )
            {
                printf "SMApacket: Group Number 0x%08\n",unpack('N',$tagdata);
            }
            else
            {
                printf "SMApacket: Invalid remaining size:%d\n",length($tagdata);
            }

            next SMADATA;
        }

        if( $tag == 0x0 )  # End of packets
        {
            print "SMAPacket: END tag.\n";

            if( length($tagdata) != 0 )
            {
                printf "SMAPacket: END tag reached but still have data left length:%d\n",length($smadata);
            }
            last SMADATA;
        }

        if( $tag == 0x10 )  # SMAnet
        {
            print "SMAPacket: SMAnet tag.\n";

            if( length($tagdata) < 2 )
            {
                printf "SMAPacket: SMAnet packet. too small: %d data: %s\n",length($tagdata),prettyhexdata($tagdata);
                next SMADATA;
            }

            my $protocolid = unpack('n',substr($tagdata,0,2));
            printf "SMAPacket: SMAnet packet protocol 0x%04x length:%d\n",$protocolid,$length;

            if( $protocolid == 0x6065 )
            {
                printSMANetPacket( substr($tagdata,2) );
                next SMADATA;
            }
            print "SMANetPacket: can't decode protocol - skipping packet\n";
            next SMADATA;
        }

        # unknown tags

        printf "SMAPacket: tag:0x%04x length:%d %s\n",$tag,$length,$length>0 ? 'raw:'.prettyhexdata($tagdata) :'';


    }

    if( length($smadata) > 0 )
    {
        printf "SMApacket: unexpected %dd bytes data at end: %s...\n",length($smadata),prettyhexdata(substr($smadata,0,40));
    }
    print "\n";
}

sub printSMANetPacket
{
    my($data) = @_;

    print "      SMANet Packet:";

    {
        my $smanet_length = unpack('C',substr($data,0,1)) * 4;

        if(    length($data) < 2
            || $smanet_length < 20
            || length($data) != $smanet_length
          )
        {
            printf "weird SMANet packet: %d != %d < 20 :%s\n",$smanet_length,length($data),prettyhexdata($data);
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

    my $footer  = substr($data,36);
    my $source  = unpack('H*',substr($data,10,6));
    my $command = unpack('v',substr($data,26,2));
    my $option1 = unpack('V',substr($data,28,4));
    my $option2 = unpack('V',substr($data,32,4));

    printf "opt1:0x%08x opt2:0x%08x ",$option1,$option2;

    my $shortnumberformat = 0;

    if(
            $option1 == 0x04    # 0100
        ||  $option1 == 0x38    # 1000
        ||  $option1 == 0x3a    # 1010
        ||  $option1 == 0x3b    # 1010
        ||  $option1 == 0x39    # 1001
        )
    {
        print "SHORTNUMBER ";
        $shortnumberformat = 1;
        $footer = substr($data,32);
    }

    print 'raw:'.prettyhexdata(substr($data,28))."\n";

    return undef if $command == 0x2800;



    FOOTERPARSING: while( length($footer) > 7 )
    {
        my $number      = unpack('C',substr($footer,0,1));
        my $code        = unpack('v',substr($footer,1,2));
        my $type        = unpack('C',substr($footer,3,1));
        my $packettime  = unpack('V',substr($footer,4,4));

        my $packet_timestring = POSIX::strftime('%Y-%m-%dT%H:%M:%S',localtime($packettime));
        my $typelength = 40;

        if( $packettime == 0 || abs($packettime - time()) < 1000)
        {
            # time ok
        }
        else
        {
            if( $packettime < 10*365*86400 ) # everything that is below ten years might be a running time
            {
                $packet_timestring = sprintf("runtime: %0dd %02d:%02d:%02d",int($packettime/86400),int( ($packettime%86400)/3600),int(($packettime%3600)/60),int($packettime%60));
            }
            elsif( ($packettime < 0x60000000) || ($packettime >(time() + 1000)) )  # everything before the program existed or in the future is weird
            {
                printf "Weird time %s raw: %s\n",$packet_timestring,prettyhexdata( substr($footer,0,60) ).'...';
                $footer = substr($footer,1);
                next FOOTERPARSING;
            }
        }
#        $type = 0 if $shortnumberformat ;

        my  $typeinformation = code2Typeinformation($code);
        my  $name = $$typeinformation{name};

            $name .= '.'.$number if $number > 0 && $number <7;
            $name .= ' ('.$$typeinformation{unit}.')' if $$typeinformation{unit};

#        print "\nFooter DATA:".prettyhexdata(substr($footer,0,40))."\n";

        printf "%s%s Code:0x%04x-0x%04x No:0x%02x Type:0x%02x %s %27s ",' ' x 7,$source,$command,$code,$number,$type,$packet_timestring,$name;

        ##### TYPE decoding

        if( $type == 0x00 || $type == 0x40 || $shortnumberformat )    # integer
        {
#            my  @values = map { unpack('V',substr($footer,8+(4*$_),4)) } (0..8);
            my @values = unpack('V*',substr($footer,8,28));

            if( $shortnumberformat )
            {
                splice(@values,2);
                $typelength = 16;
            }
            else
            {
                my $shortmarker =   @values[1] == 0
                                    || (@values[0] == 0xffffffff && @values[1] == 0xffffffff)
                                    || (@values[0] == 0xffffffff && @values[1] == 0xffffff07)
                                    ? 1 : 0;
                my $longmarker  =   (       (@values[0] == 0 && @values[1] == 0 && @values[2] == 0 && @values[3] == 0)
                                        ||  ( ((@values[2] & 0xffff0000) == 0xffff0000) && ((@values[3] & 0xffff0000) == 0xffff0000) )
    #                                    ||  (@values[0] == 0xffffffff && @values[1] == 0xffffffff && @values[2] == 0xffffffff && @values[3] == 0xffffffff)
                                        ||  !$shortmarker
#                                        || (@values[0] != 0 && @values[1] != 0 && @values[2] != 0 && @values[3] != 0)
                                    )
                                    && (@values[4] == 1 || @values[4] == 0)
                                    ? 1 : 0;
#                # 56012b7fbc76 Code:0x6400-0x543a No:0x01 Type:0x00 2021-08-20T16:39:59
                printf "S:%d L:%d 0x%08x 0x%08x",$shortmarker,$longmarker,@values[2] & 0xffff0000,@values[3] & 0xffff0000;

                if(         @values[0] == 0x0       # version number scheme
                        &&  @values[1] == 0x0
                        &&  (   (@values[2] == 0xFFFFFED8 && @values[3] == 0xFFFFFED8 )
                             || (@values[2] == 0xFFFFFFFE && @values[3] == 0xFFFFFFFE )
                            )
                        &&  @values[4] == @values[5]
                        &&  @values[6] == 0x0
                        &&  @values[7] == 0x0
                    )
                {
                    $typelength = 40;
                    @values = unpack('C*',pack('N',@values[4]));
                }
                elsif( $longmarker )
                {
                    $typelength = 28;
                    splice(@values,4);
                    splice(@values,1)  if '' eq join('',map { @values[$_-1] == @values[0] ? '' : 'somevalue' } (1..@values) );  # print one value if all are same
                }
                elsif( $shortmarker )
                {
                    splice(@values,1);
                    $typelength = 16;
                }
                else
                {
                   print "\nFooter DATA:".prettyhexdata(substr($footer,0,40))."\n";
                   print "Weird NUmber";
                   $footer = substr($footer,1);
                   next FOOTERPARSING;
                }
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

            printf "%30s ",'v:'.join('.',@values);
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

 0x4922 => { name => 'battery.cells.maxtemperature', unit => 'ºC', factor => 0.1 },
 0x4923 => { name => 'battery.cells.mintemperature', unit => 'ºC', factor => 0.1 },
 0x4933 => { name => 'battery.cells.setcharging.voltage', unit => 'V', factor => 0.01 },
 0x495D => { name => 'battery.system.current', unit => 'A', factor => 0.001 },
 0x295A => { name => 'battery.system.soc', unit => '%' },
 0x495B => { name => 'battery.system.temperature', unit => 'ºC' },
 0x495C => { name => 'battery.system.voltage', unit => 'V', factor => 0.01 },
 0x2622 => { name => 'counter.day.yield', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x462F => { name => 'counter.feedintime',unit => 's'},
 0x462E => { name => 'counter.operatingtime',unit => 's'},
 0x263F => { name => 'grid.power.feedin', unit => 'W'},
 0x2601 => { name => 'counter.total.yield', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4521 => { name => 'dc.amperage', unit => 'A', factor => 0.001 },
 0x251E => { name => 'dc.power', unit => 'W'},
 0x451F => { name => 'dc.voltage', unit => 'V', factor => 0.01 },
 0x4164 => { name => 'grid.contactstatus'},
 0x464B => { name => 'grid.powerfactor.phaseA', unit => '%'},
 0x464C => { name => 'grid.powerfactor.phaseB', unit => '%'},
 0x464D => { name => 'grid.powerfactor.phaseC', unit => '%'},
 0x464E => { name => 'grid.displacementfactor', unit => '%'},
 0x4653 => { name => 'grid.current.phaseA', unit => 'A', factor => 0.001 },
 0x4654 => { name => 'grid.current.phaseB', unit => 'A', factor => 0.001 },
 0x4655 => { name => 'grid.current.phaseC', unit => 'A', factor => 0.001 },
 0x4166 => { name => 'grid.feedinwaittime', unit => 's'},
 0x4657 => { name => 'grid.frequency', unit => 'Hz', factor => 0.001 },
 0x4640 => { name => 'grid.power.phaseA', unit => 'W'},
 0x4641 => { name => 'grid.power.phaseB', unit => 'W'},
 0x4642 => { name => 'grid.power.phaseC', unit => 'W'},
 0x4636 => { name => 'grid.total.feedin', unit => 'W'},
 0x4637 => { name => 'grid.total.usage', unit => 'W'},
 0x4648 => { name => 'grid.voltage.phaseA', unit => 'V', factor => 0.01 },
 0x4649 => { name => 'grid.voltage.phaseB', unit => 'V', factor => 0.01 },
 0x464A => { name => 'grid.voltage.phaseC', unit => 'V', factor => 0.01 },
 0x821F => { name => 'system.mainmodel'},
 0x821E => { name => 'system.name'},
 0x411E => { name => 'system.nominalpowerstatus'},
 0x4120 => { name => 'system.powerfault'},
 0x8234 => { name => 'system.softwareversion'},
 0x2148 => { name => 'system.status'},
 0x8220 => { name => 'system.type'},
 0x411F => { name => 'system.warning'},
 0x4924 => { name => 'type.unknown.maybe.battery.cells'},
 0x491E => { name => 'type.unknown.maybe.battery.counter.charges'},
 0x4926 => { name => 'type.unknown.maybe.battery.total.charge', unit => 'Ah'},
 0x4927 => { name => 'type.unknown.maybe.battery.total.discharge', unit => 'Ah'},
 0x4627 => { name => 'type.unknown.maybe.counter.day.feedin', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4628 => { name => 'type.unknown.maybe.counter.day.usage', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x46AA => { name => 'type.unknown.maybe.counter.ownconsumption', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4626 => { name => 'type.unknown.maybe.counter.total.consumption', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4624 => { name => 'type.unknown.maybe.counter.total.feedin', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4623 => { name => 'type.unknown.maybe.counter.total.generation', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4625 => { name => 'type.unknown.maybe.counter.total.usage', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4650 => { name => 'type.unknown.maybe.grid.current.phaseA', unit => 'A', factor => 0.001 },
 0x4651 => { name => 'type.unknown.maybe.grid.current.phaseB', unit => 'A', factor => 0.001 },
 0x4652 => { name => 'type.unknown.maybe.grid.current.phaseC', unit => 'A', factor => 0.001 },
 0x4631 => { name => 'type.unknown.maybe.grid.failure'},
 0x463A => { name => 'type.unknown.maybe.grid.power.feedin', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x463B => { name => 'type.unknown.maybe.grid.power.usage', unit => 'kWh', factor => ( 1.0 / 1000 ) },
 0x4639 => { name => 'type.unknown.maybe.grid.total.consumption', unit => 'W'},
 0x4635 => { name => 'type.unknown.maybe.grid.total.generation', unit => 'W'},
 0x46AB => { name => 'type.unknown.maybe.power.ownconsumption'},
 0x832A => { name => 'type.unknown.maybe.system.maximumpoweroutput'},
 0x2377 => { name => 'type.unknown.maybe.system.temperature'},

 };
    my $code = $$typeInformation{$number} || { name => 'type.unkown.'.sprintf("0x%04x",$number) };

    return $code;
}
