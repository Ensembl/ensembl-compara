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

package EnsEMBL::Web::Component::UserData::RegionReportOutput;

############# DEPRECATED #################
## This tool is no longer in use and will
## be removed in release 81
##########################################

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Region Report Output';
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  my %data_error = EnsEMBL::Web::Constants::USERDATA_MESSAGES;
  my ($html, $output, $error);

  if ($hub->param('error_code')) {
    $error = $data_error{$hub->param('error_code')};
  }
  else {
    my $record = $hub->session->get_data('code' => $hub->param('code'));

    my $extension = $record->{'extension'};
    my $filename = $record->{'filename'};
    my $tmpfile = EnsEMBL::Web::TmpFile::Text->new(
      filename  => $filename, 
      prefix    => 'download', 
      extension => $extension,
    );

    if ($tmpfile->exists) {
      my $data    = $tmpfile->retrieve; 
      my $name    = $record->{'name'} || 'region_report';
      my $url     = sprintf('/%s/download?file=%s;prefix=download;format=%s;name=%s', $hub->species, $filename, $extension, $name);
      $output    .= qq(<h3>Download: <a href="$url">$name</a></h3>);

      $output .= qq(<p><b>Preview</b> (First 50 lines of report)  - <a href="$url">download complete file</a></p><pre>);
      my $i;
      foreach my $line (split(/\n/, $data)) {
        last if $i >= 50;
        $output .= "$line\n";
        $i++;
      }
      $output .= qq(</pre><p><strong>Preview only</strong> - <a href="$url">download complete file</a></p>);
    }
    else {
      $error = $data_error{'load_file'};
    }
  }

  if ($error) {
    my $param = $hub->param('code') ? {'code' => $hub->param('code')} : {};
    $error->{'message'} .= sprintf(' Would you like to <a href="%s" class="modal_link">try again</a> with different region(s)?',
              $self->url($hub->species_path($hub->data_species) . '/UserData/SelectReportOptions', $param)
              );

    $html = $self->_info_panel($error->{'type'}, $error->{'title'}, $error->{'message'});
  }
  $html .= $output;

  return $html;
}

1;
