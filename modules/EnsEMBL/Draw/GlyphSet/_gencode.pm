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

package EnsEMBL::Draw::GlyphSet::_gencode;

### Module for drawing the gencode track inheriting from _transcript.pm, we dont have any web data in the database for gencode. Its a workaround to create a separate track for attribute type gencode.

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Draw::GlyphSet::_transcript);

sub max_label_rows { return $_[0]->my_config('max_label_rows') || 2; }

sub only_attrib { return 'gencode_basic'; }

1;
