package EnsEMBL::Web::Component::Server::ColourMap;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Server);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );

  $table->add_columns(
    { 'align' => 'center', 'key' => 'name',       'title' => 'Name'} ,
    { 'align' => 'center', 'key' => 'black',      'title' => 'On black' },
    { 'align' => 'center', 'key' => 'white',      'title' => 'On white' },
    { 'align' => 'center', 'key' => 'background', 'title' => 'As background' },
    { 'align' => 'center', 'key' => 'hex',        'title' => 'HEX' },
    { 'align' => 'center', 'key' => 'rgb',        'title' => 'RGB' },
    { 'align' => 'center', 'key' => 'hls',        'title' => 'HLS' },
    defined( $object->param('hex') ) ? {  'align' => 'right', 'key' => 'dist', 'title' => 'Distance' } : ()
  );
  my $colour  = $object->param('hex');
  my $hls     = $object->param('hls');
  my $sort_by = $object->param('sort');
  my $cm = new Bio::EnsEMBL::ColourMap( $object->species_defs );
  my @keys;

  my @r_rgb = (255,0,0);
  if(defined($colour)) {
    @r_rgb = $cm->rgb_by_hex($colour);
  }
  my %rgb = map { ( $_, [ $cm->rgb_by_hex( $cm->{$_} ) ] ) } keys %$cm;
  my %hls = map { ( $_, [ $self->hls(@{$rgb{$_}},@r_rgb )   ] ) } keys %$cm;
  if(defined $hls) {
    @keys = sort { $a->[0] <=> $b->[0] } map {
      [ $self->sortby_hls( $hls{$_}, $hls) , $_ ]
    } keys %$cm;
  } elsif(defined $colour) {
     @keys = sort { $a->[0] <=> $b->[0] } map {
       [ $self->coldist( $rgb{$_}, \@r_rgb ) , $_ ]
     } keys %$cm;
  } elsif( defined $sort_by ) {
     @keys = sort { $a->[0] <=> $b->[0] } map {
       [ $self->sortby( $rgb{$_}, $sort_by ) , $_ ]
     } keys %$cm;
  } else {
    @keys = map { [1, $_] } sort keys %$cm;
  }
  foreach my $t ( @keys ) {
    my( $dist, $k ) = @$t;
    next if $k eq 'colour_sets';
    my $v = $cm->{$k};
    my ($r,$g,$b) = @{$rgb{$k}};
    my ($h,$l,$s) = @{$hls{$k}};
    my $c = $cm->contrast($k);
    $table->add_row(
      { 'name' => $k,
        'black' => qq(<div style="margin: 0px auto; width: 10em; background-color: #000; color: #$v">$k</div>),
        'white' => qq(<div style="margin: 0px auto; width: 10em; background-color: #fff; color: #$v">$k</div>),
        'background' => qq(<div style="margin: 0px auto; width: 10em; background-color: #$v; color: $c">$k</div>),
        'hex'   => "<tt>$v</tt>",
        'rgb'   => $self->space2nbsp( sprintf( '<tt>(%3d,%3d,%3d)</tt>', $r,$g,$b ) ),
        'hls'   => $self->space2nbsp( sprintf( '<tt>(%4d,%3d,%3d)</tt>', $h,$l,$s ) ),
        'dist'  => sprintf '%0.3f', $dist
      }
    );
  }
  return $table->render;
}

sub space2nbsp {
  (my $T = $_[1]) =~ s/ /&nbsp;/g;
  return $T;
}

sub coldist {
  my( $self,$hr,$hg,$hb,$gr,$gg,$gb ) = ($_[0],@{$_[1]},@{$_[2]});
  my $d = sqrt(($hr-$gr)*($hr-$gr)+($hg-$gg)*($hg-$gg)+($hb-$gb)*($hb-$gb))/sqrt(3)/255;
  return $d;
}

sub sortby {
  my( $self, $h, $order ) = @_;
  my %h;
  ($h{'r'}, $h{'g'}, $h{'b'}) = @$h;
  my $V = 0;
  foreach ( split '',$order ) { $V = $V*1000 + $h{$_}; }
  return -$V;
}

sub sortby_hls {
  my( $self,$h, $order ) = @_;
  my %h;
  ($h{'h'}, $h{'l'}, $h{'s'}) = @$h;
  my $V = 0;
  foreach ( split '',$order ) { $V = $V*1000 + $h{$_}; }
  return -$V;
}

sub hls {
  my( $self,$r,$g,$z,$R,$G,$Z ) = @_;
  my ($mi,$x,$ma) = sort {$a<=>$b} ($r,$g,$z);
  my $l = ($r+$g+$z)/765;
  return (0,int(100*$l),0) if $mi==$ma;

  my $L = ($R+$G+$Z)/765;
  my ($MI,$X,$MA) = sort {$a<=>$b} ($R,$G,$Z);
  if($MI == $MA) {
    $R=255;
    $G=0;
    $Z=0;
    $L=1/3;
  }

  my $s = 1 - $mi/255/$l;

  ($r,$g,$z) = ( $r/$l/765-1/3, $g/$l/765-1/3, $z/$l/765-1/3 );
  ($R,$G,$Z) = ( $R/$L/765-1/3, $G/$L/765-1/3, $Z/$L/765-1/3 );
  my $d = sqrt($r*$r+$g*$g+$b*$b);
  my $D = sqrt($R*$R+$G*$G+$Z*$Z);

  my $c_th = ($r*$R+$g*$G+$b*$Z)/$d/$D;
  my $s_th = ($r*$G-$g*$R+$g*$Z-$b*$G+$b*$R-$r*$Z)/$d/$D;

  my $h = atan2($s_th,$c_th);
  return( int($h*180/3.14159), int($l*100), int($s*100) );
}

1;    


