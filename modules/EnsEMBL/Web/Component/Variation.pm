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

package EnsEMBL::Web::Component::Variation;

use strict;

use base qw(EnsEMBL::Web::Component::Shared);

sub trim_large_allele_string {
  my $self        = shift;
  my $allele      = shift;
  my $cell_prefix = shift;
  my $length      = shift;
  
  $length ||= 50;
  return $self->trim_large_string($allele,$cell_prefix,sub {
    # how to trim an allele string...
    my $trimmed = 0;
    my @out = map {
      if(length $_ > $length) {
        $trimmed = 1;
        $_ = substr($_,0,$length)."...";
      }
      $_;
    } (split m!/!,$_[0]);
    $out[-1] .= "..." unless $trimmed;
    return join("/",@out);
  });
}

1;

