package Bio::EnsEMBL::GlyphSet::vertrna;
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
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'mRNA',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $VirtualContig   = $self->{'container'};
    my $Config          = $self->{'config'};
    my $strand          = $self->strand();
    my $y               = 0;
    my $h               = 8;
    my $highlights      = $self->highlights();
    my $feature_colour  = $Config->get('vertrna','col');
    my @bitmap          = undef;
    my $pix_per_bp  	= $Config->transform()->{'scalex'};
    my $bitmap_length 	= int($VirtualContig->length * $pix_per_bp);
    my $small_contig    = 0;
    my $dep             = $Config->get('vertrna', 'dep');
    my @allfeatures = $VirtualContig->get_all_SimilarityFeatures_above_score("embl_vertrna",80,$self->glob_bp());  
	
    my %id = ();
    
    foreach my $f (@allfeatures){
	next unless ($f->strand() == $strand);
	unless ( $id{$f->id()} ){
	    $id{$f->id()} = [];
	}
	push(@{$id{$f->id()}}, $f );
    }

    foreach my $i (keys %id){
	my $has_origin = undef;
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'zmenu'     => { 
		'caption' => "$i",
		"EMBL: $i" => "http://www.ebi.ac.uk/cgi-bin/emblfetch?$i",		
	    },
	});
	
	@{$id{$i}} =  sort {$a->start() <=> $b->start() } @{$id{$i}};
	foreach my $f (@{$id{$i}}){
	    unless (defined $has_origin){
		$Composite->x($f->start());
		$Composite->y(0);
		$has_origin = 1;
	    }
	    
	    #$Composite->bordercolour($feature_colour);
	    
	    #print STDERR "Feature start: ", $f->start(), " ID:", $f->id(),  "\n";
	    #print STDERR "Feature length: ", $x1, " ID:", $f->id(),  "\n";
	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      	=> $f->start(),
		'y'      	=> 0,
		'width'  	=> $f->length(),
		'height' 	=> $h,
		'colour' 	=> $feature_colour,
		'absolutey' => 1,
		'_feature' 	=> $f, 
	    });
	    #print STDERR "Adding ", $f->id(), " to composite glyph ...\n";
	    $Composite->push($glyph);
	}
	
	#if($VirtualContig->length() <= 250001){
	if(0){
	    # loop through glyphs again adding connectors...
	    my @g = $Composite->glyphs();
	    for (my $i = 1; $i<scalar(@g); $i++){
		my $hstart  = $g[$i]->{'_feature'}->hstart();
		my $hend    = $g[$i-1]->{'_feature'}->hend();
		my $fstart  = $g[$i-1]->{'_feature'}->start();
		my $flength = $g[$i-1]->{'_feature'}->length();
		
		#print STDERR "$prefix Last end   = ", $hend, "\n";
		#print STDERR "$prefix Next start = ", $hstart, "\n";
		#print STDERR "$prefix Difference = ", $hstart - $hend, "\n";
		
		if (($hstart - $hend) < 5 && ($hstart - $hend) > -5 ){	# they are close
		    #print STDERR "$prefix Close ($i): ",$hstart, " <-> ", $hend, "\n";
		    
		    my $intglyph = new Bio::EnsEMBL::Glyph::Intron({
			'x'      	=> $fstart + $flength,
			'y'      	=> 0,
			'width'  	=> $g[$i]->{'_feature'}->start() - ($fstart + $flength),
			'height' 	=> $h,
			'strand' 	=> $strand,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
		    });
		    $Composite->{'zmenu'}->{"[Intron $i] bp $hend - $hstart"} = '';
		    #$Composite->push($intglyph);
		    
		} else {
		    $Composite->{'zmenu'}->{"[Intron $i] bp $hend - $hstart"} = '';
		    next;
		    #print STDERR "$prefix Not close: ",$hstart, " <=======> ", $hend, "\n"; 
		    my $intglyph = new Bio::EnsEMBL::Glyph::Line({
			'x'      	=> $fstart + $flength,
			'y'      	=> int($h * 0.5),
			'width'  	=> $g[$i]->{'_feature'}->start() - ($fstart + $flength),
			'height' 	=> 0,
			'colour' 	=> $feature_colour,
			'dotted'	=> 1,
			'absolutey' => 1,
		    });
		    $Composite->push($intglyph);
		}
	    }
	}
	
	if ($dep > 0){ # we bump
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
	    
	    next if ($row > $dep);
	    $Composite->y($Composite->y() + (1.5 * $row * $h * -$strand));
	    
	    # if we are bumped && on a large contig then draw frames around features....
	    $Composite->bordercolour($feature_colour) unless ($small_contig);
	}
	
	# now save the composite glyph...
	$self->push($Composite);
    }
}

1;
