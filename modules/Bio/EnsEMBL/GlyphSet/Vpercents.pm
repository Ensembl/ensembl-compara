package Bio::EnsEMBL::GlyphSet::Vpercents;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    my $Config = $self->{'config'};	
    my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => '% GC',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vpercents','col_gc'),
		'absolutey' => 1,
    });
    my $label2 = new Sanger::Graphics::Glyph::Text({
		'text'      => 'Repeats',
		'font'      => 'Small',
		'colour'	=> $Config->get('Vpercents','col_repeat'),		
		'absolutey' => 1,
    });
		
    $self->label($label);
	$self->label2($label2);
}

sub _init {
    my ($self) 		= @_;
    my $Config 		= $self->{'config'};
    my $chr      	= $self->{'container'}->{'chr'};
   	my $gc_col 	= $Config->get( 'Vpercents','col_gc' );
   	my $repeat_col 	= $Config->get( 'Vpercents','col_repeat' );
	
	
    my $repeats 	= $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'repeat'); 
    my $gc 		    = $self->{'container'}->{'da'}->get_density_per_chromosome_type($chr,'gc');

    return unless $repeats->size() && $gc->size();
	my $max_repeats = $repeats->{'_biggest_value'};
	my $max_gc      = $gc->{'_biggest_value'};
	my $MAX 	= $max_repeats > $max_gc ? $max_repeats : $max_gc;
	$MAX ||= 1;

   	$repeats->scale_to_fit( $max_repeats / $MAX * $Config->get( 'Vpercents', 'width' ) );
	$repeats->stretch(0);
   	$gc->scale_to_fit( $max_gc / $MAX * $Config->get( 'Vpercents', 'width' ) );
	$gc->stretch(0);
		

	my @repeats = $repeats->get_binvalues();
	my @gc 		= $gc->get_binvalues();	
	my @points  = [];
	my $old_x = undef;
	my $old_y = undef;
    foreach (@repeats) {
	    my $g_x = new Sanger::Graphics::Glyph::Space({
			'x'      => $_->{'chromosomestart'},
			'y'      => 0,
			'width'  => $_->{'chromosomeend'}-$_->{'chromosomestart'},
			'height' => $_->{'scaledvalue'},
			'href'   => "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$_->{'chromosomestart'}&vc_end=$_->{'chromosomeend'}"
		});
		$self->push($g_x);
	    $g_x = new Sanger::Graphics::Glyph::Line({
			'x'      => ($_->{'chromosomeend'}+$_->{'chromosomestart'})/2,
			'Y'      => 0,
			'width'  => 0,
			'height' => $_->{'scaledvalue'},
			'colour' => $repeat_col,
			'absolutey' => 1,
		});
	    $self->push($g_x);
		my $gcvalue = shift @gc;					
		my $new_x = ($gcvalue->{'chromosomeend'}+$gcvalue->{'chromosomestart'})/2;
		my $new_y = $gcvalue->{'scaledvalue'};
		if(defined $old_x) {

		    my $g_x = new Sanger::Graphics::Glyph::Line({
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
