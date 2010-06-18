#!/usr/local/ensembl/bin/perl -w
=head1
  this script does homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

=cut

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Compara::Production::GeneSet;
use Bio::EnsEMBL::Compara::Production::HomologySet;
use Time::HiRes qw { time };

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_ref_hash'}    = {};
$self->{'compara_ref_missing'} = {};
$self->{'compara_new_hash'} = {};
$self->{'conversion_hash'} = {};
$self->{'allTypes'} = {};

$self->{'refDups'} = 0;
$self->{'newDups'} = 0;

my $help;
my $url1 = undef;
my $brhurl1 = undef;
my $url2 = undef;
my $gdb1 = 1;
my $gdb2 = 2;

GetOptions('help'     => \$help,
           'url1=s'   => \$url1,
           'brhurl1=s'   => \$brhurl1,
           'url2=s'   => \$url2,
           'gdb1=i'   => \$gdb1,
           'gdb2=i'   => \$gdb2,
          );

if ($help) { usage(); }

unless($url1) {
  print "\nERROR : must specify url for compara database\n\n";
  usage();
}

$self->{'comparaDBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url1 . ';type=compara');

if(defined($url2)) {
  $self->{'compara2DBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url2 . ';type=compara');
}

test_homology_set($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "homology_diff.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url1 <str>            : url of reference compara DB\n";
  print "  -url2 <str>            : url of compara DB \n";
  print "  -gdb1 <int>            : genome_db_id of first genome\n";
  print "  -gdb2 <int>            : genome_db_id of second genome\n";
  print "homology_diff.pl v1.1\n";

  exit(1);
}


##################################
#
# HomologySet testing
#
##################################


sub load_homology_set
{
  my $self = shift;
  my $method_link_type = shift;
  my $species = shift;
  
  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{'comparaDBA'}->get_Homology2Adaptor;
 
  my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids($method_link_type, $species);
  
  my $starttime = time();
  my $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss);
  printf("%1.3f sec to fetch %d homology objects\n", 
         (time() - $starttime), scalar(@{$homology_list}));

  $starttime = time();
  my $homology_set = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set->add(@{$homology_list});
  printf("%1.3f sec to load HomologySet\n", (time() - $starttime));

  return $homology_set;
}

sub load_homology_set_2
{
  my $self = shift;
  my $method_link_type = shift;
  my $species = shift;
  
  my $mlssDBA = $self->{'compara2DBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{'compara2DBA'}->get_Homology2Adaptor;
 
  my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids($method_link_type, $species);
  
  my $starttime = time();
  my $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss);
  printf("%1.3f sec to fetch %d homology objects\n", 
         (time() - $starttime), scalar(@{$homology_list}));

  $starttime = time();
  my $homology_set = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set->add(@{$homology_list});
  printf("%1.3f sec to load HomologySet\n", (time() - $starttime));

  return $homology_set;
}

sub test_homology_set
{
  my $self = shift;

  my $homology_set1; my $paralogues1_set1; my $paralogues1_set2;
  $homology_set1 = load_homology_set($self, 'ENSEMBL_HOMOLOGUES',[$gdb1,$gdb2]);
  $paralogues1_set1 = load_homology_set($self, 'ENSEMBL_HOMOLOGUES',[$gdb1]);
  $paralogues1_set2 = load_homology_set($self, 'ENSEMBL_HOMOLOGUES',[$gdb2]);
  $homology_set1->merge($paralogues1_set1);
  $homology_set1->merge($paralogues1_set2);
  print "$url1 -- down\n";
  $homology_set1->print_stats;

  if ($brhurl1) {
    $self->{'comparaDBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($brhurl1 . ';type=compara');
  }
  my $homology_set2; my $paralogues2_set1; my $paralogues2_set2;
  if (defined($url2)) {
    $homology_set2 = load_homology_set_2($self, 'ENSEMBL_HOMOLOGUES',[$gdb1,$gdb2]);
  } else {
    $homology_set2 = load_homology_set($self, 'ENSEMBL_ORTHOLOGUES',[$gdb1,$gdb2]);
    # loading brh paralogues 
    $paralogues2_set1 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb1]);
    $paralogues2_set2 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb2]);
    $homology_set2->merge($paralogues2_set1);
    $homology_set2->merge($paralogues2_set2);
  }
  my $print_url2 = $url2 || $brhurl1;
  print "$print_url2 -- right\n";
  $homology_set2->print_stats;


  my $missing1 = $homology_set2->gene_set->relative_complement($homology_set1->gene_set);
  printf("%d genes in set1 not in set2\n", $missing1->size);
  
  my $missing2 = $homology_set1->gene_set->relative_complement($homology_set2->gene_set);
  printf("%d genes in set2 not in set1\n", $missing2->size);
  
  my $cross_hash = crossref_homologies_by_type($homology_set1, $homology_set2);
  print_conversion_stats($homology_set1, $homology_set2, $cross_hash);

  #my $gset = $cross_hash->{'_missing'}->{'RHS'}->gene_set;
  #my $gset_genome_hash = $gset->hashref_by_genome;
  #foreach my $type (keys(%$gset_genome_hash)) {
  #  my $geneSet = $gset_genome_hash->{$type};
  #  printf("  %d : %d\n", $type, $geneSet->size);
  #}
  #my $tset = $homology_set1->subset_containing_genes($gset);
  #$tset->print_stats;
  #$cross_hash = $tset->crossref_homologies_by_type($homology_set2);
  #print_conversion_stats($tset, $homology_set2, $cross_hash);
  
#  if(1) {
  if(0) {
    printf("\nBest homology for gene\n");
    my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor;
    my $geneset1 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    $geneset1->add(@{$memberDBA->fetch_all_by_source_name_genome_db_id('ENSEMBLGENE',$gdb1)});
    printf("   %d genes for genome_db_id=%d\n", $geneset1->size, $gdb1);
    $cross_hash = crossref_genes_to_best_homology($geneset1, $homology_set1, $homology_set2);
    print_conversion_stats($homology_set1, $homology_set2, $cross_hash);
    
    printf("\nBest homology for gene\n");
    my $geneset2 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    $geneset2->add(@{$memberDBA->fetch_all_by_source_name_genome_db_id('ENSEMBLGENE',$gdb2)});
    printf("   %d genes for genome_db_id=%d\n", $geneset2->size, $gdb2);
    $cross_hash = crossref_genes_to_best_homology($geneset2, $homology_set1, $homology_set2);
    print_conversion_stats($homology_set1, $homology_set2, $cross_hash);
  }
}



sub crossref_homologies_by_type {
  my $homologyset1 = shift;
  my $homologyset2 = shift;
  
  my $conversion_hash = {};
  my $other_homology;
  
  foreach my $type (@{$homologyset1->types}) { $conversion_hash->{$type} = {} };
  $conversion_hash->{'_missing'} = {};

  foreach my $type1 (@{$homologyset1->types}, '_missing', 'TOTAL') {
    foreach my $type2 (@{$homologyset2->types}, '_new', 'TOTAL') {
      $conversion_hash->{$type1}->{$type2} = new Bio::EnsEMBL::Compara::Production::HomologySet;
    }
  }
  
  foreach my $homology (@{$homologyset1->list}) {
    my $type1 = $homology->description;
    $other_homology = $homologyset2->find_homology_like($homology);
    if($other_homology) {
      my $other_type = $other_homology->description;
      $conversion_hash->{$type1}->{$other_type}->add($homology);
    } else {
      $conversion_hash->{$type1}->{'_new'}->add($homology);
      $conversion_hash->{'TOTAL'}->{'_new'}->add($homology);
    }
    
    $conversion_hash->{$type1}->{'TOTAL'}->add($homology);
    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($homology);
  }
  
  foreach my $homology (@{$homologyset2->list}) {
    my $type2 = $homology->description;
    unless($homologyset1->has_homology($homology)) {
      $conversion_hash->{'_missing'}->{$type2}->add($homology);
      $conversion_hash->{'_missing'}->{'TOTAL'}->add($homology);
    }
    $conversion_hash->{'TOTAL'}->{$type2}->add($homology);
    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($homology);
  }
  
  return $conversion_hash;
}


sub crossref_genes_to_best_homology {
  #this is a hacked method.  Do not try to reuse for it will likely break.
  my $geneset = shift;
  my $homologyset1 = shift;
  my $homologyset2 = shift;
  
  my $tree_ranks = {
    'ortholog_one2one' => 1,
    'ortholog_one2many' => 2,
    'ortholog_many2many' => 3,
    'within_species_paralog' => 4,
    'between_species_paralog' => 5
  };
  
  my $brh_ranks = {
    'UBRH' => 1,
    'MBRH' => 2,
    'RHS' => 3,
    'YoungParalogues' => 4
  };

  my $conversion_hash = {};
  my $other_homology;
  
  foreach my $type (@{$homologyset1->types}) { $conversion_hash->{$type} = {} };
  $conversion_hash->{'_missing'} = {};

  foreach my $type1 (@{$homologyset1->types}, '_missing', 'TOTAL') {
    foreach my $type2 (@{$homologyset2->types}, '_new', 'TOTAL') { 
      $conversion_hash->{$type1}->{$type2} = new Bio::EnsEMBL::Compara::Production::GeneSet;
    }
  }
  
  foreach my $gene (@{$geneset->list}) {
    my $homology1 = $homologyset1->best_homology_for_gene($gene, $tree_ranks);
    my $homology2 = $homologyset2->best_homology_for_gene($gene, $brh_ranks);

    my $type1 = '_missing';
    my $type2 = '_new';
    $type1 = $homology1->description if($homology1);
    $type2 = $homology2->description if($homology2);
    
    $conversion_hash->{$type1}->{$type2}->add($gene);

    $conversion_hash->{'TOTAL'}->{$type2}->add($gene);
    $conversion_hash->{$type1}->{'TOTAL'}->add($gene);

    $conversion_hash->{'TOTAL'}->{'TOTAL'}->add($gene);
  }
      
  return $conversion_hash;
}


sub print_conversion_stats
{
  my $set1 = shift;
  my $set2 = shift;
  my $conversion_hash = shift;
  
  my @set1Types = (sort(@{$set1->types}), '_missing', '_new', 'TOTAL');
  my @set2Types = (sort(@{$set2->types}), '_missing', '_new', 'TOTAL');

  printf("\n%37s ", "");
  foreach my $type2 (@set2Types) {
    next unless(defined($conversion_hash->{$set1Types[0]}->{$type2}));
    printf("%20s ", $type2);
  }
  print("\n");
  
  foreach my $type1 (@set1Types) {
    next unless(defined($conversion_hash->{$type1}));
    printf("%37s ", $type1);
    foreach my $type2 (@set2Types) {
      next unless($conversion_hash->{$type1}->{$type2});
      my $size = $conversion_hash->{$type1}->{$type2}->size;
      printf("%20d ", $size);
    }
    print("\n");
  }
}



1;


