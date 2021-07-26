=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::bcf;

### Module for drawing data in BCF format (either user-attached, or
### internally configured via an ini file or database record
### Extends vcf glyphset, as it is basically a sub-format of vcf

use strict;
use warnings;

use EnsEMBL::Web::IOWrapper::BCF;

use parent qw(EnsEMBL::Draw::GlyphSet::vcf);

sub get_iow {
  my ($self, $url, $args) = @_;
  return EnsEMBL::Web::IOWrapper::BCF::open($url, $args);
}

1;
