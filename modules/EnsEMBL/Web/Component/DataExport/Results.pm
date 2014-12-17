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

use EnsEMBL::Web::File::User;

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

  my $filename    = $hub->param('name');
  my $format      = $hub->param('format');
  my $path        = $hub->param('file_path');
  my $compression = $hub->param('compression');
  my $html;

  $html .= sprintf(
            '<h2>Download</h2><a href="/Download/DataExport?filename=%s;format=%s;path=%s;compression=%s">Download your %s file</a>', 
              $filename, lc($format), $path, $compression, $format,
            );

  ## Hidden form taking you back to the beginning
  my $form_url  = sprintf('/%s/DataExport/%s', $hub->species, $hub->param('export_action'));
  my $form      = $self->new_form({'id' => 'export', 'action' => $form_url, 'method' => 'post'});
  my $fieldset  = $form->add_fieldset;

  foreach ($hub->param) {
    my %field_info = ('name' => $_);

    my @core_params = keys %{$hub->core_object('parameters')};
    push @core_params, qw(name format compression data_type component export_action align);
    unless (grep @core_params, $_) {
      $field_info{'name'} .= '_'.$hub->param('format');
    }

    my @values = $hub->param($_);
    my $params;
    if (scalar @values > 1) {
      $params = [];
      foreach my $v (@values) {
        my %info = %field_info;
        $info{'value'} = $v;
        push @$params, \%info;
      }
    }
    else {
      $field_info{'value'} = $values[0] if scalar @values;
      $params = \%field_info;
    }

    $fieldset->add_hidden($params);
  }

  $fieldset->add_button({
      'type'    => 'Submit',
      'name'    => 'submit',
      'value'   => 'Back',
    });


  $html .= $form->render;

  unless ($format eq 'RTF' || $compression) {
    my $file = EnsEMBL::Web::File::User->new(hub => $hub, file_path => $path);
    if ($file) {
      $html .= '<h2 style="margin-top:1em">File preview</h2><div class="code"><pre style="color:#333">';
      $html .= $file->read;
      $html .= '</pre></div>';
    }
  }

  return $html;
}

1;
