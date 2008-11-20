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
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

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

sub dbID {
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
  my $self =shift;
  my @args = @_;

  my ($separator, $full);
  if (scalar @args) {
    ($separator, $full) = rearrange([qw(SEPARATOR FULL)], @args);
  }

  $separator = " " unless(defined $separator);
  $full = 0 unless (defined $full);

  $self->{"_separator"} = $separator unless (defined $self->{"_separator"});
  $self->{"_separator_full"} = $separator unless (defined $self->{"_separator_full"});

  $self->{'_classification'} = undef unless ($self->{"_separator"} eq $separator);
  $self->{'_classification_full'} = undef unless ($self->{"_separator_full"} eq $separator);

  return $self->{'_classification_full'} if ($full && defined $self->{'_classification_full'});
  return $self->{'_classification'} if (!$full && defined $self->{'_classification'});

  my $root = $self->root;
  my @classification;
  unless ($root->name eq "root") {
    unshift @classification, $self->name;
  }
  unless ($root->get_child_count == 0) {
    $root->_add_child_name_to_classification(\@classification, $full);
  }
  if ($self->rank eq 'species' || $self->rank eq 'subspecies') {
    my ($genus, $species, $subspecies) = split(" ", $self->binomial);
    unshift @classification, $species;
    unshift @classification, $subspecies if (defined $subspecies);
  }


  if ($full) {
    $self->{'_classification_full'} = join($separator,@classification);
    $self->{"_separator_full"} = $separator;
    return $self->{'_classification_full'};
  } else {
    $self->{'_classification'} = join($separator,@classification);
    $self->{"_separator"} = $separator;
    return $self->{'_classification'};
  }
}


=head2 subspecies

  Example    : $ncbi->subspecies;
  Description: Returns the subspeceis name for this species
  Example    : "verus" for Pan troglodytes verus
  Returntype : string
  Exceptions :
  Caller     : general

=cut

sub subspecies {
  my $self = shift;

  unless (defined $self->{'_species'}) {
    my ($genus, $species, $subspecies) = split(" ", $self->binomial);
    $self->{'_species'} = $species;
    $self->{'_genus'} = $genus;
    $self->{'_subspecies'} = $subspecies;
  }

  return $self->{'_species'};
}


=head2 species

  Example    : $ncbi->species;
  Description: Returns the speceis name for this species
  Example    : "sapiens" for Homo sapiens
  Returntype : string
  Exceptions :
  Caller     : general

=cut

sub species {
  my $self = shift;

  unless (defined $self->{'_species'}) {
    my ($genus, $species, $subspecies) = split(" ", $self->binomial);
    $self->{'_species'} = $species;
    $self->{'_genus'} = $genus;
    $self->{'_subspecies'} = $subspecies;
  }

  return $self->{'_species'};
}


=head2 genus

  Example    : $ncbi->genus;
  Description: Returns the genus name for this species
  Returntype : string
  Example    : "Homo" for Homo sapiens
  Exceptions :
  Caller     : general

=cut

sub genus {
  my $self = shift;

  unless (defined $self->{'_genus'}) {
    my ($genus, $species, $subspecies) = split(" ", $self->binomial);
    $self->{'_species'} = $species;
    $self->{'_genus'} = $genus;
    $self->{'_subspecies'} = $subspecies;
  }

  return $self->{'_genus'};
}

sub _add_child_name_to_classification {
  my $self = shift;
  my $classification = shift;
  my $full = shift;

  if ($self->get_child_count > 1) {
    throw("Can't classification on a multifurcating tree\n");
  } elsif ($self->get_child_count == 1) {
    my $child = $self->children->[0];
    if ($full) {
      unshift @$classification, $child->name unless ($child->rank eq "subgenus"
                                                     || $child->rank eq "subspecies"
                                                     || $child->rank eq "species");
    } else {
      unless ($child->genbank_hidden_flag || $child->rank eq "subgenus") {
        unshift @$classification, $child->name;
      }
    }
    unless ($child->rank eq 'species') {
      $child->_add_child_name_to_classification($classification, $full);
    }
  }
}


=head2 common_name

  Example    : $ncbi->common_name;
  Description: The comon name as defined by Genbank
  Returntype : string
  Exceptions : returns undef if no genbank common name exists.
  Caller     : general

=cut

sub common_name {
  my $self = shift;
  if ($self->has_tag('genbank common name') && $self->rank eq 'species') {
    return $self->get_tagvalue('genbank common name');
  } else {
    return undef;
  }
}

=head2 ensembl_alias_name

  Example    : $ncbi->ensembl_alias_name;
  Description: The comon name as defined by ensembl alias
  Returntype : string
  Exceptions : returns undef if no ensembl alias name exists.
  Caller     : general

=cut

sub ensembl_alias_name {
  my $self = shift;

  #Not checking for rank as we do above, because we do not get dog since the
  #rank for dog is subspecies (ensembl-51).
  if ($self->has_tag('ensembl alias name')) {
    return $self->get_tagvalue('ensembl alias name');
  } else {
    return undef;
  }
}


=head2 binomial

  Example    : $ncbi->binomial;
  Description: The binomial name (AKA the scientific name) of this genome
  Returntype : string
  Exceptions : warns when node is not a species or has no scientific name
  Caller     : general

=cut

sub binomial {
  my $self = shift;
  if ($self->has_tag('scientific name') && ($self->rank eq 'species' || $self->rank eq 'subspecies')) {
    return $self->get_tagvalue('scientific name');
  } else {
    warning("taxon_id=",$self->node_id," is not a species or subspecies. So binomial is undef\n");
    return undef;
  }
}

=head2 ensembl_alias

  Example    : $ncbi->ensembl_alias;
  Description: The ensembl_alias name (AKA the name in the ensembl website) of this genome
  Returntype : string
  Exceptions : warns when node is not a species or has no ensembl_alias
  Caller     : general

=cut

sub ensembl_alias {
  my $self = shift;
  if ($self->has_tag('ensembl alias name')) {
    return $self->get_tagvalue('ensembl alias name');
  } else {
    warning("taxon_id=",$self->node_id," is not a species or subspecies. So ensembl_alias is undef\n");
    return undef;
  }
}


=head2 short_name

  Example    : $ncbi->short_name;
  Description: The name of this genome in the Gspe ('G'enera
               'spe'cies) format.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub short_name {
  my $self = shift;
  my $name = $self->name;
  $name =~  s/(\S)\S+\s(\S{3})\S+/$1$2/;
  $name =~ s/\ //g;
  return $name;
}

sub get_short_name {
  my $self = shift;
  return $self->short_name;
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
