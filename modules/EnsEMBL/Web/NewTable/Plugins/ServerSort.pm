use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::ServerSort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use EnsEMBL::Web::NewTable::Column;

sub extend_response {
  my ($self,$config,$wire) = @_;

  return undef unless $wire->{'sort'};
  my @sort = @{$wire->{'sort'}};
  my (@columns,@keys);
  my $i = 0;
  return {
    name => 'order',
    solves => 'sort',
    pre => sub {
      @columns = map { $config->column($_->{'key'}) } @sort;
      push @sort,{ key => '__tie', dir => 1 };
      push @columns,
        EnsEMBL::Web::NewTable::Column->new($self,'numeric','__tie');
    },
    run => sub {
      my ($row) = @_;
      $row->{'__tie'} = $i++;
      push @keys, [ map { $row->{$_->{'key'}} } @sort ];
    },
    post => sub {
      my $keymeta = $config->keymeta();
      my @cache;
      my @order = sort {
        my $c = 0;
        foreach my $i (0..$#sort) {
          $cache[$i]||={};
          $c = $columns[$i]->compare($a->[$i],$b->[$i],
                                     $sort[$i]->{'dir'},$keymeta,
                                     $cache[$i],$sort[$i]->{'key'});
          last if $c; 
        }   
        $c; 
      } @keys;
      
      # Invert index
      my @out;
      $out[$order[$_]->[-1]] = $_ for (0..$#order);
      return \@out;
    },
  };
}

1;
