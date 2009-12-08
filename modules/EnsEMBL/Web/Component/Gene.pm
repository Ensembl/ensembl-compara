package EnsEMBL::Web::Component::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

use Bio::AlignIO;
use IO::String;

use base qw(EnsEMBL::Web::Component);

sub email_URL {
    my $email = shift;
    return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

1;
