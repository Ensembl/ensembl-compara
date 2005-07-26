package EnsEMBL::Web::Document::DropDown::MenuContainer::LDView;

use strict;
use EnsEMBL::Web::Document::DropDown::MenuContainer; 

our @ISA = qw(EnsEMBL::Web::Document::DropDown::MenuContainer);

# Lists the variables to be passed to ldview in order to keep the same page

sub _fields {
  my $self = shift;
  return {
    'source'  => $self->{'source'},
    'snp'     => $self->{'snp'},
    'gene'    => $self->{'gene'},
    'pop'     => $self->{'pop'},
    'focus'   => $self->{'focus'},
    'c'       => $self->{'c'},
    'w'       => $self->{'w'},
 };
}
