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

package EnsEMBL::Web::Component::Export::Alignments;

use strict;

use URI::Escape qw(uri_unescape);

use EnsEMBL::Web::Constants;

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $align = $hub->referer->{'params'}->{'align'}->[0];
  
  my $params = {
    action   => 'Location', 
    type     => 'Export/Output', 
    function => 'Alignment',
    output   => 'alignment',
    align    => $align
  };
  
  my $form = $self->modal_form('export_output_configuration', '#', { no_button => 1, method => 'get' });
  
  $form->add_fieldset;
  
  if ($align) {
    my $href    = uri_unescape($hub->url($params));
    my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
    my @list    = map qq{<a class="modal_close" href="$href;format=$_;_format=Text" rel="external">$formats{$_}</a>}, sort keys %formats;
    
    $form->add_notes({ class => undef, text => 'Please choose a format for your exported data' });
    $form->add_notes({ class => undef, list => \@list });
  } else {
    $form->add_notes({ class => undef, text => 'Please choose an alignment to export on the main page' });
  }
  
  return '<h2>Export Configuration - Genomic Alignments</h2>' . $form->render;
}

1;
