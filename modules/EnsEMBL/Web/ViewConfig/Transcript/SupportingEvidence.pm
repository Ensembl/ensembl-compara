package EnsEMBL::Web::ViewConfig::Transcript::SupportingEvidence;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
    my ($view_config) = @_;
    $view_config->title = 'Supporting Evidence';
    $view_config->_set_defaults(qw(
				   context          100
				   image_width      700
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
	    { 'value' => 'full', 'name' => 'Full Introns' },
	]
    });
    $view_config->add_form_element({
	'type'     => 'DropDown', 'select'   => 'select',
	'required' => 'yes',      'name'     => 'image_width',
	'label'    => 'Image width',
	'values'   => [
	    { 'value' => '600',  'name' => '600px' },
	    { 'value' => '700',  'name' => '700px' },
	    { 'value' => '800',  'name' => '800px' },
	    { 'value' => '900',  'name' => '900px' },
	    { 'value' => '1000', 'name' => '1000px' },
	    { 'value' => '1100', 'name' => '1100px' },
	    { 'value' => '1200', 'name' => '1200px' },
	    { 'value' => '1300', 'name' => '1300px' },
	    { 'value' => '1400', 'name' => '1400px' },
	    { 'value' => '1500', 'name' => '1500px' },
	    { 'value' => '1600', 'name' => '1600px' },
	    { 'value' => '1700', 'name' => '1700px' },
	    { 'value' => '1800', 'name' => '1800px' },
	    { 'value' => '1900', 'name' => '1900px' },
	    { 'value' => '2000', 'name' => '2000px' },
	]
    });
}

1;

