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

package EnsEMBL::Draw::GlyphSet::bam;

### Module for drawing data in BAM or CRAM format. Most of the
### functionality is in the Role package so that it can easily
### be shared with the bamcov format

use strict;

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Bam';
with 'EnsEMBL::Draw::Role::Default';

use parent qw(EnsEMBL::Draw::GlyphSet::Generic);

sub init {}

1;
