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
    my $feature_colour 	= $Config->get($self->das_name(), 'col') || $Config->colourmap()->id_by_name('contigblue1');
    my $vc 		= $self->{'container'};
    my $length 		= $vc->length();
    
    my @features = $vc->get_all_ExternalFeatures();
    my $link_text = $self->{'extras'}->{'linktext'} || 'Additional info';
    foreach my $f(@features){
		next unless ($f->primary_tag() eq "das" && $f->source_tag() eq $self->{'extras'}->{'dsn'});
		my $id     = $f->das_id();
		#	my $type   = $f->das_name();
		#	MY $dsn    = $f->das_dsn();
		#	my $source = $f->source_tag();
		#	my $strand = $f->strand();

		my $zmenu = {
                	'caption'         => $self->{'extras'}->{'label'},
                	"DAS source info" => $self->{'extras'}->{'url'}
        	};
		# JS5: If we have an ID then we can add this to the Zmenu and
		#      also see if we can make a link to any additional information
		#      about the source.
		if($id && $id ne 'null') {
            	$zmenu->{$link_text} = $self->{'extras'}->{'linkURL'}.$id
			if($self->{'extras'}->{'linkURL'});
	    	$zmenu->{$id} = '';
		}
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
            'x'      	=> $f->start(),
	    	'y'      	=> 0,
	    	'width'  	=> $f->end()-$f->start(),
	    	'height' 	=> 8,
	    	'colour' 	=> $feature_colour,
	    	'absolutey' => 1,
            'zmenu'     => $zmenu
		});
		$self->push($glyph);
    }
}

sub das_name {
    my ($self) = @_;
    return $self->{'extras'}->{'name'};
}

1;
