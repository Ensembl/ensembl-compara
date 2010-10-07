# $Id$

package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $hub = $self->hub;
  my $url = $object->species_path($object->data_species);
  my $param = {};
  my $error = $hub->input->cgi_error;

  if ($error =~ /413/) {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'too_big';
  }

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($hub->param($M)) {
      $method = $M;
      last;
    }
  }

  if ($hub->param($method)) {
    $param = upload($method, $hub);
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
}

sub upload {
## Separate out the upload, to make code reuse easier
  my ($method, $hub) = @_;
  my $param = {};
  my ($error, $format, $filename, $full_ext, %args);

  ## Try to guess the format from the extension
  unless ($method eq 'text') {
    my @orig_path = split('/', $hub->param($method));
    $filename = $orig_path[-1];
    my @parts = split('\.', $filename);
    my $ext = $parts[-1];
    #$full_ext = $ext;
    if ($ext =~ /gz/i) {
      $ext = $parts[-2];
      #$full_ext = $ext.'.'.$full_ext;
    }
    
    $format = uc $ext if $ext =~ /(bed|psl|gff|gtf|wig)/i;
  }
  
  $format = uc $hub->param('upload_format') if $hub->param('upload_format');

  ## Get original path, so can save file name as default name for upload
  my $name = $hub->param('name');
  unless ($name) {
    if ($method eq 'text') {
      $name = 'Data';
    } else {
      $name = $filename;
      $args{'filename'} = $filename;
    }
  }
  $param->{'name'} = $name;

  if ($method eq 'url') {
    my $url = $hub->param('url');
    $url = 'http://'.$url unless $url =~ /^http/;
    my $response = get_url_content($url);
    $error = $response->{'error'};
    $args{'content'} = $response->{'content'};
  }
  elsif ($method eq 'text') {
    $args{'content'} = $hub->param('text');
  }
  else {
    #$args{'extension'} = $full_ext;
    $args{'tmp_filename'} = $hub->input->tmpFileName($hub->param($method));
  }
  if ($error) {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_response';
  }
  else {
    my $file = new EnsEMBL::Web::TmpFile::Text(prefix => 'user_upload', %args);
  
    if ($file->content) {
      if ($file->save) {
        my $code = $file->md5 . '_' . $hub->session->session_id;
     
        $param->{'species'} = $hub->param('species') || $hub->species;
        ## Attach data species to session
        $hub->session->add_data(
          type      => 'upload',
          filename  => $file->filename,
          filesize  => length($file->content),
          code      => $code,
          md5       => $file->md5,
          name      => $name,
          species   => $hub->param('species'),
          format    => $format,
          assembly  => $hub->param('assembly'),
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

1;
