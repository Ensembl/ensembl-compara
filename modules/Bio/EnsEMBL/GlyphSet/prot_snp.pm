package Bio::EnsEMBL::GlyphSet::prot_snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'snps',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self, $protein, $Config) = @_;

    my $protein    = $self->{'container'};
    my $Config     = $self->{'config'};  
    my $y          = 0;
    my $h          = 4;
    my $highlights = $self->highlights();
    my $key        = "prot_snp";
    my $xp         = 0;
    my $wp         = 0;
    my $colour     = $Config->get('prot_snp','col');

    my @snp_array;

    if (@snp_array) {
	my $composite = new Bio::EnsEMBL::Glyph::Composite({
	    'id'    => $key,
	    'zmenu' => {
		'caption'  => $key,
	    },
	});
	my $colour = $Config->get('prints','col');
	
	foreach my $int (@snp_array) {
	    my $x      = $int->feature1->start();
	    my $w      = $int->feature1->end() - $x;
	    my $id     = $int->feature2->seqname();
	    my $start  = $int->feature2->start();
	    my $end    = $int->feature2->end();
	    my $length = $end - $start;
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
	    });
	    $composite->push($rect) if(defined $rect);
	}
	$self->push($composite);
    }
   
}
1;




















