package ExaLead::Link;
use strict;

sub new {
  my( $class, $string, $exalead ) = @_;
  my $self = {
    'param' => $string,
    'rootURL' => $exalead->rootURL,
    'context' => $exalead->query->context
  };
  bless $self, $class;
}

sub param     :lvalue { $_[0]->{'param'};    } # get/set string
sub rootURL   :lvalue { $_[0]->{'rootURL'};  } # get/set string
sub context   :lvalue { $_[0]->{'context'};  } # get/set string
sub URL {
  my $self = shift;
  my $URL = $self->rootURL."?_C=".$self->context;
  foreach my $p ( split /\//, $self->param ) {
    $p =~ s/\+/%2b/g; 
    $URL .= "&$p";
  }
  return $URL;
}

1;
