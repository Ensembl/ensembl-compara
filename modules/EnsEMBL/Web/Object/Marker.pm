#$Id$
package EnsEMBL::Web::Object::Marker;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);

sub caption        { return $_[0]->short_caption('global'); }
sub short_caption  { return $_[1] eq 'global' ? 'Marker: ' . $_[0]->name : 'Marker-based displays'; }
sub default_action { return 'Details'; }

sub marker { 
  my $self = shift;
  return $self->Obj;
}

sub markerSynonym {
  my $self    = shift;
  my $markers = $self->Obj;
  
  foreach (@$markers) {
    my $dms = $_->display_MarkerSynonym;
    return $dms if $dms;
  }
}

sub name { 
  my $self = shift;
  my $dms  = $self->markerSynonym;
  return $dms ? $dms->name : '';
}

1;
