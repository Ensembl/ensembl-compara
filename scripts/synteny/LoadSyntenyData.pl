#!/usr/local/ensembl/bin/perl

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

my $usage = "$0
--help                print this menu
--dbname string
[--reg_conf string]
--qy string
--tg string
\n";

my $help = 0;
my ($dbname,$qy_species, $tg_species, $reg_conf);
my $method_link_type = "SYNTENY";

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'reg_conf=s' => \$reg_conf,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname, 'compara');
my $dbc = $dba->dbc();

my $gdba = $dba->get_GenomeDBAdaptor();
my $dfa = $dba->get_DnaFragAdaptor();
my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor();

my $qy_gdb = $gdba->fetch_by_registry_name($qy_species);
my $tg_gdb = $gdba->fetch_by_registry_name($tg_species);

my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
	-METHOD_LINK_TYPE => $method_link_type, -SPECIES_SET => [$qy_gdb, $tg_gdb]);
$mlssa->store($mlss);

my $qy_slices = get_slices($qy_gdb);
my $tg_slices = get_slices($tg_gdb);

my $sth_synteny_region = $dbc->prepare('insert into synteny_region (method_link_species_set_id) values (?)');
my $sth_dnafrag_region = $dbc->prepare(q{insert into dnafrag_region (synteny_region_id,dnafrag_id,dnafrag_start,dnafrag_end,dnafrag_strand) values (?,?,?,?,?)});

my $line_number = 1;

while (defined (my $line = <>) ) {
  chomp $line;
  if ($line =~ /^(\S+)\t.*\t.*\t(\d+)\t(\d+)\t.*\t(-1|1)\t.*\t(\S+)\t(\d+)\t(\d+)$/) {#####This will need to be changed
    my ($qy_chr,$qy_start,$qy_end,$rel,$tg_chr,$tg_start,$tg_end) = ($1,$2,$3,$4,$5,$6,$7);

    my $qy_dnafrag = store_dnafrag($qy_chr, $qy_gdb, $qy_slices, $dfa);
    my $tg_dnafrag = store_dnafrag($tg_chr, $tg_gdb, $tg_slices, $dfa);

# print STDERR "1: $qy_chr, 2: $tg_chr, qy_end: " .$qy_dnafrag->end.", tg_end: ". $tg_dnafrag->end."\n";
  
    $sth_synteny_region->execute($mlss->dbID);
    my $synteny_region_id = $sth_synteny_region->{'mysql_insertid'};
    $sth_dnafrag_region->execute($synteny_region_id, $qy_dnafrag->dbID, $qy_start, $qy_end, 1);
    $sth_dnafrag_region->execute($synteny_region_id, $tg_dnafrag->dbID, $tg_start, $tg_end, $rel);
    print STDERR "synteny region line number $line_number loaded\n";
    $line_number++;
  } else {
    warn "The input file has a wrong format,
EXIT 1\n";
    exit 1;
  }

}

$sth_synteny_region->finish();
$sth_dnafrag_region->finish();

#Returns a hash of slices keyed by name; slice names at toplevel must be 
#unique otherwise this entire pipeline goes wrong
sub get_slices {
	my ($gdb) = @_;
	my $sa = $gdb->db_adaptor()->get_SliceAdaptor();
	my %slice_hash;
	foreach my $slice (@{$sa->fetch_all('toplevel')}) {
		$slice_hash{$slice->seq_region_name} = $slice;
	}
	return \%slice_hash;
}

sub store_dnafrag {
	my ($chr, $gdb, $slices, $adaptor) = @_;
	my $slice = $slices->{$chr};
	my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new(
		-NAME => $chr,
		-GENOME_DB => $gdb,
		-COORD_SYSTEM_NAME => $slice->coord_system()->name(),
		-LENGTH => $slice->seq_region_length()
	);
	$adaptor->store_if_needed($dnafrag);
	return $dnafrag;
}