package Bio::EnsEMBL::GlyphSet::Pprotein;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use EnsEMBL::Web::GeneTrans::support;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
		'text'      => 'Peptide',
		'font'      => 'Small',
		'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $protein = $self->{'container'};	
    my $Config  = $self->{'config'};
	my $pep_splice = $protein->{'bg2_splice'};
    my $x 		= 0;
	my $y       = 0;
    my $h       = 4; 
	my $flip = 0;
	my @colours  = ($Config->get('Pprotein','col1'), $Config->get('Pprotein','col2'));
	my $start_phase = 1;
	if ($pep_splice){
	for my $exon_offset (sort { $a <=> $b } keys %$pep_splice){
	   my $colour = $colours[$flip];
	   my $exon_id = $pep_splice->{$exon_offset}{'exon'};
 	   my $rect = new Sanger::Graphics::Glyph::Rect({
		'x'        => $x,
		'y'        => $y,
		'width'    => $exon_offset - $x,
		'height'   => $h,
		'id'       => $protein->id(),
		'colour'   => $colour,
		'zmenu' => {
			'caption' => "Splice Information",
			"00:Exon: $exon_id" => "",
			"01:Start Phase: $start_phase" => "",
			'02:End Phase: '. ($pep_splice->{$exon_offset}{'phase'} +1) => "",
			'03:Length: '.($exon_offset - $x)  => "", },
    	});
  #/$ENV{'ENSEMBL_SPECIES'}/exonview?exon=$exon_id&db=$db
    $self->push($rect);
	$x = $exon_offset ;
	$start_phase = ($pep_splice->{$exon_offset}{'phase'} +1) ;
	$flip = 1-$flip;
	}
	}else{
	 my $rect = new Sanger::Graphics::Glyph::Rect({
	'x'        => 0,
	'y'        => $y,
	'width'    => $protein->length(),
	'height'   => $h,
	'id'       => $protein->id(),
	'colour'   => $colours[0],
    });
    
    $self->push($rect);
	}
}
1;


