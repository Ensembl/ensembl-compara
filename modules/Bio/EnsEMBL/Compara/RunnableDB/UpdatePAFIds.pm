#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('UpdatePAFIds');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds(
                         -input_id   => 1,
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input_id
of arrayrefs of genome_db_ids, and from this species set relationship
it will search through the peptide_align_feature data and build 
SingleLinkage Clusters and store them into a NestedSet datastructure.
This is the first step in the ProteinTree analysis production system.

=cut

=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  $self->{'genomeDB_set'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;

  return 1;
}


sub run
{
  my $self = shift;

  $self->updatepafids();
  return 1;
}

sub write_output {
  my $self = shift;
  return 1;
}

##########################################
#
# internal methods
#
##########################################

# This will make sure that the indexes for paf are fine
sub updatepafids {
  my $self = shift;

  my $starttime = time();

  my @tbl_names;
  foreach my $gdb (@{$self->{'genomeDB_set'}}) {
    my $gdb_id = $gdb->dbID;
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    push @tbl_names, $tbl_name;
  }

  my ($first_tbl_name, @rest_tbl_names) = sort @tbl_names;
  # First offset -- first table remains as it is
  my $sql = "SELECT MAX(peptide_align_feature_id) as max".
            " FROM $first_tbl_name";
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my $first_offset_hash = $sth->fetchrow_hashref;
  my $first_offset = $first_offset_hash->{max};
  # Subsequent offsets -- subsequent tables are offsetted
  foreach my $tbl_name (sort @rest_tbl_names) {
    my $sql = "SELECT MAX(peptide_align_feature_id) as max".
              " FROM $tbl_name";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    my $second_offset_hash = $sth->fetchrow_hashref;
    my $second_offset = $second_offset_hash->{max};
    my $sql2 = "UPDATE $tbl_name".
               " SET peptide_align_feature_id=peptide_align_feature_id+$first_offset";
    my $sth2 = $self->dbc->prepare($sql2);
    $sth2->execute();
    $first_offset += $second_offset;
  }

  printf("  %1.3f secs to Update PAF Ids\n", (time()-$starttime));
}

1;
