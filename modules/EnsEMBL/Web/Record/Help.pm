package EnsEMBL::Web::Record::Help;

### Inside-out class used to represent help information.

use strict;
use warnings;

use EnsEMBL::Web::Record;

our @ISA = qw(EnsEMBL::Web::Record);

{

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  return $self;
}

sub data_hash {
  ## Returns fields from the data dump in a format compatible with legacy code
  my $self = shift;
  my @field_names = @_;

  ## pass standard fields
  my $hash = {'id' => $self->id };

  ## pass data dump fields
  foreach my $name (@field_names) {
    $hash->{$name} = $self->fields($name);
  }
  return $hash;
}


}

1;
