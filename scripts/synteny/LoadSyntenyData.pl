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


use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

my $usage = "$0
--help                print this menu
--dbname string
[--reg_conf string]
--ref string [previously named --qy]
--nonref string [previously named -tg]
--mlss_id int: the expected mlss_id of the synteny
\n";

my $help = 0;
my ($dbname,$qy_species, $tg_species, $reg_conf, $mlss_id);

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'reg_conf=s' => \$reg_conf,
	   'qy|ref=s' => \$qy_species,
	   'tg|nonref=s' => \$tg_species,
         'mlss_id=i' => \$mlss_id,         
);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname, 'compara');
my $dbc = $dba->dbc();

my $gdba = $dba->get_GenomeDBAdaptor();
my $dfa = $dba->get_DnaFragAdaptor();
my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor();

my $qy_gdb = $gdba->fetch_by_registry_name($qy_species);
my $tg_gdb = $gdba->fetch_by_registry_name($tg_species);

print ref($qy_gdb), " *** ", ref($tg_gdb), "\n";

my $mlss;
if ($mlss_id) {
    $mlss = $mlssa->fetch_by_dbID($mlss_id);
    my $genome_dbs = $mlss->species_set->genome_dbs;
    die "The mlss_id $mlss_id does not match the right method_link\n" if $mlss->method->type ne 'SYNTENY';
    my($qy_match, $tg_match)=(0,0);
    foreach my$this_genome_db(@$genome_dbs){
     if($this_genome_db->dbID == $qy_gdb->dbID){ 
      $qy_match++;
     } 
     elsif($this_genome_db->dbID == $tg_gdb->dbID){
      $tg_match++;
     }
    }
    die "The mlss_id $mlss_id does not match the same species set\n" unless($tg_match && $qy_match);
    
} else {
    $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method => Bio::EnsEMBL::Compara::Method->new( -type => 'SYNTENY', -class => 'SyntenyRegion.synteny' ),
        -species_set => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => [$qy_gdb, $tg_gdb] ),
    );
    $mlssa->store($mlss);
}

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
    my $synteny_region_id = $dbc->db_handle->last_insert_id(undef, undef, 'synteny_region', 'synteny_region_id');
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
	my $existing_dnafrag = $adaptor->fetch_by_GenomeDB_and_name($gdb, $chr);
	return $existing_dnafrag if $existing_dnafrag;
	my $dnafrag = Bio::EnsEMBL::Compara::DnaFrag->new_from_Slice($slice, $gdb);
	$adaptor->store($dnafrag);
	return $dnafrag;
}
