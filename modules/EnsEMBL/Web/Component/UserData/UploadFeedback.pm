package EnsEMBL::Web::Component::UserData::UploadFeedback;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'File Uploaded';
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html;

  my $upload = $object->get_session->get_data('code' => $object->param('code'));
  if ($upload) {
    $html = '<p class="space-below">Thank you. Your file uploaded successfully</p><p class="space-below"><strong>File uploaded</strong>: '.$upload->{'name'}.' (';
    if (my $format = $upload->{'format'}) {
      $html .= "$format file";
    }
    else {
      $html .= 'Unknown format';
    }
    if (my $species = $upload->{'species'}) {
      $species =~ s/_/ /;
      $html .= ", <em>$species</em>";
    }
    else {
      $html .= ', unknown species';
    }
    $html .= ')</p>';
  }
  else {
    $html = qq('Sorry, there was a problem uploading your file. Please try again.');
  }
  return $html;
}

1;
