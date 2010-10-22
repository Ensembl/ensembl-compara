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

sub species_defs { return $_[0]{'species_defs'} ||= new EnsEMBL::Web::SpeciesDefs; }
sub timer        { return $_[0]{'timer'}        ||= new EnsEMBL::Web::Timer;       }
sub timer_push   { shift->timer->push(@_); }

1;
