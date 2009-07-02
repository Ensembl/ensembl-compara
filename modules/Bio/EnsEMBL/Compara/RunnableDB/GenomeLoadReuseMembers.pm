#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadReuseMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadReuseMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->output();
$g_load_members->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadReuseMembers;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);
  print("input_id = ".$self->input_id."\n");
  $self->throw("Improper formated input_id") unless ($self->input_id =~ /{/);

  ########################################
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
  ########################################

  my $input_hash = eval($self->input_id);
  my $genome_db_id = $input_hash->{'gdb'};
  print("gdb = $genome_db_id\n");
  $self->throw("No genome_db_id in input_id") unless defined($genome_db_id);

  if($input_hash->{'pseudo_stableID_prefix'}) {
    $self->{'pseudo_stableID_prefix'} = $input_hash->{'pseudo_stableID_prefix'};
  }

  ########################################
  # Check if this is one that we need to reuse
  $self->{reuse_this} = 0;
  foreach my $reusable_gdb (@{$p->{reuse_gdb}}) {
    $self->{reusable_gdb}{$reusable_gdb} = 1;
  }
  $self->{reuse_this} = 1  if (defined($self->{reusable_gdb}{$input_hash->{'gdb'}}));
  ########################################

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);

  $self->{memberDBA} = $self->{'comparaDBA'}->get_MemberAdaptor();

  #get the Compara::GenomeDB object for the genome_db_id
  $self->{'genome_db'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
  
  
  #using genome_db_id, connect to external core database
  $self->{'coreDBA'} = $self->{'genome_db'}->db_adaptor();  
  $self->throw("Can't connect to genome database for id=$genome_db_id") unless($self->{'coreDBA'});
  
  #global boolean control value (whether the genes are also stored as members)
  $self->{'store_genes'} = 1;

  $self->{'verbose'} = 0;

  #variables for tracking success of process  
  $self->{'sliceCount'}       = 0;
  $self->{'geneCount'}        = 0;
  $self->{'realGeneCount'}    = 0;
  $self->{'transcriptCount'}  = 0;
  $self->{'longestCount'}     = 0;

  return 1;
}


sub run
{
  my $self = shift;

  #create subsets for the gene members, and the longest peptide members
  $self->{'pepSubset'}  = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' longest translations');
  $self->{'geneSubset'} = Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:".$self->{'genome_db'}->dbID ." ". $self->{'genome_db'}->name . ' genes');

  # This does an INSERT IGNORE or a SELECT if already exists
  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'pepSubset'});
  $self->{'comparaDBA'}->get_SubsetAdaptor->store($self->{'geneSubset'});

  if (1 == $self->{reuse_this}) {
    return 1 unless ($self->analysis->logic_name eq 'GenomeLoadReuseMembers');
    $self->create_temp_member_table;
    $self->load_reused_member_ids;
  }

  if (0 == $self->{reuse_this}) {
    return 1 unless ($self->analysis->logic_name eq 'GenomeLoadMembers');
  }

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(0);

  # main routine which takes a genome_db_id (from input_id) and
  # access the ensembl_core database, useing the SliceAdaptor
  # it will load all slices, all genes, and all transscripts
  # and convert them into members to be stored into compara
  $self->loadMembersFromCoreSlices();

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  $self->{'coreDBA'}->dbc->disconnect_when_inactive(1);

  if (1 == $self->{reuse_this}) {
    $self->drop_temp_member_table;
  }

  return 1;
}

sub write_output 
{
  my $self = shift;

  $DB::single=1;1;

  # We do the flow for both in the code, only one in loadGeneTreeSystem
  # Anyway, it will do the INSERT IGNORE in AnalysisJobAdaptor and
  # store it only once tried done more than one

#   if (1 == $self->{reuse_this}) {
#     return 1 unless ($self->analysis->logic_name eq 'GenomeLoadReuseMembers');
#   }

#   if (0 == $self->{reuse_this}) {
#     return 1 unless ($self->analysis->logic_name eq 'GenomeLoadMembers');
#   }

  my $output_id = "{'gdb'=>" . $self->{'genome_db'}->dbID .
                  ",'ss'=>" . $self->{'pepSubset'}->dbID . "}";
  $self->input_job->input_id($output_id);
  return 1;
}


######################################
#
# subroutines
#
#####################################

sub load_reused_member_ids {
  my $self = shift;
  my $starttime = time();

  return unless($self->{'genome_db'});
  my $gdb = $self->{'genome_db'};
  return unless $gdb;

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "reuse_member"."_"."$species_name"."_"."$gdb_id";
  my $sql = "SELECT stable_id, member_id, source_name from $tbl_name";
  print("$sql\n") if ($self->debug);
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to SELECT stable_id, member_id, source_name from $tbl_name\n", (time()-$starttime));
  while (my $href = $sth->fetchrow_hashref) {
    my $stable_id = $href->{stable_id}; my $source_name = $href->{source_name}; my $member_id = $href->{member_id};
    $self->{reuse_member_list}{$stable_id}{$source_name} = $member_id;
  }
  $sth->finish;

  return 1;
}

sub drop_temp_member_table {
  my $self = shift;
  my $starttime = time();

  $self->{comparaDBA_reuse} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{p}{reuse_db}, 'compara');
  unless (defined($self->{comparaDBA_reuse})) {
    my $reuse_db = $self->{p}{reuse_db};
    throw("Couldn't connect to reuse db $reuse_db: $!");
  }
  return unless($self->{'genome_db'});
  my $gdb = $self->{'genome_db'};
  return unless $gdb;

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "reuse_member"."_"."$species_name"."_"."$gdb_id";

  my $sql;
  $sql = "DROP TABLE IF EXISTS $tbl_name";
  print("$sql\n") if ($self->debug);
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to DROP TABLE IF EXISTS $tbl_name\n", (time()-$starttime));
  $sth->finish;

  return 1;
}

sub create_temp_member_table {
  my $self = shift;
  my $starttime = time();

  $self->{comparaDBA_reuse} = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{p}{reuse_db}, 'compara');
  unless (defined($self->{comparaDBA_reuse})) {
    my $reuse_db = $self->{p}{reuse_db};
    throw("Couldn't connect to reuse db $reuse_db: $!");
  }
  return unless($self->{'genome_db'});
  my $gdb = $self->{'genome_db'};
  return unless $gdb;

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "reuse_member"."_"."$species_name"."_"."$gdb_id";

  my $sql;
  $sql = "DROP TABLE IF EXISTS $tbl_name";
  print("$sql\n") if ($self->debug);
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to DROP TABLE IF EXISTS $tbl_name\n", (time()-$starttime));
  $sth->finish;

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

  my $cmd = "mysqldump --skip-quote-names --where=\"genome_db_id=$gdb_id\" -u $reuse_username $pass -h $reuse_host -P$reuse_port $reuse_dbname member";
  print("Running: # $cmd\n") if($self->debug);
  open(INRUN, "$cmd |") or $self->throw("Error mysqldump $tbl_name, $!\n");
  my @output = <INRUN>;
  my $exit_status = close(INRUN);
  foreach my $line (@output) {
    $line =~ s/((EXISTS|SKIP|TABLE|TABLES|INTO)) member/$1 $tbl_name/g;
  }

  my $tempfile = $self->worker_temp_directory . "$tbl_name.sql";
  open(OUTRUN, ">$tempfile") or $self->throw("Error writing mysqldump $tempfile, $!\n");
  print OUTRUN @output;
  close OUTRUN;
  $cmd = "cat $tempfile | mysql -u $dest_username $dest_pass -h $dest_host -P$dest_port $dest_dbname";
  my $ret = system($cmd);
  printf("  %1.3f secs to mysqldump $tbl_name\n", (time()-$starttime));
  if (0 != $ret) {
    throw("Error importing $tempfile: $ret\n");
  }

  return 1;
}


sub loadMembersFromCoreSlices
{
  my $self = shift;

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara
  my @slices = @{$self->{'coreDBA'}->get_SliceAdaptor->fetch_all('toplevel')};
  print("fetched ",scalar(@slices), " slices to load from\n");
  throw("problem: no toplevel slices") unless(scalar(@slices));

  SLICE: foreach my $slice (@slices) {
    $self->{'sliceCount'}++;
    #print("slice " . $slice->name . "\n");
    foreach my $gene (@{$slice->get_all_Genes}) {
      $self->{'geneCount'}++;

      # LV and C are for the Ig/TcR family, which rearranges
      # somatically so is considered as a different biotype in EnsEMBL
      # D and J are very short or have no translation at all
      if (lc($gene->biotype) eq 'protein_coding' || 
          lc($gene->biotype) eq 'IG_V_gene'      || 
          lc($gene->biotype) eq 'IG_C_gene'      || 
          lc($gene->biotype) eq 'C_segment'      || 
          lc($gene->biotype) eq 'V_segment') {
        $self->{'realGeneCount'}++;
        $self->store_gene_and_all_transcripts($gene);
        print STDERR $self->{'realGeneCount'} , " genes stored\n" if ($self->debug && (0 == ($self->{'realGeneCount'} % 100)));
      }
      # if($self->{'transcriptCount'} >= 100) { last SLICE; }
      # if($self->{'geneCount'} >= 1000) { last SLICE; }
    }
    # last SLICE;
  }

  print("loaded ".$self->{'sliceCount'}." slices\n");
  print("       ".$self->{'geneCount'}." genes\n");
  print("       ".$self->{'realGeneCount'}." real genes\n");
  print("       ".$self->{'transcriptCount'}." transscripts\n");
  print("       ".$self->{'longestCount'}." longest transcripts\n");
  print("       ".$self->{'pepSubset'}->count()." in Subset\n");
}


sub store_gene_and_all_transcripts
{
  my $self = shift;
  my $gene = shift;
  
  my @longestPeptideMember;
  my $maxLength=0;
  my $gene_member;
  my $gene_member_not_stored = 1;

  if(defined($self->{'pseudo_stableID_prefix'})) {
    $gene->stable_id($self->{'pseudo_stableID_prefix'} ."G_". $gene->dbID);
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    unless (defined $transcript->translation) {
      warn("COREDB error: No translation for transcript ", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
      next;
    }
#    This test might be useful to put here, thus avoiding to go further in trying to get a peptide
#    my $next = 0;
#    try {
#      $transcript->translate;
#    } catch {
#      warn("COREDB error: transcript does not translate", $transcript->stable_id, "(dbID=",$transcript->dbID.")\n");
#      $next = 1;
#    };
#    next if ($next);
    my $translation = $transcript->translation;

    if(defined($self->{'pseudo_stableID_prefix'})) {
      $transcript->stable_id($self->{'pseudo_stableID_prefix'} ."T_". $transcript->dbID);
      $translation->stable_id($self->{'pseudo_stableID_prefix'} ."P_". $translation->dbID);
    }

    $self->{'transcriptCount'}++;
    #print("gene " . $gene->stable_id . "\n");
    print("     transcript " . $transcript->stable_id ) if($self->{'verbose'});

    unless (defined $translation->stable_id) {
      throw("COREDB error: does not contain translation stable id for translation_id ". $translation->dbID."\n");
      next;
    }

    my $description = $self->fasta_description($gene, $transcript);

    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->{'genome_db'},
         -translate=>'yes',
         -description=>$description);

    print(" => member " . $pep_member->stable_id) if($self->{'verbose'});

    unless($pep_member->sequence) {
      print("  => NO SEQUENCE!\n") if($self->{'verbose'});
      next;
    }
    print(" len=",$pep_member->seq_length ) if($self->{'verbose'});

    # store gene_member here only if at least one peptide is to be loaded for
    # the gene.
    if($self->{'store_genes'} && $gene_member_not_stored) {
      print("     gene       " . $gene->stable_id ) if($self->{'verbose'});
      $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                                                                  -gene=>$gene,
                                                                  -genome_db=>$self->{'genome_db'});
      print(" => member " . $gene_member->stable_id) if($self->{'verbose'});

      eval {
        # We had this stable_id in reuse_db, so we store it with the same member_id again
        if (defined($self->{reuse_member_list}{$gene_member->stable_id}{ENSEMBLGENE})) {
          $gene_member->dbID($self->{reuse_member_list}{$gene_member->stable_id}{ENSEMBLGENE});
          $self->{memberDBA}->store_reused($gene_member);
        } else {
          my $stable_id = $gene_member->stable_id;
          if (1 == $self->{reuse_this}) {
            $self->input_job->update_status('FAILED');
            throw ("Reuse member set non identical for $stable_id: $!");
          }
          $self->{memberDBA}->store($gene_member);
        }
        print(" : stored") if($self->{'verbose'});
      };

      $self->{'geneSubset'}->add_member($gene_member);
      print("\n") if($self->{'verbose'});
      $gene_member_not_stored = 0;
    }

    if (defined($self->{reuse_member_list}{$pep_member->stable_id}{ENSEMBLPEP})) {
      $pep_member->dbID($self->{reuse_member_list}{$pep_member->stable_id}{ENSEMBLPEP});
      $self->{memberDBA}->store_reused($pep_member);
    } else {
      my $stable_id = $pep_member->stable_id;
      if (1 == $self->{reuse_this}) {
            $self->input_job->update_status('FAILED');
            throw ("Reuse member set non identical for $stable_id: $!");
      }
      $self->{memberDBA}->store($pep_member);
    }
    $self->{memberDBA}->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
    print(" : stored\n") if($self->{'verbose'});

    if($pep_member->seq_length > $maxLength) {
      $maxLength = $pep_member->seq_length;
      @longestPeptideMember = ($transcript, $pep_member);
    }

  }

  if(@longestPeptideMember) {
    my ($transcript, $member) = @longestPeptideMember;
    $self->{'pepSubset'}->add_member($member);
    $self->{'longestCount'}++;
    # print("     LONGEST " . $transcript->stable_id . "\n");
  }
}


sub fasta_description {
  my ($self, $gene, $transcript) = @_;

  my $description = "Transcript:" . $transcript->stable_id .
                    " Gene:" .      $gene->stable_id .
                    " Chr:" .       $gene->seq_region_name .
                    " Start:" .     $gene->seq_region_start .
                    " End:" .       $gene->seq_region_end;
  return $description;
}


1;
