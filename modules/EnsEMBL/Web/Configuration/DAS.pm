package EnsEMBL::Web::Configuration::DAS;

use strict;
use EnsEMBL::Web::Configuration;
our @ISA = qw( EnsEMBL::Web::Configuration);

sub features {
    my $self = shift;

    my $page = $self->{'page'};
    $page->set_doc_type('XML', 'DASGFF');

    my $component = $ENV{ENSEMBL_DAS_TYPE} eq 'reference' ? 'EnsEMBL::Web::Component::DAS::Reference' : 
	"EnsEMBL::Web::Component::DAS::Annotation";

    if( my $das_panel = $self->new_panel( '',
					  'code' => 'das', 
					  ) ) {
	$das_panel->add_components("das_features", $component.'::features');
	$self->add_panel( $das_panel );
    }

}

1;
