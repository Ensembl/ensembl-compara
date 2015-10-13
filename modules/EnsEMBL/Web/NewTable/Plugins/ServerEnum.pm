use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::ServerEnum;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use EnsEMBL::Web::NewTable::Column;

sub extend_response {
  my ($self,$config,$wire) = @_;

  return undef unless $wire->{'enumerate'};
  my $enums = $wire->{'enumerate'};
  my (@columns,%values);
  my $i = 0;
  return {
    name => 'enums',
    solves => 'enumerate',
    pre => sub {
      @columns = map { $config->column($_) } @$enums;
    },
    run => sub {
      my ($row) = @_;
      foreach my $col (@columns) {
        my $key = $col->key;
        $col->add_value($values{$key}||={},$row->{$key});
      }
    },
    post => sub {
      my %out;
      foreach my $col (@columns) {
        my $key = $col->key;
        $out{$key} = $col->range($values{$key});
      } 
      return \%out;
    },
  };
}

1;
