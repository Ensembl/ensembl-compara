#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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


# This is a script to set is_good_for_alignment for all (past) genomes

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;
use List::Util qw(max);
use Pod::Usage;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


## Command-line options
my ($compara_url, $help);

GetOptions(
    'compara_url=s' => \$compara_url,
    'help'          => \$help,
);

if ($help) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

$| = 1;

die "Must provide the URL of the compara database\n" unless $compara_url;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $compara_url );

foreach my $genome_db (@{$compara_dba->get_GenomeDBAdaptor->fetch_all}) {
    #next if $genome_db->name eq 'ancestral_sequences';
    my $is_good_for_alignment = compute_is_good_for_alignment($genome_db);
    if ($is_good_for_alignment != $genome_db->is_good_for_alignment) {
        print sprintf(q{UPDATE genome_db SET is_good_for_alignment = %d WHERE genome_db_id = %d;}, $is_good_for_alignment, $genome_db->dbID), "\n";
    } else {
        #print sprintf(q{# %s OK =%d}, $genome_db->name, $is_good_for_alignment), "\n";
    }
}

sub compute_is_good_for_alignment {
    my $genome_db = shift;

    #print $genome_db->toString, "\n";
    my $dnafrag_adaptor = $genome_db->adaptor->db->get_DnaFragAdaptor;
    my $all_dnafrags    = $dnafrag_adaptor->fetch_all_by_GenomeDB($genome_db, -IS_REFERENCE => 1);

    unless (scalar(@$all_dnafrags)) {
        #print "# no dnafrags in ", $genome_db->name, " !\n";
        return 0;
    }
    #print scalar(@$all_dnafrags), "\n";

    my @species_overall_len;#rule_2
    foreach my $dnafrag (@$all_dnafrags) {
        push( @species_overall_len, $dnafrag->length());#rule_2
    }

    undef $all_dnafrags;

    #-------------------------------------------------------------------------------
    my $top_limit;
    if ( scalar(@species_overall_len) < 50 ) {
        $top_limit = scalar(@species_overall_len) - 1;
    }
    else {
        $top_limit = 49;
    }

    my @top_frags = ( sort { $b <=> $a } @species_overall_len )[ 0 .. $top_limit ];
    my @low_limit_frags = ( sort { $b <=> $a } @species_overall_len )[ ( $top_limit + 1 ) .. scalar(@species_overall_len) - 1 ];
    my $avg_top = _mean(@top_frags);

    my $ratio_top_highest = _sum(@top_frags)/_sum(@species_overall_len);

    #we set to 1 in case there are no values since we want to still compute the log
    my $avg_low;
    my $ratio_top_low;
    if ( scalar(@low_limit_frags) == 0 ) {

        #$ratio_top_low = 1;
        $avg_low = 1;
    }
    else {
        $avg_low = _mean(@low_limit_frags);
    }

    $ratio_top_low = $avg_top/$avg_low;

    my $log_ratio_top_low = log($ratio_top_low)/log(10);#rule_4

    undef @top_frags;
    undef @low_limit_frags;
    undef @species_overall_len;

    #After initially considering taking all the genomes that match cov >= 65% || log >= 3
    #We then decided to combine both variables and take all the genomes for
    #which log >= 10 - 3 * cov/25%. In other words, the classifier is a line that
    #passes by the (50%,4) and (75%,1) points. It excludes genomes that have a log
    #value >= 3 but a poor coverage, or a decent coverage but a low log value.
    #my $is_good_for_alignment = ($ratio_top_highest > 0.68) || ( $log_ratio_top_low > 3 ) ? 1 : 0;

    my $diagonal_cutoff = 10-3*($ratio_top_highest/0.25);

    my $is_good_for_alignment = ($log_ratio_top_low > $diagonal_cutoff) ? 1 : 0;
    #print "$is_good_for_alignment\n";
    return $is_good_for_alignment;
}


sub _sum {
    my (@items) = @_;
    my $res;
    for my $next (@items) {
        die unless ( defined $next );
        $res += $next;
    }
    return $res;
}

sub _mean {
    my (@items) = @_;
    return _sum(@items)/( scalar @items );
}



