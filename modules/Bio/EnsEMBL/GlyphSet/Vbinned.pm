package Bio::EnsEMBL::GlyphSet::Vbinned;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) 		= @_;
    my $Config 		= $self->{'config'};
    my $chr      	= $self->{'extras'}{'chr'}||$self->{'container'}->{'chr'};
    my $track     	= $self->{'extras'}{'row'};
    my $col            	= $Config->get( $track ,'col' );
    my $data            = $Config->get( $track ,'data');
       $data = $data->{$chr};
#    return unless $data;
    my $label2          = $Config->get( $track, 'labels' );
    my $wid             = $Config->get( $track ,'width');
    my $max_len         = $Config->container_width();
    my $bin_size        = $max_len/$Config->get($track,'bins');
	my $slice			= $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr);
    my $v_offset    = $max_len - ($slice->length() || 1);
    my $max_data        = $Config->get( $track, 'max_value' );
	my $chr_min_data ;
    my $chr_max_data = 0;

    foreach(@$data) { 
		$chr_min_data = $_ if ($_<$chr_min_data || $chr_min_data eq undef); 
		$chr_max_data = $_ if $_>$chr_max_data; 
	}
	$chr_min_data ||= 0 ;
    $self->label2( $self->Text({
       'text'      => "Min:$chr_min_data Max:$chr_max_data",
       'font'      => 'Tiny',
       'colour'	=> $Config->get( $track,'col'),
       'absolutey' => 1,
    }) ); 
		
    my $old_y;
    $self->push( $self->Space( {
      'x' => 1, 'width' => 3, 'height' => $wid, 'y' => 0, 'absolutey'=>1 
    } ));
	# max line (max)
	$self->push( $self->Line({
      'x'      => $v_offset ,
      'y'      => $chr_max_data / $max_data * $wid,
	  'width'  => $max_len - $v_offset ,
	  'height' => 0,
	  'colour' => 'lavender',
	  'absolutey' => 1,
	}) ) if ($Config->get( $track, 'maxmin' ));
	# base line (0)
	$self->push( $self->Line({
      'x'      => $v_offset ,
      'y'      => 0 ,
	  'width'  => $max_len - $v_offset ,
	  'height' => 0,
	  'colour' => 'lavender',
	  'absolutey' => 1,
	}) ) if ($Config->get( $track, 'maxmin' ));
	# global max line (global max)
	$self->push( $self->Line({
      'x'      => $v_offset ,
      'y'      => $wid,
	  'width'  => $max_len - $v_offset ,
	  'height' => 0,
	  'colour' => 'lightblue',
	  'absolutey' => 1,
	}) ) if ($Config->get( $track, 'maxmin' ));
    for(my $old_x = $v_offset; $old_x < $max_len; $old_x+=$bin_size) {
      my $new_x = $old_x + $bin_size;
      my $new_y = (shift @$data) / $max_data * $wid ;
     
	  
	  if(defined $old_y) {
        
		$self->push( $self->Line({
          'x'      => $old_x ,
          'y'      => $old_y ,
	  	  'width'  => $bin_size ,
	  	  'height' => $new_y-$old_y,
	  	  'colour' => $col,
	  	  'absolutey' => 1,
	}) );			
      }
      $old_y = $new_y;
    } 
}

1;
