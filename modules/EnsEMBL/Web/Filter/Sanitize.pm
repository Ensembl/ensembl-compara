package EnsEMBL::Web::Filter::Sanitize;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Checks form fields for whitespace and quotes that might break things! 

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Doesn't need a message hash - should just work silently :)
}

sub catch {
  my $self = shift;
  foreach my $field ($self->object->param) {
    my $value = $self->object->param($field);
    $self->object->param($field, $self->clean($value));
  }
}

sub clean {
  my ($self, $content) = @_;
  $content =~ s/[\r\n].*$//sm;
  $content =~ s/"//g;
  $content =~ s/''/'/g;
  return $content;
}


}

1;
