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

  my $format    = $hub->param('format');
  my $html;

  unless ($format eq 'RTF') {
    my $file = EnsEMBL::Web::TmpFile::Text->new(filename => $hub->param('file'), 'prefix' => 'export');
    if ($file) {
      $html .= '<h2>File preview</h2><div class="code"><pre style="color:#333">';
      my $i = 0;
      ### This is really not efficient, but can't see how to slurp a TmpFile!
      foreach my $line (split /\R/, $file->content) {
        last if $i > 9;
        $html .= "$line\n";
        $i++;
      }
      $html .= '</pre></div>';
    }
  }

  $html .= sprintf(
            '<h2 style="margin-top:1em">Download</h2><a href="/Download/DataExport?file=%s;prefix=export;format=%s;ext=%s;compression=%s">Download your %s file</a>', 
              $hub->param('file'), 
              lc($format), 
              $hub->param('ext'),
              $hub->param('compression'),
              $format,
            );

  return $html;
}

1;
