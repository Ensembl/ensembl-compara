=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::TranscriptComparisonSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  my $hub = $self->hub;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select transcripts';
  $self->{'included_header'} = 'Selected transcripts';
  $self->{'excluded_header'} = 'Unselected transcripts';
  $self->{'panel_type'}      = 'MultiSelector';
  $self->{'url_param'}       = 't';
  $self->{'rel'}             = 'modal_select_transcripts';
  $self->{'url'}             = $hub->url({ function => undef, action => 'TranscriptComparison', align => $hub->param('align') }, 1);
}

sub content_ajax {
  my $self  = shift;
  my $hub   = $self->hub;
  my %shown = map { $hub->param("t$_") => $_ } grep s/^t(\d+)$/$1/, $hub->param;
  my %select_by;
  
  foreach (@{$self->object->Obj->get_all_Transcripts}) {
    my $biotype = ucfirst join ' ', split '_', $_->biotype;
    $self->{'all_options'}{$_->stable_id} = sprintf '%s (%s)', $_->external_name || $_->stable_id, $biotype;
    $select_by{$_->biotype} = $biotype;
  }
  
  $self->{'included_options'} = \%shown;
  $self->{'select_by'}        = [ [ 'none', 'None' ], map([ $_, $select_by{$_} ], sort { $a cmp $b } keys %select_by), [ 'all', 'All' ] ];
  
  $self->SUPER::content_ajax;
}

1;
