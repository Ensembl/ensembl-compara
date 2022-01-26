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
