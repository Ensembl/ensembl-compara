# $Id$

package EnsEMBL::Web::Component::UserData::UploadFeedback;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}


sub content {
  my $self   = shift;
  my $hub    = $self->hub;
  my $upload = $hub->session->get_data(code => $hub->param('code'));
  my $html;

  if ($upload) {
    my $format  = $upload->{'format'} || $hub->param('format');
    my $species = $upload->{'species'} ? $hub->species_defs->get_config($upload->{'species'}, 'SPECIES_SCIENTIFIC_NAME') : '';
    
    $html = sprintf('
      <p class="space-below">Thank you. Your file uploaded successfully</p>
      <p class="space-below"><strong>File uploaded</strong>: %s (%s, %s)</p>',
      $upload->{'name'},
      $format  ? "$format file"      : 'Unknown format',
      $species ? "<em>$species</em>" : 'unknown species'
    );
  } else {
    $html = 'Sorry, there was a problem uploading your file. Please try again.';
  }
  
  return $html;
}

1;
