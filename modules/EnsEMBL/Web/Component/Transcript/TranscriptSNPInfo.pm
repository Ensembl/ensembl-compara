package EnsEMBL::Web::Component::Transcript::TranscriptSNPInfo;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return; 
}


sub content {
  my $self = shift;
  my $object = $self->object;

  my $samples = join ", ", ($object->get_samples("default"));
  my $strain = $object->species_defs->translate("strain")."s";
  my $html = qq(<p>These $strain are displayed by default:<b> $samples.</b> <br /> Select the 'Configure this page' link in the left hand menu to customise which $strain and types of variation are displayed in the tables above.</p>);
  my $info_html = $self->_info(
  'Configuring the display',
   $html
  );
  return $info_html;
}
1;
