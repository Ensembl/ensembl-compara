use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::ServerEnum;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use EnsEMBL::Web::NewTable::Column;

sub extend_response {
  my ($self,$config,$wire,$km) = @_;

  return undef unless $wire->{'enumerate'};
  my $enums = $wire->{'enumerate'};
  my (@columns,%values);
  my $i = 0;
  return {
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
      foreach my $col (@columns) {
        my $key = $col->key;
        my $merge = $config->get_keymeta('enumerate',$col,'*')->{'merge'};
        $config->add_keymeta('enumerate',$col,'*',{
          merge => $col->range($values{$key},$km,$col,$merge)
        },1);
      } 
    },
  };
}

1;
