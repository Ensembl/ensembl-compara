package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;
use warnings;

use Class::Std;
use CGI qw(escape escapeHTML);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Tools::Misc;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($self->object->param($M)) {
      $method = $M;
      last;
    }
  }

  my $url = '/'.$self->object->data_species;
  my $param = {};
  if ($self->object->param($method)) {
    $param = upload($method, $self->object);
    if ($param->{'format'} eq 'none') {
      $url .= '/UserData/MoreInput';
    }
    else {
      $url .= '/UserData/UploadFeedback';
    } 
  }
  else {
    $url .= '/UserData/SelectFile';
  }
  $param->{'_referer'} = $self->object->param('_referer');
  $param->{'x_requested_with'} = $self->object->param('x_requested_with');
 
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

sub upload {
## Separate out the upload, to make code reuse easier
  my ($method, $object) = @_;
  my $param = {};

  ## Try to guess the format from the extension
  my ($format, $filename);
  unless ($method eq 'text') {
    my @orig_path = split('/', $object->param($method));
    $filename = $orig_path[-1];
    $filename =~ /\.(\w{1,4})$/;
    my $ext = $1;
    if ($ext =~ /bed/i || $ext =~ /psl/i || $ext =~ /gff/i || $ext =~ /gtf/i) {
      $format = uc($ext);
    }
  }

  ## Get original path, so can save file name as default name for upload
  my $name = $object->param('name');
  unless ($name) {
    if ($method eq 'text') {
      $name = 'Data';
    }
    else {
      $name = $filename;
    }
  }
  $param->{'name'} = $name;

  ## Cache data (TmpFile::Text knows whether to use memcached or temp file)
  my ($error, %args);
  if ($method eq 'url') {
    my $url = $object->param('url');
    $url = 'http://'.$url unless $url =~ /^http/;
    my $response = get_url_content($url);
    $error = $response->{'error'};
    $args{'content'} = $response->{'content'};
  }
  elsif ($method eq 'text') {
    $args{'content'} = $object->param('text');
  }
  else {
    $args{tmp_filename} = $object->[1]->{'_input'}->tmpFileName($object->param($method));
  }
  if ($error) {
    ## Put error message into session for display?
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_response';
  }
  else {
    my $file = new EnsEMBL::Web::TmpFile::Text(prefix => 'user_upload', %args);
  
    if ($file->content) {
      if ($file->save) {
        if (!$format) {
          ## Final attempt to work out format!
          my $data = $file->retrieve;
          my $parser = EnsEMBL::Web::Text::FeatureParser->new();
          $parser = $parser->init($data);
          $format = $parser->{'_info'}->{'format'};
          if (!$format) {
            $param->{'format'}  = 'none';
          }
        } 
        my $code = $file->md5 . '_' . $object->get_session->get_session_id;
     
        $param->{'species'} = $object->param('species') || $object->species;
        ## Attach data species to session
        $object->get_session->add_data(
          type      => 'upload',
          filename  => $file->filename,
          filesize  => length($file->content),
          code      => $code,
          md5       => $file->md5,
          name      => $name,
          species   => $object->param('species'),
          format    => $format,
          assembly  => $object->param('assembly'),
        );

        $param->{'code'} = $code;
      }
      else {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'no_save';
      }
    }
    else {
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'empty';
    }
  }
  return $param;
}

}

1;
