#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ($host,$dbname,$dbuser,$chr_name,$chr_start,$chr_end,$sb_species,$qy_species,$dnafrag_type);

GetOptions('host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'chr_name=s' => \$chr_name,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'sb_species=s' => \$sb_species,
	   'qy_species=s' => \$qy_species,
	   'dnafrag_type=s' => \$dnafrag_type);

# Connecting to compara database

unless (defined $dbuser) {
  $dbuser = 'ensro';
}

$|=1;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -dbname => $dbname);

my $gdbadp = $db->get_GenomeDBAdaptor;


my $sb_species_dbadaptor = $gdbadp->fetch_by_species_tag($sb_species)->db_adaptor;

my $sb_chradp = $sb_species_dbadaptor->get_ChromosomeAdaptor;
my $chr = $sb_chradp->fetch_by_chr_name($chr_name);

my $qy_species_dbadaptor = $gdbadp->fetch_by_species_tag($qy_species)->db_adaptor;

my $qy_chradp = $qy_species_dbadaptor->get_ChromosomeAdaptor;
my $qy_chrs = $qy_chradp->fetch_all;

my %qy_chrs;

foreach my $qy_chr (@{$qy_chrs}) {
  $qy_chrs{$qy_chr->chr_name} = $qy_chr;
}

# futher checks on arguments

unless (defined $chr_start) {
  warn "WARNING : setting chr_start=1\n";
  $chr_start = 1;
}

unless (defined $dnafrag_type) {
  $dnafrag_type = "Chromosome";
}

if ($chr_start > $chr->length) {
  warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 3\n";
  exit 3;
}
unless (defined $chr_end) {
  warn "WARNING : setting chr_end=chr_length ".$chr->length."\n";
  $chr_end = $chr->length;
}
if ($chr_end > $chr->length) {
  warn "WARNING : chr_end $chr_end larger than chr_length ".$chr->length."
setting chr_end=chr_length\n";
  $chr_end = $chr->length;
}

my $dafad = $db->get_DnaAlignFeatureAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_species_region($sb_species,$qy_species,$dnafrag_type,$chr_name,$chr_start,$chr_end)};

foreach my $ddaf (@DnaDnaAlignFeatures) {
  print $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hstrand," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->cigar_string,"\n";
}

exit 0;
