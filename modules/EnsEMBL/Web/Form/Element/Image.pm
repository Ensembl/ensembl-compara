package EnsEMBL::Web::Form::Element::Image;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new { my $class = shift; return $class->SUPER::new( @_ ); }

sub render { return sprintf( '<tr><td colspan="2"><input type="image" alt="%s" name="%s" src="%s" class="form-button" /></td></tr>', 
			     encode_entities($_[0]->alt),
			     encode_entities($_[0]->name),
			     encode_entities($_[0]->src || '-') ); }

1;
