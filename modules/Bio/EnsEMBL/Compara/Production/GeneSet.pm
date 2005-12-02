#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GeneSet

=cut

=head1 SYNOPSIS

An abstract data class for holding an arbitrary collection of
(ENSEMBLGENE)Member objects and providing set operations and 
cross-reference operations to compare to another GeneSet object.
Also used by HomologySet.

=cut

=head1 DESCRIPTION

A 'set' object of Gene objects.  Uses Member::stable_id to identify unique genes.  
Is used for comparing GeneSet objects with each other and building comparison
matrixes.

Not really a production object, but more an abstract data type for use by
post analysis scripts.  Placed in Production since I could not think of a better location.
The design of this object essentially was within the homology_diff.pl script
but has now been formalized into a proper object design.

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


package Bio::EnsEMBL::Compara::Production::GeneSet;

use strict;
use Bio::EnsEMBL::Compara::Member;

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
  return $self->SUPER::dealloc;
}


sub clear {
  my $self = shift;
    
  $self->{'gene_hash'} = {};
}


sub add {
  my $self = shift;
  my @gene_list = @_; 
  
  foreach my $gene (@gene_list) {
    next if(defined($self->{'gene_hash'}->{$gene->stable_id}));
    $self->{'gene_hash'}->{$gene->stable_id} = $gene;
  }  
  return $self;
}


sub merge {
  my $self = shift;
  my $other_set = shift;
  
  $self->add(@{$other_set->list});
  return $self;
}


### gene ###

sub size {
  my $self = shift;
  return scalar(@{$self->list});
}

sub list {
  my $self = shift;
  my @genes = values(%{$self->{'gene_hash'}});
  return \@genes;
}

sub includes {
  my $self = shift;
  my $gene = shift;
  return 1 if(defined($self->{'gene_hash'}->{$gene->stable_id}));
  return 0;
}

sub find_gene_like {
  my $self = shift;
  my $gene = shift;
  return $self->{'gene_hash'}->{$gene->stable_id};
}


### debug printing ###

sub print_stats {
  my $self = shift;
  
  printf("%d unique genes\n", $self->size);
}


sub hashref_by_genome {
  my $self = shift;
  my %types;
  foreach my $gene (@{$self->list}) {
    unless(defined($types{$gene->genome_db_id})) {
      $types{$gene->genome_db_id} = 
         new Bio::EnsEMBL::Compara::Production::GeneSet;
    }
    $types{$gene->genome_db_id}->add($gene);
  }
  return \%types;
}


############################################
#
# set theory operations
#
############################################

sub relative_complement {
  my $self = shift;
  my $other_set = shift;
  
  #genes in other_set that are not in my set
  my $new_set = new Bio::EnsEMBL::Compara::Production::GeneSet;
  foreach my $gene (@{$other_set->list}) {
    unless($self->includes($gene)) {
      $new_set->add($gene);
    }
  }
  return $new_set;
}


sub intersection {
  my $self = shift;
  my $other_set = shift;
  
  my $new_set = new Bio::EnsEMBL::Compara::Production::GeneSet;
  foreach my $gene (@{$self->list}) {
    if($other_set->includes($gene)) {
      $new_set->add($gene);
    }
  }
  return $new_set;
}


1;
