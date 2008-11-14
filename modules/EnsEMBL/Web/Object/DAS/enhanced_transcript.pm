package EnsEMBL::Web::Object::DAS::enhanced_transcript;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS::transcript;
our @ISA = qw(EnsEMBL::Web::Object::DAS::transcript);

sub _group_info {
  my( $self, $transcript, $gene, $db ) = @_;
  my $links = $transcript->get_all_DBLinks;
  my @link_array = ();
  foreach my $link (@$links) {
    push @link_array, { 
      'text' => $link->db_display_name.': '.$link->display_id,
      'href' => $self->session->exturl()->get_url( $link->dbname, $link->primary_id )
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
