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

package EnsEMBL::Web::Component::UserData::PreviewConvert;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);
use EnsEMBL::Web::TmpFile::Text;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return '';
}

sub content {
  my $self = shift;

  if ($self->hub->param('error')) {
    return $self->error();
  }
  my $object = $self->object;
  my $html = qq(<h2>Preview converted file(s)</h2>
<p>The first ten lines of each file are displayed below. Click on the file name to download the complete file</p>
);

  my @files = $object->param('converted');
  my $i = 1;
  foreach my $id (@files) {
    next unless $id;
    my ($file, $name, $gaps) = split(':', $id);

    ## Tidy up user-supplied names
    $name =~ s/ /_/g;
    $name =~ s/\.(\w{1,4})$/.gff/;
    if ($name !~ /\.gff$/i) {
      $name .= '.gff';
    }
    $name = 'converted_'.$name;

    ## Fetch content
    my $tmpfile = EnsEMBL::Web::TmpFile::Text->new(
                    filename => $file, prefix => 'user_upload', extension => 'gff'
    );
    next unless $tmpfile->exists;
    my $data = $tmpfile->retrieve;
    if ($data) {
      my $newname = $name || 'converted_data_'.$i.'.gff';
      $html .= sprintf('<h3>File <a href="/%s/download?file=%s;name=%s;prefix=user_upload;format=gff">%s</a></h3>', $object->species, $file, $newname, $newname);
      my $gaps = $gaps ? $gaps : 0;
      $html .= "<p>This data includes $gaps gaps where the input coordinates could not be mapped directly to the output assembly.</p>";
      $html .= '<pre>';
      my $count = 1;
      foreach my $row ( split /\n/, $data ) {
        $html .= $row."\n";
        $count++;
        last if $count == 10;
      }
      $html .= '</pre>';
      $i++;
    }
  }
  
  return $html;
}

sub error { 
  my $self = shift;

  my $html = qq(<h2>Preview converted file(s)</h2>);
  $html .= '<p>Sorry, there was a problem uploading your data.</p>';
  $html .= "<p>Error: ".$self->hub->param('error')."</p>";
  return $html;
}

1;
