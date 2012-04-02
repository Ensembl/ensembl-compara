# $Id$

package Bio::EnsEMBL::GlyphSet::Vuserdata;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::V_density);

### Fetches userdata and munges it into a basic format 
### for rendering by the parent module

sub _init {
  my $self = shift;
  my $rtn  = $self->build_tracks;
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

1;
