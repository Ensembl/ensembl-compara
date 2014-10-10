=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::bam_and_bigwig;

### Module for drawing data in BAM format (either user-attached, or
### internally configured via an ini file or database record
### Note: uses Inline C for faster handling of these huge files

use strict;
use base qw(EnsEMBL::Draw::GlyphSet::bam EnsEMBL::Draw::GlyphSet::bigwig);

use EnsEMBL::Draw::GlyphSet;

1;
