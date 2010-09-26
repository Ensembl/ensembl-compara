#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NCRecoverSearch

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncrecoversearch = Bio::EnsEMBL::Compara::RunnableDB::NCRecoverSearch->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncrecoversearch->fetch_input(); #reads from DB
$ncrecoversearch->run();
$ncrecoversearch->output();
$ncrecoversearch->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::NCRecoverSearch;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;
  $self->{context_size} = '120%';

  # Get the needed adaptors here
  $self->{gdbDBA} = $self->compara_dba->get_GenomeDBAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[param1 param2 param3 analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  # Fetch nc_tree
  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} =  
         $self->compara_dba->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
  }

  $self->{model_id} = $self->{nc_tree}->get_tagvalue('clustering_id');

  # Fetch recovered_member entries
  $self->fetch_recovered_member_entries($self->{nc_tree}->node_id);

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  ## This is disabled right now
  # $self->run_ncrecoversearch;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

  # Default autoflow
  return 1;
}


##########################################
#
# internal methods
#
##########################################

sub run_ncrecoversearch {
  my $self = shift;

  next unless(defined($self->{recovered_members}));

  my $cmsearch_executable = $self->analysis->program_file;
    unless (-e $cmsearch_executable) {
      print "Using default cmsearch executable!\n";
      $cmsearch_executable = "/nfs/users/nfs_a/avilella/src/infernal/infernal-1.0/src/cmsearch";
  }
  throw("can't find a cmalign executable to run\n") unless(-e $cmsearch_executable);

  my $worker_temp_directory = $self->worker_temp_directory;
  my $root_id = $self->{nc_tree}->node_id;

  my $input_fasta = $worker_temp_directory . $root_id . ".db";
  open FILE,">$input_fasta" or die "$!\n";

  foreach my $genome_db_id (keys %{$self->{recovered_members}}) {
    my $gdb = $self->{gdbDBA}->fetch_by_dbID($genome_db_id);
    my $slice_adaptor = $gdb->db_adaptor->get_SliceAdaptor;
    foreach my $recovered_entry (keys %{$self->{recovered_members}{$genome_db_id}}) {
      my $recovered_id = $self->{recovered_members}{$genome_db_id}{$recovered_entry};
      unless ($recovered_entry =~ /(\S+)\:(\S+)\-(\S+)/) {
        warn("failed to parse coordinates for recovered entry: [$genome_db_id] $recovered_entry\n");
        next;
      } else {
        my ($seq_region_name,$start,$end) = ($1,$2,$3);
        my $temp; if ($start > $end) { $temp = $start; $start = $end; $end = $temp;}
        my $size = $self->{context_size};
        $size = int( ($1-100)/200 * ($end-$start+1) ) if( $size =~/([\d+\.]+)%/ );
        my $slice = $slice_adaptor->fetch_by_region('toplevel',$seq_region_name,$start-$size,$end+$size);
        my $seq = $slice->seq; $seq =~ s/(.{60})/$1\n/g; chomp $seq;
        print FILE ">$recovered_id\n$seq\n";
      }
    }
  }
  close FILE;

  my $ret1 = $self->dump_model('model_id',$self->{model_id});
  my $ret2 = $self->dump_model('name',$self->{model_id}) if (1 == $ret1);
  if (1 == $ret2) {
    $self->{'nc_tree'}->release_tree;
    $self->{'nc_tree'} = undef;
    $self->input_job->transient_error(0);
    die;
  }

  my $cmd = $cmsearch_executable;
  # /nfs/users/nfs_a/avilella/src/infernal/infernal-1.0/src/cmsearch --tabfile 110257.tab snoU89_profile.cm 110257.db

  return 1;   # FIXME: this is not ready -- disabling

  my $tabfilename = $worker_temp_directory . $root_id . ".tab";
  $cmd .= " --tabfile " . $tabfilename;
  $cmd .= " " . $self->{profile_file};
  $cmd .= " " . $input_fasta;

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    throw("error running cmsearch, $!\n");
  }
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  open TABFILE,"$tabfilename" or die "$!\n";
  while (<TABFILE>) {
    next if /^\#/;
    my ($dummy,$target_name,$target_start,$target_stop,$query_start,$query_stop,$bit_sc,$evalue,$gc) = split(/\s+/,$_);
    my $sth = $self->compara_dba->dbc->prepare
      ("INSERT IGNORE INTO cmsearch_hit 
                           (recovered_id,
                            node_id,
                            target_start,
                            target_stop,
                            query_start,
                            query_stop,
                            bit_sc,
                            evalue) VALUES (?,?,?,?,?,?,?,?)");
    $sth->execute($target_name,
                  $root_id,
                  $target_start,
                  $target_stop,
                  $query_start,
                  $query_stop,
                  $bit_sc,
                  $evalue);
    $sth->finish;
  }
  close TABFILE;

  return 1;
}


sub dump_model {
  my $self = shift;
  my $field = shift;
  my $model_id = shift;

  my $sql = 
    "SELECT hc_profile FROM nc_profile ".
      "WHERE $field=\"$model_id\"";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  my $nc_profile  = $sth->fetchrow;
  unless (defined($nc_profile)) {
    return 1;
  }
  my $profile_file = $self->worker_temp_directory . $model_id . "_profile.cm";
  open FILE, ">$profile_file" or die "$!";
  print FILE $nc_profile;
  close FILE;

  $self->{profile_file} = $profile_file;
  return 0;
}

sub fetch_recovered_member_entries {
  my $self = shift;
  my $root_id = shift;

  my $sql = 
    "SELECT rcm.recovered_id, rcm.node_id, rcm.stable_id, rcm.genome_db_id ".
    "FROM recovered_member rcm ".
    "WHERE rcm.node_id=\"$root_id\" AND ".
    "rcm.stable_id not in ".
    "(SELECT stable_id FROM member WHERE source_name='ENSEMBLGENE' AND genome_db_id=rcm.genome_db_id)";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($recovered_id, $node_id, $stable_id, $genome_db_id) = @$ref;
    $self->{recovered_members}{$genome_db_id}{$stable_id} = $recovered_id;
  }

  return 0;
}


1;
