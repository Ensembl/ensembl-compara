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

package EnsEMBL::Web::IOWrapper::BigInt;

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
  
  my $class = 'EnsEMBL::Web::IOWrapper::BigInt';
  
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

sub create_hash { 
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;
  $metadata ||= {};

  my $slice_chr     = $slice->seq_region_name;
  my $slice_start   = $slice->start;
  my $slice_end     = $slice->end;

  ## Get pairwise information
  ## IMPORTANT: use column numbers, not names, because UCSC's spec allows the user 
  ## to customise the column names in the AutoSQL
  my $parser  = $self->parser;
  my $s_chr   = $parser->get_seqname(8);
  my $s_start = $parser->get_start(9);
  my $s_end   = $parser->get_end(10);
  my $t_chr   = $parser->get_seqname(13);
  my $t_start = $parser->get_start(14);
  my $t_end   = $parser->get_end(15);
  
  ## Skip this feature if the interaction crosses chromosomes
  return unless ($s_chr eq $slice_chr && $t_chr eq $slice_chr);

  ## Use full length of feature in zmenu
  my $click_start = $parser->get_start;
  my $click_end   = $parser->get_end;

  my $offset          = $slice_start - 1;
  my $feature_1_start = $s_start - $offset;
  my $feature_1_end   = $s_end - $offset;
  my $feature_2_start = $t_start - $offset;
  my $feature_2_end   = $t_end - $offset;
  return if ($feature_2_end < 0 || $feature_1_start > $slice->length);

  my $structure = [
                  {'start' => $feature_1_start, 'end' => $feature_1_end},
                  {'start' => $feature_2_start, 'end' => $feature_2_end},
                  ];

  my $href = $self->href({
                        'seq_region'  => $slice_chr,
                        'start'       => $click_start,
                        'end'         => $click_end,
                        'strand'      => 0,
                        });

  my $score = $parser->get_score;
  my $colour = $parser->get_color || 'black';
  if ($metadata->{'useScore'} || $metadata->{'spectrum'} eq 'on') {
    $colour = $self->convert_to_gradient($score, $colour);
  }

  my $direction = $s_end < $t_start ? '+' : '-';
  my $feature = {
    'seq_region'    => $slice_chr,
    'direction'     => $direction,
    'score'         => $score,
    'colour'        => $colour,
    'structure'     => $structure,
    'extra'         => [{'name' => 'Direction', 'value' => $direction}],
  };
  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $click_start;
    $feature->{'end'}   = $click_end;
  }
  else {
    $feature->{'start'} = $feature_1_start;
    $feature->{'end'}   = $feature_2_end;
    $feature->{'href'}  = $href;
  }

  return $feature;
}


1;
