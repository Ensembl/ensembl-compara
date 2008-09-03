package Bio::EnsEMBL::GlyphSet::Vbinned_outline;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) 		= @_;
  my $Config 		= $self->{'config'};
  my $chr      	= $self->{'extras'}{'chr'}||$self->{'container'}->{'chr'};
  my $track     	= $self->{'extras'}{'row'};
  my $col            	= $Config->get( $track ,'col' );
  my $data            = $Config->get( $track ,'data');
  $data = $data->{$chr};

  my $label2          = $Config->get( $track, 'labels' );
  my $wid             = $Config->get( $track ,'width');
  my $max_len         = $Config->container_width();
  my $bin_size        = $max_len/$Config->get($track,'bins');
	my $slice			      = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr);
  my $v_offset        = $max_len - ($slice->length() || 1);
  my $max_data        = $Config->get( $track, 'max_value' );
	my $chr_min_data ;
  my $chr_max_data = 0;

  ## loop through data to get max and min values
  foreach(@$data) { 
		$chr_min_data = $_ if ($_<$chr_min_data || $chr_min_data eq undef); 
		$chr_max_data = $_ if $_>$chr_max_data; 
	}
  $chr_min_data ||= 0 ;
	
  my $old_y;
  for(my $old_x = $v_offset; $old_x < $max_len; $old_x+=$bin_size) {
    my $datum = shift @$data;
    my $new_x = $old_x + $bin_size;
    my $new_y = $datum / $max_data * $wid ;
	  
	  if(defined $old_y) {
		  $self->push( $self->Rect({
          'x'      => $old_x ,
          'y'      => $old_y ,
	  	  'width'  => $bin_size * 2 ,
	  	  'height' => $new_y-$old_y,
	  	  'bordercolour' => $col,
	  	  'absolutey' => 1,
	}) );			
        
    }
    $old_y = $new_y;
  } 
}

1;
