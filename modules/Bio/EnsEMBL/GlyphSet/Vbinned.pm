package Bio::EnsEMBL::GlyphSet::Vbinned;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use Data::Dumper;

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};	
    my $track     	= $self->{'extras'}{'row'};
    $self->label( new Sanger::Graphics::Glyph::Text({
       'text'      => $Config->get( $track,'label'),
       'font'      => 'Small',
       'colour'	=> $Config->get( $track,'col'),
       'absolutey' => 1,
    }) );
}

sub _init {
    my ($self) 		= @_;
    my $Config 		= $self->{'config'};
    my $chr      	= $self->{'extras'}{'chr'}||$self->{'container'}->{'chr'};
    my $track     	= $self->{'extras'}{'row'};
    my $col            	= $Config->get( $track ,'col' );
    my $data            = $Config->get( $track ,'data');
       $data = $data->{$chr};
    return unless $data;
    my $label2          = $Config->get( $track, 'labels' );
    my $wid             = $Config->get( $track ,'width');
    my $max_len         =  $Config->container_width();
    my $bin_size        = $max_len/$Config->get($track,'bins');
    my $v_offset    = $max_len - ($self->{'container'}->{'ca'}->fetch_by_chr_name($chr)->length() || 1);
    my $max_data        = $Config->get( $track, 'max_value' );
    if( !defined($max_data) ) {
      $max_data = 0;
      foreach(@$data) { $max_data = $_ if $_>$max_data; }
    }
    return unless $max_data;
    $self->label2( new Sanger::Graphics::Glyph::Text({
       'text'      => "Max: $max_data",
       'font'      => 'Tiny',
       'colour'	=> $Config->get( $track,'col'),
       'absolutey' => 1,
    }) ); # if $label2;
    my $old_y;
    $self->push( new Sanger::Graphics::Glyph::Space( {
      'x' => 1, 'width' => 3, 'height' => $wid, 'y' => 0, 'absolutey'=>1 
    } ));
    for(my $old_x = $v_offset; $old_x < $max_len; $old_x+=$bin_size) {
      my $new_x = $old_x + $bin_size;
      my $new_y = (shift @$data) / $max_data * $wid;
      if(defined $old_y) {
        $self->push( new Sanger::Graphics::Glyph::Line({
          'x'      => $old_x,
          'y'      => $old_y,
	  'width'  => $bin_size,
	  'height' => $new_y-$old_y,
	  'colour' => $col,
	  'absolutey' => 1,
	}) );			
      }
      $old_y = $new_y;
    } 
}

1;
