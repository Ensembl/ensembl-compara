# $Id$

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
