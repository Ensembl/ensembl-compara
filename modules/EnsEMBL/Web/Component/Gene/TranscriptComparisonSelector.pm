# $Id$

package EnsEMBL::Web::Component::Gene::TranscriptComparisonSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select transcripts';
  $self->{'included_header'} = 'Selected transcripts';
  $self->{'excluded_header'} = 'Unselected transcripts';
  $self->{'panel_type'}      = 'MultiSelector';
  $self->{'url_param'}       = 't';
  $self->{'rel'}             = 'modal_select_transcripts';
}

sub content_ajax {
  my $self  = shift;
  my $hub   = $self->hub;
  my %all   = map { $_->stable_id => sprintf '%s (%s)', $_->external_name || $_->stable_id, ucfirst join ' ', split '_', $_->biotype; } @{$self->object->Obj->get_all_Transcripts};
  my %shown = map { $hub->param("t$_") => $_ } grep s/^t(\d+)$/$1/, $hub->param;
  
  $self->{'all_options'}      = \%all;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

1;
