package EnsEMBL::Web::Filter::Sanitize;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks form fields for whitespace and quotes that might break things!

sub catch {
  my $self   = shift;
  my $object = $self->object;
  
  foreach my $field ($object->param) {
    my $value = $object->param($field);
    $object->param($field, $self->clean($value));
  }
}

sub clean {
  my ($self, $content) = @_;
  $content =~ s/[\r\n].*$//sm;
  $content =~ s/"//g;
  $content =~ s/''/'/g;
  return $content;
}

1;
