package Bio::EnsEMBL::GlyphSet::primer_forward;

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Forward primers"; }

sub features {

my ($self) = @_;
my $results = $self->{'config'}->{'result'};
my @forward_primers = ();
for (@{$results}){
	push @forward_primers, $_->{'Forward'};
}

return \@forward_primers;
}

##################################################
####### copied from GlyphSet_simple.pm ###########
#### will override _init sub in GlyphSet_simple.pm

sub _init {
    my ($self) = @_;
    my $type = $self->check();
    	return unless defined $type;        

 	my $VirtualContig   = $self->{'container'};
 	my $Config          = $self->{'config'};
 	my $strand          = $self->strand();
 	my $dep             = $Config->get($type, 'dep');
 	my $strand_flag     = $Config->get($type, 'str');
 	my $BUMP_WIDTH      = $Config->get($type, 'bump_width') || 1;
       
## If only displaying on one strand skip IF not on right strand....
    return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

# Get information about the VC - length, and whether or not to
# display track/navigation               
    my $vc_length      = $VirtualContig->length( );
    my $max_length     = $Config->get( $type, 'threshold' ) || 200000000;
    my $navigation     = $Config->get( $type, 'navigation' ) || 'on';
    my $max_length_nav = $Config->get( $type, 'navigation_threshold' ) || 15000000;

## VC to long to display featues dump an error message
    if( $vc_length > $max_length *1010 ) {
        $self->errorTrack( $self->my_label." only displayed for less than $max_length Kb.");
        return; 
	}

## Decide whether we are going to include navigation (independent of switch) 
    $navigation = ($navigation eq 'on') && ($vc_length <= $max_length_nav *1010);    
    my $h = 12;

## Get highlights...
    my %highlights;
    @highlights{$self->highlights()} = ();

## Set up bumping bitmap    
    my @bitmap         = undef;

## Get information about bp/pixels    
    my $pix_per_bp     =   $Config->transform()->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
    my $dep = $Config->get($type, 'dep');

    my $flag   = 1;
    my ($w,$th) = $Config->texthelper()->px2bp('Tiny');
    my $previous_end;
    my ($T,$C,$C1) = 0;
    my ($w,$th) = $Config->texthelper()->px2bp('Tiny');

 	my $features = $self->features; 
    if(!defined($features)) {
      $self->errorTrack("Error: Could not open results file");
      return;
    }
    my @eprimer_glyphs = ();

    foreach my $eprimer ( @{$features} ) {
		my $start = ($eprimer->{'start'} );
		next if $start > $vc_length; ## Skip if totally outside VC
      	my $end = $start + 12;
      	next if $end < 1;            ## Skip if totally outside VC
      	$end   = $vc_length if $end > $vc_length;
      	$T++;
      	$C ++;
      	$previous_end = $end;
      	$flag = 0;

 		my $img_end =  $end;
		my $img_start =  $end - 6/$pix_per_bp;     
		my $row = 0;
        if ($dep > 0){ # we bump
			my $img_s = int($img_start * $pix_per_bp);
			$img_s = 0 if $img_s < 0;
			my  $img_e   = $BUMP_WIDTH + int($img_end * $pix_per_bp);
			$img_e   = $bitmap_length if $img_e > $bitmap_length;	 
	 	$row = &Sanger::Graphics::Bump::bump_row($img_s,    $img_e,    $bitmap_length,    \@bitmap );
	 	next if $row > $dep;   
		}
          
		my  $poly = new Sanger::Graphics::Glyph::Poly({
						   'points'    => [$img_start, 0 +($row * $h),
								  		 $img_start, 8 +($row * $h),
								  		 $img_end, 4 + ($row * $h)],
						   'colour'  => 'red', });
   
	 $self->push($poly);
#	 push @eprimer_glyphs, $poly;  

 	 my $space = new Sanger::Graphics::Glyph::Space({
                'x'          => $img_start-1,
                'y'          => ($row * $h),
                'width'      => 8/$pix_per_bp,
                'height'     => 8,
                "colour"     => 'transparent',
                'absolutey'  => 1			
            });

	$space->{'zmenu'} =  $self->zmenu($eprimer) ;   ## add zmenu into init call
	$self->push($space);
#	push @eprimer_glyphs, $space;
 	}  
   }

sub zmenu {
    my ($self, $eprimer) = @_;
	my $jsfunction = qq(javascript:pop_input(\\'$eprimer->{'sequence'}\\', \\'forward\\'));
    my %zmenu = ( 
        'caption'  => "Forward primer: ",
        '01:Position: ' . ($eprimer->{'start'} +  $eprimer->{'pos'}) => '',
        "02:Length: " . $eprimer->{'length'} => '',
        "03:Annealing Temperature: " . $eprimer->{'temp'} => '',
        "04:%GC: " . $eprimer->{'gc'} => '',
        "05:Sequence: " . $eprimer->{'sequence'} => '',  
		"06:Search for reverse primers " => $jsfunction
 	);   
    
    return \%zmenu;
}

1;
