# $Id$

package EnsEMBL::Web::Command::UserData::UploadFile;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Command::UserData);

sub process {
  my $self       = shift;
  my $hub        = $self->hub;
  my $error      = $hub->input->cgi_error;
  my ($method)   = grep $hub->param($_), qw(text file url);
  my $url_params = { __clear => 1 };

  if ($error =~ /413/) {
    $url_params->{'filter_module'} = 'Data';
    $url_params->{'filter_code'}   = 'too_big';
  }
  
  if ($method) {
    $url_params = $self->upload($method);
    $url_params->{'action'} = $url_params->{'format'} ? 'UploadFeedback' : 'MoreInput';
  } else {
    $url_params->{'action'} = 'SelectFile';
  }

  $self->file_uploaded($url_params);
}

1;