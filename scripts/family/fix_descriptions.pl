#!/usr/local/bin/perl -w

# Fix the incompletely parsed Uniprot descriptions in member table

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub parse_description {
    my $old_desc = shift @_;

    my @top_parts = split(/(Includes|Contains):/,$old_desc);
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
        
        my @parts = split(/(RecName|SubName|AltName|Flags):/, $top_data);
        shift @parts;
        while(@parts) {
            my $prefix = shift @parts;
            my $data   = shift @parts;

            if($prefix eq 'Flags') {
                $data=~/^(.*);/;
                $flags .= $1;
            } else {
                while($data=~/(\w+)\=(.*?);/g) {
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
    }
    if($top_prefix) {
        $desc .= ']';
    }

    return $name . $flags . $desc;
}

sub loop_descriptions {
    my ($dbc, $force) = @_;

    my $sth = $dbc->prepare( qq{
        SELECT member_id, stable_id, description
          FROM member
         WHERE source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL')
           AND (description LIKE '%Contains:%' OR description LIKE '%Includes:%')
    });

    $sth->execute();
    while( my ($member_id, $stable_id, $old_desc) = $sth->fetchrow()) {
        print "Member: $stable_id (id=$member_id)\n";
        print "OldDescription: $old_desc\n";
        my $new_desc = parse_description($old_desc);
        print "NewDescription: $new_desc\n\n";
    }
    $sth->finish();
}

my $force = 0;
my $dbconn = { -host => 'compara2', -port => '5316', -user => 'ensro', -dbname => 'avilella_compara_homology_55' };

GetOptions(
            # connection parameters:
        'dbhost=s' => \$dbconn->{-host},
        'dbport=i' => \$dbconn->{-port},
        'dbuser=s' => \$dbconn->{-user},
        'dbpass=s' => \$dbconn->{-pass},
        'dbname=s' => \$dbconn->{-dbname},

            # optional parameters:
       'force!'       => \$force,
);

my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$dbconn)
        || die "Could not create the DBAdaptor";

loop_descriptions($dba->dbc(), $force);

