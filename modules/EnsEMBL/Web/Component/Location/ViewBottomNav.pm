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
    $extra_html .= sprintf( '<a href="#%s"><img alt="" src="/i/blank.gif" class="blank" style="height:%dpx" /></a>', $_->[1],$_->[0] );
  }
  return sprintf qq(
  <div class="autocenter navbar" style="width:%spx">
    <form action="#"><div class="relocate">
      Location: <label class="hidden" for="region">Region</label><input name="region" id="region" class="text" style="width:3em" value="%s" type="text" /> :
                <label class="hidden" for="start">Start</label><input name="start" id="start" class="text" style="width:5em" value="%s" type="text" /> - 
		<label class="hidden" for="end">End</label><input name="end" id="end" class="text" style="width:5em" value="%s" type="text" />
		<input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
    <a href="%s"><img src="/i/nav-l2.gif" class="zoom" alt="1Mb left"/></a><a 
       href="%s"><img src="/i/nav-l1.gif" class="zoom" alt="window left"/></a><a
       href="%s"><img src="/i/zoom-plus.gif" class="zoom" alt="zoom in"/></a>$extra_html<a
       href="%s"><img src="/i/zoom-minus.gif" class="zoom" alt="zoom out"/></a><a
       href="%s"><img src="/i/nav-r1.gif" class="zoom" alt="window left"/></a><a
       href="%s"><img src="/i/nav-r2.gif" class="zoom" alt="1Mb left"/></a>
  </div>), $image_width,
   $object->seq_region_name,
   $object->seq_region_start,
   $object->seq_region_end,
   '#',
   '#',
   '#',
   '#',
   '#',
   '#';
}


1;
