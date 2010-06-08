# $Id$

package EnsEMBL::Web::Command::UserData::CheckConvert;

### Upload some data and add relevant parameters to the wizard workflow

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Command::UserData::UploadFile;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url;
  my $param;

  if ($object->param('id_mapper')){
    $param->{'id_mapper'} = $object->param('id_mapper');
    $url = $object->species_path($object->data_species).'/UserData/SelectOutput';
  } elsif ($object->param('consequence_mapper')) {
    $param->{'consequence_mapper'} = $object->param('consequence_mapper');
    $url = $object->species_path($object->data_species).'/UserData/SNPConsequence';
    $param->{'upload_format'} = $object->param('upload_format');
  } else {
    $url = $object->species_path($object->data_species).'/UserData/ConvertFeatures';
  }

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
  unless ($object->param('id_mapper') || $object->param('consequence_mapper')){
    $param->{'conversion'} = $object->param('conversion');
  }
  if ($object->param('id_limit')) {
    $param->{'id_limit'} = $object->param('id_limit');
  }
  if ($object->param('variation_limit')) {
    $param->{'variation_limit'} = $object->param('variation_limit');
  }

  ## This will need changing if we add more tools
  ## FIXME - this wizard structure is getting a bit crazy!
  my $next_node = $object->param('consequence_mapper') ? 'command' : 'component';

  ## Go from a modal form (with file upload) directly to another web page
  if ($next_node eq 'component' && $object->param('uploadto') eq 'iframe') {
    $url = encode_entities($self->url($url, $param));

    $self->r->content_type('text/html; charset=utf-8');

    print qq{
    <html>
    <head>
      <script type="text/javascript">
        if (!window.parent.Ensembl.EventManager.trigger('modalOpen', { href: '$url', title: 'File uploaded' })) {
          window.parent.location = '$url';
        }
      </script>
    </head>
    <body><p>UP</p></body>
    </html>};
  } else {
    $self->ajax_redirect($url, $param);
  }   

}

1;

