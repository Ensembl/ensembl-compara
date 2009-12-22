package EnsEMBL::Web::Component::Regulation;

use strict;
use warnings;
no warnings 'uninitialized';


use base qw(EnsEMBL::Web::Component);

sub email_URL {
  my $email = shift;
  return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

1;
