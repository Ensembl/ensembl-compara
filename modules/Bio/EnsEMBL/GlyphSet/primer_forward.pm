package Bio::EnsEMBL::GlyphSet::primer_forward;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Forward primers"; }

sub features {

my ($self) = @_;
my $temp_file = $self->{'config'}->{'temp_file'};
my (@primer_all, @line, %remove_duplicates, $key);
open (EPRIMER_RESULTS4GRAPH, "<$temp_file") or die "Cannot open EPRIMER_RESULTS4GRAPH file for reading:  $!";
 while (<EPRIMER_RESULTS4GRAPH>) {
my @primer;
 chomp;
 s/^\s+//; # remove leading spaces
 @line = split /\s+/, $_; # split string on space and create array

 if (/FORWARD PRIMER/) {
 @primer = @line[2..6];
  
push @primer, $self->{'config'}->{'startbp'};
$key = join('',@line[2..6]) ;

 if (!(exists($remove_duplicates{$key}))) {
$remove_duplicates{$key}++;
push @primer_all, \@primer;
} 

 }

}

close (EPRIMER_RESULTS4GRAPH);
return \@primer_all;

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
 my $BUMP_WIDTH      = $Config->get($type, 'bump_width');
    $BUMP_WIDTH      = 1 unless defined $BUMP_WIDTH;

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
        return; }


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
    my @eprimer_glyphs = ();

    foreach my $f ( @{$features} ) {

      my @eprimer = @{$f};

      my $start = ($eprimer[0]);

      

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
	 $row = &Sanger::Graphics::Bump::bump_row(
						  $img_s,    $img_e,    $bitmap_length,    \@bitmap
						 );
	 next if $row > $dep;   }
      
     # my $primer_type = $eprimer[4]; 
      my $poly;
     # if ($primer_type eq 'forward') {
	$poly = new Sanger::Graphics::Glyph::Poly({
						   'points'    => [$img_start, 0 +($row * $h),
								   $img_start, 8 +($row * $h),
								   $img_end, 4 + ($row * $h)],
						 
						   'colour'  => 'red', 
 });
   

 push @eprimer_glyphs, $poly;  


 my $space = new Sanger::Graphics::Glyph::Space({
                'x'          => $img_start-1,
                'y'          => ($row * $h),
                'width'      => 8/$pix_per_bp,
                'height'     => 8,
                "colour"     => 'transparent',
                'absolutey'  => 1
						
            });


$space->{'zmenu'} =  $self->zmenu($f) ;
push @eprimer_glyphs, $space;
 }
    
    foreach( @eprimer_glyphs) {   
$self->push($_); 
}
    
    
  }






sub zmenu {
    my ($self, $f) = @_;
    
    my @eprimer = @{$f};

my $jsfunction = qq(javascript:pop_input(\\'$eprimer[4]\\', \\'forward\\'));

    my %zmenu = ( 
        'caption'  => "Forward primer: ",
        '01:Position: ' . ($eprimer[0] + $eprimer[5]) => '',
        "02:Length: " . $eprimer[1] => '',
        "03:Annealing Temperature: " . $eprimer[2] => '',
        "04:%GC: " . $eprimer[3] => '',
        "05:Sequence: " . $eprimer[4] => '',  
"06:Search for reverse primers " => $jsfunction
 
   );   
    
    return \%zmenu;
}


















1;
