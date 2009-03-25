package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Tools::Misc;
use EnsEMBL::Web::RegObj;
use CGI qw(escape escapeHTML);
use base 'EnsEMBL::Web::Command';

{

sub BUILD {
}

sub process {
  my $self = shift;

  my $url = '/UserData/SelectFile'; ## Fallback on error
  my $param = {
    '_referer' => $self->object->param('_referer'),
    'x_requested_with' => $self->object->param('x_requested_with'),
  };
  my $method = $self->object->param('url') ? 'url' : 'file';

  if ($self->object->param($method)) {

    ## Get original path, so can save file name as default name for upload
    my $name = $self->object->param('name');
    unless ($name) {
      my @orig_path = split('/', $self->object->param($method));
      $name = $orig_path[-1];
    }

    ## Cache data (TmpFile::Text knows whether to use memcached or temp file)
    my $file = new EnsEMBL::Web::TmpFile::Text(
      prefix => 'user_upload',
      ($method eq 'url') ?
      (content      => EnsEMBL::Web::Tools::Misc::get_url_content($self->object->param('url'))) :
      (tmp_filename => $self->object->[1]->{'_input'}->tmpFileName($self->object->param('file'))),
    );
    
    if ($file->save) {
      ## Identify format
      my $data = $file->retrieve;
      my $parser = EnsEMBL::Web::Text::FeatureParser->new();
      $parser = $parser->init($data);
      
      my $code = $file->md5 . '_' . $self->object->get_session->get_session_id;
      
      if ($parser->{'_info'} && $parser->{'_info'}->{'count'} && $parser->{'_info'}->{'count'} > 0) {
        my $format = $parser->{'_info'}->{'format'};

        $param->{'parser'} = $parser;
        $param->{'species'} = $self->object->param('species');
        ## Attach data species to session
        $self->object->get_session->add_data(
          type      => 'upload',
          filename  => $file->filename,
          code      => $code,
          md5       => $file->md5,
          name      => $name,
          species   => $self->object->param('species'),
          format    => $format,
          assembly  => $self->object->param('assembly'),
        );

        $param->{'code'} = $code;
        if (!$format) {
          ## Get more input from user
          $url = '/UserData/MoreInput';
          $param->{'format'}  = 'none';
        }
        else {
          $url = '/UserData/UploadFeedback';
          $param->{'format'} = $format;
        }
      }
      else {
        $param->{'filter_module'} = 'Data';
        $param->{'filter_code'} = 'empty';
      }
    }
    else {
      $param->{'filter_module'} = 'Data';
      $param->{'filter_code'} = 'no_save';
    }
  }
  else {
    $param->{'filter_module'} = 'Data';
    $param->{'filter_code'} = 'no_data';
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
