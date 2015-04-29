=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Variation::Compara_Alignments;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::Compara_Alignments);

sub init { 
  my $self = shift;
  
  $self->SUPER::init;
  
  # Set a default align parameter (the smallest multiway alignment with available for this species)
  if (!$self->hub->param('align')) {
    my @alignments = map { /species_(\d+)/ && $self->{'options'}{join '_', 'species', $1, lc $self->species} ? $1 : () } keys %{$self->{'options'}};
    my %align;
    
    $align{$_}++ for @alignments;
    
    $self->hub->param('align', [ sort { $align{$a} <=> $align{$b} } keys %align ]->[0]);
  }
  
  $self->set_defaults({
    title_display => 'yes',
  });
}

sub form {
  my $self = shift;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;
  
  $self->add_form_element($general_markup_options{'hide_long_snps'});
  $self->add_form_element($general_markup_options{'line_numbering'});
  $self->add_form_element($other_markup_options{'title_display'});
  $self->alignment_options;
}

1;
