# $Id$

package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;
use warnings;
no warnings 'uninitialized';

use Class::Std;
use CGI qw(escape escapeHTML header);

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Tools::Misc;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species;
  my $param = {};

  if (my $error = $object->[1]->{'_input'}->cgi_error()) {
    warn ">>> CGI ERROR $error";
    if ($error =~ /413/) {
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'too_big';
    }
  }

  my @methods = qw(text file url);
  my $method;
  foreach my $M (@methods) {
    if ($object->param($M)) {
      $method = $M;
      last;
    }
  }

  if ($object->param($method)) {
    $param = upload($method, $object);
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
  $param->{'_referer'} = $object->param('_referer');
  $param->{'x_requested_with'} = $object->param('x_requested_with');

  $url = escapeHTML($self->url($url, $param));

  header(-type => 'text/html', -charset => 'utf-8');

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
  my ($method, $object) = @_;
  my $param = {};
  my ($error, $format, $filename, $full_ext, %args);

  ## Try to guess the format from the extension
  unless ($method eq 'text') {
    my @orig_path = split('/', $object->param($method));
    $filename = $orig_path[-1];
    my @parts = split('\.', $filename);
    my $ext = $parts[-1];
    #$full_ext = $ext;
    if ($ext =~ /gz/i) {
      $ext = $parts[-2];
      #$full_ext = $ext.'.'.$full_ext;
    }
    if ($ext =~ /bed/i || $ext =~ /psl/i || $ext =~ /gff/i || $ext =~ /gtf/i || $ext =~ /wig/i) {
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
      $args{'filename'} = $filename;
    }
  }
  $param->{'name'} = $name;

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
    #$args{'extension'} = $full_ext;
    $args{'tmp_filename'} = $object->[1]->{'_input'}->tmpFileName($object->param($method));
  }
  if ($error) {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_response';
  }
  else {
    my $file = new EnsEMBL::Web::TmpFile::Text(prefix => 'user_upload', %args);
  
    if ($file->content) {
      if ($file->save) {
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
