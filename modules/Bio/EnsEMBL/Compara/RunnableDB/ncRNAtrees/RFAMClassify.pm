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


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $rfamclassify = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );

$rfamclassify->fetch_input(); #reads from DB
$rfamclassify->run();
$rfamclassify->write_output(); #writes to DB


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take the descriptions of each
ncrna and classify them into the respective cluster according
to their RFAM id. It also takes into account information from mirBase.

=cut




=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify;

use strict;
use warnings;

use Data::Dumper;
use IO::File;
use LWP::Simple;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use Bio::EnsEMBL::Compara::GeneTreeMember;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::HMMProfile;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub param_defaults {
    return {
            'sort_clusters'         => 1,
            'immediate_dataflow'    => 1,
            'member_type'           => 'ncrna',
    };
}

sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch MLSS with dbID=$mlss_id";

    my $sequence_ids_sql = 'SELECT seq_member_id, sequence_id FROM seq_member';
    my $all_members = $self->compara_dba->dbc->db_handle->selectall_arrayref($sequence_ids_sql);
    my %member2seq = map {$_->[0] => $_->[1]} @$all_members;
    my %seq2member;
    push @{$seq2member{$_->[1]}}, $_->[0] for @$all_members;
    $self->param('member2seq', \%member2seq);
    $self->param('seq2member', \%seq2member);
    $self->param('classified_members', {});

    $self->param('cluster_mlss', $mlss);
}


sub run {
    my $self = shift @_;

    $self->load_mirbase_families;
    $self->run_rfamclassify;
}


sub write_output {
    my $self = shift @_;

    $self->store_clusterset('default', $self->param('allclusters'));
}


##########################################
#
# internal methods
#
##########################################

sub run_rfamclassify {
    my $self = shift;

    # vivification:
    $self->param('rfamcms', {});

    $self->build_hash_cms('model_id');
    $self->load_names_model_id();
    #  $self->build_hash_cms('name');
    $self->build_hash_models();

    my %allclusters;
    $self->param('allclusters', \%allclusters);

    my %seen_seqid;

    # Classify the cluster that already have an RFAM id or mir id
    print STDERR "Storing clusters...\n" if ($self->debug);
    my $counter = 1;
    foreach my $cm_id (keys %{$self->param('rfamcms')->{'model_id'}}) {
        print STDERR "++ $cm_id\n" if ($self->debug);
        next if not defined($self->param('rfamclassify')->{$cm_id});
        my @cluster_list = keys %{$self->param('rfamclassify')->{$cm_id}};
        my $n1 = scalar(@cluster_list);

        # Expand with other members that have the same sequence
        foreach my $id (@cluster_list) {
            my $sequence_id = $self->param('member2seq')->{$id};
            $seen_seqid{$sequence_id} = 1;
            foreach my $other_id (@{ $self->param('seq2member')->{$sequence_id} }) {
                next if $self->param('classified_members')->{$other_id};
                $self->param('rfamclassify')->{$cm_id}->{$other_id}++;
            }
        }
        @cluster_list = keys %{$self->param('rfamclassify')->{$cm_id}};

        # If it's a singleton, we don't store it as a nc tree
        next if (scalar(@cluster_list < 2));

        #printf("%10d clusters\n", $counter) if (($counter % 20 == 0) && ($self->debug));
        $counter++;

        my $model_name;
        if    (defined($self->param('model_id_names')->{$cm_id})) { $model_name = $self->param('model_id_names')->{$cm_id}; }
        elsif (defined($self->param('model_name_ids')->{$cm_id})) { $model_name = $cm_id; }

        print STDERR "ModelName: $model_name: $n1+".(scalar(@cluster_list)-$n1)." members\n" if ($self->debug);

        $allclusters{$cm_id} = {'members' => [@cluster_list],
                                'model_name' => $model_name,
                                'model_id' => $cm_id,
                               }
    }

    # Now find the clusters made of identical sequences with no RFAM ids
    my $seq2member = $self->param('seq2member');
    foreach my $sequence_id (keys %$seq2member) {
        next if $seen_seqid{$sequence_id};
        next if scalar(@{$seq2member->{$sequence_id}}) < 2;
        $allclusters{"s$sequence_id"} = { 'members' => $seq2member->{$sequence_id}, };
        print STDERR "New cluster for sequence_id=$sequence_id : ".scalar(@{$seq2member->{$sequence_id}})." members\n" if $self->debug;
    }
}

sub build_hash_models {
  my $self = shift;

    # vivification:
  $self->param('rfamclassify', {});
  $self->param('orphan_transcript_model_id', {});

  foreach my $gdb (@{$self->compara_dba->get_GenomeDBAdaptor->fetch_all()}) {
   my $seq_members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($gdb);
   Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->compara_dba->get_GeneMemberAdaptor, $seq_members);

   foreach my $transc (@$seq_members) {
    my $gene = $transc->gene_member;
      my $gene_description = $gene->description;
      my $transcript_member_id = $transc->seq_member_id;
      my $transcript_description = $transc->description;

    $transcript_description =~ /Acc:(\w+)/;
    my $transcript_model_id = $1;
    if ($transcript_model_id =~ /MI\d+/) {
      # We use mirbase families to link
      my @family_ids = keys %{$self->param('mirbase_families')->{$transcript_model_id}};
      my $family_id = $family_ids[0];
      if (defined $family_id) {
        $transcript_model_id = $family_id;
      } elsif (defined $gene_description) {
        if ($gene_description =~ /\w+\-(mir-\S+)\ / || $gene_description =~ /\w+\-(let-\S+)\ /) {
          # We take the mir and let ids from the gene description
          $transcript_model_id = $1;
          # We correct the model_id for genes like 'mir-129-2' which have a 'mir-129' model
          if ($transcript_model_id =~ /(mir-\d+)-\d+/) {
            $transcript_model_id = $1;
          }
        } else {
            print STDERR "$transcript_model_id is not a mirbase family and is not a mir or let gene\n" if ($self->debug);
        }
      } else {
        print STDERR "$transcript_model_id has no description. Cannot guess its family\n" if ($self->debug);
      }
    }
    # A simple hash classified by the Acc model ids
    if (defined $self->param('model_name_ids')->{$transcript_model_id}) {
        print STDERR "$transcript_model_id has been converted to id " . $self->param('model_name_ids')->{$transcript_model_id} . "\n" if ($self->debug);
        $transcript_model_id = $self->param('model_name_ids')->{$transcript_model_id};
    }
    $self->param('rfamclassify')->{$transcript_model_id}{$transcript_member_id} = 1;
    $self->param('classified_members')->{$transcript_member_id} = 1;

    # Store list of orphan ids
    unless (defined($self->param('rfamcms')->{'model_id'}{$transcript_model_id}) || defined($self->param('rfamcms')->{'name'}{$transcript_model_id})) {
      $self->param('orphan_transcript_model_id')->{$transcript_model_id}++;     # NB: this data is never used afterwards
    }
   }
  }

  return 1;
}

sub build_hash_cms {
  my $self = shift;
  my $field = shift;

  die "I don't expect a field value different than model_id, but $field has been passed" unless($field eq "model_id");

  my $ids = $self->compara_dba->get_HMMProfileAdaptor()->fetch_all_by_column_names([$field],'infernal');
  for my $id (@$ids) {
      $self->param('rfamcms')->{$field}{$id->[0]} = 1;
  }

}

sub load_names_model_id {
  my $self = shift;

    # vivification:
  $self->param('model_id_names', {});
  $self->param('model_name_ids', {});

  my $ids = $self->compara_dba->get_HMMProfileAdaptor()->fetch_all_by_column_names(['model_id', 'name'],'infernal');
  for my $id (@$ids) {
      $self->param('model_id_names')->{$id->[0]} = $id->[1];
      $self->param('model_name_ids')->{$id->[1]} = $id->[0];
  }

}

sub load_mirbase_families {
  my $self = shift;

  my $starttime = time();
  print STDERR "fetching mirbase families...\n" if ($self->debug);

  my $worker_temp_directory = $self->worker_temp_directory;
  my $url  = 'ftp://mirbase.org/pub/mirbase/CURRENT/';
  my $file = 'miFam.dat.gz';

  my $tmp_file = $worker_temp_directory . "/" .$file;
  my $mifam = $tmp_file;

  my $ftp_file = $url . $file;
  my $status = getstore($ftp_file, $tmp_file);
  die "load_mirbase_families: error $status on $ftp_file" unless is_success($status);

  $mifam =~ s/\.gz//;
  my $cmd = "rm -f $mifam";
  $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1, description => 'delete previously downloaded file' } );

  $cmd = "gunzip $tmp_file";
  $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1, description => 'expand mirbase families' } );

    # vivfication:
  $self->param('mirbase_families', {});

  open (FH, $mifam) or $self->throw("Couldnt open miFam file [$mifam]");
  my $family_ac; my $family_id;
  while (<FH>) {
    if ($_ =~ /^AC\s+(\S+)/) {
      $family_ac = $1;
    } elsif ($_ =~ /^ID\s+(\S+)/) {
      $family_id = $1;
    } elsif ($_ =~ /^MI\s+(\S+)\s+(\S+)/) {
      my $mi_id = $1; my $mir_id = $2;
      $self->param('mirbase_families')->{$mi_id}{$family_id}{$family_ac}{$mir_id} = 1;
    } elsif ($_ =~ /\/\//) {
    } else {
      $self->throw("Unexpected line: [$_] in mifam file\n");
    }
  }

  printf("time for mirbase families fetch : %1.3f secs\n" , time()-$starttime);
}


1;
