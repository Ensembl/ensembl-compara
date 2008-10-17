package EnsEMBL::Web::Fake;

sub new {
  my( $class, $self ) = @_;
  bless $self, $class;
  return $self;
}

sub adaptor { return $_[0]->{'adaptor'}; }
sub type {    return $_[0]->{'type'};    }
sub view {    return $_[0]->{'view'};    }
sub stable_id { return $_[0]->{'id'};    }
sub name {    return $_[0]->{'name'};    }
sub description { return $_[0]->{'description'}; }

1;
