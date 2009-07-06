#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastTableReuse

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('BlastTableReuse');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::BlastTableReuse(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This analysis will import peptide_align_feature tables from previous
compara release using a mysql-dependent mysqldump pipe mysql command.

=cut

=head1 CONTACT

  Contact Albert Vilella on module implemetation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastTableReuse;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Hive::URLFactory;               # Blast_reuse
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{gdba}         = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  my $p = eval($self->analysis->parameters);
  if (defined $p->{'blast_template_analysis_data_id'}) {
    my $analysis_data_id = $p->{'blast_template_analysis_data_id'};
    my $ada = $self->db->get_AnalysisDataAdaptor;
    my $new_params = eval($ada->fetch_by_dbID($analysis_data_id));
    if (defined $new_params) {
      $p = $new_params;
    }
  }
  $self->{p} = $p;
  $self->{null_cigar} = $p->{null_cigar} if (defined($p->{null_cigar}));

  my $input_hash = eval($self->input_id);
  $self->{gdb} = $self->{gdba}->fetch_by_dbID($input_hash->{'gdb'});

  if ($self->debug) {
    print("parameters...\n");
    foreach my $key (keys %{$self->{p}}) { print "  $key -- ", $self->{p}{$key}, "\n"; }
    print("input_id...\n");
    print "  gdb_id = ",$self->{gdb}->dbID ,"\n";
    print "  gdb_name = ",$self->{gdb}->name ,"\n";
  }

  # Check if this is one that we need to reuse
  $self->{reuse_this} = 0;
  foreach my $reusable_gdb (@{$p->{reuse_gdb}}) {
    $self->{reusable_gdb}{$reusable_gdb} = 1;
  }
  $self->{reuse_this} = 1  if (defined($self->{reusable_gdb}{$input_hash->{'gdb'}}));

  return 1;
}

sub run
{
  my $self = shift;

  if (1 == $self->{reuse_this}) {
    $self->import_paf_table;
  }
  return 1;
}

sub write_output {
  my $self = shift;

#   if (1 == $self->{reuse_this}) {
#     $self->update_paf_table;
#   }

  return 1;
}

##########################################
#
# internal methods
#
##########################################

sub import_paf_table {
  my $self = shift;
  my $starttime = time();

  return unless($self->{'gdb'});
  my $gdb = $self->{'gdb'};
  return unless $gdb;

  $self->{comparaDBA_reuse} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{p}{reuse_db}, 'compara');
  my $reuse_username = $self->{comparaDBA_reuse}->dbc->username;
  my $reuse_password = $self->{comparaDBA_reuse}->dbc->password;
  my $pass = "-p$reuse_password " if ($reuse_password);
  my $reuse_host = $self->{comparaDBA_reuse}->dbc->host;
  my $reuse_port = $self->{comparaDBA_reuse}->dbc->port;
  my $reuse_dbname = $self->{comparaDBA_reuse}->dbc->dbname;

  my $dest_username = $self->dbc->username;
  my $dest_password = $self->dbc->password;
  my $dest_pass = "-p$dest_password" if ($dest_password);
  my $dest_host = $self->dbc->host;
  my $dest_port = $self->dbc->port;
  my $dest_dbname = $self->dbc->dbname;

  my $hgenome_dbs = join (",",keys %{$self->{reusable_gdb}});

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $cmd = "mysqldump --compress --where=\"hgenome_db_id in ($hgenome_dbs)\" -u $reuse_username $pass -h $reuse_host -P$reuse_port $reuse_dbname $tbl_name";
  $cmd .= " | mysql -u $dest_username $dest_pass -h $dest_host -P$dest_port $dest_dbname";

  $DB::single=1;1;#??
  my $ret = system($cmd);
  printf("  %1.3f secs to mysqldump $tbl_name\n", (time()-$starttime));
  if (0 != $ret) {
    throw("Error importing $tbl_name: $ret\n");
  }
}

# sub update_paf_table {
#   my $self = shift;
#   my $starttime = time();

#   return unless($self->{'gdb'});
#   my $gdb = $self->{'gdb'};
#   return unless $gdb;
# }

1;
