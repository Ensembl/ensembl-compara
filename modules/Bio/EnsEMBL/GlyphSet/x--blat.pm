package Bio::EnsEMBL::GlyphSet::blat;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use SiteDefs;
use Sanger::Graphics::ColourMap;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
	'text'      => 'Mouse (UCSC)',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $self->label($label);
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
		
		my $glyph = new Sanger::Graphics::Glyph::Rect({
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
