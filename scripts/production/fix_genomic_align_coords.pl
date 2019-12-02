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


use strict;
use warnings;

=head1 NAME

fix_genomic_align_coords.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script will fix out-of-bound coordinates for a list of given genomic_align_block_ids

=head1 SYNOPSIS

  perl fix_genomic_align_coords.pl --help

  perl fix_genomic_align_coords.pl
    [--reg_conf registry_configuration_file]
    --compara compara_db_name_or_alias
    --file path/to/file/that/contains/genomic_align_block_ids

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file

=item B<[--file path/to/file/that/contains/genomic_align_block_ids]>

File that contains the genomic_align_block_ids tha need to be fixed (one per line).

=back

=cut

use strict;
use warnings;

use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::IO qw/:slurp/;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;


my $help;
my $reg_conf;
my $compara;
my $file;

GetOptions(
    'help'          => \$help,
    'reg_conf=s'    => \$reg_conf,
    'compara=s'     => \$compara,
    'file=s'        => \$file,
  );

# Print Help and exit if help is requested
if ($help or !$file or !$compara) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}
throw ("Cannot connect to database [$compara]") if (!$compara_dba);

my $gab_a = $compara_dba->get_GenomicAlignBlockAdaptor();

my $gab_ids = slurp_to_array($file, "chomp");


foreach my $genomic_align_block_id (@$gab_ids) {
#foreach my $genomic_align_block_id ((92630000341952)) {
#foreach my $genomic_align_block_id ((92560001486983)) {
#foreach my $genomic_align_block_id ((92560000272666,92560001486983,92630000341952,92630001487775,92630002773343,92640000242394,92640001552906,92650000594926,92650001563933,92670000281183,92680000038437,92680000649463,92690000320686,92690000371934,92690001645420)) {
    my $gab = $gab_a->fetch_by_dbID($genomic_align_block_id);
    my $length = $gab->length;
    print "** $genomic_align_block_id **\n";
    $gab->_print;
    foreach my $ga (@{$gab->get_all_GenomicAligns}) {
        print $ga->genome_db->name, " ", $ga->cigar_line, "\n";
    }
    my $out = 0;
    while (1) {
        my $excess = 0;
        foreach my $ga (@{$gab->get_all_GenomicAligns}) {
            if ($ga->dnafrag_start >= $ga->dnafrag->length) {
                $out = 1;
            } elsif ($ga->dnafrag_end > $ga->dnafrag->length) {
                my $this = $ga->dnafrag_end - $ga->dnafrag->length;
                if ($this > $excess) {
                    $excess = $this;
                }
            }
        }
        if ($out) {
            print "out\n";
            print STDERR sprintf(q{DELETE FROM genomic_align       WHERE genomic_align_block_id = %d;}, $genomic_align_block_id), "\n";
            print STDERR sprintf(q{DELETE FROM genomic_align_block WHERE genomic_align_block_id = %d;}, $genomic_align_block_id), "\n";
            last;
        } elsif ($excess) {
            $length -= $excess;
            die if $length < 0;
            print "removing $excess down to $length\n";
            $gab = $gab->restrict_between_alignment_positions(1, $length);
            $gab->_print;
        } else {
            last;
        }
    }
    if ($gab->original_dbID) {
        foreach my $ga (@{$gab->get_all_GenomicAligns}) {
            print $ga->genome_db->name, " ", $ga->cigar_line, "\n";
        }
        print STDERR sprintf(q{UPDATE genomic_align_block SET length = %d WHERE genomic_align_block_id = %d;}, $gab->length, $genomic_align_block_id), "\n";
        foreach my $ga (@{$gab->get_all_GenomicAligns}) {
            print STDERR sprintf(q{UPDATE genomic_align SET dnafrag_end = %d, cigar_line = "%s" WHERE genomic_align_id = %d;}, $ga->dnafrag_end, $ga->cigar_line, $ga->original_dbID), "\n";
        }
    }
    print "\n\n";
}

