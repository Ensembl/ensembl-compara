package EnsEMBL::Web::ExtIndex::ENSEMBL_RETRIEVE;

use strict;
use Data::Dumper;
sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }

sub get_seq_by_id {
  my ($self, $arghashref)=@_;
  my $reg = "Bio::EnsEMBL::Registry";
  my $ID = $arghashref->{'ID'};

  #get species name etc from stable ID
  my ($species, $type, $dbt) = $reg->get_species_and_object_type($ID);

  my $seq;
  my $pep_seq = '';

  #try and retrieve translation of Ensembl object
  my $adaptor = $reg->get_adaptor($species, $dbt, $type);
  if (my $obj = $adaptor->fetch_by_stable_id($ID)) {
    if (ref($obj) eq 'Bio::EnsEMBL::Gene') {
      #get longest translation from a gene
      foreach my $trans (@{$obj->get_all_Transcripts()}) {
	if (my $trl = $trans->translation) {
	  if ( length($trl->seq) > length($pep_seq) ) {
	    $pep_seq =  $trl->seq;
	    my $id = $trl->stable_id;
	    $seq = [ ">$id\n" ];
	  }
	}
      }
    }
    if (ref($obj) eq 'Bio::EnsEMBL::Transcript') {
      if (my $trl = $obj->translation) {
	$pep_seq  = $trl->seq;
	my $id = $trl->stable_id;
	$seq = [ ">$id\n" ];
      }
    }
    if (ref($obj) eq 'Bio::EnsEMBL::Translation') {
      $pep_seq = $obj->seq;
      my $id = $obj->stable_id;
      $seq = [ ">$id\n" ];
    }

    if (! $pep_seq) {
      my $archStableIdAdap = $reg->get_adaptor($species, $dbt, 'ArchiveStableId');
      if (my $obj = $archStableIdAdap->fetch_by_stable_id($ID,lc($type))) {
	($seq, $pep_seq) = $self->transl_of_archive_stable_id($obj);
      }
    }
  }
  else {
    my $archStableIdAdap = $reg->get_adaptor($species, $dbt, 'ArchiveStableId');
    if (my $obj = $archStableIdAdap->fetch_by_stable_id($ID,lc($type))) {
      ($seq, $pep_seq) = $self->transl_of_archive_stable_id($obj);
    }
  }

  return [] if (! $pep_seq);

  #generate arrayref of header and amino acid sequence ready for using by WISE2
  my $pos = 0;
  while ( $pos < length($pep_seq) ) {
    my $substr = substr($pep_seq,$pos,60);
    $substr .= "\n";
    push @{$seq}, $substr;
    $pos += 60;
  }
  return $seq ;
}

sub transl_of_archive_stable_id {
  my ($self, $obj, $adap) = @_;
  return ();
  #enable the following when we know how to do it correctly
  my $translations = $obj->get_all_translation_archive_ids();
  my @sorted_translations = sort { $a->release <=> $b->release || length($a->get_peptide) <=> length($a->get_peptide) } @$translations;
  my $pep_seq = $sorted_translations[0]->get_peptide();
  my $id      = $sorted_translations[0]->stable_id();
#  warn "id of longest latest translation is $id";
  return ( [ ">$id\n" ], $pep_seq );

}


1;
