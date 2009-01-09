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

sub _nav_url {
  my( $self, $s, $e ) = @_;
  return $self->object->_url({'r'=>$self->object->seq_region_name.':'.$s.'-'.$e});
}

sub content_region {
  my $self = shift;
  return $self->content( [ [4,1e4], [6,5e4], [8,1e5], [10,5e5], [12,1e6], [14,2e6], [16,5e6], [18,1e7] ] )
}

sub content {
  my $self   = shift;
  my $ramp_entries = shift || [ [4,1e3], [6,5e3], [8,1e4], [10,5e4], [12,1e5], [14,2e5], [16,5e5], [18,1e6] ];
  my $object = $self->object;

  my $threshold = 1e6 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $image_width = $self->image_width;

  my $extra_html = '';
  my $cp = int( ($object->seq_region_end+$object->seq_region_start) / 2);
  my $wd = $object->seq_region_end-$object->seq_region_start+1;
  my $url = $object->_url( {'r'=>undef}, 1 );
  my @mp = ();
  my $x=0;
  foreach(@$ramp_entries) {
    push @mp, sqrt( $x * $_->[1] );
    $x = $_->[1];
  }
  push @mp, 1e30;
  my $l = shift @mp;
  foreach(@$ramp_entries) {
    my $r = shift @mp;
    $extra_html .= sprintf( '<a href="%s"><img title="%d bp" alt="%s bp" src="/i/blank.gif" class="blank%s" style="height:%dpx" /></a>', 
      $self->_nav_url( $cp - $_->[1]/2+1, $cp + $_->[1]/2), $_->[1], $_->[1],
      $wd > $l && $wd <= $r ? '_high' : '',
      $_->[0]
    );
    $l = $r;
  }
  my $extra_inputs;
  foreach(sort keys %{$url->[1]||{}}) {
    $extra_inputs .= sprintf '
        <input type="hidden" name="%s" value="%s" />', escapeHTML($_),escapeHTML($url->[1]{$_});
  }
  return sprintf qq(
  <div class="autocenter navbar print_hide" style="width:%spx">
    <form action="%s" method="get"><div class="relocate">
      Location: %s
        <label class="hidden" for="region">Region</label><input name="region" id="region" class="text" style="width:3em" value="%s" type="text" /> :
        <label class="hidden" for="start">Start</label><input name="start" id="start" class="text" style="width:5em" value="%s" type="text" /> - 
        <label class="hidden" for="end">End</label><input name="end" id="end" class="text" style="width:5em" value="%s" type="text" />
        <input value="Go&gt;" type="submit" class="go-button" />
    </div></form>
    <a href="%s"><img src="/i/nav-l2.gif" class="zoom" alt="1Mb left"/></a><a 
       href="%s"><img src="/i/nav-l1.gif" class="zoom" alt="window left"/></a><a
       href="%s"><img src="/i/zoom-plus.gif" class="zoom" alt="zoom in"/></a>%s<a
       href="%s"><img src="/i/zoom-minus.gif" class="zoom" alt="zoom out"/></a><a
       href="%s"><img src="/i/nav-r1.gif" class="zoom" alt="window left"/></a><a
       href="%s"><img src="/i/nav-r2.gif" class="zoom" alt="1Mb left"/></a>
  </div>), 
   $image_width,
   $url->[0],
   $extra_inputs,
   $object->seq_region_name,
   $object->seq_region_start,
   $object->seq_region_end,
   $self->_nav_url( $object->seq_region_start - 1e6, $object->seq_region_end - 1e6 ),
   $self->_nav_url( $object->seq_region_start - $wd, $object->seq_region_end - $wd ),
   $self->_nav_url( $cp - int($wd/4)+1,              $cp + int($wd/4) ),
   $extra_html,
   $self->_nav_url( $cp - $wd+1,                     $cp + $wd ),
   $self->_nav_url( $object->seq_region_start + $wd, $object->seq_region_end + $wd ),
   $self->_nav_url( $object->seq_region_start + 1e6, $object->seq_region_end + 1e6 ),
}


1;
