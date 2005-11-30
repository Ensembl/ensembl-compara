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
  $self->{'types'} = {};
}


sub add {
  my $self = shift;
  my @homology_list = @_; 
  
  foreach my $homology (@homology_list) {
    next if(defined($self->{'homology_hash'}->{$homology->homology_key}));
    #printf("HomologySet add: %s\n", $homology->homology_key);    
    my ($ma1, $ma2) = @{$homology->get_all_Member_Attribute};
    my $geneMember1 = $ma1->[0];
    my $geneMember2 = $ma2->[0];
    $self->{'homology_hash'}->{$homology->homology_key} = $homology;
    $self->{'gene_set'}->add($geneMember1);
    $self->{'gene_set'}->add($geneMember2);
    $self->{'types'}->{$homology->description}++;    
  }  
  return $self;
}


sub merge {
  my $self = shift;
  my $other_set = shift;
  
  $self->add(@{$other_set->homology_list});
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

sub homology_count {
  my $self = shift;
  return scalar(keys(%{$self->{'homology_hash'}}));
}

sub homology_list {
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
  foreach my $homology (@{$self->homology_list}) {
    foreach my $gene (@{$homology->gene_list}) {
      if($gene_set->includes($gene)) {
        $newset->add($homology);
      }
    }
  }
  return $newset;
}


### gene ###

sub gene_set {
  my $self = shift;
  return $self->{'gene_set'};
}

### debug printing ###

sub print_stats {
  my $self = shift;
  
  printf("%d unique genes\n", $self->gene_set->count);
  printf("%d unique homologies\n", $self->homology_count);
  foreach my $type (@{$self->types}) {
    printf("%10d : %s\n", $self->count_for_type($type), $type);
  }
}


############################################
#
# HomologySet cross-referencing operations
#
############################################


sub crossref_homologies_by_type {
  my $self = shift;
  my $other_set = shift;
  
  my $conversion_hash = {};
  my $other_homology;
  
  foreach my $type (@{$self->types}) { $conversion_hash->{$type} = {} };
  $conversion_hash->{'_missing'} = {};

  foreach my $type1 (@{$self->types}, '_missing') {
    foreach my $type2 (@{$other_set->types}, '_new') { 
      $conversion_hash->{$type1}->{$type2} = new Bio::EnsEMBL::Compara::Production::HomologySet;
    }
  }
  
  foreach my $homology (@{$self->homology_list}) {
    my $ref_type = $homology->description;
    $other_homology = $other_set->find_homology_like($homology);
    if($other_homology) {
      my $other_type = $other_homology->description;
      $conversion_hash->{$ref_type}->{$other_type}->add($homology);
    } else {
      $conversion_hash->{$ref_type}->{'_new'}->add($homology);
    }
  }
  
  foreach my $homology (@{$other_set->homology_list}) {
    my $type = $homology->description;
    unless($self->has_homology($homology)) {
      $conversion_hash->{'_missing'}->{$type}->add($homology);
    }
  }
  
  return $conversion_hash;
}


sub print_conversion_stats
{
  my $self = shift;
  my $set2 = shift;
  my $conversion_hash = shift;
  
  my @refTypes = sort(@{$self->types});
  my @newTypes = sort(@{$set2->types});
  push @refTypes, '_missing';
  push @newTypes, '_new';

  printf("\n%35s ", "");
  foreach my $new_type (@newTypes) {
    printf("%10s ", $new_type);
  }
  print("\n");
  
  foreach my $ref_type (@refTypes) {
    my $convHash = $conversion_hash->{$ref_type};
    printf("%35s ", $ref_type);
    foreach my $new_type (@newTypes) {
      my $count = $conversion_hash->{$ref_type}->{$new_type}->homology_count;
      printf("%10d ", $count);
    }
    print("\n");
  }
}


1;
