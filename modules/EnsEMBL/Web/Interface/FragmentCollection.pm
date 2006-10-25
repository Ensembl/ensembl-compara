package EnsEMBL::Web::Interface::FragmentCollection;

use EnsEMBL::Web::Interface::Fragment;

{

my %Fragments_of;

sub new {
  ### c
  my ($class, %parameters) = @_;
  my $self = bless \my($scalar), $class;
  $Fragments_of{$self}    = defined $params{fragments} ? $params{fragments} : [];
  return $self;
}

sub add_fragment {
  my ($self, $fragment) = @_;
  push @{ $self->fragments }, $fragment; 
}

sub fragment_with_name {
  my ($self, $name) = @_;
  my $fragment= {};
  foreach my $f (@{ $self->fragment}) {
    if ($f->{name} eq $name) {
      $fragment = $f;
    }
  }
  return $fragment;
}

sub size {
  my $self = shift;
  my @array = @{ $self->fragments};
  return $#array + 1;
}

sub fragments {
  my $self = shift;
  $Fragments_of{$self} = shift if @_;
  return $Fragments_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Fragments_of{$self};
}

}

1;
