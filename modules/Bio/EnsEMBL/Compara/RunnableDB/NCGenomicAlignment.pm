#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::NCGenomicAlignment

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $ncgenomicalignment = Bio::EnsEMBL::Compara::RunnableDB::NCGenomicAlignment->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$ncgenomicalignment->fetch_input(); #reads from DB
$ncgenomicalignment->run();
$ncgenomicalignment->output();
$ncgenomicalignment->write_output(); #writes to DB

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


package Bio::EnsEMBL::Compara::RunnableDB::NCGenomicAlignment;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use POSIX qw(ceil floor);

use Bio::AlignIO;
use Bio::EnsEMBL::BaseAlignFeature;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Member;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  $self->{'ncgenomicalignment_starttime'} = time()*1000;
  $self->{'method'} = 'NCGenomicAlignment';

  $self->{memberDBA} = $self->compara_dba->get_MemberAdaptor;
  $self->{treeDBA} = $self->compara_dba->get_NCTreeAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  # Fetch sequences
  $self->{'input_fasta'} = $self->dump_sequences_to_workdir($self->{'nc_tree'});

# For long parameters, look at analysis_data
  if($self->{analysis_data_id}) {
    my $analysis_data_id = $self->{analysis_data_id};
    my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
    $self->get_params($analysis_data_params);
  }

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return if ($param_string eq "1");

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  print("parameters...\n");
  if (defined $params->{'max_gene_count'}) {
    $self->{'max_gene_count'} = $params->{'max_gene_count'};
    printf("  max_gene_count : %d\n", $self->{'max_gene_count'});
  }
  if(defined($params->{'nc_tree_id'})) {
    $self->{'nc_tree'} = 
         $self->compara_dba->get_NCTreeAdaptor->
         fetch_node_by_node_id($params->{'nc_tree_id'});
    printf("  nc_tree_id : %d\n", $self->{'nc_tree_id'});
  }
  if(defined($params->{'clusterset_id'})) {
    $self->{'clusterset_id'} = $params->{'clusterset_id'};
    printf("  clusterset_id : %d\n", $self->{'clusterset_id'});
  }

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  return if (defined($self->{single_peptide_tree}));
  $self->run_ncgenomicalignment;
  $self->run_ncgenomic_tree('phyml');
  $self->run_ncgenomic_tree('nj'); # Useful for 3-membered trees
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores nctree
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;
}


##########################################
#
# internal methods
#
##########################################

1;

sub dump_sequences_to_workdir {
  my $self = shift;
  my $cluster = shift;

  my $fastafile = $self->worker_temp_directory . "cluster_" . $cluster->node_id . ".fasta";
  print("fastafile = '$fastafile'\n") if($self->debug);

  my $seq_id_hash;
  my $residues = 0;
  print "fetching sequences...\n" if ($self->debug);
  my $member_list = $cluster->get_all_leaves;
  $self->{'tag_gene_count'} = scalar(@{$member_list});

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write!");
  my $count = 0;
  if (2 > scalar @{$member_list}) {
    $self->{single_peptide_tree} = 1;
    return 1;
  }
  foreach my $member (@{$member_list}) {
    my $description = $member->description;
    $description =~ /Acc\:(\w+)/;
    my $acc = $1;
    my $gene_member = $member->gene_member;
    $self->throw("Error fetching gene member") unless (defined($gene_member));
    my $gene = $gene_member->get_Gene;
    $self->throw("Error fetching gene") unless (defined($gene));
    # We fetch a slice that is 500% the size of the gene
    my $slice = $gene->slice->adaptor->fetch_by_Feature($gene,'500%');
    $self->throw("Error fetching slice") unless (defined($slice));
    my $seq = $slice->seq;
    $residues += length($seq);
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;
    $count++;
    print STDERR $member->stable_id. "\n" if ($self->debug);
    print OUTSEQ ">". $member->member_id . "_" . $member->taxon_id . "\n$seq\n";
    print STDERR "sequences $count\n" if ($count % 50 == 0);
  }
  close(OUTSEQ);

  if(scalar (@{$member_list}) <= 1) {
    $self->update_single_peptide_tree($cluster);
    $self->{single_peptide_tree} = 1;
  }

  $self->{'tag_residue_count'} = $residues;

  return $fastafile;
}

sub update_single_peptide_tree
{
  my $self   = shift;
  my $tree   = shift;

  foreach my $member (@{$tree->get_all_leaves}) {
    next unless($member->isa('Bio::EnsEMBL::Compara::AlignedMember'));
    next unless($member->sequence);
    $member->cigar_line(length($member->sequence)."M");
    $self->compara_dba->get_NCTreeAdaptor->store($member);
    printf("single_pepide_tree %s : %s\n", $member->stable_id, $member->cigar_line) if($self->debug);
  }
}


sub run_ncgenomicalignment {
  my $self = shift;

  return if (1 == $self->{single_peptide_tree});
  my $input_fasta = $self->{'input_fasta'};

  my $mfa_output = $self->worker_temp_directory . "output.mfa";

  my $ncgenomicalignment_executable = $self->analysis->program_file;
    unless (-e $ncgenomicalignment_executable) {
      print "Using default cmalign executable!\n";
      $ncgenomicalignment_executable = "/software/ensembl/compara/prank/090707/src/prank";
  }
  $self->throw("can't find a prank executable to run\n") unless(-e $ncgenomicalignment_executable);

  my $cmd = $ncgenomicalignment_executable;
  # /software/ensembl/compara/prank/090707/src/prank -noxml -notree -f=Fasta -o=/tmp/worker.904/cluster_17438.mfa -d=/tmp/worker.904/cluster_17438.fast

  $cmd .= " -quiet " unless ($self->debug);
  $cmd .= " -noxml -notree -f=Fasta -o=" . $mfa_output;
  $cmd .= " -d=" . $self->{input_fasta};

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  unless(system($cmd) == 0) {
    $self->throw("error running ncgenomicalignment, $!\n");
  }
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  # Prank renames the output by adding ".2.fas"
  my $fasta_output = $mfa_output . ".2.fas";

  $self->{ncgenomicalignment_output} = $fasta_output;

  return 0;
}

sub run_ncgenomic_tree {
  my $self = shift;
  my $method = shift;
  my $input_aln = $self->{ncgenomicalignment_output};

  my $njtree_phyml_executable = "/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/treebest";

  # Defining a species_tree
  # Option 1 is species_tree_string in nc_tree_tag, which then doesn't require tracking files around
  # Option 2 is species_tree_file which should still work for compatibility
  my $sql1 = "select value from nc_tree_tag where tag='species_tree_string'";
  my $sth1 = $self->dbc->prepare($sql1);
  $sth1->execute;
  my $species_tree_string = $sth1->fetchrow_hashref;
  $sth1->finish;
  my $eval_species_tree;
  eval {
    $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string->{value});
    my @leaves = @{$eval_species_tree->get_all_leaves};
  };

  $self->throw("can't find species_tree\n") if ($@);
  $self->{species_tree_string} = $species_tree_string->{value};
  my $spfilename = $self->worker_temp_directory . "spec_tax.nh";
  open SPECIESTREE, ">$spfilename" or die "$!";
  print SPECIESTREE $self->{species_tree_string};
  close SPECIESTREE;
  $self->{'species_tree_file'} = $spfilename;

  $self->{'newick_file'} = $input_aln . ".treebest.$method.nh";

  my $cmd = $njtree_phyml_executable;
  $cmd .= " $method ";
  $cmd .= " -Snf " if ($method eq 'phyml');
  $cmd .= " -s "   if ($method eq 'nj');
  $cmd .= $self->{'species_tree_file'};
  $cmd .= " ". $input_aln;
  $cmd .= " > " . $self->{'newick_file'};
  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  my $worker_temp_directory = $self->worker_temp_directory;
  $DB::single=1;1;
  unless(system("cd $worker_temp_directory; $cmd") == 0) {
    print("$cmd\n");
    $self->throw("error running treebest $method, $!\n");
  }

  $self->compara_dba->dbc->disconnect_when_inactive(0);

  $self->store_newick_into_protein_tree_tag_string($method);
  return;
}

sub store_newick_into_protein_tree_tag_string {
  my $self = shift;

  my $method = shift;
  my $newick_file =  $self->{'newick_file'};
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) {
    chomp $_;
    $newick .= $_;
  }
  close(FH);
  $newick =~ s/(\d+\.\d{4})\d+/$1/g; # We round up to only 4 digits
  return if ($newick eq '_null_;');
  my $tag = "pg_IT_" . $method;
  $self->{'nc_tree'}->store_tag($tag, $newick);
}

1;
