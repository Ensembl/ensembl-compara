package EnsEMBL::Web::ViewConfig::Transcript::SupportingEvidence;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
    my ($view_config) = @_;
    $view_config->title = 'Supporting Evidence';
    $view_config->_set_defaults(qw(
				   context          100
			       ));
    $view_config->storable = 1;
}

sub form {
    my( $view_config, $object ) = @_;
    $view_config->add_form_element({
	'type'     => 'DropDown', 'select'   => 'select',
	'required' => 'yes',      'name'     => 'context',
	'label'    => 'Context',
	'values'   => [
	    { 'value' => '20',   'name' => '20bp' },
	    { 'value' => '50',   'name' => '50bp' },
	    { 'value' => '100',  'name' => '100bp' },
	    { 'value' => '200',  'name' => '200bp' },
	    { 'value' => '500',  'name' => '500bp' },
	    { 'value' => '1000', 'name' => '1000bp' },
	    { 'value' => '2000', 'name' => '2000bp' },
	    { 'value' => '5000', 'name' => '5000bp' },
	    { 'value' => 'FULL', 'name' => 'Full Introns' },
	]
    });
}

1;

