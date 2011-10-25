#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify

=cut

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
$rfamclassify->output();
$rfamclassify->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take the descriptions of each
ncrna member and classify them into the respective cluster according
to their RFAM id. It also takes into account information from mirBase.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMClassify;

use strict;
use Data::Dumper;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::GeneTreeNode;
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'clusterset_id'  => 1,
    };
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    $self->input_job->transient_error(0);
    my $mlss_id = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter\n";
    $self->input_job->transient_error(1);

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch MLSS with dbID=$mlss_id";

    $self->param('cluster_mlss', $mlss);
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;

    $self->tag_assembly_coverage_depth;
    $self->load_mirbase_families;
    $self->run_rfamclassify;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores nctree
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->dataflow_clusters;
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

  my $nctree_adaptor = $self->compara_dba->get_NCTreeAdaptor;

  # Create the clusterset and associate mlss
  my $clusterset;
  eval {$clusterset = $nctree_adaptor->fetch_node_by_node_id($self->param('clusterset_id'));};
  if (!defined($clusterset)) {
    $self->param('ccEngine', new Bio::EnsEMBL::Compara::Graph::ConnectedComponents);
    $clusterset = $self->param('ccEngine')->clusterset;
    $self->throw("no clusters generated") unless($clusterset);

    $clusterset->name("NC_TREES"); # FIXME: NC_TREES?
    $nctree_adaptor->store_node($clusterset);
    printf("clusterset_id %d\n", $clusterset->node_id);
    $self->param('clusterset_id', $clusterset->node_id);
  }
  my $mlss_id = $self->param('mlss_id');

  # Classify the cluster that already have an RFAM id or mir id
  print STDERR "Storing clusters...\n" if ($self->debug);
  my $counter = 1;
#  foreach my $field ('model_id','name') {
    foreach my $cm_id (keys %{$self->param('rfamcms')->{'model_id'}}) {
        print STDERR "++ $cm_id\n" if ($self->debug);
      if (defined($self->param('rfamclassify')->{$cm_id})) {
        my @cluster_list = keys %{$self->param('rfamclassify')->{$cm_id}};

        print STDERR Dumper \@cluster_list if ($self->debug);
        # If it's a singleton, we don't store it as a nc tree
        next if (scalar(@cluster_list < 2));

#        printf("%10d clusters\n", $counter) if (($counter % 20 == 0) && ($self->debug));
        $counter++;

        my $model_name;
        if    (defined($self->param('model_id_names')->{$cm_id})) { $model_name = $self->param('model_id_names')->{$cm_id}; }
        elsif (defined($self->param('model_name_ids')->{$cm_id})) { $model_name = $cm_id; }

        print STDERR "ModelName: $model_name\n" if ($self->debug);

        my $cluster = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $clusterset->add_child($cluster);

        foreach my $pmember_id (@cluster_list) {
            print STDERR "Adding $pmember_id\n" if ($self->debug);
          my $node = new Bio::EnsEMBL::Compara::GeneTreeNode;
          $node->node_id($pmember_id);
          $cluster->add_child($node);
          $cluster->clusterset_id($self->param('clusterset_id'));
          #leaves are GeneTreeNode objects, bless to make into GeneTreeMember objects
          bless $node, "Bio::EnsEMBL::Compara::GeneTreeMember";

          #the building method uses member_id's to reference unique nodes
          #which are stored in the node_id value, copy to member_id
          $node->member_id($node->node_id);
          $node->method_link_species_set_id($mlss_id);
        }
        $DB::single=1;1;
        # Store the cluster
        $nctree_adaptor->store($cluster);

        #calc residue count total
        my $leaves = $cluster->get_all_leaves;
        if (defined($model_name)) {
          foreach my $leaf (@$leaves) { 
              print STDERR "Storing acc_name ($model_name) for " . $leaf->node_id() . "\n" if ($self->debug);
              $leaf->store_tag('acc_name',$model_name);
          }
        }
        my $leafcount = scalar @$leaves;
        $cluster->store_tag('gene_count', $leafcount);
        $cluster->store_tag('clustering_id', $cm_id);
        $cluster->store_tag('model_name', $model_name) if (defined($model_name));
      }
    }
#}

  # Flow the members that havent been associated to a cluster at this
  # stage to the search for all models

  return 1;
}

sub dataflow_clusters {
    my $self = shift;

    my $clusterset = $self->compara_dba->get_NCTreeAdaptor->fetch_node_by_node_id($self->param('clusterset_id')) || $self->param('ccEngine')->clusterset;

    foreach my $cluster (@{$clusterset->children}) {
        $self->dataflow_output_id( {
            'nc_tree_id'    => $cluster->node_id,
            'clusterset_id' => $clusterset->node_id,
        } , 2);
    }
}

sub build_hash_models {
  my $self = shift;

    # vivification:
  $self->param('rfamclassify', {});
  $self->param('orphan_transcript_model_id', {});

  # We only take the longest transcript by doing a join with subset_member.
  # Right now, this only affects a few transcripts in Drosophila, but it's safer this way.
  my $sql = 
    "SELECT gene.member_id, gene.description, transcript.member_id, transcript.description ".
    "FROM subset_member sm, ".
    "member gene, ".
    "member transcript ".
    "WHERE ".
    "sm.member_id=transcript.member_id ".
    "AND gene.source_name='ENSEMBLGENE' ".
    "AND transcript.source_name='ENSEMBLTRANS' ".
    "AND transcript.gene_member_id=gene.member_id ".
    "AND transcript.description not like '%Acc:NULL%' ".
    "AND transcript.description not like '%Acc:'";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute;
  while( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($gene_member_id, $gene_description, $transcript_member_id, $transcript_description) = @$ref;
    $transcript_description =~ /Acc:(\w+)/;
    my $transcript_model_id = $1;
    if ($transcript_model_id =~ /MI\d+/) {
      # We use mirbase families to link
      my @family_ids = keys %{$self->param('mirbase_families')->{$transcript_model_id}};
      my $family_id = $family_ids[0];
      if (defined $family_id) {
        $transcript_model_id = $family_id;
      } else {
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
      }
    }
    # A simple hash classified by the Acc model ids
    if (defined $self->param('model_name_ids')->{$transcript_model_id}) {
        print STDERR "$transcript_model_id has been converted to id " . $self->param('model_name_ids')->{$transcript_model_id} . "\n" if ($self->debug);
        $transcript_model_id = $self->param('model_name_ids')->{$transcript_model_id};
    }
    $self->param('rfamclassify')->{$transcript_model_id}{$transcript_member_id} = 1;

    # Store list of orphan ids
    unless (defined($self->param('rfamcms')->{'model_id'}{$transcript_model_id}) || defined($self->param('rfamcms')->{'name'}{$transcript_model_id})) {
      $self->param('orphan_transcript_model_id')->{$transcript_model_id}++;     # NB: this data is never used afterwards
    }
  }

  $sth->finish;
  return 1;
}

sub build_hash_cms {
  my $self = shift;
  my $field = shift;

  my $sql = "SELECT $field from nc_profile";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute;
  while( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($field_value) = @$ref;
    $self->param('rfamcms')->{$field}{$field_value} = 1;
  }
}

sub load_names_model_id {
  my $self = shift;

    # vivification:
  $self->param('model_id_names', {});
  $self->param('model_name_ids', {});

  my $sql = "SELECT model_id, name from nc_profile";
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute;
  while( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($model_id, $name) = @$ref;
    $self->param('model_id_names')->{$model_id} = $name;
    $self->param('model_name_ids')->{$name} = $model_id;
  }
}

sub load_mirbase_families {
  my $self = shift;

  my $starttime = time();
  print STDERR "fetching mirbase families...\n" if ($self->debug);

  my $worker_temp_directory = $self->worker_temp_directory;
  my $url  = 'ftp://mirbase.org/pub/mirbase/CURRENT/';
  my $file = 'miFam.dat.gz';

  my $tmp_file = $worker_temp_directory . $file;
  my $mifam = $tmp_file;

  my $ftp_file = $url . $file;
  my $status = getstore($ftp_file, $tmp_file);
  die "load_mirbase_families: error $status on $ftp_file" unless is_success($status);

  $mifam =~ s/\.gz//;
  my $cmd = "rm -f $mifam";
  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    $self->throw("error deleting previously downloaded file $!\n");
  }

  my $cmd = "gunzip $tmp_file";
  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    $self->throw("error expanding mirbase families $!\n");
  }

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

sub tag_assembly_coverage_depth {
  my $self = shift;

  my @low_coverage  = ();
  my @high_coverage = ();

  foreach my $gdb (@{$self->param('cluster_mlss')->species_set}) {
    my $name = $gdb->name;
    my $coreDBA = $gdb->db_adaptor;
    my $metaDBA = $coreDBA->get_MetaContainerAdaptor;
    my $assembly_coverage_depth = @{$metaDBA->list_value_by_key('assembly.coverage_depth')}->[0];
    next unless (defined($assembly_coverage_depth) || $assembly_coverage_depth ne '');
    if ($assembly_coverage_depth eq 'low' || $assembly_coverage_depth eq '2x') {
      push @low_coverage, $gdb;
    } elsif ($assembly_coverage_depth eq 'high' || $assembly_coverage_depth eq '6x' || $assembly_coverage_depth >= 6) {
      push @high_coverage, $gdb;
    } else {
      $self->throw("Unrecognised assembly.coverage_depth value in core meta table: $assembly_coverage_depth [$name]\n");
    }
  }
  return undef unless(scalar(@low_coverage));

  my $species_set_adaptor = $self->compara_dba->get_SpeciesSetAdaptor;

  my $ss = $species_set_adaptor->fetch_all_by_GenomeDBs(\@low_coverage);
  if (defined($ss)) {
    my $value = $ss->get_tagvalue('name');
    if ($value eq 'low-coverage') {
      # Already stored, nothing needed
    } else {
      # We need to add the tag
      $species_set_adaptor->_store_tagvalue($ss->species_set_id,'name','low-coverage');
    }
  } else {
    # We need to create the species_set, then add the tag
    my $species_set_id;
    my $sth2 = $self->dbc->prepare("INSERT INTO species_set VALUES (?, ?)");
    foreach my $genome_db (@low_coverage) {
      my $genome_db_id = $genome_db->dbID;
      $sth2->execute(($species_set_id or undef), $genome_db_id);
      $species_set_id = $sth2->{'mysql_insertid'};
    }
    $sth2->finish();
    $species_set_adaptor->_store_tagvalue($species_set_id,'name','low-coverage');
  }
}

1;
