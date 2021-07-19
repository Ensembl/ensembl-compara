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

package EnsEMBL::Web::IOWrapper::BigPsl;

### Wrapper around Bio::EnsEMBL::IO::Parser::BigBed

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);

use parent qw(EnsEMBL::Web::IOWrapper::BigBed);

## BigPsl is basically a BigBed file with custom AutoSQL, so we need to force
## use of the BigBed parser

sub open {
  ## Override the default open method, to force use of the BigBed parser
  my ($url, $format, $args) = @_;
  
  my $class = 'EnsEMBL::Web::IOWrapper::BigPsl';
  
  my $wrapper;
  if (dynamic_use($class, 1)) {
    my $parser = Bio::EnsEMBL::IO::Parser::open_as('BigBed', $url);
    
    if ($parser) {
    
      $wrapper = $class->new({
                              'parser' => $parser,
                              'format' => $format,
                              %{$args->{options}||{}}
                            });
    }                       
  } 
  return $wrapper;
} 

sub create_structure { 
  ## Don't use thick start and thick end for Psl
  my ($self, $feature, $start_coord, $end_coord, $slice_start) = @_;
  
  my $block_count   = $self->parser->get_blockCount;
  my $structure = [];

  if ($block_count) {
    my @block_starts  = @{$self->parser->get_blockStarts};
    my @block_lengths = @{$self->parser->get_blockSizes};
    my $offset        = $start_coord - $slice_start;

    foreach(0..($self->parser->get_blockCount - 1)) {
      my $start   = shift @block_starts;
      ## Adjust to be relative to slice
      $start      = $start + $offset;
      my $length  = shift @block_lengths;
      ## Adjust coordinates here to accommodate drawing code without 
      ## altering zmenu content
      my $end     = $start + $length - 1;

      push @$structure, {'start' => $start, 'end' => $end};
    }
  }
  else {
    ## Single-block feature
    $structure = [{'start' => $feature->{'start'}, 'end' => $feature->{'end'}}];
  }
  return $structure;
}

1;
