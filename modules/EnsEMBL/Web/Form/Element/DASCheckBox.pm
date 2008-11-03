package EnsEMBL::Web::Form::Element::DASCheckBox;

use strict;

use base qw( EnsEMBL::Web::Form::Element::CheckBox);

my $DAS_DESC_WIDTH = 120;

sub new {
  my $class = shift;
  my %params = @_;
  $params{'long_label'} ||= 1;
  $params{'name'}       ||= 'dsn';
  $params{'value'}      ||= $params{'das'}->logic_name;
  $params{'label'}      ||= $params{'das'}->label;
  $params{'notes'}      ||= &_short_das_desc( $params{'das'} );
  my $self = $class->SUPER::new( %params );
  $self->checked = $params{'checked'};
  $self->{'class'} = $params{'long_label'} ? 'checkbox-long' : '';
  return $self;
}

sub _short_das_desc {
  my ( $source ) = @_;
  my $desc = $source->description;
  if (length $desc > $DAS_DESC_WIDTH) {
    $desc = substr $desc, 0, $DAS_DESC_WIDTH;
    $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./; # replace final space with " ..."
  }
  return $desc;
}

1;