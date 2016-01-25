=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### Module for drawing data in BAM format (either user-attached, or
### internally configured via an ini file or database record
### Note: uses Inline C for faster handling of these huge files

### Note also that because of the file size, we do not use standard
### ensembl-io parsers with an IOWrapper module, but instead use an 
### adaptor and then munge the data here in the glyphset

use strict;

### Module for drawing data in BAM or CRAM format. Most of the
### functionality is in the Role package so that it can easily
### be shared with the bamcov format

use Role::Tiny;

use parent qw(EnsEMBL::Draw::GlyphSet);

sub can_json { return 1; }

sub init {
  my $self = shift;
  my @roles = ('EnsEMBL::Draw::Role::Bam');
  Role::Tiny->apply_roles_to_object($self, @roles);
}

1;
