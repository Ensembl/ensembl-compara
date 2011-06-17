package EnsEMBL::Web::Component::UserData::ConsequenceTool;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::UserData);

use URI::Escape qw(uri_unescape);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '<h2>Variant Effect Predictor  Results:</h2>';

  my @files = ($object->param('code'));
  my $size_limit =  $object->param('variation_limit');

  ## Tidy up user-supplied names
  my $id = $object->param('convert_file');
  my ($file, $name, $gaps) = split(':', $id);
  $name =~ s/ /_/g;
  if ($name !~ /\.txt$/i) {
    $name .= '.txt';
  }
  my $newname = $name || 'converted_data.txt';
  my $download_url = sprintf('/%s/download?file=%s;name=%s;prefix=user_upload;format=txt', $object->species, $file, $newname, $newname);

  $html .= qq(<p><a href="$download_url">Download text version</a></p>);
  foreach my $code (@files) {
    my $data = $object->consequence_data_from_file($code); 
    my $table = $object->consequence_table($data);
    $html .= $table->render;
  }

  return $html;
}

1;
