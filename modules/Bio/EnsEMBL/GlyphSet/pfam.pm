package Bio::EnsEMBL::GlyphSet::pfam;
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
	'text'      => 'pfam',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($this) = @_;
    my %hash;
    my $caption = "pfam";

    my $protein = $this->{'container'};
    my $Config = $this->{'config'};

    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();
    
   
   foreach my $feat ($protein->each_Protein_feature()) {
              
       if ($feat->feature2->seqname =~ /^PF\w+/) {
	   push(@{$hash{$feat->feature2->seqname}},$feat);
       }
    }
    
    foreach my $key (keys %hash) {
	
	
	my @row = @{$hash{$key}};
       
     
	my $desc = $row[0]->idesc();
	
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
		$desc => ''
	    },
	});
	   
	my $colour = $Config->get($Config->script(), 'pfam','col');
#To be changed
	
	#$colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);

	
	

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
	    
	    
	    $Composite->push($rect) if(defined $rect);
	    
	}

#	push @{$this->{'glyphs'}}, $Composite;
	$this->push($Composite);
	$y = $y + 8;
    }
    
}

1;


