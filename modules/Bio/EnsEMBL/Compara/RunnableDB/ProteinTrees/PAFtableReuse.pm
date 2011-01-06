#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PAFtableReuse

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('ProteinTrees::PAFtableReuse');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PAFtableReuse(
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PAFtableReuse;

use strict;
use Bio::EnsEMBL::Hive::URLFactory;               # Blast_reuse
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id') || $self->param('genome_db_id', $self->param('gdb'))        # for compatibility
                or die "'genome_db_id' is an obligatory parameter";

    my $genome_db    = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id)
                            or die "Could not fetch genome_db with id='$genome_db_id'";

    unless( $self->param('name_and_id') ) {
        my $name_and_id = $genome_db->name . '_' . $genome_db_id;
        $self->param('name_and_id', $name_and_id);
    }

    unless( defined($self->param('reuse_this')) ) {
        die "'reuse_this' is an obligatory parameter";
    }

    my $reuse_ss_id = $self->param('reuse_ss_id')
                    or die "'reuse_ss_id' is an obligatory parameter dynamically set in 'meta' table by the pipeline - please investigate";

    my $reuse_ss = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($reuse_ss_id)
                    or die "Could not fetch reuse species_set with dbID=$reuse_ss_id";

    my $reuse_gdb_list = [ map { $_->dbID() } @{ $reuse_ss->genome_dbs() } ];
    $self->param('reuse_gdb_list', $reuse_gdb_list );
}

sub run {
    my $self = shift @_;

    if($self->param('reuse_this')) {
        $self->import_paf_table( $self->param('name_and_id') );
    }
}

sub write_output {
    my $self = shift @_;
}



sub import_paf_table {
  my ($self, $name_and_id) = @_;

  my $starttime = time();

  my $reuse_db = Bio::EnsEMBL::Hive::URLFactory->fetch($self->param('reuse_db'). ';type=compara');
  my $reuse_username = $reuse_db->dbc->username;
  my $reuse_password = $reuse_db->dbc->password;
  my $pass = "-p$reuse_password " if ($reuse_password);
  my $reuse_host = $reuse_db->dbc->host;
  my $reuse_port = $reuse_db->dbc->port;
  my $reuse_dbname = $reuse_db->dbc->dbname;

  my $dest_username = $self->dbc->username;
  my $dest_password = $self->dbc->password;
  my $dest_pass = "-p$dest_password" if ($dest_password);
  my $dest_host = $self->dbc->host;
  my $dest_port = $self->dbc->port;
  my $dest_dbname = $self->dbc->dbname;

  my $hgenome_dbs = join (',', @{$self->param('reuse_gdb_list')});

  my $tbl_name = 'peptide_align_feature_'.$name_and_id;

  my $cmd = "mysqldump --compress --where=\"hgenome_db_id in ($hgenome_dbs)\" -u $reuse_username $pass -h $reuse_host -P$reuse_port $reuse_dbname $tbl_name";
  $cmd .= " | mysql -u $dest_username $dest_pass -h $dest_host -P$dest_port $dest_dbname";

  my $ret = system($cmd);
  printf("  %1.3f secs to mysqldump $tbl_name\n", (time()-$starttime));
  if($ret) {
    $self->throw("Error importing $tbl_name: $ret\n");
  }
}

1;
