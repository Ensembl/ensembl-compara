package EnsEMBL::Web::Component::UserData::PreviewConvert;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

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
  my $object = $self->object;
  my $html = qq(<h2>Preview converted file(s)</h2>
<p>The first ten lines of each file are displayed below. Right-click on the file name to download the complete file</p>
);

  my @files = $object->param('converted');
  my $i = 1;
  foreach my $file (@files) {
    next unless $file;
    my $tmpfile = new EnsEMBL::Web::TmpFile::Text(
                    filename => $file, prefix => 'export', extension => 'gff'
    );
    next unless $tmpfile->exists;
    my $data = $tmpfile->retrieve;
    if ($data) {
      my $name = 'converted_data_'.$i.'.gff';
      $html .= sprintf('<h3>Converted file <a href="/%s/download?file=%s;name=%s;prefix=export;format=gff">%s</a></h3>', $object->species, $file, $name, $name);
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

1;
