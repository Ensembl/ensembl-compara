#!/usr/local/ensembl/bin/perl -w

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
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::EnsEMBL::Compara::NestedSet;
use Switch;

$| = 1;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'scale'} = 100;


my ($help, $url);

GetOptions('help'        => \$help,
           'url=s'       => \$url,
           'taxon_id=i'   => \$self->{'taxon_id'},
           'taxa_list=s'   => \$self->{'taxa_list'},
           'name=s'   => \$self->{'scientific_name'},
           'scale=f'     => \$self->{'scale'},
           'mini'        => \$self->{'minimize_tree'},
           'count'       => \$self->{'stats'},
          );

my $state;
if($self->{'taxon_id'}) { $state=1; }
if($self->{'scientific_name'}) { $state=2; }
if($self->{'taxa_list'}) { 
  $self->{'taxa_list'} = [ split(",",$self->{'taxa_list'}) ];
  $state=3;
}

if ($help or !$state) { usage(); }

$self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara') if($url);
unless(defined($self->{'comparaDBA'})) {
  print("no url URL\n\n");
  usage();
}

Bio::EnsEMBL::Registry->no_version_check(1);

switch($state) {
  case 1 { fetch_by_ncbi_taxon_id($self); }
  case 2 { fetch_by_scientific_name($self); }
  case 3 { fetch_by_ncbi_taxa_list($self); }
}


#cleanup memory
#if($self->{'root'}) {
#  print("ABOUT TO MANUALLY release tree\n");
#  $self->{'root'}->release_tree;
#  $self->{'root'} = undef;
#  print("DONE\n");
#}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "testTaxonTree.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <string>          : connect to compara at url e.g. mysql://ensro\@ia64e/abel_tree_test\n";
  print "  -taxon_id <int>        : print tree by taxon_id\n";
  print "  -taxa_list <string>    : print tree by taxa list e.g. \"9606,10090\"\n";
  print "  -scale <int>           : scale factor for printing tree (def: 100)\n";
  print "  -mini                  : minimize tree\n";
  print "taxonTreeTool.pl v1.1\n";

  exit(1);
}

sub fetch_by_ncbi_taxon_id {
  my $self = shift;
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $node = $taxonDBA->fetch_node_by_taxon_id($self->{'taxon_id'});
  $node->release_children;
  my $root = $node->root;

  $root->print_tree($self->{'scale'});
  if ($node->rank eq 'species') {
    print "classification: ",$node->classification,"\n";
    print "scientific name: ",$node->binomial,"\n";
    if (defined $node->common_name) {
      print "common name: ",$node->common_name,"\n";
    } else {
      print "no common name\n";
    }
  }
}

sub fetch_by_scientific_name {
  my $self = shift;
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $node = $taxonDBA->fetch_node_by_name($self->{'scientific_name'});
  $node->release_children;
  my $root = $node->root;

  $root->print_tree($self->{'scale'});
  if ($node->rank eq 'species') {
    print "classification: ",$node->classification,"\n";
    print "scientific name: ",$node->binomial,"\n";
    if (defined $node->common_name) {
      print "common name: ",$node->common_name,"\n";
    } else {
      print "no common name\n";
    }
  }
}

sub fetch_by_ncbi_taxa_list {
  my $self = shift;
  
  my @taxa_list = @{$self->{'taxa_list'}};

  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $first_taxon_id = shift @taxa_list;
  my $node = $taxonDBA->fetch_node_by_taxon_id($first_taxon_id);
  $node->release_children;
  my $root = $node->root;

  foreach my $taxon_id (@taxa_list) {
    my $node = $taxonDBA->fetch_node_by_taxon_id($taxon_id);
    unless (defined $node) {
      print STDERR "$taxon_id not in the database\n";
      next;
    }
    $node->release_children;
    $root->merge_node_via_shared_ancestor($node);
  }

  $root->print_tree($self->{'scale'});
  $root->flatten_tree->print_tree($self->{'scale'});
#  $self->{'root'} = $root;
}


sub fetch_compara_ncbi_taxa {
  my $self = shift;
  
  printf("fetch_compara_ncbi_taxa\n");
  
  my $taxonDBA = $self->{'comparaDBA'}->get_NCBITaxonAdaptor;
  my $root = $self->{'root'};

  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_node_by_taxon_id($gdb->taxon_id);
    $taxon->release_children;

    $root = $taxon->root unless($root);
    $root->merge_node_via_shared_ancestor($taxon);
  }


  #$root = $root->find_node_by_name('Mammalia');
  
  $root->minimize_tree if($self->{'minimize_tree'});
  
  $root->print_tree($self->{'scale'});
  
  my $newick = $root->newick_format;
  print("$newick\n");

  $self->{'root'} = $root;
  
  drawPStree($self);
}
