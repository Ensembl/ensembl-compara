=head1 NAME

NCBITaxon - DESCRIPTION of Object

=head1 DESCRIPTION
  
  An object that hold a node within a taxonomic tree.  Inherits from NestedSet.

  From Bio::Species
   classification
   common_name
   binomial

  Here are also the additional methods in Bio::Species that "might" be useful, but let us
  forget about these for now.
   genus
   species
   sub_species
   variant
   organelle
   division

=head1 CONTACT

  Contact Jessica Severin on implemetation/design detail: jessica@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::NCBITaxon;

use strict;
use Bio::Species;
use Bio::EnsEMBL::Compara::NestedSet;

our @ISA = qw(Bio::EnsEMBL::Compara::NestedSet);

=head2 copy

  Arg [1]    : int $member_id (optional)
  Example    :
  Description: returns copy of object, calling superclass copy method
  Returntype :
  Exceptions :
  Caller     :

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = $self->SUPER::copy;
  bless $mycopy, "Bio::EnsEMBL::Compara::NCBITaxon";
  
  $mycopy->ncbi_taxid($self->ncbi_taxid);
  $mycopy->rank($self->rank);
  $mycopy->genbank_hidden_flag($self->genbank_hidden_flag);

  return $mycopy;
}


sub ncbi_taxid {
  my $self = shift;
  my $value = shift;
  $self->node_id($value) if($value); 
  return $self->node_id;
}

sub taxon_id {
  my $self = shift;
  my $value = shift;
  $self->node_id($value) if($value); 
  return $self->node_id;
}

sub rank {
  my $self = shift;
  $self->{'_rank'} = shift if(@_);
  return $self->{'_rank'};
}

sub genbank_hidden_flag {
  my $self = shift;
  $self->{'_genbank_hidden_flag'} = shift if(@_);
  return $self->{'_genbank_hidden_flag'};
}

sub classification {
  my $self = shift;

  unless ($self->rank eq 'species') {
    throw("classification can only be called on node of species rank\n");
  }
  
  unless (defined $self->{'_classification'}) {
    
    my $root = $self->root;
    my @classification;
    unless ($root->name eq "root") {
      unshift @classification, $self->name;
    }
    unless ($root->get_child_count == 0) {
      $root->_add_child_name_to_classification(\@classification);
    }
    my ($genus, $species) = split(" ", $self->binomial);
    unshift @classification, $species;
    $self->{'_classification'} = join(" ",@classification);
  }
  
  return $self->{'_classification'};
}

sub _add_child_name_to_classification {
  my $self = shift;
  my $classification = shift;
  if ($self->get_child_count > 1) {
    throw("Can't classification on a multifurcating tree\n");
  } elsif ($self->get_child_count == 1) {
    my $child = $self->children->[0];
    unless ($child->genbank_hidden_flag) {
      unshift @$classification, $child->name;
    }
    $child->_add_child_name_to_classification($classification);
  }
}

sub common_name {
  my $self = shift;
  if ($self->has_tag('genbank common name') && $self->rank eq 'species') {
    return $self->get_tagvalue('genbank common name');
  } else {
    return undef;
  }
}

sub binomial {
  my $self = shift;
  if ($self->has_tag('scientific name') && $self->rank eq 'species') {
    return $self->get_tagvalue('scientific name');
  } else {
    return undef;
  }
}


sub RAP_species_format {
  my $self = shift;
  my $newick = "";
  
  if($self->get_child_count() > 0) {
    $newick .= "(";
    my $first_child=1;
    foreach my $child (@{$self->sorted_children}) {  
      $newick .= "," unless($first_child);
      $newick .= $child->newick_format;
      $first_child = 0;
    }
    $newick .= ")";
  }
  
  $newick .= sprintf("\"%s\"", $self->name,);
  $newick .= sprintf(":%1.4f", $self->distance_to_parent) if($self->distance_to_parent > 0);

  if(!($self->has_parent)) {
    $newick .= ";";
  }
  return $newick;
}


sub print_node {
  my $self  = shift;
  printf("(%s", $self->node_id);
  printf(" %s", $self->rank) if($self->rank);
  print(")");
  printf("%s", $self->name) if($self->name);
  print("\n");
}

1;
