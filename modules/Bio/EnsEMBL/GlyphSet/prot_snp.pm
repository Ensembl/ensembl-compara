package Bio::EnsEMBL::GlyphSet::prot_snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub _init {
    my ($this, $protein, $Config) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'snps',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $this->label($label);

    my $protein = $this->{'container'};
    my $Config = $this->{'config'};  

    my $y          = 0;
    my $h          = 4;
    my $highlights = $this->highlights();
    my $key = "prot_snp";

    my $xp = 0;
    my $wp = 0;
   
    my $colour = $Config->get($Config->script(), 'prot_snp','col');

    my @snp_array;

    if (@snp_array) {
	my $composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key
		},
		});
	my $colour = $Config->get($Config->script(), 'prints','col');
	
	foreach my $int (@snp_array) {
	    my $x = $int->feature1->start();
	    my $w = $int->feature1->end() - $x;
	    my $id = $int->feature2->seqname();
	    
	    my $start = $int->feature2->start();
	    my $end = $int->feature2->end();

	    my $length = $end - $start;
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
		#'zmenu' => {
		#    'caption' => $id,
		#    $length => ''
		#},
	    });
	    $composite->push($rect) if(defined $rect);
	}
	$this->push($composite);
    }
   
}
1;




















