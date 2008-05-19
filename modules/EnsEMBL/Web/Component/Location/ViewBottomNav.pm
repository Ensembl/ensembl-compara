package EnsEMBL::Web::Component::Location::ViewBottomNav;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Location);
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}


sub content {
  my $self   = shift;
  my $object = $self->object;

  my $threshold = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  my $extra_html = '';
  my @ramp_entries = ( [4,1e3], [6,5e3], [8,1e4], [10,5e4], [12,1e5], [14,2e5], [16,5e5], [18,1e6] );
  foreach(@ramp_entries) {
    $extra_html .= sprintf( '<a href="#%s"><img src="/i/blank.gif" class="blank" style="height:%dpx" /></a>', $_->[1],$_->[0] );
  }
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx">
    <div class="relocate">
      Location: <input class="text" style="width:3em" value="%s" type="text" /> :
                <input class="text" style="width:5em" value="%s" type="text" /> - 
		<input class="text" style="width:5em" value="%s" type="text" />
		<input value="Go&gt;" type="submit" class="go-button" />
    </div>
    <a href="%s"><img src="/i/zoom-plus.gif" class="zoom" alt="zoom in"/></a>$extra_html<a href="%s"><img src="/i/zoom-minus.gif" class="zoom" alt="zoom out"/></a>

  </div>), $image_width,
   $object->seq_region_name,
   $object->seq_region_start,
   $object->seq_region_end,
   '#',
   '#';
}


1;
