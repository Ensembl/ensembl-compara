package Bio::EnsEMBL::GlyphSet::unigene;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Line;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'UniGene',
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
    my $feature_colour = $Config->get('unigene', 'col');
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get('unigene', 'dep');

    my @allfeatures = $VirtualContig->get_all_SimilarityFeatures_by_strand("unigene.seq",80,$self->glob_bp(),$strand);  
    #@allfeatures =  grep $_->strand() == $strand, @allfeatures; # keep only our strand's features
    
    foreach my $f (@allfeatures){
	unless ( $id{$f->id()} ){
	    $id{$f->id()} = [];
	}
	push(@{$id{$f->id()}}, $f );
    }
    foreach my $i (keys %id){
	
	#@{$id{$i}} =  sort {$a->start() <=> $b->start() } @{$id{$i}};
	#@{$id{$i}} =  reverse @{$id{$i}} if ($strand == -1);
	my $j = 1;
	
	my $has_origin = undef;
	my $unigeneid = $i;
	$unigeneid =~ s/\./&CID=/;
	
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'zmenu'     => { 
		'caption' => "$i",
		"UniGene cluster $i" => "http://www.ncbi.nlm.nih.gov/UniGene/clust.cgi?ORG=$unigeneid",		
	    },
	});
	foreach my $f (@{$id{$i}}){
	    unless (defined $has_origin){
		$Composite->x($f->start());
		$Composite->y(0);
		$has_origin = 1;
	    }
	    
	    #$Composite->bordercolour($feature_colour);
	    
	    #print STDERR "Feature [$j] start: ", $f->start(), " ID:", $f->id(),  "(strand: $strand)\n";
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
	    #print STDERR "Adding ", $f->id(), " to composite glyph (strand: $strand)\n";
	    $Composite->push($glyph);
	    $j++;
	}
	
	#if($VirtualContig->length() <= 250001){
	if(0){
	    # loop through glyphs again adding connectors...
	    my @g = $Composite->glyphs();
	    for (my $i = 1; $i<scalar(@g); $i++){
		my $id = $Composite->id();
		my $prefix  =  "[ID: $id]";
		my $hstart  = $g[$i]->{'_feature'}->hstart();
		my $hend    = $g[$i-1]->{'_feature'}->hend();
		my $fstart  = $g[$i-1]->{'_feature'}->start();
		my $flength = $g[$i-1]->{'_feature'}->length();
		
		#print STDERR "$prefix Last end   = ", $hend, "\n";
		#print STDERR "$prefix Next start = ", $hstart, "\n";
		#print STDERR "$prefix Difference = ", $hstart - $hend, "\n";
		
		if (($hstart - $hend) < 5 && ($hstart - $hend) > -5 ){	# they are close
		    print STDERR "$prefix Close ($i): ",$hstart, " <-> ", $hend, "\n";
		    
		    my $intglyph = new Bio::EnsEMBL::Glyph::Intron({
			'x'      	=> $fstart + $flength,
			'y'      	=> 0,
			'width'  	=> $g[$i]->{'_feature'}->start() - ($fstart + $flength),
			'height' 	=> $h,
			'strand' 	=> $strand,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
		    });
		    $Composite->{'zmenu'}->{"[$id:$i] $hend - $hstart"} = 1;;
		    #print STDERR "Adding inton to composite glyph ...\n";
		    $Composite->push($intglyph);
		    
		} else {
		    print STDERR "$prefix Not close: ",$hstart, " <=======> ", $hend, "\n"; 
		    my $intglyph = new Bio::EnsEMBL::Glyph::Line({
			'x'      	=> $fstart + $flength,
			'y'      	=> int($h * 0.5),
			'width'  	=> $g[$i]->{'_feature'}->start() - ($fstart + $flength),
			'height' 	=> 0,
			'colour' 	=> $feature_colour,
			'dotted'	=> 1,
			'absolutey' => 1,
		    });
		    $Composite->{'zmenu'}->{"[$id:$i] $hend - $hstart ======> GAP"} = 1;;
		    #$Composite->push($intglyph);
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
