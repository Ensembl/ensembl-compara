#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
#use Bio::EnsEMBL::Compara::Taxon;
use Bio::EnsEMBL::Compara::Homology;

my $compara_old = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  (-host => "ecs2d",
   -user => "ensro",
   -dbname => "ensembl_compara_16_1",
   -conf_file => "/nfs/acari/abel/src/ensembl_main/compara-family-merge/modules/Bio/EnsEMBL/Compara/Compara.conf");

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  (-host => "ecs2e",
   -user => "ensadmin",
   -pass => "ensembl",
   -dbname => "ensembl_compara_new_schema",
   -conf_file => "/nfs/acari/abel/src/ensembl_main/compara-family-merge/modules/Bio/EnsEMBL/Compara/Compara.conf");

my $ha = $compara_db->get_HomologyAdaptor;
my $gdb = $compara_db->get_GenomeDBAdaptor;
my %genomedbs;
foreach my $genomedb (@{$gdb->fetch_all}) {
  $genomedbs{$genomedb->name . $genomedb->assembly} = $genomedb;
}

my $sql = "select gm.gene_relationship_id, gm.genome_db_id, gm.member_stable_id, gm.chrom_start, gm.chrom_end, gm.chromosome,gdb.name,gdb.assembly from gene_relationship_member gm, genome_db gdb where gm.genome_db_id=gdb.genome_db_id;";

my $sth = $compara_old->prepare($sql);
$sth->execute;

my ($gene_relationship_id, $genome_db_id, $member_stable_id, $chrom_start, $chrom_end, $chromosome,$name,$assembly);
my %column;
$sth->bind_columns(\$gene_relationship_id, \$genome_db_id, \$member_stable_id, \$chrom_start, \$chrom_end, \$chromosome, \$name, \$assembly);

my %homologies;

while ($sth->fetch()) {
#  print $gene_relationship_id,"\n";
  my $member = new Bio::EnsEMBL::Compara::Member;
  $member->stable_id($member_stable_id);
  my $taxon_id = $genomedbs{$name . $assembly}->taxon_id;
  $member->taxon_id($taxon_id);
  $member->description("NULL");
  $member->genome_db_id($genomedbs{$name . $assembly}->dbID);
  $member->chr_name($chromosome);
  $member->chr_start($chrom_start);
  $member->chr_end($chrom_end);
  $member->sequence("NULL");
  $member->source_name("ENSEMBLGENE");

  my $attribute = new Bio::EnsEMBL::Compara::Attribute;
  
  if (defined $homologies{$gene_relationship_id}) {
    $homologies{$gene_relationship_id}->add_Member_Attribute([$member, $attribute]);
  } else {
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    my $stable_id = sprintf ("ENSHOMOLOG%011.0d",$gene_relationship_id);
    $homology->stable_id($stable_id);
    $homology->source_name("ENSEMBL_HOMOLOGS");
    $homology->description("ORTHOLOG");
    $homology->add_Member_Attribute([$member, $attribute]);
    $homologies{$gene_relationship_id} = $homology;
  }
}

#print scalar keys %homologies,"\n";

foreach my $hom (values %homologies) {
#  print STDERR $hom->stable_id,"\n";
#  print scalar @{$hom->get_all_Member},"\n";
  $ha->store($hom);
}
