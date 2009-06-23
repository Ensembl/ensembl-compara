package EnsEMBL::Web::Command::UserData::CheckConvert;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species.'/UserData/';
  my $param;
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($object->param($M)) {
      $method = $M;
      last;
    }
  }
  $param->{'conversion'} = $object->param('conversion');
  $param->{'_time'} = $object->param('_time');

  if ($method) {
    $url .= 'UploadFile';
    $param->{$method} = $object->param($method);
    $param->{'name'} = $object->param('name');
    $param->{'species'} = $object->param('species');
    $param->{'previous'} = 'SelectFeatures';
    $param->{'next'} = 'ConvertFeatures';
  }
  else {
    $param->{'convert_file'} = $object->param('convert_file');
    $url .= 'ConvertFeatures';
  }

  if( $self->object->param('uploadto' ) eq 'iframe' ) {
    CGI::header( -type=>"text/html",-charset=>'utf-8' );
    printf q(<html><head><script type="text/javascript">
  window.parent.__modal_dialog_link_open_2( '%s' ,'File uploaded' );
</script>
</head><body><p>UP</p></body></html>), CGI::escapeHTML($self->url($url, $param));
  }
  else {
    $self->ajax_redirect($url, $param);
  }

}

}

1;
