=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::ClassToStyle::CSS;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::ClassToStyle);

sub convert_class_to_style {
  my ($self,$current_class,$config) = @_;

  return undef unless @$current_class;
  my %class_to_style = %{$self->make_class_to_style_map($config)};
  my %style_hash;
  foreach (sort { $class_to_style{$a}[0] <=> $class_to_style{$b}[0] } @$current_class) {
    my $st = $class_to_style{$_}[1];
    map $style_hash{$_} = $st->{$_}, keys %$st;
  }
  return join ';', map "$_:$style_hash{$_}", keys %style_hash;
}

1;
