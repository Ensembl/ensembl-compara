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

package EnsEMBL::Web::Component::UserData::ConsequenceTool;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $html       = '<h2>Variant Effect Predictor  Results:</h2>';
  my $size_limit = $hub->param('variation_limit');
  my ($file, $name, $gaps) = split ':', $hub->param('convert_file');
  
  ## Tidy up user-supplied names
  $name  =~ s/ /_/g;
  $name .= '.txt' unless $name =~ /\.txt$/i;
  
  my $newname      = $name || 'converted_data.txt';
  my $download_url = sprintf '/%s/download?file=%s;name=%s;prefix=user_upload;format=txt', $hub->species, $file, $newname, $newname;

  $html .= qq{<p style="padding-top:1em"><a href="$download_url">Download text version</a></p>};
  $html .= $object->consequence_table($object->consequence_data_from_file($_))->render for $hub->param('code');

  return $html;
}

1;
