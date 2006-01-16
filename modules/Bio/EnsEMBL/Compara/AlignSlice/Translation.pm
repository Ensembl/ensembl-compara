#
# Ensembl module for Bio::EnsEMBL::Compara::AlignSlice::Translation
#
# Original author: Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice::Translation - Extension of the Bio::EnsEMBL::Translation
module for the translations mapped on the AlignSlices

=head1 INHERITANCE

This module inherits attributes and methods from Bio::EnsEMBL::Translation module

=head1 SYNOPSIS

The Bio::EnsEMBL::Compara::AlignSlice framework is used to map features between species. As the
original Bio::EnsEMBL::Translation might mapped only partially, this module extends the core
Bio::EnsEMBL::Translation module to allow the storage of the mapping of both start end codons.
Both start and end codons might be mapped no, one or several times. At the moment this module
implements a couple of method only, all_start_codon_mappings and all_end_codon_mappings which
return a reference to an array of Bio::EnsEMBL::Compara::AlignSlice::Slice which correspond to
sub-slices of the original Bio::EnsEMBL::Compara::AlignSlice::Slice.

Actual mapping is done by the Bio::EnsEMBL::Compara::AlignSlice::Slice module, this one only
stores the results.

=head1 OBJECT ATTRIBUTES


=head1 AUTHORS

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2006. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::AlignSlice::Translation;

use strict;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);

our @ISA = qw(Bio::EnsEMBL::Translation);


=head2 all_start_codon_mappings

  Arg [1]    : [optional] listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
  Example    : $translation->all_start_codon_mappings($all_start_codon_mappings);
  Example    : my $all_start_codon_mappings = $translation->all_start_codon_mappings();
  Description: getter/setter for the results of the mapping of the original start
               codon on the corresponding Bio::EnsEMBL::Compara::AlignSlice::Slice
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
  Exceptions :

=cut

sub all_start_codon_mappings {
  my $self = shift(@_);

  if (@_) {
    $self->{_all_start_codon_mappings} = shift;
  }

  return $self->{_all_start_codon_mappings};
}


=head2 all_end_codon_mappings

  Arg [1]    : [optional] listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
  Example    : $translation->all_end_codon_mappings($all_end_codon_mappings);
  Example    : my $all_end_codon_mappings = $translation->all_end_codon_mappings();
  Description: getter/setter for the results of the mapping of the original end
               codon on the corresponding Bio::EnsEMBL::Compara::AlignSlice::Slice
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
  Exceptions :

=cut

sub all_end_codon_mappings {
  my $self = shift(@_);

  if (@_) {
    $self->{_all_end_codon_mappings} = shift;
  }

  return $self->{_all_end_codon_mappings};
}

1;
