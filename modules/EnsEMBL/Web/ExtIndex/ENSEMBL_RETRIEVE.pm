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
  if(!$species){ return []; }

  my $seq;
  my $id;
  my $obj_seq = '';

  #try and retrieve translation of Ensembl object
  my $adaptor = $reg->get_adaptor($species, $dbt, $type);
  if (my $obj = $adaptor->fetch_by_stable_id($ID)) {
    if (ref($obj) eq 'Bio::EnsEMBL::Gene') {
      #get longest translation from a gene
      foreach my $trans (@{$obj->get_all_Transcripts()}) {
	if (my $trl = $trans->translation) {
	  if ( length($trl->seq) > length($obj_seq) ) {
	    $obj_seq =  $trl->seq;
	    $id = $trl->stable_id;
	  }
	}
      }
    }
    if (ref($obj) eq 'Bio::EnsEMBL::Transcript') {
      if (my $trl = $obj->translation) {
	$obj_seq  = $trl->seq;
	$id = $trl->stable_id;
      }
      else {
        $obj_seq = $obj->seq->seq;
        $id = $obj->stable_id;
      }
    }
    if (ref($obj) eq 'Bio::EnsEMBL::Translation') {
      $obj_seq = $obj->seq;
      $id = $obj->stable_id;
    }

    if (! $obj_seq) {
      #don't think this works
      my $archStableIdAdap = $reg->get_adaptor($species, $dbt, 'ArchiveStableId');
      if (my $obj = $archStableIdAdap->fetch_by_stable_id($ID,lc($type))) {
	($seq, $obj_seq) = $self->transl_of_archive_stable_id($obj);
      }
    }
    else {
      $seq = [ ">$id\n" ];
    }
  }
  else {
    #don't think this works
    my $archStableIdAdap = $reg->get_adaptor($species, $dbt, 'ArchiveStableId');
    if (my $obj = $archStableIdAdap->fetch_by_stable_id($ID,lc($type))) {
      ($seq, $obj_seq) = $self->transl_of_archive_stable_id($obj);
    }
  }

  return [] if (! $obj_seq);

  #generate arrayref of header and sequence ready for using by WISE2/Matcher
  my $pos = 0;
  while ( $pos < length($obj_seq) ) {
    my $substr = substr($obj_seq,$pos,60);
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
