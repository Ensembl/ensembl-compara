package Bio::EnsEMBL::GlyphSet::vertrna;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

	my $strand = $self->strand();
    my $y          = 0;
    my $h          = 8;
    my $highlights = $self->highlights();

    my @bitmap      	= undef;
    my $im_width 		= $Config->image_width();
    my $src 			= $Config->get($Config->script(),'feature','col');
	my $cmap  			= $Config->colourmap();
    my $bitmap_length 	= $VirtualContig->length();
	my @allfeatures;

	my $feature_colour = $cmap->id_by_name('pine');

    my $glob_bp = 100;

    my @vert = $VirtualContig->get_all_SimilarityFeatures_above_score("embl_vertrna",80,$glob_bp);  
    push @allfeatures,@vert;
	
	my %id = ();
	@allfeatures = sort { $a->id() cmp $b->id() } @allfeatures;
	
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
		'id'		=> $i,
		'zmenu'     => { caption => $i },
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
		
		if(1){
		# loop through glyphs again adding connectors...
		my @g = $Composite->glyphs();
		for (my $i = 1; $i<scalar(@g); $i++){
			print STDERR "[ID:",$Composite->id(),"] ";
			if (($g[$i]->{'_feature'}->hstart() - $g[$i-1]->{'_feature'}->hend()) < 5){	# they are close
				print STDERR "Close ($i): ",$g[$i]->{'_feature'}->hstart(), " - ", $g[$i-1]->{'_feature'}->hend(), "\n";

				my $intglyph = new Bio::EnsEMBL::Glyph::Intron({
					'x'      	=> $g[$i-1]->{'_feature'}->start() + $g[$i-1]->{'_feature'}->length(),
					'y'      	=> 0,
					'width'  	=> $g[$i]->{'_feature'}->start() - ($g[$i-1]->{'_feature'}->start() + $g[$i-1]->{'_feature'}->length()),
					'height' 	=> $h,
					'colour' 	=> $feature_colour,
					'absolutey' => 1,
				});

				#print STDERR "Adding inton to composite glyph ...\n";
				#$Composite->push($intglyph);

			} else {
				print STDERR "Not close: ",$g[$i]->{'_feature'}->hstart(), " - ", $g[$i-1]->{'_feature'}->hend(), "\n"; 
			}
		}
		}
		
		if ($Config->get($Config->script(), 'feature', 'dep') > 0){ # we bump
	    	my $bump_start = $Composite->x();
	    	$bump_start = 0 if ($bump_start < 0);

	    	my $bump_end = $bump_start + ($Composite->width());
	    	next if $bump_end > $bitmap_length;
	    	my $row = &Bump::bump_row(      
				    	  $bump_start,
				    	  $bump_end,
				    	  $bitmap_length,
				    	  \@bitmap
	    	);

	    	next if $row > $Config->get($Config->script(), 'vertrna', 'dep');
	    	$Composite->y($Composite->y() + (1.5 * $row * $h * -$strand));
		}
		
		# now save the composite glyph...
		$self->push($Composite);
	}
	
}

1;
