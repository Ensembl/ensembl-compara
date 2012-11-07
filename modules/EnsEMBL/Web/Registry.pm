# $Id$

package EnsEMBL::Web::Registry;

use strict;

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Timer;

sub new {
  my $class = shift;
  
  my $self = {
    timer        => undef,
    species_defs => undef
  };
  
  bless $self, $class;
  return $self;
}

sub species_defs { return $_[0]{'species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new; }
sub timer        { return $_[0]{'timer'}        ||= EnsEMBL::Web::Timer->new;       }
sub timer_push   { shift->timer->push(@_); }

1;
