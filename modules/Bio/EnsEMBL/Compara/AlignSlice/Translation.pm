=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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

=head1 AUTHORS

Javier Herrero

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::AlignSlice::Translation;

use strict;
use warnings;
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
