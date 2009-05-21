package EnsEMBL::Web::Form::Element::File;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'widget_type' => 'file' ); }

sub validate { return 1; }

sub _extra { return qq(class="input-file @{[$_[0]->style]}" ); }

1;
