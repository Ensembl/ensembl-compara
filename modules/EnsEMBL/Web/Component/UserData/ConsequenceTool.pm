# $Id$

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
