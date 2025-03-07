#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 DESCRIPTION

This script fetches data for zebrafish from [https://zfin.org]:
    homo_sapiens            = https://zfin.org/downloads/human_orthos.txt
    drosophila_melanogaster = https://zfin.org/downloads/fly_orthos.txt
    mus_musculus            = https://zfin.org/downloads/mouse_orthos.txt

=cut

use strict;
use warnings;

use Getopt::Long;
use DBI;

my $user;
my $pwd;
my $database;
my $hostname;
my $port;
my $release;

my %input_files;

my @species_to_get_ids = ( "homo_sapiens", "danio_rerio", "drosophila_melanogaster", "mus_musculus" );

$input_files{'homo_sapiens'}            = 'human_orthos.txt';    #https://zfin.org/downloads/human_orthos.txt
$input_files{'drosophila_melanogaster'} = 'fly_orthos.txt';      #https://zfin.org/downloads/fly_orthos.txt
$input_files{'mus_musculus'}            = 'mouse_orthos.txt';    #https://zfin.org/downloads/mouse_orthos.txt

GetOptions( "user=s" => \$user, "database=s" => \$database, "hostname=s" => \$hostname, "port=s" => \$port, "pwd=s" => \$pwd, "release=s" => \$release );
die "Usage: coverage.pl -user [you] -database [db] -hostname [mysql-ens-compara-prod-4] -port [1234] -pwd [123abc] -release [e85]"
  if ( !$user || !$database || !$hostname || !$release );

$pwd  = ""     if ( !$pwd );
$port = "3306" if ( !$port );

my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect( $dsn, $user, $pwd ) || die "Could no connect to MySQL server";

#get list of members:
my %members_list;

#150    => homo_sapiens
#134    => mus_musculus
#236    => danio_rerio
#156    => drosophila_melanogaster

my $sth = $dbh->prepare("SELECT stable_id, display_label, description, name FROM gene_member JOIN genome_db USING (genome_db_id) WHERE genome_db_id IN (150,134,236,156) AND stable_id NOT LIKE \"LRG_%\"");
$sth->execute();
while ( my @row = $sth->fetchrow_array() ) {
    my $stable_id     = $row[0];
    my $display_label = $row[1];
    my $description   = $row[2];
    my $species       = $row[3];
    $members_list{$species}{$display_label}{$stable_id} = $description;
}

#======================================================================
# ZEBRAFISH
#======================================================================

# There are no ENSEMBL ids on the "golden" file. So we need to map the ids for both human and zebrafish
# For human we use the display labels.
# For zebrafish we map the ZFIN ids with the description field.
# For fly we use Acc:FBgn0
#

my %specific_ids_to_ensembl_ids;

foreach my $species (@species_to_get_ids) {

    #map ZFIN ids to ensembl zebrafish IDs
    foreach my $display_label ( keys( %{ $members_list{$species} } ) ) {
        foreach my $stable_id ( keys( %{ $members_list{$species}{$display_label} } ) ) {

            if ( $species eq "danio_rerio" ) {

                # use description
                my $description = $members_list{$species}{$display_label}{$stable_id};

                my @t1 = split( /\s/, $description );
                my @t2 = split( /;/,  $t1[-1] );
                my @t3 = split( /:/,  $t2[0] );
                my $source = $t3[1];

                if ( $source eq "ZFIN" ) {
                    @t3 = split( /:/, $t2[-1] );
                    my $ZFIN_id = $t3[-1];

                    $ZFIN_id = substr( $ZFIN_id, 0, -1 );
                    $specific_ids_to_ensembl_ids{'danio_rerio'}{$ZFIN_id} = $stable_id;
                    #print ">>>$ZFIN_id|$stable_id<<<\n";
                    #die;
                }
            }
            elsif ( $species eq "drosophila_melanogaster" ) {
                #use display labels
                #$specific_ids_to_ensembl_ids{'drosophila_melanogaster'}{$display_label} = $stable_id;
                $specific_ids_to_ensembl_ids{'drosophila_melanogaster'}{$stable_id} = $stable_id;
                #print ">>>$display_label|$stable_id<<<\n";
            }
            elsif ( $species eq "homo_sapiens" ) {

                #use display labels
                $specific_ids_to_ensembl_ids{'homo_sapiens'}{$display_label} = $stable_id;
                #print ">>>$display_label|$stable_id<<<\n";
            }
            elsif ( $species eq "mus_musculus" ) {

                # use description
                my $description = $members_list{$species}{$display_label}{$stable_id};

                if ( $description =~ /MGI\:/ ) {
                    my @t1 = split( /\s/, $description );
                    my @t2 = split( /;/,  $t1[-1] );
                    my @t3 = split( /:/,  $t2[-1] );
                    my $MGI_id = $t3[-1];
                    $MGI_id = substr( $MGI_id, 0, -1 );
                    $specific_ids_to_ensembl_ids{'mus_musculus'}{$MGI_id} = $stable_id;
                    #print "\t\t===$MGI_id|$stable_id|$description<<<\n";
                }

            }
        } ## end foreach my $stable_id ( keys...)
    } ## end foreach my $display_label (...)
} ## end foreach my $species (@species_to_get_ids)

my %zebrafish_homology;         # Stores all the homology
my %zebrafish_homology_type;    # Stores the type of homology
my %zebrafish_gold;             # Stores only the wanted fields from the reference file excluding duplications introduced by the field Pub_ID

foreach my $species ( keys %input_files ) {
    open my $fh, "<", $input_files{$species};
    while (<$fh>) {
        chomp($_);
        my @tok = split( /\t/, $_ );
        my $zfin_stable_id;
        my $species_id;

        if ( $species eq "drosophila_melanogaster" ) {
            $zfin_stable_id = $tok[0];
            $species_id     = $tok[5];
            #print ">>>$zfin_stable_id|$species_id<<<\n";
        }
        elsif ( $species eq "homo_sapiens" ) {
            $zfin_stable_id = $tok[0];
            $species_id     = $tok[3];
            #print ">>>$zfin_stable_id|$species_id<<<\n";
        }
        elsif ( $species eq "mus_musculus" ) {
            $zfin_stable_id = $tok[0];
            $species_id = substr( ( split /:/, $tok[5] )[1], 0 );
            #print ">>>$zfin_stable_id|$species_id<<<\n";
        }
        $zebrafish_gold{$species}{$zfin_stable_id}{$species_id} = 1;
    }
    close($fh);
}

foreach my $species ( keys %zebrafish_gold ) {
    print "\t>>>$species<<<\n";
    foreach my $zfin_stable_id ( keys %{ $zebrafish_gold{$species} } ) {
        foreach my $species_id ( keys %{ $zebrafish_gold{$species}{$zfin_stable_id} } ) {

            my $zebrafish_ensembl_stable_id = $specific_ids_to_ensembl_ids{'danio_rerio'}{$zfin_stable_id};
            #if ($species eq "mus_musculus"){
            #    print "\t$zfin_stable_id|$species_id|$zebrafish_ensembl_stable_id|\n";
            #    die;
            #}

            if ($zebrafish_ensembl_stable_id) {

                my $ensembl_stable_id = $specific_ids_to_ensembl_ids{$species}{$species_id};

                if ($ensembl_stable_id) {
                    $zebrafish_homology{$species}{$ensembl_stable_id}{$zebrafish_ensembl_stable_id} = 1;
                    $zebrafish_homology_type{$species}{$ensembl_stable_id}++;
                    $zebrafish_homology_type{'danio_rerio'}{$zebrafish_ensembl_stable_id}++;
                }
            }
        }
    }
}

#my $homology_count = 0;

#Print results to file:
foreach my $species ( keys %zebrafish_homology ) {
    my $zebrafish_homology_out_file = "zebrafish_homology_$species\_$release.out";
    open my $fh_zebrafish, ">", $zebrafish_homology_out_file;
    foreach my $ensembl_stable_id ( keys %{ $zebrafish_homology{$species} } ) {
        foreach my $zebrafish_ensembl_stable_id ( keys %{ $zebrafish_homology{$species}{$ensembl_stable_id} } ) {

            my $species_zebrafish_count = $zebrafish_homology_type{$species}{$ensembl_stable_id};
            my $zebrafish_species_count = $zebrafish_homology_type{'danio_rerio'}{$zebrafish_ensembl_stable_id};

            my $homology_type;

            if ( ( $species_zebrafish_count == 1 ) && ( $zebrafish_species_count == 1 ) ) {
                $homology_type = "ortholog_one2one";
            }
            elsif ( ( $species_zebrafish_count > 1 ) && ( $zebrafish_species_count > 1 ) ) {
                $homology_type = "ortholog_many2many";
            }
            else {
                $homology_type = "ortholog_one2many";
            }

            print $fh_zebrafish "$ensembl_stable_id\t$zebrafish_ensembl_stable_id\t$species\tdanio_rerio\t$homology_type\t$species_zebrafish_count|$zebrafish_species_count\n";
            #print $fh_zebrafish "$homology_count\t$ensembl_stable_id\t$zebrafish_ensembl_stable_id\t$species\tdanio_rerio\t$homology_type\t$species_zebrafish_count|$zebrafish_species_count\n";
            #$homology_count++;
            #print "$ensembl_stable_id\t$zebrafish_ensembl_stable_id\t$homology_type\t$species_zebrafish_count|$zebrafish_species_count\n";
        }
    }
} ## end foreach my $species ( keys ...)

#======================================================================
