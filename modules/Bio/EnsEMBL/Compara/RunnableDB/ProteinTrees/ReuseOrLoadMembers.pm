
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ReuseOrLoadMembers

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $g_load_members = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ReuseOrLoadMembers->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$g_load_members->fetch_input(); #reads from DB
$g_load_members->run();
$g_load_members->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This RunnableDB has two modes, depending on the logic_name and whether the 'reuse' mode was actually requested.

In 'non-reuse' mode it loads peptide+gene members from a particular core database defined by $self->param('genome_db_id').

In 'reuse' mode it tries to reuse the peptide+gene members for a particular $self->param('genome_db_id') from the previous release's database.

=cut

=head1 CONTACT

Describe contact details here

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::ReuseOrLoadMembers;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception;

use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Subset;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'store_genes'     => 1, # whether the genes are also stored as members
    };
}


sub fetch_input {
    my $self = shift @_;

        # not sure if this can be done directly in param_defaults because of the order things get initialized:
    unless(defined($self->param('verbose'))) {
        $self->param('verbose', $self->debug == 2);
    }

    my $genome_db_id = $self->param('genome_db_id')
        or die "'genome_db_id' is an obligatory parameter";

    unless( defined( $self->param('reuse_this') ) ) {
        die "'reuse_this' is an obligatory parameter";
    }

    my $compara_dba = $self->compara_dba();

        #get the Compara::GenomeDB object for the genome_db_id:
    my $genome_db = $self->param('genome_db', $compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) )
        or die "Can't fetch the genome_db object (gdb_id=$genome_db_id) from Compara";
  
        #using genome_db_id, connect to external core database:
    $self->param('core_dba', $genome_db->db_adaptor() )
        or die "Can't connect to external core database for gdb=$genome_db_id";

    my $genome_db_name = $genome_db->name;

        # this one will be used later for dataflow:
    $self->param('per_genome_suffix', $genome_db_name.'_'.$genome_db_id );

        #create subsets for the gene members, and the longest peptide members:
    $self->param('pepSubset', Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:$genome_db_id $genome_db_name longest translations") );

    $self->param('geneSubset', Bio::EnsEMBL::Compara::Subset->new(
      -name=>"gdb:$genome_db_id $genome_db_name genes") );

        # This does an INSERT IGNORE or a SELECT if already exists:
    $compara_dba->get_SubsetAdaptor->store($self->param('pepSubset'));
    $compara_dba->get_SubsetAdaptor->store($self->param('geneSubset'));


    if ($self->param('coding_exons')) {
        $self->param('exonSubset', Bio::EnsEMBL::Compara::Subset->new(
          -name=>"gdb:$genome_db_id $genome_db_name coding exons") );

        $compara_dba->get_SubsetAdaptor->store($self->param('exonSubset'));
    }
}


sub run {
    my $self = shift @_;

    my $compara_dba    = $self->compara_dba();
    my $genome_db_id   = $self->param('genome_db_id');

    my $reuse_this      = $self->param('reuse_this');

    my $reuse_table_name = 'reuse_member_'.$self->param('per_genome_suffix');

    $self->param('reuse_member_hash', {});

    if ( $reuse_this) {
        $self->drop_temp_member_table( $reuse_table_name );
        $self->create_temp_member_table( $reuse_table_name );
        $self->load_reused_member_ids( $reuse_table_name );
    }

    $compara_dba->dbc->disconnect_when_inactive(0);
    $self->param('core_dba')->dbc->disconnect_when_inactive(0);

        # main routine to load members from a particular CoreDB:
    $self->loadMembersFromCoreSlices();

    $compara_dba->dbc->disconnect_when_inactive(1);
    $self->param('core_dba')->dbc->disconnect_when_inactive(1);

    if( $reuse_this ) {
        $self->drop_temp_member_table( $reuse_table_name );
    }
}


sub write_output {
    my $self = shift @_;

    my $genome_db_id      = $self->param('genome_db_id');
    my $reuse_this        = $self->param('reuse_this');
    my $subset_id         = $self->param('pepSubset')->dbID;

        #Overwrite subset_id if doing coding_exons (eg MercatorPecan pipeline) :
    if ($self->param('coding_exons')) {
        $subset_id = $self->param('exonSubset')->dbID;
    }
    my $per_genome_suffix = $self->param('per_genome_suffix');

    $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'reuse_this' => $reuse_this, 'subset_id' => $subset_id, 'per_genome_suffix' => $per_genome_suffix } , 1);
}


######################################
#
# subroutines
#
#####################################

sub dbc_2_mysql_params {    # NB: this subroutine is not a method!
    my $dbc = shift @_;

    my $username = $dbc->username;
    my $password = $dbc->password;
    my $pass     = $password ? "-p'$password'" : '';
    my $host     = $dbc->host;
    my $port     = $dbc->port;
    my $dbname   = $dbc->dbname;

    return " -h$host -P$port -u$username $pass $dbname ";
}

sub dbconn_2_mysql_params {     # NB: this subroutine is not a method!
    my $dbconn_hash = shift @_;

    my $host     = $dbconn_hash->{-host};
    my $port     = $dbconn_hash->{-port};
    my $username = $dbconn_hash->{-user};
    my $password = $dbconn_hash->{-pass};
    my $pass     = $password ? "-p'$password'" : '';
    my $dbname   = $dbconn_hash->{-dbname};

    return " -h$host -P$port -u$username $pass $dbname ";
}

sub drop_temp_member_table {
    my $self             = shift @_;
    my $reuse_table_name = shift @_;

    my $starttime = time();
    my $sql = "DROP TABLE IF EXISTS $reuse_table_name";
    print("$sql\n") if ($self->debug);
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    printf("  %1.3f secs to '$sql'\n", (time()-$starttime));
    $sth->finish;
}

sub create_temp_member_table {
    my $self             = shift @_;
    my $reuse_table_name = shift @_;

    my $genome_db_id     = $self->param('genome_db_id');

    my $reuse_db = $self->param('reuse_db') or die "'reuse_db' connection parameters hash has to be defined in reuse mode";

    my $cmd = "mysqldump --skip-quote-names --where=\"genome_db_id=${genome_db_id}\" ".dbconn_2_mysql_params($reuse_db). ' member';
    print("Running: # $cmd\n") if($self->debug);

    my $starttime = time();
    open(INRUN, "$cmd |") or die "Could not open pipe [$cmd |] for reading : $!";
    my @output = <INRUN>;
    my $exit_status = close(INRUN);
    foreach my $line (@output) {
        $line =~ s/((EXISTS|SKIP|TABLE|TABLES|INTO)) member/$1 $reuse_table_name/g;
    }

    my $tempfile = $self->worker_temp_directory . "$reuse_table_name.sql";
    open(OUTRUN, ">$tempfile") or die "Could not open mysqldump file '$tempfile' for writing : $!";
    print OUTRUN @output;
    close OUTRUN;

    $cmd = "cat $tempfile | mysql ".dbc_2_mysql_params($self->dbc);
    my $return_value = system($cmd);
    printf("  %1.3f secs to mysqldump $reuse_table_name\n", (time()-$starttime));
    if($return_value) {
        $self->throw("Error importing $tempfile: $return_value\n");
    }
}

sub load_reused_member_ids {
    my $self             = shift @_;
    my $reuse_table_name = shift @_;

    my $starttime = time();
    my $sql = "SELECT stable_id, member_id, source_name from $reuse_table_name";
    print("$sql\n") if ($self->debug);
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    printf("  %1.3f secs to '$sql'\n", (time()-$starttime));

    my $reuse_member_hash = $self->param('reuse_member_hash');
    while (my ($stable_id, $member_id, $source_name)= $sth->fetchrow_array() ) {
        $reuse_member_hash->{$stable_id}{$source_name} = $member_id;
    }
    $sth->finish;
}

sub loadMembersFromCoreSlices {
  my $self = shift @_;

        # initialize internal counters for tracking success of process:
    $self->param('sliceCount',      0);
    $self->param('geneCount',       0);
    $self->param('realGeneCount',   0);
    $self->param('transcriptCount', 0);
    $self->param('longestCount',    0);
    $self->param('exonCount',       0);

  #from core database, get all slices, and then all genes in slice
  #and then all transcripts in gene to store as members in compara

  my @slices = @{$self->param('core_dba')->get_SliceAdaptor->fetch_all('toplevel')};
  print("fetched ",scalar(@slices), " slices to load from\n");
  $self->throw("problem: no toplevel slices") unless(scalar(@slices));

  my $genes;

  SLICE: foreach my $slice (@slices) {
    $self->param('sliceCount', $self->param('sliceCount')+1 );
    #print("slice " . $slice->name . "\n");

    @$genes = ();
    my $current_end;

    foreach my $gene (sort {$a->start <=> $b->start} @{$slice->get_all_Genes}) {
      $self->param('geneCount', $self->param('geneCount')+1 );
      # LV and C are for the Ig/TcR family, which rearranges
      # somatically so is considered as a different biotype in EnsEMBL
      # D and J are very short or have no translation at all

      if (defined $self->param('coding_exons')) {
          $current_end = $gene->end unless (defined $current_end);
          $self->param('geneCount', $self->param('geneCount')+1);
          if((lc($gene->biotype) eq 'protein_coding')) {
              $self->param('realGeneCount', $self->param('realGeneCount')+1 );
    #	      print "gene_start " . $gene->start . " end $current_end\n";
              if ($gene->start <= $current_end) {
                  push @$genes, $gene;
                  $current_end = $gene->end if ($gene->end > $current_end);
              } else {
                  $self->store_all_coding_exons($genes);
                  @$genes = ();
                  $current_end = $gene->end;
                  push @$genes, $gene;
              }
          }
      } else {
          if (   lc($gene->biotype) eq 'protein_coding'
             || lc($gene->biotype) eq 'ig_v_gene'
             || lc($gene->biotype) eq 'ig_c_gene'
             #         || lc($gene->biotype) eq 'polymorphic_pseudogene'     # lg4: not sure if this biotype is ok, as it has a stop codon in the middle
             ) {
              $self->param('realGeneCount', $self->param('realGeneCount')+1 );
              
              $self->store_gene_and_all_transcripts($gene);
              
              print STDERR $self->param('realGeneCount') , " genes stored\n" if ($self->debug && (0 == ($self->param('realGeneCount') % 100)));
          }
      }
    } # foreach

    if ($self->param('coding_exons')) {
        $self->store_all_coding_exons($genes);
    }
  }

  print("loaded ".$self->param('sliceCount')." slices\n");
  print("       ".$self->param('geneCount')." genes\n");
  print("       ".$self->param('realGeneCount')." real genes\n");
  print("       ".$self->param('transcriptCount')." transcripts\n");
  print("       ".$self->param('pepSubset')->count()." in Subset\n");
}

sub store_gene_and_all_transcripts {
  my $self = shift;
  my $gene = shift;

  my $member_adaptor = $self->compara_dba->get_MemberAdaptor();
  
  my @canonicalPeptideMember;
  my $gene_member;
  my $gene_member_not_stored = 1;

  if(defined($self->param('pseudo_stableID_prefix'))) {
    $gene->stable_id($self->param('pseudo_stableID_prefix') ."G_". $gene->dbID);
  }

  my $canonical_transcript; my $canonical_transcript_stable_id;
  eval {
    $canonical_transcript = $gene->canonical_transcript;
    $canonical_transcript_stable_id = $canonical_transcript->stable_id;
  };
  if (!defined($canonical_transcript) && !defined($self->param('force_unique_canonical'))) {
    print STDERR "WARN: ", $gene->stable_id, " has no canonical transcript\n" if ($self->debug);
    return 1;
  }

  foreach my $transcript (@{$gene->get_all_Transcripts}) {
    my $translation = $transcript->translation;
    next unless (defined $translation);

    if (!defined($self->param('force_unique_canonical'))) {
      if ($canonical_transcript->biotype ne $gene->biotype) {
        # This can happen when the only transcripts are, e.g., NMDs
        print STDERR "INFO: ", $canonical_transcript->stable_id, " biotype ", $canonical_transcript->biotype, " is canonical\n" if ($self->debug);
      }
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

    if(defined($self->param('pseudo_stableID_prefix'))) {
      $transcript->stable_id($self->param('pseudo_stableID_prefix') ."T_". $transcript->dbID);
      $translation->stable_id($self->param('pseudo_stableID_prefix') ."P_". $translation->dbID);
    }

    $self->param('transcriptCount', $self->param('transcriptCount')+1 );
    #print("gene " . $gene->stable_id . "\n");
    print("     transcript " . $transcript->stable_id ) if($self->param('verbose'));

    unless (defined $translation->stable_id) {
      $self->throw("CoreDB error: does not contain translation stable id for translation_id ". $translation->dbID."\n");
      next;
    }

    my $description = $self->fasta_description($gene, $transcript);

    my $pep_member = Bio::EnsEMBL::Compara::Member->new_from_transcript(
         -transcript=>$transcript,
         -genome_db=>$self->param('genome_db'),
         -translate=>'yes',
         -description=>$description);

    print(" => member " . $pep_member->stable_id) if($self->param('verbose'));

    unless($pep_member->sequence) {
      print "  => NO SEQUENCE for member " . $pep_member->stable_id;
      next;
    }
    print(" len=",$pep_member->seq_length ) if($self->param('verbose'));

    # store gene_member here only if at least one peptide is to be loaded for
    # the gene.
    if($self->param('store_genes') && $gene_member_not_stored) {
      print("     gene       " . $gene->stable_id ) if($self->param('verbose'));
      $gene_member = Bio::EnsEMBL::Compara::Member->new_from_gene(
                                                                  -gene=>$gene,
                                                                  -genome_db=>$self->param('genome_db'));
      print(" => member " . $gene_member->stable_id) if($self->param('verbose'));

      # We had this stable_id in reuse_db, so we store it with the same member_id again
      if (my $gene_member_id = $self->param('reuse_member_hash')->{$gene_member->stable_id}{ENSEMBLGENE}) {
        $gene_member->dbID( $gene_member_id );
        $member_adaptor->store_reused($gene_member);
      } else {
        my $stable_id = $gene_member->stable_id;
        if ( $self->param('reuse_this') ) {
          $self->input_job->transient_error(0);
          die "Reuse member set non identical for $stable_id";
        }
        $member_adaptor->store($gene_member);
      }
      print(" : stored") if($self->param('verbose'));

      $self->param('geneSubset')->add_member($gene_member);
      print("\n") if($self->param('verbose'));
      $gene_member_not_stored = 0;
    }

    if (my $pep_member_id = $self->param('reuse_member_hash')->{$pep_member->stable_id}{ENSEMBLPEP}) {
      $pep_member->dbID( $pep_member_id );
      $member_adaptor->store_reused($pep_member);
    } else {
      my $stable_id = $pep_member->stable_id;
      if ( $self->param('reuse_this') ) {
            $self->input_job->transient_error(0);
            die "Reuse member set non identical for $stable_id";
      }
      $member_adaptor->store($pep_member);
    }
    $member_adaptor->store_gene_peptide_link($gene_member->dbID, $pep_member->dbID);
    print(" : stored\n") if($self->param('verbose'));

    if(($transcript->stable_id eq $canonical_transcript_stable_id) || defined($self->param('force_unique_canonical'))) {
      @canonicalPeptideMember = ($transcript, $pep_member);
    }

  }

  if(@canonicalPeptideMember) {
    my ($transcript, $member) = @canonicalPeptideMember;
    $self->param('pepSubset')->add_member($member);
    $self->param('longestCount', $self->param('longestCount') );
    # print("     LONGEST " . $transcript->stable_id . "\n");
  }
  return 1;
}

sub store_all_coding_exons {
  my ($self, $genes) = @_;

  return 1 if (scalar @{$genes} == 0);

  my $member_adaptor = $self->compara_dba->get_MemberAdaptor();
  my $genome_db = $self->param('genome_db');
  my @exon_members = ();

  foreach my $gene (@{$genes}) {
      #print " gene " . $gene->stable_id . "\n";

    foreach my $transcript (@{$gene->get_all_Transcripts}) {
      $self->param('transcriptCount', $self->param('transcriptCount')+1);

      print("     transcript " . $transcript->stable_id ) if($self->param('verbose'));
      
      foreach my $exon (@{$transcript->get_all_translateable_Exons}) {
#	  print "        exon " . $exon->stable_id . "\n";
        unless (defined $exon->stable_id) {
          warn("COREDB error: does not contain exon stable id for translation_id ".$exon->dbID."\n");
          next;
        }
        my $description = $self->fasta_description($exon, $transcript);
        
        my $exon_member = new Bio::EnsEMBL::Compara::Member;
        $exon_member->taxon_id($genome_db->taxon_id);
        if(defined $description ) {
          $exon_member->description($description);
        } else {
          $exon_member->description("NULL");
        }
        $exon_member->genome_db_id($genome_db->dbID);
        $exon_member->chr_name($exon->seq_region_name);
        $exon_member->chr_start($exon->seq_region_start);
        $exon_member->chr_end($exon->seq_region_end);
        $exon_member->chr_strand($exon->seq_region_strand);
        $exon_member->version($exon->version);
        $exon_member->stable_id($exon->stable_id);
        $exon_member->source_name("ENSEMBLEXON");

	#Not sure what this should be but need to set it to something or else the members do not get added
	#to the member table in the store method of MemberAdaptor
	$exon_member->display_label("NULL");
        
        my $seq_string = $exon->peptide($transcript)->seq;
        ## a star or a U (selenocysteine) in the seq breaks the pipe to the cast filter for Blast
        $seq_string =~ tr/\*U/XX/;
        if ($seq_string =~ /^X+$/) {
          warn("X+ in sequence from exon " . $exon->stable_id."\n");
        }
        else {
          $exon_member->sequence($seq_string);
        }

        print(" => member " . $exon_member->stable_id) if($self->param('verbose'));

        unless($exon_member->sequence) {
          print("  => NO SEQUENCE!\n") if($self->param('verbose'));
          next;
        }
        print(" len=",$exon_member->seq_length ) if($self->param('verbose'));
        next if ($exon_member->seq_length < $self->param('min_length'));
        push @exon_members, $exon_member;
      }
    }
  }
  @exon_members = sort {$b->seq_length <=> $a->seq_length} @exon_members;
  my @exon_members_stored = ();
  while (my $exon_member = shift @exon_members) {
    my $not_to_store = 0;
    foreach my $stored_exons (@exon_members_stored) {
      if ($exon_member->chr_start <=$stored_exons->chr_end &&
          $exon_member->chr_end >= $stored_exons->chr_start) {
        $not_to_store = 1;
        last;
      }
    }
    next if ($not_to_store);
    push @exon_members_stored, $exon_member;

    eval {
	#if (my $exon_member_id = $self->param('reuse_member_hash')->{$exon_member->stable_id}{ENSEMBLEXON}) {
	if (my $exon_member_id = $self->param('reuse_member_hash')->{$exon_member->stable_id}{''}) {
	    $exon_member->dbID( $exon_member_id );
	    $member_adaptor->store_reused($exon_member);
	    #print "Reuse member\n";
	} else {
	    my $stable_id = $exon_member->stable_id;
	    if ( $self->param('reuse_this') ) {
		$self->input_job->transient_error(0);
		$self->throw ("Reuse member set non identical for $stable_id: $!")
	    }
	    #print "New member\n";
	    $member_adaptor->store($exon_member);
	    print(" : stored\n") if($self->param('verbose'));
	}
    };
    $self->param('exonSubset')->add_member($exon_member);
    $self->param('exonCount', $self->param('exonCount')+1);
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
