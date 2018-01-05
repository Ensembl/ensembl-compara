#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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

#
# This script dumps genome of a given species in FASTA format
# Output options include writing a file-per chromosome, a multifasta of chromosomes
# or a single sequence of concatenated chromosomes (default)
#

use strict;
use warnings;
use Getopt::Long;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my ( $help, $reg_conf, $compara, $species, $gdb_id, $assembly, $outfile );
my ( $file_per_chr, $multifasta ) = ( 0, 0 );
GetOptions(
	'h|help'       => \$help,
	'reg_conf=s'   => \$reg_conf,
	'compara=s'    => \$compara,
	'species=s'    => \$species,
	'genome_db_id' => \$gdb_id,
	'assembly=s'   => \$assembly,
	'o|outfile=s'  => \$outfile,
	'file_per_chr' => \$file_per_chr,
	'multifasta'   => \$multifasta,
);

die &helptext if ($help || !$compara);

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $compara );

my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
my $dnafrag_adaptor   = $compara_dba->get_DnaFragAdaptor;

my $genome_db;
$genome_db = $genome_db_adaptor->fetch_by_name_assembly( $species, $assembly ) if $species;
$genome_db = $genome_db_adaptor->fetch_by_dbID( $gdb_id ) if $gdb_id;
my $species_id = $genome_db->name . "." . $genome_db->assembly;
$outfile ||= $species_id;
if ( !$file_per_chr ) {
	open( OUT, '>', $outfile ) or die "Cannot open output file '$outfile'\n";
	print OUT "> $species_id\n" unless $multifasta;
}

my $dnafrags  = $dnafrag_adaptor->fetch_all_by_GenomeDB_region( $genome_db, 'chromosome', undef, 1 );
print "Dumping " . scalar(@$dnafrags) . " dnafrags to $outfile for " . $genome_db->name . "(" . $genome_db->assembly . ")\n";
foreach my $this_dnafrag ( @$dnafrags ) {
	my $chr_name = $this_dnafrag->name;
	if ( $file_per_chr ) {
		my $this_outfile = "$species_id.$chr_name.fa";
		open( OUT, '>', $this_outfile ) or die "Cannot open file for writing: $this_outfile\n";
	}
	print OUT "> $chr_name\n" if ( $multifasta || $file_per_chr );
	print OUT $this_dnafrag->slice->seq . "\n";
	close OUT;
}
close OUT if !$file_per_chr;

sub helptext {
	my $help = "\nUsage: dump_genome.pl [options]\n";
	$help .=   "  --reg_conf     : registry config file\n";
	$help .=   "  --compara      : url or alias for compara db\n";
	$help .=   "  --species      : name of species to dump\n";
	$help .=   "  --genome_db_id : genome_db ID of species (in place of species name + assembly)\n";
	$help .=   "  --assembly     : which assembly of the species to dump\n";
	$help .=   "  --outfile      : prefix for resulting output files (default: species_name.assembly\n";
	$help .=   "  --file_per_chr : write each chromosome to its own file (default: false)\n";
	$help .=   "  --multifasta   : fasta header per-chromosome (default: false)\n";
	return $help;
}