=head1 NAME

Bio::EnsEMBL::Compara::NCTree - A class representing an NCTree

=end

=head1 SYNOPSIS

   my $nctree_adaptor = Bio::EnsEMBL::Registry->get_adaptor
     ("Multi", "compara", "NCTree");
   my $nctree = $nctree_adaptor->fetch_by_Member_root_id($member);

=end

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the leaves of this tree
are AlignedMember objects and the tree is a representation of a NC derived
Phylogenetic tree

=head1 CONTACT

  Contact Albert Vilella on implemetation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::NCTree;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::SimpleAlign;
use IO::File;

use Bio::EnsEMBL::Compara::ProteinTree;
our @ISA = qw(Bio::EnsEMBL::Compara::ProteinTree);


sub get_leaf_by_Member {
  my $self = shift;
  my $member = shift;

  if($member->isa('Bio::EnsEMBL::Compara::NCTree')) {
    return $self->find_leaf_by_node_id($member->node_id);
  } elsif ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    return $self->find_leaf_by_name($member->get_canonical_peptide_Member->stable_id);
  } else {
    die "Need a Member object!";
  }
}

sub get_SitewiseOmega_values {
  my $self = shift;

  $self->throw("method not defined by implementing" .
               " subclass of ProteinTree");
  return undef;
}

# Get the internal Ensembl GeneTree stable_id from the separate table
sub stable_id {
  my $self = shift;

  return undef; #FIXME, delete this line when stable_ids called for nctrees

  if(@_) {
    $self->{'_stable_id'} = shift;
    return $self->{'_stable_id'};
  }
  
  if(!defined($self->{'_stable_id'}))
    {
    $self->{'_stable_id'} = $self->adaptor->_fetch_stable_id_by_node_id($self->node_id);
  }

  return $self->{'_stable_id'};
}

1;
