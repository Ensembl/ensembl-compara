package Bio::EnsEMBL::GlyphSet::Vpercents;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my ($self) 		= @_;
    my $Config 		= $self->{'config'};
    my $chr      	= $self->{'container'}->{'chr'};
    my $gc_col 	= $Config->get( 'Vpercents','col_gc' );
    my $repeat_col 	= $Config->get( 'Vpercents','col_repeat' );
    my $chr_slice = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr);	
	
    my $da = $self->{'container'}->{'da'};
    my $repeats = $da->fetch_Featureset_by_Slice($chr_slice, 'PercentageRepeat',150,1); 
    my $gc      = $da->fetch_Featureset_by_Slice($chr_slice, 'PercentGC', 150,1);

    return unless $repeats->size() && $gc->size();
	my $max_repeats = $repeats->max_value;
	my $max_gc      = $gc->max_value;
	my $MAX 	= $max_repeats > $max_gc ? $max_repeats : $max_gc;
	$MAX ||= 1;

   	$repeats->scale_to_fit( $max_repeats / $MAX * $Config->get( 'Vpercents', 'width' ) );
	$repeats->stretch(0);
   	$gc->scale_to_fit( $max_gc / $MAX * $Config->get( 'Vpercents', 'width' ) );
	$gc->stretch(0);

	my @repeats = @{$repeats->get_all_binvalues()};
	my @gc 		= @{$gc->get_all_binvalues()};	
	my @points  = [];
	my $old_x = undef;
	my $old_y = undef;
    foreach (@repeats) {
	    my $g_x = $self->Space({
			'x'      => $_->start,
			'y'      => 0,
			'width'  => $_->end - $_->start,
			'height' => $_->scaledvalue,
			'href'   => "/@{[$self->{container}{web_species}]}/contigview?chr=$chr;vc_start=$_->start;vc_end=$_->end"
		});
		$self->push($g_x);
	    $g_x = $self->Line({
			'x'      => ($_->end + $_->start)/2,
			'Y'      => 0,
			'width'  => 0,
			'height' => $_->scaledvalue,
			'colour' => $repeat_col,
			'absolutey' => 1,
		});
	    $self->push($g_x);
		my $gcvalue = shift @gc;					
		my $new_x = ($gcvalue->end + $gcvalue->start)/2;
		my $new_y = $gcvalue->scaledvalue ;
		if(defined $old_x) {

		    my $g_x = $self->Line({
				'x'      => $old_x,
				'y'      => $old_y,
				'width'  => $new_x-$old_x,
				'height' => $new_y-$old_y,
				'colour' => $gc_col,
				'absolutey' => 1,
			});			
			$self->push($g_x);
		}
		$old_x = $new_x;
		$old_y = $new_y;
	}
}

1;
