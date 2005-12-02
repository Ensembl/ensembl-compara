#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::HomologySet

=cut

=head1 SYNOPSIS

An abstract data class for holding an arbitrary collection of
Hhomology objects and providing set operations and cross-reference
operations to compare to another HomologySet object.

=cut

=head1 DESCRIPTION

A 'set' object of Homology objects.  Uses Homology::homology_key to identify
unique homologies and Member::stable_id to identify unique genes.  
Is used for comparing HomologySet objects with each other and building comparison
matrixes.

Not really a production object, but more an abstract data type for use by
post analysis scripts.  Placed in Production since I could not think of a better location.
The design of this object essentially was within the homology_diff.pl script
but has now been formalized into a proper object design.

General use is like:
  $homology_set1 = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set1->add(@{$homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss1));
  
  $homology_set2 = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set2->add(@{$homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss2));

  $crossref = $homology_set1->crossref_homologies_by_type($homology_set2);
  $homology_set1->print_conversion_stats($homology_set2,$crossref);


=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::Production::HomologySet;

use strict;
use Bio::EnsEMBL::Compara::Production::GeneSet;
use Bio::EnsEMBL::Compara::Homology;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::Graph::CGObject;
our @ISA = qw(Bio::EnsEMBL::Compara::Graph::CGObject);


sub init {
  my $self = shift;
   $self->SUPER::init;
   $self->clear;
  return $self;
}

sub dealloc {
  my $self = shift;
  #$self->unlink_all_neighbors;
  return $self->SUPER::dealloc;
}


sub clear {
  my $self = shift;
    
  $self->{'conversion_hash'} = {};
  $self->{'gene_set'} = new Bio::EnsEMBL::Compara::Production::GeneSet;
  $self->{'homology_hash'} = {};
  $self->{'gene_to_homologies'} = {};
  $self->{'types'} = {};
}


sub add {
  my $self = shift;
  my @homology_list = @_; 
  
  foreach my $homology (@homology_list) {
    next if(defined($self->{'homology_hash'}->{$homology->homology_key}));
    #printf("HomologySet add: %s\n", $homology->homology_key);
    my ($gene1, $gene2) = @{$homology->gene_list};
    $self->{'homology_hash'}->{$homology->homology_key} = $homology;
    $self->{'gene_set'}->add($gene1);
    $self->{'gene_set'}->add($gene2);
    $self->{'types'}->{$homology->description}++;

    $self->{'gene_to_homologies'}->{$gene1->stable_id} = []
      unless(defined($self->{'gene_to_homologies'}->{$gene1->stable_id}));
    $self->{'gene_to_homologies'}->{$gene2->stable_id} = []
      unless(defined($self->{'gene_to_homologies'}->{$gene2->stable_id}));      

    push @{$self->{'gene_to_homologies'}->{$gene1->stable_id}}, $homology;
    push @{$self->{'gene_to_homologies'}->{$gene2->stable_id}}, $homology;
  }  
  return $self;
}


sub merge {
  my $self = shift;
  my $other_set = shift;
  
  $self->add(@{$other_set->list});
  return $self;
}


### homology types ie description ###

sub types {
  my $self = shift;
  my @types = keys(%{$self->{'types'}});
  return \@types;
}


sub count_for_type {
  my $self = shift;
  my $type = shift;
  my $count = $self->{'types'}->{$type};
  $count=0 unless(defined($count));
  return $count;
}

### homology ###

sub size {
  my $self = shift;
  return scalar(keys(%{$self->{'homology_hash'}}));
}

sub list {
  my $self = shift;
  my @homologies = values(%{$self->{'homology_hash'}});
  return \@homologies;
}

sub has_homology {
  my $self = shift;
  my $homology = shift;
  return 1 if(defined($self->{'homology_hash'}->{$homology->homology_key}));
  return 0;
}

sub find_homology_like {
  my $self = shift;
  my $homology = shift;
  return $self->{'homology_hash'}->{$homology->homology_key};
}

sub subset_containing_genes {
  my $self = shift;
  my $gene_set = shift;
  my $newset = new Bio::EnsEMBL::Compara::Production::HomologySet;
  foreach my $homology (@{$self->list}) {
    foreach my $gene (@{$homology->gene_list}) {
      if($gene_set->includes($gene)) {
        $newset->add($homology);
      }
    }
  }
  return $newset;
}

sub homologies_for_gene {
  my $self = shift;
  my $gene = shift;
  my $homologies = $self->{'gene_to_homologies'}->{$gene->stable_id};
  return $homologies if($homologies);
  return [];
}

sub best_homology_for_gene {
  my $self = shift;
  my $gene = shift;
  my $ordered_types = shift; #hashref type=>rank
    
  my $best_homology = undef;
  my $best_rank = undef;
  
  #$gene->print_member;
  foreach my $homology (@{$self->homologies_for_gene($gene)}) {
    #$homology->print_homology;
    my $rank = $ordered_types->{$homology->description};
    if(!defined($best_rank) or ($rank and ($rank<$best_rank))) {
      $best_homology = $homology;
      $best_rank = $rank;
    }
  }
  #if($best_homology) { printf("BEST: "); $best_homology->print_homology; }
  return $best_homology;
}

### gene ###

sub gene_set {
  my $self = shift;
  return $self->{'gene_set'};
}

### debug printing ###

sub print_stats {
  my $self = shift;
  
  printf("%d unique genes\n", $self->gene_set->size);
  printf("%d unique homologies\n", $self->size);
  foreach my $type (@{$self->types}) {
    printf("%10d : %s\n", $self->count_for_type($type), $type);
  }
}



1;
