package Bio::EnsEMBL::GlyphSet::Ptransmembrane;
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
        'text'      => 'Transmembrane',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my %hash;
    my $caption    = "transmembrane";
    my $y          = 0;
    my $h          = 4;
    my $highlights = $self->highlights();
    my $protein    = $self->{'container'};
    my $Config     = $self->{'config'};  

    my @transm_feat = $protein->get_all_TransmembraneFeatures();
    foreach my $feat(@transm_feat) {
	push(@{$hash{$feat->feature1->seqname}},$feat);
    }

    foreach my $key (keys %hash) {
       	my @row       = @{$hash{$key}};
	my $desc      = $row[0]->idesc();
	my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
	my $colour    = $Config->get('Ptransmembrane', 'col');

	foreach my $pf (@row) {
	    my $x  = $pf->feature1->start();
	    my $w  = $pf->feature1->end - $x;
	    my $id = $pf->feature2->seqname();
	    
	    my $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $w,
		'height'   => $h,
		'id'       => $id,
		'colour'   => $colour,
	    });
	    
	    $Composite->push($rect) if(defined $rect);
	}

	$self->push($Composite);
	$y = $y + 8;
    }
}
1;




















