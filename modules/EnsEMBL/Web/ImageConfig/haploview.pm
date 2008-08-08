package EnsEMBL::Web::ImageConfig::haploview;
use strict;
use EnsEMBL::Web::ImageConfig;
use vars qw(@ISA);
@ISA = qw(EnsEMBL::Web::ImageConfig);

sub init {
    my ($self) = @_;
    $self->{'_userdatatype_ID'} = 4;
    
    $self->{'general'}->{'haploview'} = {
	    '_artefacts' => [qw(snplotype)],
	    '_options'   => [qw(on pos col hi known unknown)],
		'_settings' => {
	  'show_labels'		=> 'no',
	},
	    '_names'     => {
	        'on'  => 'activate',
	        'pos' => 'position',
	        'col' => 'colour',
	        'dep' => 'bumping depth',
	        'str' => 'strand',
	        'hi'  => 'highlight colour',
	    },
	    '_settings' => {
	        'width'   => 600,
	        'bgcolor' => 'white',
	    },
	    'snplotype' => {
	        'on'  => "on",
	        'pos' => '0',
	        'col' => 'black',
	    },
    };
}
1;
