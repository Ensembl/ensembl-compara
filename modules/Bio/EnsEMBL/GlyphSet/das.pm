package Bio::EnsEMBL::GlyphSet::das;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => $self->{'extras'}->{'caption'},
	'font'      => 'Small',
	'absolutey' => 1
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;
    return unless ($self->strand() == -1);
	
    my $Config         	= $self->{'config'};
    my $feature_colour 	= $Config->get($self->das_name(), 'col');
    my $vc 		= $self->{'container'};
    my $length 		= $vc->length();
    
    my @features = $vc->get_all_ExternalFeatures();
    foreach my $f(@features){
	next unless ($f->primary_tag() eq "das" && $f->source_tag() eq $self->{'extras'}->{'dsn'});
	
	my $id     = $f->das_id();
#	my $type   = $f->das_name();
#	my $dsn    = $f->das_dsn();
#	my $source = $f->source_tag();
#	my $strand = $f->strand();
	
	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'      	=> $f->start(),
	    'y'      	=> 0,
	    'width'  	=> $f->end()-$f->start(),
	    'height' 	=> 8,
	    'colour' 	=> $feature_colour,
	    'absolutey' => 1,
            'zmenu'     => {
                'caption' 	  => $self->{'extras'}->{'label'},
                $id 		  => "",
                "DAS source info" => $self->{'extras'}->{'url'},
	    }
	});
	$self->push($glyph);
    }
}

sub das_name {
    my ($self) = @_;
    return $self->{'extras'}->{'name'};
}

1;
