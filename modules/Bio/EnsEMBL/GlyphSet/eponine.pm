package Bio::EnsEMBL::GlyphSet::eponine;
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

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'TSS Eponine(Das)',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

	return unless ($self->strand() == -1);
	
    my $Config         	= $self->{'config'};
    my $feature_colour 	= $Config->get($Config->script(),'high','col');
	my $vc 				= $self->{'container'};
	my $length 			= $vc->length();

	my @features = $vc->get_all_ExternalFeatures();
	foreach my $f(@features){
		next unless ($f->primary_tag() eq "das" && $f->source_tag() eq "tss_eponine");
		
		my $type = $f->das_name();
		my $dsn = $f->das_dsn();
		my $source = $f->source_tag();
		#print STDERR "DAS feature name: $type from DSN: $dsn\n";
		
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
			'x'      	=> $f->start(),
			'y'      	=> 0,
			'width'  	=> $f->end()-$f->start(),
			'height' 	=> 8,
			'colour' 	=> $feature_colour,
			'absolutey' => 1,
            'zmenu'     => {
                'caption' 	=> "Transcript start site",
                $type 		=> "",
                "DAS source info" 		=> "http://servlet.sanger.ac.uk:8080/das/dsn",
			}
		});
		$self->push($glyph);
	}
	
}


1;
