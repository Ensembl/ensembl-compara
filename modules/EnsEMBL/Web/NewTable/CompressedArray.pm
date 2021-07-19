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

package EnsEMBL::Web::NewTable::CompressedArray;

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
    data => [],
    block => [],
    block_size => 10000,
    block_num => -1,
    max_row => -1,
  };
  bless $self,$class;
  return $self;
}

sub _load_block {
  my ($self,$block) = @_;

  if($self->{'block_num'}!=-1) {
    $self->{'data'}[$self->{'block_num'}]=compress_block($self->{'block'});
  }
  $self->{'block_num'} = $block;
  $self->{'block'} = [];
  if($self->{'data'}[$block]) {
    $self->{'block'} = uncompress_block($self->{'data'}[$block]);
  }
}

sub row {
  my ($self,$idx,$value) = @_;

  my $block = int($idx/$self->{'block_size'});
  my $offset = $idx - $block*$self->{'block_size'};
  $self->_load_block($block) unless $self->{'block_num'} == $block;
  $self->{'block'}[$offset] = $value if @_>2;
  $self->{'max_row'} = $idx if $self->{'max_row'} < $idx;
  return $self->{'block'}[$offset]; 
}

sub max { return $_[0]->{'max_row'}; }

1;
