=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Export::Formats;

use strict;

use URI::Escape qw(uri_unescape);

use base 'EnsEMBL::Web::Component::Export';

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $form_action = $hub->url({ action => 'Configure', function => $hub->function }, 1);
  my $slice       = $hub->param('slice');
  my $href        = $hub->param('base_url');
  my $form        = $self->modal_form('export_output_configuration', $form_action->[0], { label => '< Back', method => 'post' });
  
  $form->add_fieldset;
  
  if ($slice) {
    my (@list, @formats, $note);
    
    if ($href) {
      @formats = (
        [ 'HTML', $href, 'HTML', ' rel="external"' ],
        [ 'Text', $href, 'Text', ' rel="external"' ],
        [ 'Compressed text (.gz)', $href, 'TextGz' ]
      );
      
      $note = 'Please choose the output format for your export';
    } else {
      @formats = (
        [ 'Sequence data',   $hub->param('seq_file'),  '', ' rel="external"', ' [FASTA format]' ],
        [ 'Annotation data', $hub->param('anno_file'), '', ' rel="external"', ' [pipmaker format]' ],
        [ 'Combined file',   $hub->param('tar_file') ]
      );
      
      $note = 'Your export has been processed successfully. You can download the exported data by following the links below';
    }
        
    foreach (@formats) {
      my $url = uri_unescape($_->[1] . ($_->[2] ? ";_format=$_->[2]" : ''));      
      push @list, qq{<a class="modal_close" href="$url"$_->[3]>$_->[0]</a>$_->[4]};
    }
    
    $form->add_notes({ class => undef, text => $note });
    $form->add_notes({ class => undef, list => \@list });
  } else { # User has input an invalid location
    $form->add_notes({ class => 'error', heading => 'Invalid Region', text => 'The region you have chosen does not exist. Please go back and try again' });
  }
  
  $form->add_element(type => 'Hidden', name => $_, value => $form_action->[1]->{$_}) for keys %{$form_action->[1]};
  
  return '<h2>Export Configuration - Output Format</h2>' . $form->render;
}

1;
