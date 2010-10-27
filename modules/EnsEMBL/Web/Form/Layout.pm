package EnsEMBL::Web::Form::Layout;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Form::Div);
use Carp qw(cluck);
use constant {
  HEADING_TAG           => 'h2',
  CSS_CLASS             => '',
  CSS_CLASS_HEADING     => '',
  CSS_CLASS_HEAD_NOTES  => 'form-headnotes',
  CSS_CLASS_FOOT_NOTES  => 'form-footnotes',
};

## Override following subs in the required sub classes
sub add_field {           shift->_not_supported((caller(0))[3]); }
sub add_subheading_row {  shift->_not_supported((caller(0))[3]); }
sub add_column {          shift->_not_supported((caller(0))[3]); }
sub add_columns {         shift->_not_supported((caller(0))[3]); }
sub add_row {             shift->_not_supported((caller(0))[3]); }
sub set_input_prefix {    shift->_not_supported((caller(0))[3]); }

sub _not_supported {
  my ($self, $sub) = @_;
  warn "$sub is not supported with ".ref($self)." layout. Set the required layout for form before calling this method.";
  cluck;
}

1;