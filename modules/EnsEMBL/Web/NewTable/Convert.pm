=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::NewTable::CompressedArray;

sub uncompress_block {
  return JSON->new->decode(uncompress(decode_base64($_[0])));
}

sub new {
  my ($proto,$squarify) = @_;
  my $class = ref($proto) || $proto;
  my $self = {
    series => [],
    rseries => {},
    out => EnsEMBL::Web::NewTable::CompressedArray->new,
    squarify => $squarify,
  };
  bless $self,$class;
  return $self;
}

sub add_response {
  my ($self,$response) = @_; 

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
    my @drow = (0) x @{$response->{'series'}};
    foreach my $row (0..$response->{'len'}[$block]-1) {
      my $rownum = $response->{'start'}+$row;
      my $out = $self->{'out'}->row($rownum);
      if($self->{'squarify'}) {
        $out ||= [];
        foreach my $i (0..$#{$response->{'series'}}) {
          next if $null->[$i][$row];
          $out->[$self->{'rseries'}{$response->{'series'}[$i]}] = $data->[$i][$drow[$i]++];
        }
      } else {
        $out ||= {};
        foreach my $i (0..$#{$response->{'series'}}) {
          next if $null->[$i][$row];
          $out->{$response->{'series'}[$i]} = $data->[$i][$drow[$i]++];
        }
      }
      $self->{'out'}->row($rownum,$out);
    }   
  }   
}

sub series { return $_[0]->{'series'}; }

sub run {
  my ($self,$fn) = @_;

  foreach my $i (0..$self->{'out'}->max) {
    $fn->($self->{'out'}->row($i));
  }
}

1;
