package Bio::EnsEMBL::GlyphSet::prosite;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Prosite',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this) = @_;
    my %hash;
    my $y          = 0;
    my $h          = 4;

    my $protein = $this->{'container'};
    my $Config = $this->{'config'};

    
    foreach my $feat ($protein->each_Protein_feature()) {
		if ($feat->feature2->seqname =~ /^PS\w+/) {
			push(@{$hash{$feat->feature2->seqname}},$feat);
		}
    }
    
    my $caption = "Prosite";

    foreach my $key (keys %hash) {
		my @row = @{$hash{$key}};
       	my $desc = $row[0]->idesc();

		my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    	'zmenu' => {
				'caption'  	=> "Prosite: $desc",
				$key 		=> "http://www.expasy.ch/cgi-bin/nicesite.pl?$key"
			},
			});

		my $colour = $Config->get($Config->script(), 'prosite','col');
		my @row = @{$hash{$key}};

		my $prsave;
		foreach my $pr (@row) {
	    	my $x = $pr->feature1->start();
	    	my $w = $pr->feature1->end - $x;
	    	my $id = $pr->feature1->id();

	    	my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $x,
			'y'        => $y,
			'width'    => $w,
			'height'   => $h,
			'id'       => $id,
			'colour'   => $colour,
	    	});
			
	    	$Composite->push($rect) if(defined $rect);
	    	$prsave = $pr;
		}

		my $font = "Tiny";
		my $text = new Bio::EnsEMBL::Glyph::Text({
	    	'font'   => $font,
	    	'text'   => $prsave->idesc,
	    	'x'      => $row[0]->feature1->start(),
	    	'y'      => $h,
	    	'height' => $Config->texthelper->height($font),
	    	'colour' => $colour,
		});

		#$this->push($text);

		$this->push($Composite);
    }
    
}

1;
