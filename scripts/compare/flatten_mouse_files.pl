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

This script fetches data from MGI and maps its ids with Ensembl stable ids.
MGI annotations come dorectly from the web [https://genenames.org/]

=cut

use strict;
use warnings;

use LWP::Simple qw(get);
use Getopt::Long;
use DBI;

my $user;
my $pwd;
my $database;
my $hostname;
my $port;
my $release;
my $mouse_gold_annotations_file;

GetOptions( "user=s" => \$user, "database=s" => \$database, "hostname=s" => \$hostname, "port=s" => \$port, "pwd=s" => \$pwd, "release=s" => \$release, "mouse_gold_annotations_file=s" => \$mouse_gold_annotations_file );
die "Usage: coverage.pl -user [you] -database [db] -hostname [mysql-ens-compara-prod-4] -port [1234] -pwd [123abc] -release [e85]"
  if ( !$user || !$database || !$hostname || !$release );

$pwd  = ""     if ( !$pwd );
$port = "3306" if ( !$port );

my $dsn = "DBI:mysql:database=$database;host=$hostname;port=$port";
my $dbh = DBI->connect( $dsn, $user, $pwd ) || die "Could no connect to MySQL server";

my %members_list;

#get list of members:
my $sth = $dbh->prepare("SELECT stable_id, display_label, description, name FROM gene_member JOIN genome_db USING (genome_db_id) WHERE genome_db_id IN (150,134,154) AND stable_id NOT LIKE \"LRG_%\"");
$sth->execute();
while ( my @row = $sth->fetchrow_array() ) {
    my $stable_id = $row[0];
    #next if ( $stable_id =~ "LRG_" );
    my $display_label = $row[1];
    my $description   = $row[2];
    my $species       = $row[3];
    if ( ( $stable_id ne "" ) && ( $display_label ne "" ) && ( $description ne "" ) ) {
        $members_list{$species}{$stable_id} = $description;
    }
}

#======================================================================
# MOUSE
#======================================================================

my %ensembl_mgi_stable_map;

#map MGI ids to ensembl mouse IDs
foreach my $stable_id ( keys( %{ $members_list{'mus_musculus'} } ) ) {
    my $description = $members_list{'mus_musculus'}{$stable_id};
    if ( $description =~ /MGI\:/ ) {
        my @t1 = split( /\s/, $description );
        my @t2 = split( /;/,  $t1[-1] );
        my @t3 = split( /:/,  $t2[-1] );
        my $MGI_id = $t3[-1];
        $MGI_id = substr( $MGI_id, 0, -1 );
        $ensembl_mgi_stable_map{$MGI_id} = $stable_id;
    }
}

my %mouse_homology;         # Stores all the homology
my %mouse_homology_type;    # Stores the type of homology

my %goden_ensembl_mgi_map;  # Maps MGI ids with Ensembl stable ids 
my @mouse_gold_annotations; # Input from MGI annotations, it can come from a file or directly from the web [https://genenames.org]

if(($mouse_gold_annotations_file) && (! -e $mouse_gold_annotations_file)){
    print "Parsing from file: $mouse_gold_annotations_file\n";
    open my $fh, "<", $mouse_gold_annotations_file;
    while (<$fh>) {
        print "===\n";
        chomp($_);
        push(@mouse_gold_annotations, $_);
    }
}
else {
    print "Parsing from remote source: [https://genenames.org]\n";
    my $url = 'https://genenames.org/cgi-bin/download/custom?col=gd_hgnc_id&col=gd_app_sym&col=gd_pub_ensembl_id&col=gd_mgd_id&status=Approved&status=Entry%20Withdrawn&hgnc_dbtag=on&order_by=gd_app_sym_sort&format=text&submit=submit';
    my $lines = get $url;
    @mouse_gold_annotations = split /\n/, $lines;
}

foreach my $line (@mouse_gold_annotations) {
    if ( $line =~ /MGI/ ) {
        chomp($_);
        my @tok = split( /\t/, $line );

        my $hgnc_id       = ( split /:/, $tok[0] )[1];
        my $display_label = $tok[1];
        my $stable_id     = $tok[2];

        if ( $tok[3] =~ /, / ) {
            my @tmp = split( /, /, $tok[3] );
            foreach my $tmp_mgi (@tmp) {
                my @tok1 = split( /:/, $tmp_mgi );
                my $mgi = $tok1[1];
                $goden_ensembl_mgi_map{$mgi} = $stable_id;
            }
        }
        else {
            my @tok1 = split( /:/, $tok[3] );
            my $mgi = $tok1[1];
            $goden_ensembl_mgi_map{$mgi} = $stable_id;
        }
    }
}

#close($fh);

foreach my $mgi ( keys %goden_ensembl_mgi_map ) {
    my $mouse_ensembl_stable_id = $ensembl_mgi_stable_map{$mgi};
    my $human_ensembl_stable_id = $goden_ensembl_mgi_map{$mgi};
    if ( $mouse_ensembl_stable_id && $human_ensembl_stable_id ) {
        #print "$mgi\t\t|M:$mouse_ensembl_stable_id|H:$human_ensembl_stable_id\n";
        $mouse_homology{$human_ensembl_stable_id}{$mouse_ensembl_stable_id} = 1;
        $mouse_homology_type{'homo_sapiens'}{$human_ensembl_stable_id}++;
        $mouse_homology_type{'mus_musculus'}{$mouse_ensembl_stable_id}++;
    }
}

#Print results to file:
my $mouse_homology_out_file = "mouse_homology_$release.out";
open my $fh_mouse, ">", $mouse_homology_out_file;

foreach my $human_ensembl_stable_id ( keys %mouse_homology ) {
    foreach my $mouse_ensembl_stable_id ( keys %{ $mouse_homology{$human_ensembl_stable_id} } ) {

        my $human_mouse_count = $mouse_homology_type{'homo_sapiens'}{$human_ensembl_stable_id};
        my $mouse_human_count = $mouse_homology_type{'mus_musculus'}{$mouse_ensembl_stable_id};

        my $homology_type;

        if ( ( $human_mouse_count == 1 ) && ( $mouse_human_count == 1 ) ) {
            $homology_type = "ortholog_one2one";
        }
        elsif ( ( $human_mouse_count > 1 ) && ( $mouse_human_count > 1 ) ) {
            $homology_type = "ortholog_many2many";
        }
        else {
            $homology_type = "ortholog_one2many";
        }

        my $display_label = $mouse_homology{$human_ensembl_stable_id}{$mouse_ensembl_stable_id};

        print $fh_mouse "$human_ensembl_stable_id\t$mouse_ensembl_stable_id\thomo_sapiens\tmus_musculus\t$homology_type\t$human_mouse_count|$mouse_human_count\n";
    }
}

#======================================================================
