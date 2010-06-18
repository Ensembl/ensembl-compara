#!/usr/local/ensembl/bin/perl -w
=head1
  this script does homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

=cut

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Compara::Production::GeneSet;
use Bio::EnsEMBL::Compara::Production::HomologySet;
use Time::HiRes qw { time };
use Bio::EnsEMBL::Registry;

$| = 1;

Bio::EnsEMBL::Registry->no_version_check(1);

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
my $url2 = undef;
my $gdb1 = 1;
my $gdb2 = 2;
my $conf = undef;
my $best = 0;

GetOptions('help'   => \$help,
           'url1=s' => \$url1,
           'url2=s' => \$url2,
           'gdb1=i' => \$gdb1,
           'gdb2=i' => \$gdb2,
           'conf=s' => \$conf,
           'best'   => \$best);

if ($help) { usage(); }

unless($url1 && $url2) {
  print "\nERROR : must specify a compara database url for both --url1 anf --url2\n\n";
  usage();
}

unless ($conf) {
  print "\nERROR : must provide a homology description scoring file with --conf\n\n";
  usage();
}

$self->{$url1} = Bio::EnsEMBL::Hive::URLFactory->fetch($url1 . ';type=compara');
$self->{$url2} = Bio::EnsEMBL::Hive::URLFactory->fetch($url2 . ';type=compara');

my ($homology_description_ranking_set1, $homology_description_ranking_set2) = @{do($conf)};

print STDERR "\nranking for homology description of set 1\n";
foreach my $desc (sort {$homology_description_ranking_set1->{$a} <=> $homology_description_ranking_set1->{$b}} keys %$homology_description_ranking_set1) {
  print STDERR " ",$homology_description_ranking_set1->{$desc}," ",$desc,"\n";
}

print STDERR "\nranking for homology description of set 2\n";
foreach my $desc (sort {$homology_description_ranking_set2->{$a} <=> $homology_description_ranking_set2->{$b}} keys %$homology_description_ranking_set2) {
  print STDERR " ",$homology_description_ranking_set2->{$desc}," ",$desc,"\n";
}

compare_homology_sets($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "\nhomology_diff.pl [options]\n";
  print " --help                  : print this help\n";
  print " --url1 <str>            : url of reference compara DB\n";
  print " --url2 <str>            : url of compara DB \n";
  print " --gdb1 <int>            : genome_db_id of first genome\n";
  print " --gdb2 <int>            : genome_db_id of second genome\n";
  print " --conf <str>            : path to configuration file. An example is given\n";
  print "                           ensembl-compara/scripts/compare/homology_diff.conf.pl\n";
  print " --best                  : will print out numbers on the basis of gene counts,\n";
  print "                           not only homologies (or gene pairs)";
  print "\n";

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
  my $url = shift;

  my $mlssDBA = $self->{$url}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{$url}->get_HomologyAdaptor;
 
  my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids($method_link_type, $species);

  unless (defined $mlss) {
    return undef;
  }

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

sub compare_homology_sets
{
  my $self = shift;

  my $homology_set1;
  my $paralogues1_set1;
  my $paralogues1_set2;

  print "\n$url1 -- in the final table shown in left down\n";
  $homology_set1 = load_homology_set($self, 'ENSEMBL_ORTHOLOGUES',[$gdb1,$gdb2],$url1);
  $paralogues1_set1 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb1],$url1);
  $paralogues1_set2 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb2],$url1);
  $homology_set1->merge($paralogues1_set1);
  $homology_set1->merge($paralogues1_set2);
  $homology_set1->print_stats;

  my $homology_set2;
  my $paralogues2_set1;
  my $paralogues2_set2;

  print "\n$url2 -- in the final table shown in horizontal right\n";
  $homology_set2 = load_homology_set($self, 'ENSEMBL_ORTHOLOGUES',[$gdb1,$gdb2],$url2);
  $paralogues2_set1 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb1],$url2);
  $paralogues2_set2 = load_homology_set($self, 'ENSEMBL_PARALOGUES',[$gdb2],$url2);
  $homology_set2->merge($paralogues2_set1);
  $homology_set2->merge($paralogues2_set2);
  $homology_set2->print_stats;

  my $missing1 = $homology_set2->gene_set->relative_complement($homology_set1->gene_set);
  printf("\n%d genes in set1 not in set2\n", $missing1->size);

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

  if($best) {
    printf("\nBest homology for gene\n");
    my $memberDBA = $self->{$url1}->get_MemberAdaptor;
    my $gdba = $self->{$url1}->get_GenomeDBAdaptor;
    my $geneset1 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    my $genome_db1 = $gdba->fetch_by_dbID($gdb1);
    $geneset1->add(@{$memberDBA->fetch_all_by_source_taxon('ENSEMBLGENE',$genome_db1->taxon_id)});
    printf("   %d genes for genome_db_id=%d\n", $geneset1->size, $gdb1);
    $cross_hash = crossref_genes_to_best_homology($geneset1, $homology_set1, $homology_set2);
    print_conversion_stats($homology_set1, $homology_set2, $cross_hash);
    
    printf("\nBest homology for gene\n");
    my $geneset2 = new Bio::EnsEMBL::Compara::Production::GeneSet;
    my $genome_db2 = $gdba->fetch_by_dbID($gdb2);
    $geneset2->add(@{$memberDBA->fetch_all_by_source_taxon('ENSEMBLGENE',$genome_db2->taxon_id)});
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
    if (scalar @{$homology->method_link_species_set->species_set} == 1) {
      my ($gdb) = @{$homology->method_link_species_set->species_set};
      $type1 .= "_".$gdb->dbID;
      unless (defined $homology_description_ranking_set1->{$type1}) {
        $homology_description_ranking_set1->{$type1} = $homology_description_ranking_set1->{$homology->description};
      }
    }
    $other_homology = $homologyset2->find_homology_like($homology);
    if($other_homology) {
      my $other_type = $other_homology->description;
      if (scalar @{$other_homology->method_link_species_set->species_set} == 1) {
        my ($gdb) = @{$other_homology->method_link_species_set->species_set};
        $other_type .= "_".$gdb->dbID;
        unless (defined $homology_description_ranking_set2->{$other_type}) {
          $homology_description_ranking_set2->{$other_type} = $homology_description_ranking_set2->{$other_homology->description};
        }
      }
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
    if (scalar @{$homology->method_link_species_set->species_set} == 1) {
      my ($gdb) = @{$homology->method_link_species_set->species_set};
      $type2 .= "_".$gdb->dbID;
      unless (defined $homology_description_ranking_set2->{$type2}) {
        $homology_description_ranking_set2->{$type2} = $homology_description_ranking_set2->{$homology->description};
      }
    }
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
    my $homology1 = $homologyset1->best_homology_for_gene($gene, $homology_description_ranking_set1);
    my $homology2 = $homologyset2->best_homology_for_gene($gene, $homology_description_ranking_set2);

    my $type1 = '_missing';
    my $type2 = '_new';
    if (defined $homology1) {
      $type1 = $homology1->description;
      if (scalar @{$homology1->method_link_species_set->species_set} == 1) {
        my ($gdb) = @{$homology1->method_link_species_set->species_set};
        $type1 .= "_".$gdb->dbID;
        unless (defined $homology_description_ranking_set1->{$type1}) {
          $homology_description_ranking_set1->{$type1} = $homology_description_ranking_set1->{$homology1->description};
        }
      }
    }
    if (defined $homology2) {
      $type2 = $homology2->description;
      if (scalar @{$homology2->method_link_species_set->species_set} == 1) {
        my ($gdb) = @{$homology2->method_link_species_set->species_set};
        $type2 .= "_".$gdb->dbID;
        unless (defined $homology_description_ranking_set2->{$type2}) {
          $homology_description_ranking_set2->{$type2} = $homology_description_ranking_set2->{$homology2->description};
        }
      }
    }
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
  
  my @set1Types = (sort({$homology_description_ranking_set1->{$a} <=> $homology_description_ranking_set1->{$b} || $a cmp $b} @{$set1->types}), '_missing', 'TOTAL');

  my @set2Types = (sort({$homology_description_ranking_set2->{$a} <=> $homology_description_ranking_set2->{$b} || $a cmp $b} @{$set2->types}), '_new', 'TOTAL');

  my $longest_type_string_length = 0;
  foreach my $type1 (@set1Types) {
    $longest_type_string_length = length($type1) if (length($type1) > $longest_type_string_length);
  }

  printf("\n%".$longest_type_string_length."s", "");
  foreach my $type2 (@set2Types) {
    foreach my $type1 (@set1Types) {
      next unless(defined($conversion_hash->{$type1}->{$type2}));
      my $l = length($type2) + 1;
      $l = 8 if ($l < 8);
      printf("%".$l."s", $type2);
      last;
    }
  }
  print("\n");
  
  foreach my $type1 (@set1Types) {
    next unless(defined($conversion_hash->{$type1}));
    printf("%".$longest_type_string_length."s", $type1);
    foreach my $type2 (@set2Types) {
      next unless($conversion_hash->{$type1}->{$type2});
      my $l = length($type2) + 1;
      $l = 8 if ($l < 8);
      my $size = $conversion_hash->{$type1}->{$type2}->size;
      printf("%".$l."s", $size);
    }
    print("\n");
  }
}

1;


