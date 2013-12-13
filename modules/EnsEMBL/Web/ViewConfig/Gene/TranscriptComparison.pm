=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Gene::TranscriptComparison;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig::TextSequence);

sub init {
  my $self = shift;
  
  $self->SUPER::init;
  
  $self->set_defaults({
    display_width  => 120,
    exons_only     => 'off',
    snp_display    => 'yes',
    line_numbering => 'sequence',
  });

  $self->title = 'Transcript comparison';
}

sub extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;

  return [
    'Select transcripts',
    $hub->url('Component', {
      action   => 'Web',
      function => 'TranscriptComparisonSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })
  ];
}

sub form {
  my $self                   = shift;
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # shared with compara_markup and marked-up sequence
  my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;   # shared with compara_markup
  
  $self->add_form_element($other_markup_options{'display_width'});
  $self->add_form_element({ type => 'DropDown', name => 'exons_only', select => 'select', label => 'Show exons only', values => [{ value => 'yes', caption => 'Yes' }, { value => 'off', caption => 'No' }] });
  $self->variation_options({ snp_link => 'no' }) if $self->species_defs->databases->{'DATABASE_VARIATION'};
  $self->add_form_element($general_markup_options{'line_numbering'});
  $self->add_form_element($other_markup_options{'title_display'});
}

1;
