package Bio::EnsEMBL::GlyphSet::signal_peptide;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($self) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Signal peptide',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
}


sub _init {
    my ($self) = @_;
    my %hash;
    
    my $y          = 0;
    my $h          = 4;
    my $protein = $self->{'container'};
    my $Config = $self->{'config'};  

    foreach my $feat ($protein->each_Protein_feature()) {
		  #print STDERR "desc: ",$feat->feature2->seqname ,"!\n";
       if ($feat->feature2->seqname eq "signalp") {
		  #print STDERR "found a sig peptide!\n";
	   	  push(@{$hash{$feat->feature2->seqname}},$feat);
       }
    }
	
    my $caption = "signal_peptide";
    foreach my $key (keys %hash) {
		my @row = @{$hash{$key}};
		my $desc = $row[0]->idesc();
		my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    	'zmenu' => {
			'caption'  => $key,
			$desc => ''
	    	},
		});

		my $colour = $Config->get($Config->script(), 'signal_peptide','col');

		foreach my $pf (@row) {
	    	my $x = $pf->feature1->start();
	    	my $w = $pf->feature1->end - $x;
	    	my $id = $pf->feature2->seqname();

	    	my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $x,
			'y'        => $y,
			'width'    => $w,
			'height'   => $h,
			'id'       => $id,
			'colour'   => $colour,
			'zmenu' => {
		    	'caption' => $caption,
			},
	    	});
	    	$Composite->push($rect);
		}

		$self->push($Composite);
    }
}
1;




















