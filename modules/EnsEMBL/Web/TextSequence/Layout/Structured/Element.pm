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

package EnsEMBL::Web::TextSequence::Layout::Structured::Element;

use strict;
use warnings;

sub new {
  my ($proto,$string,$format) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    string => $string,
    format => $format,
  };
  bless $self,$class;
  return $self;
}

sub format { $_[0]->{'format'} = $_ if @_>1; return $_[0]->{'format'}; }
sub string { $_[0]->{'string'} = $_ if @_>1; return $_[0]->{'string'}; }

sub append { $_[0]->{'string'} .= $_[1] }

sub size {
  my ($self) = @_;

  return 0 if ref($self->{'string'});
  return length $self->{'string'};
}

1;
