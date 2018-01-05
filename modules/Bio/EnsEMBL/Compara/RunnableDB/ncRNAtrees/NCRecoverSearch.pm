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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverSearch

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncrecoversearch = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverSearch->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncrecoversearch->fetch_input(); #reads from DB
$ncrecoversearch->run();
$ncrecoversearch->write_output(); #writes to DB

=cut


=head1 DESCRIPTION


=cut


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::NCRecoverSearch;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'context_size'  => '120%',
    };
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $nc_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($nc_tree_id) or die "Could not fetch nc_tree with id=$nc_tree_id\n";
    $self->param('model_id', $nc_tree->get_value_for_tag('model_id'));

    $self->fetch_recovered_member_entries($nc_tree_id);

        # Get the needed adaptors here:
    $self->param('genomedb_adaptor', $self->compara_dba->get_GenomeDBAdaptor);
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
}


##########################################
#
# internal methods
#
##########################################

sub run_ncrecoversearch {
  my $self = shift;

  next unless(keys %{$self->param('recovered_members')});

  my $cmsearch_exe = $self->require_executable('cmsearch_exe');

  my $worker_temp_directory = $self->worker_temp_directory;
  my $root_id = $self->param('gene_tree_id');

  my $input_fasta = $worker_temp_directory . "/" . $root_id . ".db";
  open FILE,">$input_fasta" or die "$!\n";

  foreach my $genome_db_id (keys %{$self->param('recovered_members')}) {
    my $gdb = $self->param('genomedb_adaptor')->fetch_by_dbID($genome_db_id);
    my $core_slice_adaptor = $gdb->db_adaptor->get_SliceAdaptor;
    foreach my $recovered_entry (keys %{$self->param('recovered_members')->{$genome_db_id}}) {
      my $recovered_id = $self->param('recovered_members')->{$genome_db_id}{$recovered_entry};
      unless ($recovered_entry =~ /(\S+)\:(\S+)\-(\S+)/) {
        warn("failed to parse coordinates for recovered entry: [$genome_db_id] $recovered_entry\n");
        next;
      } else {
        my ($seq_region_name,$start,$end) = ($1,$2,$3);
        my $temp; if ($start > $end) { $temp = $start; $start = $end; $end = $temp;}
        my $size = $self->param('context_size');
        $size = int( ($1-100)/200 * ($end-$start+1) ) if( $size =~/([\d+\.]+)%/ );
        my $slice = $core_slice_adaptor->fetch_by_region('toplevel',$seq_region_name,$start-$size,$end+$size);
        my $seq = $slice->seq; $seq =~ s/(.{60})/$1\n/g; chomp $seq;
        print FILE ">$recovered_id\n$seq\n";
      }
    }
  }
  close FILE;

  my $model_id = $self->param('model_id');
  my $not_found = $self->dump_model('model_id', $model_id);
     $not_found = $self->dump_model('name',     $model_id) if $not_found;
  if ($not_found) {
    $self->input_job->transient_error(0);
    die "Failed to find '$model_id' both in 'model_id' and 'name' fields of 'hmm_profile' table";
  }

  my $cmd = $cmsearch_exe;
  # /nfs/users/nfs_a/avilella/src/infernal/infernal-1.0/src/cmsearch --tabfile 110257.tab snoU89_profile.cm 110257.db

  return 1;   # FIXME: this is not ready -- disabling

  my $tabfilename = $worker_temp_directory . "/" . $root_id . ".tab";
  $cmd .= " --tabfile " . $tabfilename;
  $cmd .= " " . $self->param('profile_file');
  $cmd .= " " . $input_fasta;

  $self->run_command($cmd, { die_on_failure => 1 });

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

  my $nc_profile = $self->compara_dba->get_HMMProfileAdaptor()->fetch_all_by_model_id_type($model_id)->[0]->profile();

#   my $sql = 
#     "SELECT hc_profile FROM hmm_profile ".
#       "WHERE $field=\"$model_id\"";
#   my $sth = $self->compara_dba->dbc->prepare($sql);
#   $sth->execute();
#  my $nc_profile  = $sth->fetchrow;
  unless (defined($nc_profile)) {
    return 0;
  }
  my $profile_file = $self->worker_temp_directory . "/" . $model_id . "_profile.cm";
  $self->_spurt($profile_file, $nc_profile);

  $self->param('profile_file', $profile_file);
  return 1;
}

sub fetch_recovered_member_entries {
  my $self = shift;
  my $root_id = shift;

  $self->param('recovered_members', {});

  my $sql = 
    "SELECT rcm.recovered_id, rcm.node_id, rcm.stable_id, rcm.genome_db_id ".
    "FROM recovered_member rcm ".
    "WHERE rcm.node_id=\"$root_id\" AND ".
    "rcm.stable_id not in ".
    "(SELECT stable_id FROM gene_member WHERE source_name='ENSEMBLGENE' AND genome_db_id=rcm.genome_db_id)";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($recovered_id, $node_id, $stable_id, $genome_db_id) = @$ref;
    $self->param('recovered_members')->{$genome_db_id}{$stable_id} = $recovered_id;
  }
}


1;
