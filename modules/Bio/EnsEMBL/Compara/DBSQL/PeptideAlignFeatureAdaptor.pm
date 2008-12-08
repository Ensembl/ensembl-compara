=head1 NAME

  Bio::EnsEMBL::Hive::DBSQL::PeptideAlignFeatureAdaptor

=head1 SYNOPSIS

  $peptideAlignFeatureAdaptor = $db_adaptor->get_PeptideAlignFeatureAdaptor;
  $peptideAlignFeatureAdaptor = $peptideAlignFeatureObj->adaptor;

=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class PeptideAlignFeature
  There should be just one per application and database connection.

=head1 CONTACT

  Contact Jessica Severin on implementation/design detail: jessica@ebi.ac.uk
  Contact Albert Vilella on implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


package Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
#use Bio::EnsEMBL::Compara::SyntenyPair;
use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;
use Bio::EnsEMBL::Utils::Exception;

use vars '@ISA';

@ISA = ('Bio::EnsEMBL::DBSQL::BaseAdaptor');

#############################
#
# fetch methods
#
#############################


=head2 fetch_all_by_qmember_id

  Arg [1]    : int $member->dbID
               the database id for a peptide member
  Example    : $pafs = $adaptor->fetch_all_by_qmember_id($member->dbID);
  Description: Returns all PeptideAlignFeatures from all target species
               where the query peptide member is know.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_by_qmember_id{
  my $self = shift;
  my $member_id = shift;

  throw("member_id undefined") unless($member_id);

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($member_id);

  my $gdb = $member->genome_db;
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.qmember_id = $member_id";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_qmember_id{
#   my $self = shift;
#   my $member_id = shift;

#   throw("member_id undefined") unless($member_id);
#   my $constraint = "paf.qmember_id = $member_id";
#   return $self->_generic_fetch($constraint);
# }


=head2 fetch_all_by_hmember_id

  Arg [1]    : int $member->dbID
               the database id for a peptide member
  Example    : $pafs = $adaptor->fetch_all_by_hmember_id($member->dbID);
  Description: Returns all PeptideAlignFeatures from all query species
               where the hit peptide member is know.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_by_hmember_id{
  my $self = shift;
  my $member_id = shift;

  throw("member_id undefined") unless($member_id);

  my $sql = 'SHOW TABLES LIKE "peptide_align_feature_%"';
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my @tbl_names;
  while ( my $tbl_name  = $sth->fetchrow ) {
    push @tbl_names, $tbl_name;
  }
  $sth->finish;

  my $paf;
  foreach my $tbl_name (@tbl_names) {
    my $columns = join(', ', $self->_columns());

    my $sql = "SELECT $columns FROM $tbl_name paf WHERE paf.hmember_id=$member_id";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $paf = $self->_objs_from_sth($sth);
    if (defined($paf) && (0 != scalar @$paf)) {
      foreach my $this_paf (@$paf) {
        push @pafs, $this_paf;
      }
    }
  }
  $sth->finish;
  return \@pafs;
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_hmember_id{
#   my $self = shift;
#   my $member_id = shift;

#   throw("member_id undefined") unless($member_id);
#   my $constraint = "paf.hmember_id = $member_id";
#   return $self->_generic_fetch($constraint);
# }


=head2 fetch_all_by_qmember_id_hmember_id

  Arg [1]    : int $query_member->dbID
               the database id for a peptide member
  Arg [2]    : int $hit_member->dbID
               the database id for a peptide member
  Example    : $pafs = $adaptor->fetch_all_by_qmember_id_hmember_id($qmember_id, $hmember_id);
  Description: Returns all PeptideAlignFeatures for a given query member and
               hit member.  If pair did not align, array will be empty.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if either member_id is not defined
  Caller     : general

=cut

sub fetch_all_by_qmember_id_hmember_id{
  my $self = shift;
  my $qmember_id = shift;
  my $hmember_id = shift;

  throw("must specify query member dbID") unless($qmember_id);
  throw("must specify hit member dbID") unless($hmember_id);

  my $qmember = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $qmember->genome_db;
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.qmember_id = $qmember_id AND paf.hmember_id = $hmember_id";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_qmember_id_hmember_id{
#   my $self = shift;
#   my $qmember_id = shift;
#   my $hmember_id = shift;

#   throw("must specify query member dbID") unless($qmember_id);
#   throw("must specify hit member dbID") unless($hmember_id);
#   my $constraint = "paf.qmember_id=$qmember_id AND paf.hmember_id=$hmember_id";
#   return $self->_generic_fetch($constraint);
# }


=head2 fetch_all_by_qmember_id_hgenome_db_id

  Arg [1]    : int $query_member->dbID
               the database id for a peptide member
  Arg [2]    : int $hit_genome_db->dbID
               the database id for a genome_db
  Example    : $pafs = $adaptor->fetch_all_by_qmember_id_hgenome_db_id(
                    $member->dbID, $genome_db->dbID);
  Description: Returns all PeptideAlignFeatures for a given query member and
               target hit species specified via a genome_db_id
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if either member->dbID or genome_db->dbID is not defined
  Caller     : general

=cut

sub fetch_all_by_qmember_id_hgenome_db_id{
  my $self = shift;
  my $qmember_id = shift;
  my $hgenome_db_id = shift;

  throw("must specify query member dbID") unless($qmember_id);
  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  my $qmember = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $qmember->genome_db;
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.qmember_id = $qmember_id AND paf.hgenome_db_id = $hgenome_db_id";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_qmember_id_hgenome_db_id{
#   my $self = shift;
#   my $qmember_id = shift;
#   my $hgenome_db_id = shift;

#   throw("must specify query member dbID") unless($qmember_id);
#   throw("must specify hit genome_db dbID") unless($hgenome_db_id);
#   my $constraint = "paf.qmember_id=$qmember_id AND paf.hgenome_db_id=$hgenome_db_id";
#   return $self->_generic_fetch($constraint);
# }


=head2 fetch_all_by_hmember_id_qgenome_db_id

  Arg [1]    : int $hit_member->dbID
               the database id for a peptide member
  Arg [2]    : int $query_genome_db->dbID
               the database id for a genome_db
  Example    : $pafs = $adaptor->fetch_all_by_hmember_id_qgenome_db_id(
                    $member->dbID, $genome_db->dbID);
  Description: Returns all PeptideAlignFeatures for a given hit member and
               query species specified via a genome_db_id
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if either member->dbID or genome_db->dbID is not defined
  Caller     : general

=cut

sub fetch_all_by_hmember_id_qgenome_db_id{
   my $self = shift;
   my $hmember_id = shift;
   my $qgenome_db_id = shift;

   throw("must specify hit member dbID") unless($hmember_id);
   throw("must specify query genome_db dbID") unless($qgenome_db_id);

   my $species_name = lc($self->db->get_GenomeDBAdaptor->fetch_by_dbID($qgenome_db_id)->name);
   $species_name =~ s/\ /\_/g;
   my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$qgenome_db_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.hmember_id = $hmember_id";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_hmember_id_qgenome_db_id{
#   my $self = shift;
#   my $hmember_id = shift;
#   my $qgenome_db_id = shift;

#   throw("must specify hit member dbID") unless($hmember_id);
#   throw("must specify query genome_db dbID") unless($qgenome_db_id);
#   my $constraint = "paf.hmember_id=$hmember_id AND paf.qgenome_db_id=$qgenome_db_id";
#   return $self->_generic_fetch($constraint);
# }


sub fetch_all_by_hgenome_db_id{
  my $self = shift;
  my $hgenome_db_id = shift;

  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  my $sql = 'SHOW TABLES LIKE "peptide_align_feature_%"';
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my @tbl_names;
  while ( my $tbl_name  = $sth->fetchrow ) {
    push @tbl_names, $tbl_name;
  }
  $sth->finish;

  my $paf;
  foreach my $tbl_name (@tbl_names) {
    my $columns = join(', ', $self->_columns());

    my $sql = "SELECT $columns FROM $tbl_name paf WHERE paf.hgenome_db_id=$hgenome_db_id";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $paf = $self->_objs_from_sth($sth);
    if (defined($paf) && (0 != scalar @$paf)) {
      foreach my $this_paf (@$paf) {
        push @pafs, $this_paf;
      }
    }
  }
  $sth->finish;
  return \@pafs;
}

# Previous all-in-one-table paf
# sub old_fetch_all_by_hgenome_db_id{
#   my $self = shift;
#   my $hgenome_db_id = shift;

#   throw("must specify hit genome_db dbID") unless($hgenome_db_id);
#   my $constraint = "paf.hgenome_db_id=$hgenome_db_id";
#   return $self->_generic_fetch($constraint);
# }


sub fetch_all_by_qgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);

  my $gdb = $$self->db->get_GenomeDBAdaptor->fetch_by_dbID($qgenome_db_id);
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  # my $constraint = "paf.qmember_id = $member_id";
  my $sql = "SELECT $columns FROM $tbl_name paf";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}

sub fetch_all_by_qgenome_db_id_hgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;
  my $hgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);
  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  my $gdb = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($qgenome_db_id);
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.hgenome_db_id = $hgenome_db_id";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}


sub fetch_all_besthit_by_qgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);

  my $gdb = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($qgenome_db_id);
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.hit_rank=1";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}


sub fetch_all_besthit_by_qgenome_db_id_hgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;
  my $hgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);
  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  my $gdb = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($qgenome_db_id);
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $constraint = "paf.hgenome_db_id = $hgenome_db_id AND paf.hit_rank=1";
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE $constraint";
  my $sth = $self->prepare($sql);
  $sth->execute;

  return $self->_objs_from_sth($sth);
}


=head2 fetch_selfhit_by_qmember_id

  Arg [1]    : int $member->dbID
               the database id for a peptide member
  Example    : $paf = $adaptor->fetch_selfhit_by_qmember_id($member->dbID);
  Description: Returns the selfhit PeptideAlignFeature defined by the id $id.
  Returntype : Bio::EnsEMBL::Compara::PeptideAlignFeature
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut


sub fetch_selfhit_by_qmember_id {
  my $self= shift;
  my $qmember_id = shift;

  throw("qmember_id undefined") unless($qmember_id);

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $member->genome_db;
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());
  my $sql = "SELECT $columns FROM $tbl_name paf WHERE qmember_id=$qmember_id AND qmember_id=hmember_id";
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  $paf = $self->_objs_from_sth($sth)->[0];
  $sth->finish;

  return $paf;
}


=head2 final_clause

  Arg [1]    : <string> SQL clause
  Example    : $adaptor->final_clause("ORDER BY paf.qmember_id LIMIT 10");
               $pafs = $adaptor->fetch_all;
               $adaptor->final_clause("");
  Description: getter/setter method for specifying an extension to the SQL prior to
               a fetch operation.  Useful final clauses are either 'ORDER BY' or 'LIMIT'
  Returntype : <string>
  Caller     : general

=cut

sub final_clause {
  my $self = shift;
  $self->{'_final_clause'} = shift if(@_);
  return $self->{'_final_clause'};
}


#############################
#
# store methods
#
#############################

sub store {
  my ($self, @features)  = @_;

  my @pafList = ();

  foreach my $feature (@features) {
    if($feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
      #displayHSP_short($feature);
      my $pepFeature = $self->_create_PAF_from_BaseAlignFeature($feature);
      #$pepFeature->display_short();
      push @pafList, $pepFeature;
    }
    elsif($feature->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {
      push @pafList, $feature;
    }
  }

  @pafList = sort sort_by_score_evalue_and_pid @pafList;
  my $rank=1;
  my $prevPaf = undef;
  foreach my $paf (@pafList) {
    $rank++ if($prevPaf and !pafs_equal($prevPaf, $paf));
    $paf->hit_rank($rank);
    $prevPaf = $paf;
  }

  $self->_store_PAFS(@pafList);
}


sub _store_PAFS {
  my ($self, @out)  = @_;

  return unless(@out and scalar(@out));

  # Query genome db id should always be the same
  my $first_qgenome_db_id = $out[0]->query_genome_db_id;

  my $gdb = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($first_qgenome_db_id);
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$first_qgenome_db_id";

  my $query = "INSERT INTO $tbl_name(".
                "qmember_id,hmember_id,qgenome_db_id,hgenome_db_id,analysis_id," .
                "qstart,qend,hstart,hend,".
                "score,evalue,align_length," .
                "identical_matches,perc_ident,".
                "positive_matches,perc_pos,hit_rank,cigar_line) VALUES ";

  my $addComma=0;
  foreach my $paf (@out) {
    if($paf->isa('Bio::EnsEMBL::Compara::PeptideAlignFeature')) {

      my $analysis_id = 0;
      if($paf->analysis()) {
        #print("paf has analysis '".$paf->analysis->logic_name()."' dbID=".$paf->analysis->dbID."\n");
        $analysis_id=$paf->analysis()->dbID();
      }

      # print STDERR "== ", $paf->query_member_id, " - ", $paf->hit_member_id, "\n";
      my $qgenome_db_id = $paf->query_genome_db_id;
      $qgenome_db_id = 0 unless($qgenome_db_id);
      my $hgenome_db_id = $paf->hit_genome_db_id;
      $hgenome_db_id = 0 unless($hgenome_db_id);

      # Null_cigar option for leaner paf tables
      $paf->cigar_line('') if (defined $paf->{null_cigar});

      $query .= ", " if($addComma);
      $query .= "(".$paf->query_member_id.
                ",".$paf->hit_member_id.
                ",".$qgenome_db_id.
                ",".$hgenome_db_id.
                ",".$analysis_id.
                ",".$paf->qstart.
                ",".$paf->qend.
                ",".$paf->hstart.
                ",".$paf->hend.
                ",".$paf->score.
                ",".$paf->evalue.
                ",".$paf->alignment_length.
                ",".$paf->identical_matches.
                ",".$paf->perc_ident.
                ",".$paf->positive_matches.
                ",".$paf->perc_pos.
                ",".$paf->hit_rank.
                ",'".$paf->cigar_line."')";
      $addComma=1;
      # $paf->display_short();
    }
  }
  #print("$query\n");
  my $sth = $self->prepare($query);
  $sth->execute();
  $sth->finish();
}


sub _create_PAF_from_BaseAlignFeature {
  my($self, $feature) = @_;

  unless(defined($feature) and $feature->isa('Bio::EnsEMBL::BaseAlignFeature')) {
    throw("arg must be a [Bio::EnsEMBL::BaseAlignFeature] not a [$feature]");
  }

  my $paf = new Bio::EnsEMBL::Compara::PeptideAlignFeature;

  my $memberDBA = $self->db->get_MemberAdaptor();

  if ($feature->seqname =~ /IDs\:(\d+)\:(\d+)/) {
    $paf->query_genome_db_id($1);
    $paf->query_member_id($2);
  } elsif($feature->seqname =~ /member_id_(\d+)/) {
    #printf("qseq: member_id = %d\n", $1);
    $paf->query_member($memberDBA->fetch_by_dbID($1));
  } else {
    my ($source_name, $stable_id) = split(/:/, $feature->seqname);
    #printf("qseq: %s %s\n", $source_name, $stable_id);
    $paf->query_member($memberDBA->fetch_by_source_stable_id($source_name, $stable_id));
  }

  if ($feature->hseqname =~ /IDs\:(\d+)\:(\d+)/) {
    $paf->hit_genome_db_id($1);
    $paf->hit_member_id($2);
  } elsif ($feature->hseqname =~ /member_id_(\d+)/) {
    #printf("hseq: member_id = %d\n", $1);
    $paf->hit_member($memberDBA->fetch_by_dbID($1));
  } else {
    my ($source_name, $stable_id) = split(/:/, $feature->hseqname);
    #printf("hseq: %s %s\n", $source_name, $stable_id);
    my $hit_member = $memberDBA->fetch_by_source_stable_id($source_name, $stable_id);
    if (defined($hit_member)) {
      $paf->hit_member($hit_member);
    } else {
      die "couldnt find $stable_id\n";
    }
  }

  $paf->analysis($feature->analysis);

  $paf->qstart($feature->start);
  $paf->hstart($feature->hstart);
  $paf->qend($feature->end);
  $paf->hend($feature->hend);
  #$paf->qlength($qlength);
  #$paf->hlength($hlength);
  $paf->score($feature->score);
  $paf->evalue($feature->p_value);

  $paf->cigar_line($feature->cigar_string);
  $paf->{null_cigar} = 1 if (defined $feature->{null_cigar});

  $paf->alignment_length($feature->alignment_length);
  $paf->identical_matches($feature->identical_matches);
  $paf->positive_matches($feature->positive_matches);

  $paf->perc_ident(int($feature->identical_matches*100/$feature->alignment_length));
  $paf->perc_pos(int($feature->positive_matches*100/$feature->alignment_length));
  return $paf;
}


sub sort_by_score_evalue_and_pid {
  $b->score <=> $a->score ||
    $a->evalue <=> $b->evalue ||
      $b->perc_ident <=> $a->perc_ident ||
        $b->perc_pos <=> $a->perc_pos;
}


sub pafs_equal {
  my ($paf1, $paf2) = @_;
  return 0 unless($paf1 and $paf2);
  return 1 if(($paf1->score == $paf2->score) and
              ($paf1->evalue == $paf2->evalue) and
              ($paf1->perc_ident == $paf2->perc_ident) and
              ($paf1->perc_pos == $paf2->perc_pos));
  return 0;
}


sub displayHSP {
  my($paf) = @_;

  my $percent_ident = int($paf->identical_matches*100/$paf->alignment_length);
  my $pos = int($paf->positive_matches*100/$paf->alignment_length);

  print("=> $paf\n");
  print("pep_align_feature :\n" .
    " seqname           : " . $paf->seqname . "\n" .
    " start             : " . $paf->start . "\n" .
    " end               : " . $paf->end . "\n" .
    " hseqname          : " . $paf->hseqname . "\n" .
    " hstart            : " . $paf->hstart . "\n" .
    " hend              : " . $paf->hend . "\n" .
    " score             : " . $paf->score . "\n" .
    " p_value           : " . $paf->p_value . "\n" .
    " alignment_length  : " . $paf->alignment_length . "\n" .
    " identical_matches : " . $paf->identical_matches . "\n" .
    " perc_ident        : " . $percent_ident . "\n" .
    " positive_matches  : " . $paf->positive_matches . "\n" .
    " perc_pos          : " . $pos . "\n" .
    " cigar_line        : " . $paf->cigar_string . "\n");
}

sub displayHSP_short {
  my($paf) = @_;

  unless(defined($paf)) {
    print("qy_stable_id\t\t\thit_stable_id\t\t\tscore\talen\t\%ident\t\%positive\n");
    return;
  }
  
  my $perc_ident = int($paf->identical_matches*100/$paf->alignment_length);
  my $perc_pos = int($paf->positive_matches*100/$paf->alignment_length);

  print("HSP ".$paf->seqname."(".$paf->start.",".$paf->end.")".
        "\t" . $paf->hseqname. "(".$paf->hstart.",".$paf->hend.")".
        "\t" . $paf->score .
        "\t" . $paf->alignment_length .
        "\t" . $perc_ident . 
        "\t" . $perc_pos . "\n");
}



############################
#
# INTERNAL METHODS
# (pseudo subclass methods)
#
############################

#internal method used in multiple calls above to build objects from table data

sub _tables {
  my $self = shift;

  return (['peptide_align_feature', 'paf'] );
}

sub _columns {
  my $self = shift;

  return qw (paf.peptide_align_feature_id
             paf.qmember_id
             paf.hmember_id
             paf.analysis_id
             paf.qstart
             paf.qend
             paf.hstart
             paf.hend
             paf.score
             paf.evalue
             paf.align_length
             paf.identical_matches
             paf.perc_ident
             paf.positive_matches
             paf.perc_pos
             paf.hit_rank
             paf.cigar_line
            );
}

sub _default_where_clause {
  my $self = shift;
  return '';
}


sub _objs_from_sth {
  my ($self, $sth) = @_;

  my %column;
  $sth->bind_columns( \( @column{ @{$sth->{NAME_lc} } } ));

  my @pafs = ();

  while ($sth->fetch()) {
    my $paf;

    $paf = Bio::EnsEMBL::Compara::PeptideAlignFeature->new();

    $paf->dbID($column{'peptide_align_feature_id'});
    $paf->qstart($column{'qstart'});
    $paf->qend($column{'qend'});
    $paf->hstart($column{'hstart'});
    $paf->hend($column{'hend'});
    $paf->score($column{'score'});
    $paf->evalue($column{'evalue'});
    $paf->alignment_length($column{'align_length'});
    $paf->identical_matches($column{'identical_matches'});
    $paf->perc_ident($column{'perc_ident'});
    $paf->positive_matches($column{'positive_matches'});
    $paf->perc_pos($column{'perc_pos'});
    $paf->hit_rank($column{'hit_rank'});
    $paf->cigar_line($column{'cigar_line'});
    $paf->rhit_dbID($column{'pafid2'});

    if($column{'analysis_id'} and $self->db->get_AnalysisAdaptor) {
      $paf->analysis($self->db->get_AnalysisAdaptor->fetch_by_dbID($column{'analysis_id'}));
    }

    my $memberDBA = $self->db->get_MemberAdaptor;
    if($column{'qmember_id'} and $memberDBA) {
      $paf->query_member($memberDBA->fetch_by_dbID($column{'qmember_id'}));
    }
    if($column{'hmember_id'} and $memberDBA) {
      $paf->hit_member($memberDBA->fetch_by_dbID($column{'hmember_id'}));
    }
  
    #$paf->display_short();
    
    push @pafs, $paf;

  }
  $sth->finish;

  return \@pafs;
}



###############################################################################
#
# General access methods that could be moved
# into a superclass
#
###############################################################################


#sub fetch_by_dbID_qgenome_db_id {


=head2 fetch_by_dbID

  Arg [1]    : int $id
               the unique database identifier for the feature to be obtained
  Example    : $paf = $adaptor->fetch_by_dbID(1234);
  Description: Returns the PeptideAlignFeature created from the database defined by the
               the id $id.
  Returntype : Bio::EnsEMBL::Compara::PeptideAlignFeature
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbID{
  my ($self,$id) = @_;

  unless(defined $id) {
    $self->throw("fetch_by_dbID must have an id");
  }

  my $sql = 'SHOW TABLES LIKE "peptide_align_feature_%"';
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my @tbl_names;
  while ( my $tbl_name  = $sth->fetchrow ) {
    push @tbl_names, $tbl_name;
  }
  $sth->finish;

  my $paf;
  foreach my $tbl_name (@tbl_names) {
    my $columns = join(', ', $self->_columns());

    my $sql = "SELECT $columns FROM $tbl_name paf WHERE peptide_align_feature_id=$id";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $paf = $self->_objs_from_sth($sth)->[0];
    if (defined($paf)) {
      # Found it in one of the tables, no need to go any further
      # assuming UpdatePAFIds has done its job properly
      $sth->finish;
      return $paf;
    }
  }
  $sth->finish;
  return undef;
}

# Previous all-in-one-table paf
# sub old_fetch_by_dbID{
#   my ($self,$id) = @_;

#   unless(defined $id) {
#     $self->throw("fetch_by_dbID must have an id");
#   }

#   my @tabs = $self->_tables;

#   my ($name, $syn) = @{$tabs[0]};

#   #construct a constraint like 't1.table1_id = 1'
#   my $constraint = "${syn}.${name}_id = $id";

#   #return first element of _generic_fetch list
#   my ($obj) = @{$self->_generic_fetch($constraint)};
#   return $obj;
# }

=head2 fetch_by_dbIDs

  Arg [1...] : int $id (multiple)
               the unique database identifier for the feature to be obtained
  Example    : $pafs = $adaptor->fetch_by_dbID(paf1_id, $paf2_id, $paf3_id);
  Description: Returns the PeptideAlignFeature created from the database defined by the
               the id $id.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_by_dbIDs{
  my $self = shift;
  my @ids = @_;

  return undef unless(scalar(@ids));

  my $id_string = join(",", @ids);

  my $sql = 'SHOW TABLES LIKE "peptide_align_feature_%"';
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my @tbl_names;
  while ( my $tbl_name  = $sth->fetchrow ) {
    push @tbl_names, $tbl_name;
  }
  $sth->finish;

  my @pafs;
  my $paf;
  foreach my $tbl_name (@tbl_names) {
    my $columns = join(', ', $self->_columns());

    my $sql = "SELECT $columns FROM $tbl_name paf WHERE peptide_align_feature_id in ($id_string)";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute;
    $paf = $self->_objs_from_sth($sth);
    if (defined($paf) && (0 != scalar @$paf)) {
      foreach my $this_paf (@$paf) {
        push @pafs, $this_paf;
      }
    }
  }
  $sth->finish;
  return \@pafs;
}

# Previous all-in-one-table paf
# sub old_fetch_by_dbIDs{
#   my $self = shift;
#   my @ids = @_;

#   return undef unless(scalar(@ids));

#   my $id_string = join(",", @ids);
#   my $constraint = "paf.peptide_align_feature_id in ($id_string)";
#   #printf("fetch_by_dbIDs has contraint\n$constraint\n");

#   #return first element of _generic_fetch list
#   return $self->_generic_fetch($constraint);
# }


=head2 fetch_BRH_by_member_genomedb

  Arg [1]    : member_id of query peptide member
  Arg [2]    : genome_db_id of hit species
  Example    : $paf = $adaptor->fetch_BRH_by_member_genomedb(31957, 3);
  Description: Returns the PeptideAlignFeature created from the database
               This is the old algorithm for pulling BRHs (compara release 20-23)
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : none
  Caller     : general

=cut


sub fetch_BRH_by_member_genomedb
{
  # using trick of specifying table twice so can join to self
  my $self             = shift;
  my $qmember_id       = shift;
  my $hit_genome_db_id = shift;

  #print(STDERR "fetch_all_RH_by_member_genomedb qmember_id=$qmember_id, genome_db_id=$hit_genome_db_id\n");
  return unless($qmember_id and $hit_genome_db_id);

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $member->genome_db;
  my $species_name1 = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name1 =~ s/\ /\_/g;
  my $tbl_name1 = "peptide_align_feature"."_"."$species_name1"."_"."$gdb_id";

  my $species_name2 = lc($self->db->get_GenomeDBAdaptor->fetch_by_dbID($hit_genome_db_id)->name);
  $species_name2 =~ s/\ /\_/g;
  my $tbl_name2 = "peptide_align_feature"."_"."$species_name2"."_"."$hit_genome_db_id";

  my $columns = join(', ', $self->_columns());

  my $sql = "SELECT $columns, paf2.peptide_align_feature_id AS pafid2".
            " FROM $tbl_name1 paf, $tbl_name2 paf2".
            " WHERE paf.hmember_id=paf2.qmember_id".
            " AND paf.hit_rank=1 AND paf2.hit_rank=1".
            " AND paf.qmember_id=$qmember_id and paf.hgenome_db_id=$hit_genome_db_id".
            " AND paf2.hmember_id=$qmember_id and paf2.qgenome_db_id=$hit_genome_db_id";

  my $sth = $self->dbc->prepare($sql);
  $sth->execute;
  my $obj = $self->_objs_from_sth($sth)->[0];
  $sth->finish;

  return $obj;
}


# Previous all-in-one-table paf
# sub old_fetch_BRH_by_member_genomedb
# {
#   # using trick of specifying table twice so can join to self
#   my $self             = shift;
#   my $qmember_id       = shift;
#   my $hit_genome_db_id = shift;

#   #print(STDERR "fetch_BRH_by_member_genomedb qmember_id=$qmember_id, genome_db_id=$hit_genome_db_id\n");
#   return unless($qmember_id and $hit_genome_db_id);
#   my $extrajoin = [
#                     [ ['peptide_align_feature', 'paf2'],
#                       'paf.qmember_id=paf2.hmember_id AND paf.hmember_id=paf2.qmember_id',
#                       ['paf2.peptide_align_feature_id AS pafid2']]
#                   ];

#   my $constraint = "paf.hit_rank=1 AND paf2.hit_rank=1".
#                    " AND paf.qmember_id='".$qmember_id."'".
#                    " AND paf2.hmember_id='".$qmember_id."'".
#                    " AND paf.hgenome_db_id='".$hit_genome_db_id."'".
#                    " AND paf2.qgenome_db_id='".$hit_genome_db_id."'";

#   return $self->_generic_fetch($constraint, $extrajoin);
# }


=head2 fetch_all_RH_by_member_genomedb

  Overview   : This an experimental method and not currently used in production
  Arg [1]    : member_id of query peptide member
  Arg [2]    : genome_db_id of hit species
  Example    : $feat = $adaptor->fetch_by_dbID($musBlastAnal, $ratBlastAnal);
  Description: Returns all the PeptideAlignFeatures that reciprocal hit the qmember_id
               onto the hit_genome_db_id
  Returntype : array of Bio::EnsEMBL::Compara::PeptideAlignFeature objects by reference
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_RH_by_member_genomedb
{
  # using trick of specifying table twice so can join to self
  my $self             = shift;
  my $qmember_id       = shift;
  my $hit_genome_db_id = shift;

  #print(STDERR "fetch_all_RH_by_member_genomedb qmember_id=$qmember_id, genome_db_id=$hit_genome_db_id\n");
  return unless($qmember_id and $hit_genome_db_id);

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $member->genome_db;
  my $species_name1 = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name1 =~ s/\ /\_/g;
  my $tbl_name1 = "peptide_align_feature"."_"."$species_name1"."_"."$gdb_id";

  my $species_name2 = lc($self->db->get_GenomeDBAdaptor->fetch_by_dbID($hit_genome_db_id)->name);
  $species_name2 =~ s/\ /\_/g;
  my $tbl_name2 = "peptide_align_feature"."_"."$species_name2"."_"."$hit_genome_db_id";

  my $columns = join(', ', $self->_columns());

  my $sql = "SELECT $columns, paf2.peptide_align_feature_id AS pafid2".
            " FROM $tbl_name1 paf, $tbl_name2 paf2".
            " WHERE paf.hmember_id=paf2.qmember_id".
            " AND paf.qmember_id=$qmember_id and paf.hgenome_db_id=$hit_genome_db_id".
            " AND paf2.hmember_id=$qmember_id and paf2.qgenome_db_id=$hit_genome_db_id";

  my $sth = $self->dbc->prepare($sql);
  $sth->execute;
  my $objs = $self->_objs_from_sth($sth);
  $sth->finish;

  return $objs;
}

# Previous all-in-one-table paf
# sub old_fetch_all_RH_by_member_genomedb
# {
#   # using trick of specifying table twice so can join to self
#   my $self             = shift;
#   my $qmember_id       = shift;
#   my $hit_genome_db_id = shift;

#   #print(STDERR "fetch_all_RH_by_member_genomedb qmember_id=$qmember_id, genome_db_id=$hit_genome_db_id\n");
#   return unless($qmember_id and $hit_genome_db_id);
#   my $extrajoin = [
#                     [ ['peptide_align_feature', 'paf2'],
#                       'paf.qmember_id=paf2.hmember_id AND paf.hmember_id=paf2.qmember_id',
#                       ['paf2.peptide_align_feature_id AS pafid2']]
#                   ];

#   my $constraint = " paf.qmember_id='".$qmember_id."'".
#                    " AND paf2.hmember_id='".$qmember_id."'".
#                    " AND paf.hgenome_db_id='".$hit_genome_db_id."'".
#                    " AND paf2.qgenome_db_id='".$hit_genome_db_id."'";

#   #$self->final_clause("ORDER BY paf.hit_rank");
#   my $objs = $self->_generic_fetch($constraint, $extrajoin);
#   #$self->final_clause("");
#   return $objs;
# }


=head2 fetch_all_RH_by_member

  Overview   : This an experimental method and not currently used in production
  Arg [1]    : member_id of query peptide member
  Example    : $feat = $adaptor->fetch_by_dbID($musBlastAnal, $ratBlastAnal);
  Description: Returns all the PeptideAlignFeatures that reciprocal hit all genomes
  Returntype : array of Bio::EnsEMBL::Compara::PeptideAlignFeature objects by reference
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_RH_by_member
{
  # using trick of specifying table twice so can join to self
  my $self             = shift;
  my $qmember_id       = shift;

  #print(STDERR "fetch_all_RH_by_member_genomedb qmember_id=$qmember_id, genome_db_id=$hit_genome_db_id\n");
  return unless($qmember_id);

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $member->genome_db;
  my $species_name = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $columns = join(', ', $self->_columns());

  my $sql = "SELECT $columns, paf2.peptide_align_feature_id AS pafid2".
            " FROM $tbl_name paf, $tbl_name paf2".
            " WHERE paf.hmember_id=paf2.qmember_id".
            " AND paf.qmember_id=$qmember_id".
            " AND paf2.hmember_id=$qmember_id";

  my $sth = $self->dbc->prepare($sql);
  $sth->execute;
  my $objs = $self->_objs_from_sth($sth);
  $sth->finish;

  return $objs;
}


# Previous all-in-one-table paf
# sub old_fetch_all_RH_by_member
# {
#   # using trick of specifying table twice so can join to self
#   my $self             = shift;
#   my $qmember_id       = shift;

#   #print(STDERR "fetch_all_RH_by_member qmember_id=$qmember_id\n");
#   return unless($qmember_id);
#   my $extrajoin = [
#                     [ ['peptide_align_feature', 'paf2'],
#                        'paf.qmember_id=paf2.hmember_id AND paf.hmember_id=paf2.qmember_id',
#                        ['paf2.peptide_align_feature_id AS pafid2']]
#                   ];

#   my $constraint = " paf.qmember_id='".$qmember_id."'".
#                    " AND paf2.hmember_id='".$qmember_id."'";

#   return $self->_generic_fetch($constraint, $extrajoin);
# }


=head2 fetch_all

  Arg        : None
  Example    : @pafs = @{$adaptor->fetch_all};
  Description: fetch all peptide align features.  Not generally useful since it
               can return millions of objects.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions :
  Caller     :

=cut

sub fetch_all {
  my $self = shift;

  return $self->_generic_fetch();
}


=head2 fetch_BRH_web_for_member_genome_db

  Overview   : This is the new (compara_24) algorithm method for finding UBRH and MBRH
               homologies.  
  Arg [1]    : member_id of query peptide member
  Arg [2]    : genome_db_id of hit species
  Description: Returns all the 'best' PeptideAlignFeatures starting with qmember_id
               hitting onto the hit_genome_db_id via recursive search
  Returntype : array of Bio::EnsEMBL::Compara::PeptideAlignFeature objects by reference
               or undef if nothing found
  Exceptions : none
  Caller     : general

=cut

sub fetch_BRH_web_for_member_genome_db
{
  # recursive search to find web of 'best' hits starting with a given
  # qmember_id and hit_genome_db_id
  my $self               = shift;
  my $qmember_id         = shift;
  my $hit_genome_db_id   = shift;

  my $tested_member_ids  = {};
  my $found_paf_ids      = {};

  $self->_recursive_find_brh_pafs_for_member_genome_db(
             $qmember_id,
             $hit_genome_db_id,
             $tested_member_ids,
             $found_paf_ids);

  my $pafsArray = $self->fetch_by_dbIDs(keys %$found_paf_ids);
  return undef unless($pafsArray);
  
  #match up the reciprocals
  foreach my $paf1 (@$pafsArray) {
    foreach my $paf2 (@$pafsArray) {
      if(($paf1->query_member->dbID == $paf2->hit_member->dbID) and
         ($paf1->hit_member->dbID   == $paf2->query_member->dbID))
      {
        $paf1->rhit_dbID($paf2->dbID);
        $paf2->rhit_dbID($paf1->dbID);
      }
    }
  }
  return $pafsArray;
}

sub _recursive_find_brh_pafs_for_member_genome_db
{
  # recursive search to find web of 'best' hits starting with a given
  # member_id and genome_db_ids
  my $self               = shift;
  my $qmember_id         = shift;
  my $hit_genome_db_id   = shift;
  my $tested_member_ids  = shift;  #ref to hash
  my $found_paf_ids      = shift;  #ref to hash

  my $member = $self->db->get_MemberAdaptor->fetch_by_dbID($qmember_id);

  my $gdb = $member->genome_db;
  my $species_name1 = lc($gdb->name);
  my $gdb_id = lc($gdb->dbID);
  $species_name1 =~ s/\ /\_/g;
  my $tbl_name1 = "peptide_align_feature"."_"."$species_name1"."_"."$gdb_id";

  my $species_name2 = lc($self->db->get_GenomeDBAdaptor->fetch_by_dbID($hit_genome_db_id)->name);
  $species_name2 =~ s/\ /\_/g;
  my $tbl_name2 = "peptide_align_feature"."_"."$species_name2"."_"."$hit_genome_db_id";

  return unless($qmember_id and $hit_genome_db_id);
  return if($tested_member_ids->{$qmember_id}); #already tested this member

  $tested_member_ids->{$qmember_id} = 1;
  #printf(" recursive_web qm=%d  hg=%d\n", $qmember_id, $hit_genome_db_id);
  my $sql = "SELECT paf1.peptide_align_feature_id, paf1.hmember_id, paf1.qgenome_db_id ".
            " FROM $tbl_name1 paf1, $tbl_name2 paf2".
            " WHERE paf1.hmember_id=paf2.qmember_id".
            " AND paf1.qmember_id=? and paf1.hgenome_db_id=? and paf1.hit_rank=1".
            " AND paf2.hmember_id=? and paf2.qgenome_db_id=? and paf2.hit_rank=1";
  my $sth = $self->prepare($sql);
  $sth->execute($qmember_id, $hit_genome_db_id, $qmember_id, $hit_genome_db_id);

  while (my ($pafID, $hmember_id, $qgenome_db_id) = $sth->fetchrow_array()) {
    #printf("  found pafID $pafID in recursive search\n");
    $found_paf_ids->{$pafID} = 1;
    $self->_recursive_find_brh_pafs_for_member_genome_db($hmember_id, $qgenome_db_id, $tested_member_ids, $found_paf_ids);
  }
  $sth->finish;
}

# sub _old_recursive_find_brh_pafs_for_member_genome_db
# {
#   # recursive search to find web of 'best' hits starting with a given
#   # member_id and genome_db_ids
#   my $self               = shift;
#   my $qmember_id         = shift;
#   my $hit_genome_db_id   = shift;
#   my $tested_member_ids  = shift;  #ref to hash
#   my $found_paf_ids      = shift;  #ref to hash

#   return unless($qmember_id and $hit_genome_db_id);
#   return if($tested_member_ids->{$qmember_id}); #already tested this member

#   $tested_member_ids->{$qmember_id} = 1;
#   #printf(" recursive_web qm=%d  hg=%d\n", $qmember_id, $hit_genome_db_id);
#   my $sql = "SELECT paf1.peptide_align_feature_id, paf1.hmember_id, paf1.qgenome_db_id ".
#             " FROM peptide_align_feature paf1, peptide_align_feature paf2".
#             " WHERE paf1.hmember_id=paf2.qmember_id".
#             " AND paf1.qmember_id=? and paf1.hgenome_db_id=? and paf1.hit_rank=1".
#             " AND paf2.hmember_id=? and paf2.qgenome_db_id=? and paf2.hit_rank=1";
#   my $sth = $self->prepare($sql);
#   $sth->execute($qmember_id, $hit_genome_db_id, $qmember_id, $hit_genome_db_id);

#   while (my ($pafID, $hmember_id, $qgenome_db_id) = $sth->fetchrow_array()) {
#     #printf("  found pafID $pafID in recursive search\n");
#     $found_paf_ids->{$pafID} = 1;
#     $self->_recursive_find_brh_pafs_for_member_genome_db($hmember_id, $qgenome_db_id, $tested_member_ids, $found_paf_ids);
#   }
#   $sth->finish;
# }


sub _generic_fetch {
  my ($self, $constraint, $join) = @_;

  my @tables = $self->_tables;
  my $columns = join(', ', $self->_columns());

  if ($join) {
    foreach my $single_join (@{$join}) {
      my ($tablename, $condition, $extra_columns) = @{$single_join};
      if ($tablename && $condition) {
        push @tables, $tablename;

        if($constraint) {
          $constraint .= " AND $condition";
        } else {
          $constraint = " $condition";
        }
      }
      if ($extra_columns) {
        $columns .= ", " . join(', ', @{$extra_columns});
      }
    }
  }

  #construct a nice table string like 'table1 t1, table2 t2'
  my $tablenames = join(', ', map({ join(' ', @$_) } @tables));

  my $sql = "SELECT $columns FROM $tablenames";

  my $default_where = $self->_default_where_clause;
  my $final_clause = $self->final_clause;

  #append a where clause if it was defined
  if($constraint) {
    $sql .= " WHERE $constraint ";
    if($default_where) {
      $sql .= " AND $default_where ";
    }
  } elsif($default_where) {
    $sql .= " WHERE $default_where ";
  }

  #append additional clauses which may have been defined
  $sql .= " $final_clause" if($final_clause);

  # print STDERR $sql,"\n";
  my $sth = $self->prepare($sql);
  $sth->execute;

  # print STDERR $sql,"\n";
  # print STDERR "sql execute finished. about to build objects\n";

  return $self->_objs_from_sth($sth);
}

1;
