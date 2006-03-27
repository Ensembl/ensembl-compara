#!/usr/local/ensembl/bin/perl -w

use strict;
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

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname, 'compara')->dbc;

my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
my $dfa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaFrag');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');

my $qy_binomial = Bio::EnsEMBL::Registry->get_adaptor($qy_species,'core','MetaContainer')->get_Species->binomial;
my $tg_binomial = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','MetaContainer')->get_Species->binomial;

my $qy_gdb = $gdba->fetch_by_name_assembly($qy_binomial);
my $tg_gdb = $gdba->fetch_by_name_assembly($tg_binomial);
my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
$mlss->method_link_type($method_link_type);
$mlss->species_set([$qy_gdb, $tg_gdb]);
$mlssa->store($mlss);

my $qy_sa = Bio::EnsEMBL::Registry->get_adaptor($qy_species, 'core', 'Slice');
my %qy_slices;
foreach my $qy_slice (@{$qy_sa->fetch_all('toplevel')}) {
  $qy_slices{$qy_slice->seq_region_name} = $qy_slice;
}

my $tg_sa = Bio::EnsEMBL::Registry->get_adaptor($tg_species, 'core', 'Slice');
my %tg_slices;
foreach my $tg_slice (@{$tg_sa->fetch_all('toplevel')}) {
  $tg_slices{$tg_slice->seq_region_name} = $tg_slice;
}

my $sth_synteny_region = $dbc->prepare("insert into synteny_region (method_link_species_set_id) values (?)");
my $sth_dnafrag_region = $dbc->prepare("insert into dnafrag_region (synteny_region_id,dnafrag_id,dnafrag_start,dnafrag_end,dnafrag_strand) values (?,?,?,?,?)");

my $line_number = 1;

while (defined (my $line = <>) ) {
  chomp $line;
  if ($line =~ /^(\S+)\t.*\t.*\t(\d+)\t(\d+)\t.*\t(-1|1)\t.*\t(\S+)\t(\d+)\t(\d+)$/) {#####This will need to be changed
    my ($qy_chr,$qy_start,$qy_end,$rel,$tg_chr,$tg_start,$tg_end) = ($1,$2,$3,$4,$5,$6,$7);

    my $qy_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
    $qy_dnafrag->name($qy_chr);
    $qy_dnafrag->genome_db($qy_gdb);
    $qy_dnafrag->coord_system_name($qy_slices{$qy_chr}->coord_system->name);
    $qy_dnafrag->length($qy_slices{$qy_chr}->seq_region_length);
 
    $dfa->store_if_needed($qy_dnafrag);
    
    my $tg_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag;
    $tg_dnafrag->name($tg_chr);
    $tg_dnafrag->genome_db($tg_gdb);
    $tg_dnafrag->coord_system_name($tg_slices{$tg_chr}->coord_system->name);
    $tg_dnafrag->length($tg_slices{$tg_chr}->seq_region_length);
    $dfa->store_if_needed($tg_dnafrag);

# print STDERR "1: $qy_chr, 2: $tg_chr, qy_end: " .$qy_dnafrag->end.", tg_end: ". $tg_dnafrag->end."\n";
  
    $sth_synteny_region->execute($mlss->dbID);
    my $synteny_region_id = $sth_synteny_region->{'mysql_insertid'};
    $sth_dnafrag_region->execute($synteny_region_id,$qy_dnafrag->dbID,$qy_start,$qy_end,1);
    $sth_dnafrag_region->execute($synteny_region_id,$tg_dnafrag->dbID,$tg_start,$tg_end,$rel);
    print STDERR "synteny region line number $line_number loaded\n";
    $line_number++;
  } else {
    warn "The input file has a wrong format,
EXIT 1\n";
    exit 1;
  }

}
