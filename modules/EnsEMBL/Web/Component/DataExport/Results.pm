=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::DataExport::Results;

use strict;
use warnings;

use EnsEMBL::Web::TmpFile;

use base qw(EnsEMBL::Web::Component::DataExport);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;

  my $format      = $hub->param('format');
  my $prefix      = $hub->param('prefix');
  my $compress    = $hub->param('compression') ? 1 : 0;
  my $html;

  $html .= sprintf(
            '<h2>Download</h2><a href="/Download/DataExport?file=%s;prefix=%s;format=%s;ext=%s;compression=%s">Download your %s file</a>', 
              $hub->param('file'), 
              $prefix,
              lc($format), 
              $hub->param('ext'),
              $hub->param('compression'),
              $format,
            );

  unless ($format eq 'RTF') {
    my $file = EnsEMBL::Web::TmpFile::Text->new(filename => $hub->param('file'), 'prefix' => $prefix, 'compress' => $compress);
    if ($file) {
      $html .= '<h2 style="margin-top:1em">File preview</h2><div class="code"><pre style="color:#333">';
      $html .= $file->content;
      $html .= '</pre></div>';
    }
  }

=pod
  ## Hidden form taking you back to the beginning
  my $form_url  = sprintf('/%s/DataExport/%s', $hub->species, $hub->param('export_action'));
  my $form      = $self->new_form({'id' => 'export', 'action' => $form_url, 'method' => 'post'});
  my $fieldset  = $form->add_fieldset;

  foreach ($hub->param) {
    my $info = {'name' => $_, 'value' => $hub->param($_)};
    my @core_params = keys %{$hub->core_object('parameters')};
    push @core_params, qw(name format compression data_type component export_action);
    unless (grep @core_params, $_) {
      $info->{'name'} .= '_'.$hub->param('format');
    }
    $fieldset->add_hidden($info);
  }

  $fieldset->add_button({
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Back',
    });


  $html .= $form->render;
=cut
  return $html;
}

1;
