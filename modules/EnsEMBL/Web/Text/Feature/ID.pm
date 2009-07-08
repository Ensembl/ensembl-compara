package EnsEMBL::Web::Text::Feature::ID;


use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);
sub id        {  return $_[0]->{'__raw__'}[0]; }

1;
