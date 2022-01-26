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

package EnsEMBL::Web::Component::DataExport::Results;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

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

  my $filename    = $hub->param('filename');
  my $format      = $hub->param('format');
  my $path        = $hub->param('file');
  my $html;

  my $export_action = $hub->param('export_action');
  my $back_action = $hub->url({'action' => 'Output',  'function' => '', '__clear' => 1});
  my $download_href = $hub->url('Download', {
    'action'      => '',
    'function'    => '',
    'filename'    => $filename,
    'file'        => $path,
    'compression' => '',
    'format'      => $format
  });
  my $download_compressed_action = $hub->url({'action' => 'Output',  'function' => '', '__clear' => 1});

  ## Hidden form taking you back to the beginning
  my $form      = $self->new_form({'id' => 'export', 'class' => 'bgcolour', 'action' => $hub->url({'action' => $hub->param('export_action')}), 'method' => 'post'});
  my $fieldset  = $form->add_fieldset;

  my @core_params = keys %{$hub->core_object('parameters')};
  push @core_params, qw(name format compression data_type data_action component export_action align g1);

  foreach ($hub->param) {
    next if $_ =~ /^species_/;
    my %field_info = ('name' => $_);

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

  # Keep
  $fieldset->add_hidden([
    { name => 'back', value => $back_action },
    { name => 'uncompressed', value => $download_href },
    { name => 'gz', value => $download_compressed_action },
  ]);

  $fieldset->add_field({
    'field_class' => [qw(export_buttons_div)],
    'inline'      => 1,
    'elements'    => [
      { type => 'button', value => 'Back', name => 'back', class => 'export_buttons_preview' },
      { type => 'button', value => 'Download', name => 'uncompressed', class => 'export_buttons_preview' },
      { type => 'button', value => 'Download Compressed', name => 'gz', class => 'export_buttons_preview' },
    ]
  });

  $html .= $form->render;

  my $file = EnsEMBL::Web::File::User->new(hub => $hub, file => $path);
  if ($file) {
    my $read = $file->read;
    if ($read->{'content'}) {
      (my $preview = $read->{'content'}) =~ s/\n{2,}/\n/g;
      $html .= '<h2 style="margin-top:1em">File preview ('. $format .')</h2><div class="code"><pre style="color:#333">';
      $html .= encode_entities($preview);
      $html .= '</pre>';
    }
  }
  else {
    $html = "<p>Could not fetch file preview</p>";
  }
  $html .= '</div>';

  return $html;
}

1;
