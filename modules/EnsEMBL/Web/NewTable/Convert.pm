=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::NewTable::Convert;

use strict;
use warnings;

use JSON;
use MIME::Base64;
use Compress::Zlib;

sub compress_block {
  return encode_base64(compress(JSON->new->encode($_[0])));
}

sub uncompress_block {
  return JSON->new->decode(uncompress(decode_base64($_[0])));
}

sub new {
  my ($proto) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    series => [],
    rseries => {},
    outblock => [],
  };
  bless $self,$class;
  return $self;
}

sub add_response {
  my ($self,$response) = @_; 

  my $ob_size = 10000;
  my $outblock = -1; 
  my $rows = []; 
  # Columns
  foreach my $col (@{$response->{'series'}}) {
    next if exists $self->{'rseries'}{$col};
    push @{$self->{'series'}},$col;
    $self->{'rseries'}{$col} = $#{$self->{'series'}};
  }
  # Data
  foreach my $block (0..$#{$response->{'len'}}) {
    my $data = uncompress_block($response->{'data'}[$block]);
    my $null = uncompress_block($response->{'nulls'}[$block]);
    foreach my $row (0..$response->{'len'}[$block]-1) {
      my $rownum = $response->{'start'}+$row;
      my $new_ob = int($rownum/$ob_size);
      my $offset = $rownum-($new_ob*$ob_size);
      if($outblock != $new_ob) {
        if($outblock!=-1) {
          $self->{'outblock'}[$outblock] = compress_block($rows);
        }
        $outblock = $new_ob;
        if($self->{'outblock'}[$outblock]) {
          $rows = uncompress_block($self->{'outblock'}[$outblock]);
        } else {
          $rows = []; 
        }   
      }   
      my @row;
      foreach my $i (0..$#{$response->{'series'}}) {
        next if $null->[$i][$row];
        $row[$self->{'rseries'}{$response->{'series'}[$i]}] = $data->[$i][$row];
      }   
      $rows->[$offset] = \@row;
    }   
  }   
  $self->{'outblock'}[$outblock] = compress_block($rows) if $outblock != -1;
}

sub series { return $_[0]->{'series'}; }

sub run {
  my ($self,$fn) = @_;

  foreach my $outblock (@{$self->{'outblock'}}) {
    my $rows = uncompress_block($outblock);
    $fn->($_) for @$rows;
  }
}

1;
