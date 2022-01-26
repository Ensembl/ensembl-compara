=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::ServerSort;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use EnsEMBL::Web::NewTable::Column;

sub _sort_fn {
  my ($aa,$bb,$columns,$sort,$keymeta,$cache) = @_;

  my $c = 0;
  foreach my $i (0..$#$sort) {
    $cache->[$i]||={};
    $c = $columns->[$i]->compare($aa->[$i],$bb->[$i],
                                 $sort->[$i]->{'dir'},$keymeta,
                                 $cache->[$i],$sort->[$i]->{'key'});
    return $c if $c;
  }
  return 0;
}

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
      my $s = sub {
        return _sort_fn($a,$b,\@columns,\@sort,$keymeta,\@cache,\@sort);
      };
      my @order = sort $s @keys;
      
      # Invert index
      my @out;
      $out[$order[$_]->[-1]] = $_ for (0..$#order);
      return \@out;
    },
  };
}

1;
