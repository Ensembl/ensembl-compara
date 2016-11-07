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

package EnsEMBL::Draw::GlyphSet::fg_crispr;

use strict;

use URI::Escape qw(uri_escape);

use parent qw(EnsEMBL::Draw::GlyphSet::fg_bigbed);

sub supports_subtitles { 0; }

sub get_filename {
  my $self  = shift;
  my $slice = $self->{'container'};

  my $fgh     = $slice->adaptor->db->get_db_adaptor('funcgen');
  my $csa     = $fgh->get_CrisprSitesFileAdaptor;
  my $crispr  = $csa->fetch_file;
  return $crispr->file;
}

sub extra_metadata {
  my ($self, $metadata) = @_;
  (my $caption = $self->my_config('data_id')) =~ s/_/ /g;
  $metadata->{'zmenu_caption'} = $caption;
}

1;
