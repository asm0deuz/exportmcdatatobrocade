#!/usr/bin/perl

#Teoman ONAY 17/08/2012
#Export McData Zones / Aliases to Brocade Command

use strict;
use warnings;

# use module
use XML::LibXML;
use XML::LibXML::Reader;

# read XML file
my $data = XML::LibXML::Reader->new(location => "ara.xml") or die "cannot read ara.xml\n";
my $data2 = XML::LibXML::Reader->new(location => "ara.xml") or die "cannot read ara.xml\n";
#Alias creation command lines
open ALIASESFILES, ">aliases.txt";
#Zones creation command lines
open ZONESFILES, ">zones.txt";
#Configuration creation command line;
open CONFIG, ">config.txt";
my %aliasWwn;

#Process document
$data->nextElement("Aliases");
%aliasWwn = &processNode($data, "aliases");
#print %aliasWwn;
%aliasWwn = reverse %aliasWwn;
#while (($a, $b) = each %aliasWwn) {
#    print "$a -> $b\n";
#}
$data2->nextElement("Zone");
&processNode($data2, "zones", %aliasWwn);

close ALIASESFILES;
close ZONESFILES;
close CONFIG;

sub processNode {
    my $node = shift;
    my $whatToProcess = shift;
    if (scalar @_ > 1) {
        my %aliasWwn = @_;
    }
    my $aliasCount;
    if ($whatToProcess eq "aliases") {
        if ($node->name() eq "Aliases") {
            #How many aliases to create ?
            $aliasCount = &getAliasCount($node);
            #Processing
            my ($result, %aliasWwn) = &processAliases($node);
            if ($result == $aliasCount) {
                print "$result aliases created with no error\n";
                return %aliasWwn;
            } else {
                print "error during alias creation";
            }
        }
    } elsif ($whatToProcess eq "zones") {
        if ($node->name() eq "Zone") {
            if ($node->nodeType() == 1) {
                &processZones($node, %aliasWwn);
            }
        }
    }

    sub processAliases {
        my $reader = shift;
        my %aliasWwn;
        my $aliasCreated = 0;
        while ($reader->read()) {
            if ($reader->name() eq "Association") {
                #Replace - by _ as - isn't permitted and uppercase to lowercase
                my $alias = $reader->getAttribute("Alias");
                $alias = &cleanName($alias);
                $alias = "a_".$alias;
                my $wwn = $reader->getAttribute("WWN");
                #write the command to file
                $aliasWwn{$alias} = $wwn;
                #print ALIASESFILES "alicreate \"$alias\", \"$wwn\"\n";
                print ALIASESFILES "alicreate \"$alias\", \"$aliasWwn{$alias}\"\n";
                $aliasCreated++;
            }
        }
        return $aliasCreated, %aliasWwn;
    }

    sub processZones {
        my $reader = shift;
        my %wwnAlias = @_;
        my $a, my $b;
        while (($a, $b) = each %wwnAlias) {
        print "$a -> $b\n";
        }
        #how many zones to create ?
        my $memberCount;
        my $zoneCreated = 0;
        my @config = "DEGROOF";
        $reader->read();
        if($reader->hasValue()) {
            $memberCount = $reader->value();
        }
        $reader->read;
        #Parse each zone
        for (my $i = 0; $i < $memberCount; $i++) {
            my $currentPos = $reader;
            my @zone;
            #Will contain the complete command
            my $zoneToFile;
            $reader->nextElement("Name");
            $reader->read();
            #Zone name + cleaning - and convert to lowercase;
            $zone[0] = $reader->value();
            $zone[0] = &cleanName($zone[0]);
            #add zone names to configuration command
            push(@config, $zone[0]);
            $reader->nextElement("Member");
            $reader->read();
            #How many member by zone ?
            my $numberOfWwn = $reader->value();
            for (my $i = 1; $i <= $numberOfWwn; $i++) {
                $reader->nextElement("Wwn");
                $reader->read();
                $zone[$i] = $reader->value();
            }
            $zoneToFile = "zonecreate $zone[0],\"";
            for (my $i = 1; $i < @zone; $i++) {
                if (exists $wwnAlias{$zone[$i]}) {
                    $zoneToFile .= "$wwnAlias{$zone[$i]};";
                } else {
                    $zoneToFile .= "$zone[$i];";
                }
                #$zoneToFile .= "$zone[$i];";
                #print "$wwnAlias{$zone[$i]}\n";
                #$zoneToFile .= "$wwnAlias{$zone[$i]};";
            }
            #Remove trailing ;
            $zoneToFile =~ s/;$//g;
            $zoneToFile .= "\"";
            #Write the command to file
            print ZONESFILES "$zoneToFile\n";
            $zoneCreated++;
            $reader = $currentPos;
            $reader->nextSibling();
        }

        if ($memberCount == $zoneCreated) {
            print "$zoneCreated zones created with no error\n";
        } else {
            print "error during zones creation";
        }

        #creation of configuration
        my $curConfig = "cfgcreate $config[0], ";
        for (my $i = 1; $i < @config; $i++) {
            $curConfig .= "$config[$i];";
        }
        $curConfig =~ s/;$//g;
        print CONFIG "$curConfig";
        print "config file generated\n";

        #Replace all - by _ and convert uppercase to lowercase
        sub cleanName {
            my $name = shift;

            $name =~ s/-/_/g;
            $name = lc $name;
        }
    }

    sub getAliasCount {
        my $param = shift;
        $param->getAttribute("Count");
    }
}
