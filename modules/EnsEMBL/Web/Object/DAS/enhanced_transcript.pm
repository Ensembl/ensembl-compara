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

package EnsEMBL::Web::Object::DAS::enhanced_transcript;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS::transcript;
our @ISA = qw(EnsEMBL::Web::Object::DAS::transcript);

sub _group_info {
  my( $self, $transcript, $gene, $db ) = @_;
  my $links = $transcript->get_all_DBLinks;
  my $exturl = $self->hub->ExtURL;
  my @link_array = ();
  foreach my $link (@$links) {
    push @link_array, { 
      'text' => $link->db_display_name.': '.$link->display_id,
      'href' => $exturl->get_url( $link->dbname, $link->primary_id )
    };
  }
  @link_array = sort { $a->{'text'} cmp $b->{'text'} } @link_array;
  return
    'NOTE' => [
      "Description: ".$gene->description,
      "Analysis: ".   $transcript->analysis->description,
    ],
    'LINK' => [ { 'text' => 'Transcript Summary '.$transcript->stable_id ,
                  'href' => sprintf( $self->{'templates'}{transview_URL}, $transcript->stable_id, $db ) },
                { 'text' => 'Gene Summary '. $gene->stable_id,
                  'href' => sprintf( $self->{'templates'}{geneview_URL},  $gene->stable_id,       $db ) },
  $transcript->translation ?
                { 'text' => 'Protein Summary '.$transcript->translation->stable_id,
                  'href' => sprintf( $self->{'templates'}{protview_URL}, $transcript->translation->stable_id, $db ) } : (),
                @link_array
    ];
}

1;
