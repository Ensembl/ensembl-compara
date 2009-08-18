#!/usr/local/bin/perl -w

# This script can retro-fix the incompletely parsed Uniprot descriptions
# after they have been read into a separate file by parse_mcl.pl
#
# (NB: you would still need to fix the Uniprot members' descriptions in the database)

use strict;
use Getopt::Long;

sub parse_description {
    my $old_desc = shift @_;

    my @top_parts = split(/(?!\[\s*)(Includes|Contains):/,$old_desc);
    unshift @top_parts, '';

    my ($name, $desc, $flags, $top_prefix, $prev_top_prefix) = (('') x 3);
    while(@top_parts) {
        $prev_top_prefix = $top_prefix;
        $top_prefix      = shift @top_parts;

        if($top_prefix) {
            if($top_prefix eq $prev_top_prefix) {
                $desc .='; ';
            } else {
                if($prev_top_prefix) {
                    $desc .=']';
                }
                $desc .= "[$top_prefix ";
            }
        }
        my $top_data         = shift @top_parts;
        
        if($top_data=~/^\s*\w+:/) {
            my @parts = split(/(RecName|SubName|AltName|Flags):/, $top_data);
            shift @parts;
            while(@parts) {
                my $prefix = shift @parts;
                my $data   = shift @parts;

                if($prefix eq 'Flags') {
                    $data=~/^(.*?);/;
                    $flags .= $1;
                } else {
                    while($data=~/(\w+)\=([^\[;]*?(?:\[[^\]]*?\])?[^\[;]*?);/g) {
                        my($subprefix,$subdata) = ($1,$2);
                        if($subprefix eq 'Full') {
                            if($prefix eq 'RecName') {
                                if($top_prefix) {
                                    $desc .= $subdata;
                                } else {
                                    $name .= $subdata;
                                }
                            } elsif($prefix eq 'SubName') {
                                $name .= $subdata;
                            } elsif($prefix eq 'AltName') {
                                $desc .= "($subdata)";
                            }
                        } elsif($subprefix eq 'Short') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'EC') {
                            $desc .= "(EC $subdata)";
                        } elsif($subprefix eq 'Allergen') {
                            $desc .= "(Allergen $subdata)";
                        } elsif($subprefix eq 'INN') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'Biotech') {
                            $desc .= "($subdata)";
                        } elsif($subprefix eq 'CD_antigen') {
                            $desc .= "($subdata antigen)";
                        }
                    }
                }
            }
        } else {
            $desc .= $top_data; # This is to save the names that do not follow the pattern.
                                # Uniprot curators [should want to] thank us very much for this!
        }
    }
    if($top_prefix) {
        $desc .= ']';
    }

    return $name . $flags . $desc;
}

sub loop_on_file {
    my ($filename) = @_;

    open(INFILE,"<$filename");

    while(my $line = <INFILE>) {
        chomp $line;
        my ($member_source, $family_dbID, $member_stable_id, $old_description) = split(/\t/, $line, 4);

        my $new_description = parse_description($old_description);
        
        print join("\t", $member_source, $family_dbID, $member_stable_id, $new_description)."\n";
    }

    close INFILE;
}


unless(@ARGV == 1) {
    die "Need one input_file argument";
}

my ($filename) = @ARGV;

loop_on_file($filename);
