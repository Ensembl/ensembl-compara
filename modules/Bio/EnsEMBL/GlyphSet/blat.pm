package Bio::EnsEMBL::GlyphSet::blat;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

sub init_label {
    my ($this) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Mouse (UCSC)',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);
	
    my $Config         	= $self->{'config'};
    my $feature_colour 	= $Config->get('blat', 'col');
    my $vc 		= $self->{'container'};
    my $length 		= $vc->length();
    
	my @features = $vc->get_all_ExternalFeatures();
	
	foreach my $f(@features){
		#print STDERR "BLAT TAGS: ", $f->primary_tag(), " ", $f->source_tag(), "\n";
		next unless ($f->primary_tag() eq "blat");
		
		my $id = $f->source_tag();
		
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      	=> $f->start(),
			'y'      	=> 0,
			'width'  	=> $f->end()-$f->start(),
			'height' 	=> 8,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
            'zmenu'     => {
                'caption' 	=> "UCSC(Blat)",
                $id 		=> "",
			}
		});
		$self->push($glyph);
	}
	
}


1;
