=head1 NAME Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor

=head1 SYNOPSIS

=head1 CONTACT

  Michele Clamp : michele@sanger.ac.uk

=head1 APPENDIX

=cut


package Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::SyntenyPair;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use vars '@ISA';

@ISA = ('Bio::EnsEMBL::DBSQL::BaseAdaptor');


sub store {
  my ($self,@out)  = @_;

  my $memberAdaptor = $self->db->get_MemberAdaptor();
  
  my $query = "insert into peptide_align_feature(".
                "qmember_id,qstart,qend," .
                "hmember_id,hstart,hend,".
                "score,evalue,align_length," .
                "identical_matches,perc_ident,".
                "positive_matches,perc_pos,cigar_line) ".
              " values (?,?,?,?,?,?,?,?,?,?,?,?,?,?)";
  my $sth = $self->db->prepare($query);

  foreach my $out (@out) {
    if($out->isa('Bio::EnsEMBL::BaseAlignFeature')) {
      my ($qy_member, $hit_member);

      $qy_member  = $memberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP', $out->seqname);
      $hit_member = $memberAdaptor->fetch_by_source_stable_id('ENSEMBLPEP', $out->hseqname);
    
      $sth->execute($qy_member->dbID,
                    $out->start,
                    $out->end,
                    $hit_member->dbID,
                    $out->hstart,
                    $out->hend,
                    $out->score,
                    $out->p_value,
                    $out->alignment_length,
                    $out->identical_matches,
                    int($out->identical_matches*100/$out->alignment_length),
                    $out->positive_matches,
                    int($out->positive_matches*100/$out->alignment_length),
                    $out->cigar_string
                   );
    }

  }
}

1;
