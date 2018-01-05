=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor

=head1 SYNOPSIS

  $peptideAlignFeatureAdaptor = $db_adaptor->get_PeptideAlignFeatureAdaptor;
  $peptideAlignFeatureAdaptor = $peptideAlignFeatureObj->adaptor;

=head1 DESCRIPTION

  Module to encapsulate all db access for persistent class PeptideAlignFeature
  There should be just one per application and database connection.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::PeptideAlignFeature;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

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
  my $seq_member_id = shift;

  throw("seq_member_id undefined") unless($seq_member_id);

  my $member = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($seq_member_id);
  $self->{_curr_gdb_id} = $member->genome_db_id;

  my $constraint = 'paf.qmember_id = ?';
  $self->bind_param_generic_fetch($seq_member_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
}


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
  my $seq_member_id = shift;

  throw("seq_member_id undefined") unless($seq_member_id);

  my @pafs;
  foreach my $genome_db_id ($self->_get_all_genome_db_ids) {
    push @pafs, @{$self->fetch_all_by_hmember_id_qgenome_db_id($seq_member_id, $genome_db_id)};
  }
  return \@pafs;
}


=head2 fetch_all_by_qmember_id_hmember_id

  Arg [1]    : int $query_member->dbID
               the database id for a peptide member
  Arg [2]    : int $hit_member->dbID
               the database id for a peptide member
  Example    : $pafs = $adaptor->fetch_all_by_qmember_id_hmember_id($qmember_id, $hmember_id);
  Description: Returns all PeptideAlignFeatures for a given query member and
               hit member.  If pair did not align, array will be empty.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if either seq_member_id is not defined
  Caller     : general

=cut

sub fetch_all_by_qmember_id_hmember_id{
  my $self = shift;
  my $qmember_id = shift;
  my $hmember_id = shift;

  throw("must specify query member dbID") unless($qmember_id);
  throw("must specify hit member dbID") unless($hmember_id);

  my $qmember = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($qmember_id);
  $self->{_curr_gdb_id} = $qmember->genome_db_id;

  my $constraint = 'paf.qmember_id=? AND paf.hmember_id=?';
  $self->bind_param_generic_fetch($qmember_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($hmember_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
}


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

  my $qmember = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($qmember_id);
  $self->{_curr_gdb_id} = $qmember->genome_db_id;

  my $constraint = 'paf.qmember_id=? AND paf.hgenome_db_id=?';
  $self->bind_param_generic_fetch($qmember_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($hgenome_db_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
}


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

   $self->{_curr_gdb_id} = $qgenome_db_id;
   # we don't need to add "paf.qgenome_db_id=$qgenome_db_id" because it is implicit from the table name
   my $constraint = 'paf.hmember_id=?';
   $self->bind_param_generic_fetch($hmember_id, SQL_INTEGER);
   return $self->generic_fetch($constraint);
}


sub fetch_all_by_hgenome_db_id{
  my $self = shift;
  my $hgenome_db_id = shift;

  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  my @pafs;
  foreach my $genome_db_id ($self->_get_all_genome_db_ids) {
    push @pafs, @{$self->fetch_all_by_qgenome_db_id_hgenome_db_id($genome_db_id, $hgenome_db_id)};
  }
  return \@pafs;
}


sub fetch_all_by_qgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);

  $self->{_curr_gdb_id} = $qgenome_db_id;
  return $self->generic_fetch();
}


sub fetch_all_by_qgenome_db_id_hgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;
  my $hgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);
  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  $self->{_curr_gdb_id} = $qgenome_db_id;

  my $constraint = 'paf.hgenome_db_id = ?';
  $self->bind_param_generic_fetch($hgenome_db_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
}


sub fetch_all_besthit_by_qgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);

  $self->{_curr_gdb_id} = $qgenome_db_id;

  my $constraint = "paf.hit_rank=1";
  return $self->generic_fetch($constraint);
}


sub fetch_all_besthit_by_qgenome_db_id_hgenome_db_id{
  my $self = shift;
  my $qgenome_db_id = shift;
  my $hgenome_db_id = shift;

  throw("must specify query genome_db dbID") unless($qgenome_db_id);
  throw("must specify hit genome_db dbID") unless($hgenome_db_id);

  $self->{_curr_gdb_id} = $qgenome_db_id;

  my $constraint = 'paf.hgenome_db_id = ? AND paf.hit_rank=1';
  $self->bind_param_generic_fetch($hgenome_db_id, SQL_INTEGER);
  return $self->generic_fetch($constraint);
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

  my $member = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($qmember_id);

  $self->{_curr_gdb_id} = $member->genome_db_id;
  my $constraint = 'qmember_id=? AND qmember_id=hmember_id';
  $self->bind_param_generic_fetch($qmember_id, SQL_INTEGER);
  return $self->generic_fetch_one($constraint);
}



#############################
#
# store methods
#
#############################

sub rank_and_store_PAFS {
  my ($self, @features)  = @_;

  my %by_query = ();
  foreach my $f (@features) {
      push @{$by_query{$f->query_genome_db_id}{$f->query_member_id}}, $f;
  };
  foreach my $query_genome_db_id (keys %by_query) {
      foreach my $sub_features (values %{$by_query{$query_genome_db_id}}) {
          my @pafList = sort sort_by_score_evalue_and_pid @$sub_features;
          my $rank = 1;
          my $prevPaf = undef;
          foreach my $paf (@pafList) {
              $rank++ if($prevPaf and !pafs_equal($prevPaf, $paf));
              $paf->hit_rank($rank);
              $prevPaf = $paf;
          }
          $self->store_PAFS(@pafList);
      }
  }
}


## WARNING: all the features are supposed to come from the same query_genome_db_id !
sub store_PAFS {
  my ($self, @features)  = @_;

  return unless(@features);

  # Query genome db id should always be the same
  my $first_qgenome_db_id = $features[0]->query_genome_db_id;

  my $tbl_name = 'peptide_align_feature';
  if ($first_qgenome_db_id){
  	my $gdb = $self->db->get_GenomeDBAdaptor->fetch_by_dbID($first_qgenome_db_id);
  	$tbl_name .= "_$first_qgenome_db_id";
  }

  my @stored_columns = qw(qmember_id hmember_id qgenome_db_id hgenome_db_id qstart qend hstart hend score evalue align_length identical_matches perc_ident positive_matches perc_pos hit_rank cigar_line);
  my $query = sprintf('INSERT INTO %s (%s) VALUES (%s)', $tbl_name, join(',', @stored_columns), join(',', map {'?'} @stored_columns) );
  my $sth = $self->prepare($query);

  foreach my $paf (@features) {
      # print STDERR "== ", $paf->query_member_id, " - ", $paf->hit_member_id, "\n";

      $sth->execute($paf->query_member_id, $paf->hit_member_id, $paf->query_genome_db_id, $paf->hit_genome_db_id,
          $paf->qstart, $paf->qend, $paf->hstart, $paf->hend,
          $paf->score, $paf->evalue, $paf->alignment_length,
          $paf->identical_matches, $paf->perc_ident, $paf->positive_matches, $paf->perc_pos, $paf->hit_rank, $paf->cigar_line);
  }
  $sth->finish;
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
    " seq_member_id     : " . $paf->seq_member_id . "\n" .
    " start             : " . $paf->start . "\n" .
    " end               : " . $paf->end . "\n" .
    " hseq_member_id    : " . $paf->hseq_member_id . "\n" .
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

  print("HSP ".$paf->seq_member_id."(".$paf->start.",".$paf->end.")".
        "\t" . $paf->hseq_member_id. "(".$paf->hstart.",".$paf->hend.")".
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

  return (['peptide_align_feature_'.$self->{_curr_gdb_id}, 'paf'] );
}

sub _columns {
  my $self = shift;

  return qw (paf.peptide_align_feature_id
             paf.qmember_id
             paf.hmember_id
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

sub _objs_from_sth {
    my ($self, $sth) = @_;

    my $memberDBA = $self->db->get_SeqMemberAdaptor;
    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::PeptideAlignFeature', [
            'dbID',
            '_query_member_id',
            '_hit_member_id',
            '_qstart',
            '_qend',
            '_hstart',
            '_hend',
            '_score',
            '_evalue',
            '_alignment_length',
            '_identical_matches',
            '_perc_ident',
            '_positive_matches',
            '_perc_pos',
            '_hit_rank',
            '_cigar_line',
        ], sub {
            my $a = shift;
            return {
                ($a->[1] ? ('_query_member' => $memberDBA->fetch_by_dbID($a->[1])) : ()),
                ($a->[2] ? ('_hit_member'   => $memberDBA->fetch_by_dbID($a->[2])) : ()),
            };
        });
}

sub _get_all_genome_db_ids {
    my $self = shift;

    return map {$_->dbID} grep {$_->name ne 'ancestral_sequences'} @{$self->db->get_GenomeDBAdaptor->fetch_all};
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
    throw("fetch_by_dbID must have an id");
  }

  $self->{_curr_gdb_id} = int($id/100000000);

  my $constraint = 'peptide_align_feature_id=?';
  $self->bind_param_generic_fetch($id, SQL_INTEGER);
  return $self->generic_fetch_one($constraint);
}


=head2 fetch_all_by_dbID_list

  Arg [1]    : array ref $id_list_ref
               the unique database identifier for the feature to be obtained
  Example    : $pafs = $adaptor->fetch_by_dbID( [paf1_id, $paf2_id, $paf3_id] );
  Description: Returns the PeptideAlignFeature created from the database defined by the
               the id $id.
  Returntype : array reference of Bio::EnsEMBL::Compara::PeptideAlignFeature objects
  Exceptions : thrown if $id is not defined
  Caller     : general

=cut

sub fetch_all_by_dbID_list {
  my $self = shift;
  my $id_list_ref = shift;

  return [map {$self->fetch_by_dbID($_)} @$id_list_ref];
}


=head2 fetch_BRH_by_member_genomedb

  Arg [1]    : seq_member_id of query peptide member
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

  my $member = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($qmember_id);

  $self->{_curr_gdb_id} = $member->genome_db_id;

   my $extrajoin = [
                     [ ['peptide_align_feature_'.$hit_genome_db_id, 'paf2'],
                       'paf.qmember_id=paf2.hmember_id AND paf.hmember_id=paf2.qmember_id',
                       {'paf2.peptide_align_feature_id AS pafid2' => '_rhit_dbID'}]
                   ];

   my $constraint = "paf.hit_rank=1 AND paf2.hit_rank=1 AND paf.qmember_id=? AND paf.hgenome_db_id=?";
  $self->bind_param_generic_fetch($qmember_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($hit_genome_db_id, SQL_INTEGER);

  return $self->generic_fetch_one($constraint, $extrajoin);
}


=head2 fetch_all_RH_by_member_genomedb

  Overview   : This an experimental method and not currently used in production
  Arg [1]    : seq_member_id of query peptide member
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

  my $member = $self->db->get_SeqMemberAdaptor->fetch_by_dbID($qmember_id);

  $self->{_curr_gdb_id} = $member->genome_db_id;

   my $extrajoin = [
                     [ ['peptide_align_feature_'.$hit_genome_db_id, 'paf2'],
                       'paf.qmember_id=paf2.hmember_id AND paf.hmember_id=paf2.qmember_id',
                       ['paf2.peptide_align_feature_id AS pafid2']]
                   ];

   my $constraint = "paf.qmember_id=? AND paf.hgenome_db_id=?";
   my $final_clause = "ORDER BY paf.hit_rank";
  $self->bind_param_generic_fetch($qmember_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($hit_genome_db_id, SQL_INTEGER);

  return $self->generic_fetch($constraint, $extrajoin, $final_clause);

}


=head2 fetch_all_RH_by_member

  Overview   : This an experimental method and not currently used in production
  Arg [1]    : seq_member_id of query peptide member
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

  my @pafs;
  foreach my $genome_db_id ($self->_get_all_genome_db_ids) {
    push @pafs, @{$self->fetch_all_RH_by_member_genomedb($qmember_id, $genome_db_id)};
  }
  return \@pafs;
}


1;
