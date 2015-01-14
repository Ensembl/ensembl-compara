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

package EnsEMBL::Web::IOWrapper;

### A lightweight interpreter layer on top of the ensembl-io parsers, 
### providing the extra functionality required by the website

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Root);

sub new {
  ### Constructor
  ### Instantiates a parser for the appropriate file type 
  ### and opens the file for reading
  my ($class, $format, $path) = @_;

  my $parser;
  my $parser_formats = EnsEMBL::Web::Constants::PARSER_FORMATS;
  my $parser_class = 'Bio::EnsEMBL::IO::Parser::'.$parser_formats->{lc($args->{'format'})}{'class'};
  if (EnsEMBL::Root::dynamic_use($parser_class)) {
    $parser = $parser_class->open($path);
  }

  my $self = { parser => $parser };
  bless $self, $class;
  return $self;
}

sub create_hash {
  ### Stub - needs to be implemented in each child
  ### The purpose of this method is to convert IO-specific terms 
  ### into ones familiar to the webcode, and also munge data for
  ### the web display
}

sub coords {
  ### Simple accessor to return the coordinates from the parser
  my $self = shift;
  return ($self->parser->get_seqname, $self->parser->get_start, $self->parser->get_end);
}

sub rgb_to_hex {
  ### For the web we really need hex colours, but file formats have traditionally used RGB
  ### @param Arrayref of three RGB values
  ### @return String - same colour in hex
  my ($self, $triple_ref) = @_;
  return sprintf("%02x%02x%02x", @{$triple_ref});
}

1;
