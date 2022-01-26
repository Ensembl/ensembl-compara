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

package EnsEMBL::Web::Document::Element::Meta;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    tags  => {},
    equiv => {}
  });
}

sub add      { $_[0]{'tags'}{$_[1]}  = $_[2]; }
sub addequiv { $_[0]{'equiv'}{$_[1]} = $_[2]; }

sub content {
  my $self = shift;
  my $content;
  
  $content .= sprintf qq{  <meta name="%s" content="%s" />\n},       encode_entities($_), encode_entities($self->{'tags'}{$_})  for keys %{$self->{'tags'}};
  $content .= sprintf qq{  <meta http-equiv="%s" content="%s" />\n}, encode_entities($_), encode_entities($self->{'equiv'}{$_}) for keys %{$self->{'equiv'}};
  $content .= '<meta name="viewport" content="target-densitydpi=device-dpi, width=device-width, initial-scale=1.0, maximum-scale=2.0, user-scalable=yes" />';
  
  return $content;
}

sub init {
  # There's nothing in the codebase. Delete?
}

1;
