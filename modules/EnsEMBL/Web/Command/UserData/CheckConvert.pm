# $Id$

package EnsEMBL::Web::Command::UserData::CheckConvert;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Command::UserData::UploadFile;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url;
  if ($object->param('id_mapper')){
    $url = '/'.$object->data_species.'/UserData/SelectOutput';
  } else {
    $url = '/'.$object->data_species.'/UserData/ConvertFeatures';
  }
  my $param;

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($object->param($M)) {
      $method = $M;
      last;
    }
  }

  my $files_to_convert = [];
  if ($method) {
    my $upload_response = EnsEMBL::Web::Command::UserData::UploadFile::upload($method, $object);    
    foreach my $p (keys %$upload_response) {
      if ($p eq 'code') {
        push @$files_to_convert, 'temp-upload-'.$upload_response->{'code'}.':'.$upload_response->{'name'};
      }
      else {
        $param->{$p} = $upload_response->{$p};
      }
    }
  }
  if ($object->param('convert_file')) {
    push @$files_to_convert, $object->param('convert_file');
  }
  $param->{'convert_file'} = $files_to_convert;
  unless ($object->param('id_mapper')){
    $param->{'conversion'} = $object->param('conversion');
  }
  if ($object->param('id_limit')) {
    $param->{'id_limit'} = $object->param('id_limit');
  }
  ## Set these separately, or they cause an error if undef
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');

  if ($self->object->param('uploadto') eq 'iframe') {
    CGI::header( -type=>"text/html",-charset=>'utf-8' );
    printf q(
    <html>
    <head>
      <script type="text/javascript">
        window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '%s', title: 'File uploaded' });
      </script>
    </head>
    <body><p>UP</p></body>
    </html>), CGI::escapeHTML($self->url($url, $param));
  } else {
    $self->ajax_redirect($url, $param);
  }

}

}

1;
