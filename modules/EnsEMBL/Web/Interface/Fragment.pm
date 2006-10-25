package EnsEMBL::Web::Interface::Fragment;

{

my %Components_of;

sub new {
  ### c
  my ($class, %parameters) = @_;
  my $self = bless \my($scalar), $class;
  $Components_of{$self}    = defined $params{components} ? $params{components} : [];
  return $self;
}

sub add {
  my ($self, $component) = @_;
  push @{ $self->components }, $component; 
}

sub component_with_name {
  my ($self, $name) = @_;
  my $component = {};
  foreach my $c (@{ $self->components }) {
    if ($c->{name} eq $name) {
      $component = $c;
    }
  }
  return $component;
}

sub size {
  my $self = shift;
  my @array = @{ $self->components };
  return $#array + 1;
}

sub components {
  my $self = shift;
  $Components_of{$self} = shift if @_;
  return $Components_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Components_of{$self};
}

}

1;
