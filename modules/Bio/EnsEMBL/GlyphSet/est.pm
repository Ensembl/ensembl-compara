package Bio::EnsEMBL::GlyphSet::est;
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
	'text'      => 'ESTs',
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
    my $feature_colour = $Config->get('est', 'col');
    my %id             = ();
    my $small_contig   = 0;
    my $dep            = $Config->get('est', 'dep');
    my @est		= ();

    my @allfeatures = $VirtualContig->get_all_ExternalFeatures($self->glob_bp);  
    @allfeatures =  grep $_->strand() == $strand, @allfeatures; # keep only our strand's features
		
    ## need to sort external features into ESTs, SNPs or traces and treat them differently
    foreach my $f (@allfeatures){
		if ($f->source_tag() eq "est") {
	    	push(@est, $f);
		}
    }

    foreach my $f (@est){
		unless ( $id{$f->id()} ){
	    	$id{$f->id()} = [];
		}
		push(@{$id{$f->id()}}, $f );
    }

    foreach my $i (keys %id){
	
	@{$id{$i}} =  sort {$a->start() <=> $b->start() } @{$id{$i}};
	my $j = 1;
	
	my $has_origin = undef;
	my $estid = $i;
	$estid =~ s/(.*?)\.\d+/$1/;
	
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'zmenu'     => { 
		'caption' => "EST $i",
		"$i" => "http://www.sanger.ac.uk/srs6bin/cgi-bin/wgetz?-e+[DBEST-ALLTEXT:$estid]",		
	    },
	});
	foreach my $f (@{$id{$i}}){
	    unless (defined $has_origin){
		$Composite->x($f->start());
		$Composite->y(0);
		$has_origin = 1;
	    }
	    
	    #$Composite->bordercolour($feature_colour);
	    
	    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
		'x'      	=> $f->start(),
		'y'      	=> 0,
		'width'  	=> $f->length(),
		'height' 	=> $h,
		'colour' 	=> $feature_colour,
		'absolutey' => 1,
		'_feature' 	=> $f, 
	    });
	    $Composite->push($glyph);
	    $j++;
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
	
	$self->push($Composite);
    }
}

1;
