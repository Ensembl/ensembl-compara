=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::GlyphSet::_tmp_user_data;

use strict;

use EnsEMBL::Web::File::Text;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment);

sub features {
  my $self = shift;
  my $data_source = $self->my_config( 'url' ) ;

  my $format = $self->my_config('format');
  my @data = ();
  if( $data_source eq 'tmp' ) {
    my $file = EnsEMBL::Web::File::Text->new($self->species_defs);
    my @data = split /[\r\n]+/, $file->retrieve( $self->my_config('filename') );
    foreach( @data ) {
      
    }
  }
  return [];
}

1;
