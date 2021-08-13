#!/usr/bin/perl

use strict;
use IO::Socket::INET;

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

my $filehandle;
if( length $filename )
{
    open( $filehandle, ">>", $filename) || die "Can't open $filename for appending due to:$!";
    binmode $filehandle;
}

my $sessionid   = sprintf '1234 %04x 4321',int(rand(0x10000));
my $inverterid  = 'ffff ffff ffff';

my @commands = (
    "0C04 fdff 07000000 84030000 4c20cb51 00000000".encodePassword($password),  # login


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
    print $filehandle $data if $filehandle;
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
        printf "%s: invalide SMA packet: %0x %0x %d=%d %0x %s\n",$prefix,$smaheader,$proto,$length,$expectedlen,$footer,prettyhexdata($data);
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

    my $smanet_length = unpack('C',substr($data,0,1)) * 4;

    if(    length($data) < 2
        || length($data) != $smanet_length
        || $smanet_length < 32
      )
    {
        printf "Invalid SMANet packet: %d != %d < 32 :%s\n",$smanet_length,length($data),prettyhexdata($data);
        return undef;
    }

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

    my $valuetype   = unpack('V',substr($data,28,4));
    my $valuecount  = unpack('V',substr($data,32,4));


    my $header = substr($data,0,36);
    my $footer = substr($data,36);

    printf "type:0x%08x count:0x%08x raw:%s\n",$valuetype,$valuecount,prettyhexdata($header);

    while( length($footer) > 28 )
    {
        my $time  = unpack('V',substr($footer,4,4));
        my $value = unpack('V',substr($footer,8,4));
        my @stringvalues = map { ord($_)>31 && ord($_)<0x7E ? $_ : '.' } split(//,substr($footer,8,14));
        printf "\t%s %s,%d %s\n",prettyhexdata(substr($footer,0,28)),''.localtime($time),$value,join('',@stringvalues);
        $footer = substr($footer,28);
    }

    if ( length( $footer ) > 0 )
    {
        if ( length( $footer ) > 11 )
        {
            my $time  = unpack('V',substr($footer,4,4));
            my $value = unpack('V',substr($footer,8,4));

            printf "\t%s %s,%d\n",prettyhexdata($footer),''.localtime($time),$value;
        }
        else
        {
            printf "\t%s\n",prettyhexdata( $footer );
        }
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

