package EnsEMBL::Web::Object::Link;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub URL { return $_[0]->Obj; }
1;
