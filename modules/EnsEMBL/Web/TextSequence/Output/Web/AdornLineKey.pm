package EnsEMBL::Web::TextSequence::Output::Web::AdornLineKey;

use strict;
use warnings;
no if $] >= 5.018000, warnings => 'experimental::smartmatch';

use Scalar::Util qw(weaken);

sub new {
  my ($proto,$line,$k) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    line => $line,
    key => $k,
    linec => [],
    akey => $line->akey($k),
  };
  bless $self,$class;
  weaken($self->{'line'});
  return $self;
}

sub addall {
  my ($self,$vs) = @_;

  my $prevv = "";
  my $repeat = 0;
  my $akey = $self->{'akey'};
  my @data;
  foreach my $v (@$vs) {
    $v = "" unless $v;
    my $eq = ($prevv ~~ $v); 
    if(@data and $eq) {
      if($repeat) { $data[-1]--; }
      else { push @data,-1; $repeat = 1; }
    } elsif(!$v) {
      $repeat = 0;
      push @data,0;
    } else {
      $repeat = 0;
      my $id = $akey->get_id($v);
      push @data,$id;
    }
    $prevv = $v;
  }
  $self->{'linec'} = \@data;
}

sub data { return $_[0]->{'linec'}; }

1;
