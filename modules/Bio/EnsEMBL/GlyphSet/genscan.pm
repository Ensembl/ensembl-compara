package Bio::EnsEMBL::GlyphSet::genscan;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Genscan',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $VirtualContig  = $self->{'container'};
    my $Config         = $self->{'config'};
    my $strand         = $self->strand();
    my $h              = 8;
    my $highlights     = $self->highlights();
    my @bitmap         = undef;
    my $pix_per_bp     = $Config->transform()->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
    my $feature_colour = $Config->get('genscan','col');
    my %id             = ();
    my $small_contig   = 0;
    my @allfeatures    = ();

    my $k = 1;
    foreach my $seq_feat ($VirtualContig->get_all_PredictionFeatures()){
	if ($seq_feat->strand() == $strand){
	    #print STDERR "GENSCAN: Strand: $strand == ", $seq_feat->strand(), " for genscan\n";
	    #print STDERR "GENSCAN: ID: ", $seq_feat->id(), " for genscan\n";
	    my @tmp = $seq_feat->sub_SeqFeature();
	    $id{$seq_feat->id()} = \@tmp;
	    $k++;
	}
    }

    foreach my $i (keys %id){
	
	@{$id{$i}} =  sort {$a->start() <=> $b->start() } @{$id{$i}};
	#print STDERR "GENSCAN: seq_feature id: $i\n";
	my $has_origin = undef;
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({});

	foreach my $f (@{$id{$i}}){
	    
	    unless (defined $has_origin){
		$Composite->x($f->start());
		$Composite->y(0);
		$has_origin = 1;
		my $id = $f->id();
		$Composite->{'zmenu'}     = { 
		    caption => "Genscan $id",
		    'View peptide' => "/perl/dumpview?type=genscan&id=$id",		
		},
	    }
	    
	    #print STDERR "GENSCAN: Feature [$f ($i)] start: ", $f->start(), " ID:", $f->id(),  " (strand: $strand)\n";
	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      	=> $f->start(),
		'y'      	=> 0,
		'width'  	=> $f->length(),
		'height' 	=> $h,
		'colour' 	=> $feature_colour,
		'absolutey' => 1,
		'_fstart' 	=> $f->start(), 
		'_flength' 	=> $f->length(), 
	    });
	    $Composite->push($glyph);
	}
	
	# loop through glyphs again adding connectors...
	my @g = $Composite->glyphs();
	for (my $i = 1; $i<scalar(@g); $i++){
	    my $id = $Composite->id();
	    my $fstart  = $g[$i-1]->{'_fstart'};
	    my $flength = $g[$i-1]->{'_flength'};
	    
	    my $intglyph = new Bio::EnsEMBL::Glyph::Intron({
		'x'      	=> $fstart + $flength,
		'y'      	=> 0,
		'width'  	=> $g[$i]->{'_fstart'} - ($fstart + $flength),
		'height' 	=> $h,
		'strand' 	=> $strand,
		'colour' 	=> $feature_colour,
		'absolutey' => 1,
	    });
	    $Composite->push($intglyph);
	}
	
	if ($Config->get('genscan', 'dep') > 0){ # we bump
	    my $bump_start = int($Composite->x() * $pix_per_bp);
	    $bump_start = 0 if ($bump_start < 0);
	    
	    my $bump_end = $bump_start + ($Composite->width() * $pix_per_bp);
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
	    my $row = &Bump::bump_row(
				      $bump_start,
				      $bump_end,
				      $bitmap_length,
				      \@bitmap
				      );
	    
	    next if $row > $Config->get('genscan', 'dep');
	    $Composite->y($Composite->y() + (1.5 * $row * $h * -$strand));
	    
	}
	
	#########
	# now save the composite glyph...
	#
	$self->push($Composite);
    }
}

1;
