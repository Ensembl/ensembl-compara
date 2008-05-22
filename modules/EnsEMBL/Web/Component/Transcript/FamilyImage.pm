package EnsEMBL::Web::Component::Transcript::FamilyImage;

### Displays a karyotype image with genes marked

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;

  my $html = qq(
  );

  return $html;
}

1;
