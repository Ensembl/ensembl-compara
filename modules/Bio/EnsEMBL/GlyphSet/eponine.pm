package Bio::EnsEMBL::GlyphSet::eponine;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

my $SPECIES = $ENV{'ENSEMBL_SPECIES'};
my $species_defs = "${SPECIES}_Defs";
eval "require $species_defs";
if ($@){ die "Can't use ${species_defs}.pm - $@\n"; }

sub init_label {
    my ($self) = @_;
    $self->{'das_key'}  = 'eponine';
    $self->{'das_conf'} = $species_defs->ENSEMBL_INTERNAL_DAS_SOURCES->{ $self->{'das_key'} };
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $self->{'das_conf'}->{'caption'},
        'font'      => 'Small',
	'absolutey' => 1
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    
    return unless ($self->strand() == -1);
    
    my $das_conf       = $self->{'das_conf'};
    my $Config         = $self->{'config'};
    my $feature_colour = $Config->get($self->{'das_key'}, 'col');
    my $vc             = $self->{'container'};
    my $length         = $vc->length();
    
    
    my @features = $vc->get_all_ExternalFeatures();
    foreach my $f(@features){
	next unless ($f->primary_tag() eq "das" && $f->source_tag() eq $das_conf->{'dsn'});
	
	my $id = $f->das_id();
	# my $type = $f->das_name();
	# my $dsn = $f->das_dsn();
	# my $source = $f->source_tag();
	# my $strand = $f->strand();
	
	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      	=> $f->start(),
	    'y'      	=> 0,
	    'width'  	=> $f->end()-$f->start(),
	    'height' 	=> 8,
	    'colour' 	=> $feature_colour,
	    'absolutey' => 1,
            'zmenu'     => {
                'caption' 	  => $das_conf->{'label'},
                $id 		  => "",
                "DAS source info" => $das_conf->{'url'},
	    }
	});
	$self->push($glyph);
    }
}


1;
