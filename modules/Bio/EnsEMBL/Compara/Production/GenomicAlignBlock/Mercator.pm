#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mercator

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 CONTACT

Abel Ureta-Vidal <abel@ebi.ac.uk>

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Mercator;

use strict;
use Bio::EnsEMBL::Analysis::Runnable::Mercator;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;;
use Bio::EnsEMBL::Utils::Exception;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);

  #set defaults
  $self->pre_map(1);
  $self->method_link_type("SYNTENY");
  $self->maximum_gap(50000);

  # read parameters and input options
  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

#  throw("Missing dna_collection_name") unless($self->dna_collection_name);

  return 1;
}

sub run
{
  my $self = shift;
  $self->dumpMercatorFiles;

  unless (defined $self->output_dir) {
    my $output_dir = $self->worker_temp_directory . "/output_dir";
    $self->output_dir($output_dir);
  }
  if (! -e $self->output_dir) {
    mkdir($self->output_dir, 0777);
  }

  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Mercator
    (-input_dir => $self->input_dir,
     -output_dir => $self->output_dir,
     -genome_names => $self->genome_db_ids,
     -analysis => $self->analysis,
     -program => $self->analysis->program_file);
  $self->{'_runnable'} = $runnable;
  $runnable->run_analysis;
#  $self->output($runnable->output);
#  rmdir($runnable->workdir) if (defined $runnable->workdir);
}

sub write_output {
  my ($self) = @_;

  my %run_ids2synteny_and_constraints;
  my $synteny_region_ids = $self->store_synteny(\%run_ids2synteny_and_constraints);
  foreach my $sr_id (@{$synteny_region_ids}) {
    my $dataflow_output_id = "synteny_region_id=>$sr_id";
    if ($self->msa_method_link_species_set_id()) {
      $dataflow_output_id .= ",method_link_species_set_id=>".
          $self->msa_method_link_species_set_id();
    }
    if ($self->tree_analysis_data_id()) {
      $dataflow_output_id .= ",tree_analysis_data_id=>'".$self->tree_analysis_data_id()."'";
    } elsif ($self->tree_file()) {
      $dataflow_output_id .= ",tree_file=>'".$self->tree_file()."'";
    }
    $self->dataflow_output_id("{$dataflow_output_id}");
  }

  return 1;
}

=head2 store_synteny

  Arg[1]      : hashref $run_ids2synteny_and_constraints (unused)
  Example     : $self->store_synteny();
  Description : This method will store the syntenies defined by Mercator
                into the compara DB. The MethodLinkSpecieSet for these
                syntenies is created and stored if needed at this point.
                The IDs for the new Bio::EnsEMBL::Compara::SyntenyRegion
                objects are returned in an arrayref.
  ReturnType  : arrayref of integer
  Exceptions  :
  Status      : stable

=cut

sub store_synteny {
  my ($self, $run_ids2synteny_and_constraints) = @_;

  my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $sra = $self->{'comparaDBA'}->get_SyntenyRegionAdaptor;
  my $dfa = $self->{'comparaDBA'}->get_DnaFragAdaptor;
  my $gdba = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  my @genome_dbs;
  foreach my $gdb_id (@{$self->genome_db_ids}) {
    my $gdb = $gdba->fetch_by_dbID($gdb_id);
    push @genome_dbs, $gdb;
  }
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
    (-method_link_type => $self->method_link_type,
     -species_set => \@genome_dbs);
  $mlssa->store($mlss);
  $self->method_link_species_set($mlss);

  my $synteny_region_ids;
  my %dnafrag_hash;
  foreach my $sr (@{$self->{'_runnable'}->output}) {
    my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion
      (-method_link_species_set_id => $mlss->dbID);
    my $run_id;
    foreach my $dfr (@{$sr}) {
      my ($gdb_id, $seq_region_name, $start, $end, $strand);
      ($run_id, $gdb_id, $seq_region_name, $start, $end, $strand) = @{$dfr};
      next if ($seq_region_name eq 'NA' && $start eq 'NA' && $end eq 'NA' && $strand eq 'NA');
      $seq_region_name =~ s/\-\-\d+$//;
      my $dnafrag = $dnafrag_hash{$gdb_id."_".$seq_region_name};
      unless (defined $dnafrag) {
        $dnafrag = $dfa->fetch_by_GenomeDB_and_name($gdb_id, $seq_region_name);
        $dnafrag_hash{$gdb_id."_".$seq_region_name} = $dnafrag;
      }
      $strand = ($strand eq "+")?1:-1;
      my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion
        (-dnafrag_id => $dnafrag->dbID,
         -dnafrag_start => $start+1, # because half-open coordinate system
         -dnafrag_end => $end,
         -dnafrag_strand => $strand);
      $synteny_region->add_child($dnafrag_region);
    }
    $sra->store($synteny_region);
    push @{$synteny_region_ids}, $synteny_region->dbID;
    push @{$run_ids2synteny_and_constraints->{$run_id}}, $synteny_region->dbID;
    $synteny_region->release;
  }

  return $synteny_region_ids;
}


##########################################
#
# getter/setter methods
# 
##########################################

#sub dna_collection_name {
#  my $self = shift;
#  $self->{'_dna_collection_name'} = shift if(@_);
#  return $self->{'_dna_collection_name'};
#}

sub input_dir {
  my $self = shift;
  $self->{'_input_dir'} = shift if(@_);
  return $self->{'_input_dir'};
}

sub output_dir {
  my $self = shift;
  $self->{'_output_dir'} = shift if(@_);
  return $self->{'_output_dir'};
}

sub genome_db_ids {
  my $self = shift;
  $self->{'_genome_db_ids'} = shift if(@_);
  return $self->{'_genome_db_ids'};
}

sub cutoff_score {
  my $self = shift;
  $self->{'_cutoff_score'} = shift if(@_);
  return $self->{'_cutoff_score'};
}

sub cutoff_evalue {
  my $self = shift;
  $self->{'_cutoff_evalue'} = shift if(@_);
  return $self->{'_cutoff_evalue'};
}

sub pre_map {
  my $self = shift;
  $self->{'_pre_map'} = shift if(@_);
  return $self->{'_pre_map'};
}

sub mavid_constraints {
  my $self = shift;
  $self->{'_mavid_constraints'} = shift if(@_);
  return $self->{'_mavid_constraints'};
}

sub method_link_species_set {
  my $self = shift;
  $self->{'_method_link_species_set'} = shift if(@_);
  return $self->{'_method_link_species_set'};
}

sub msa_method_link_species_set_id {
  my $self = shift;
  $self->{'_msa_method_link_species_set_id'} = shift if(@_);
  return $self->{'_msa_method_link_species_set_id'};
}

sub tree_file {
  my $self = shift;
  $self->{'_tree_file'} = shift if(@_);
  return $self->{'_tree_file'};
}

sub tree_analysis_data_id {
  my $self = shift;
  $self->{'_tree_analysis_data_id'} = shift if(@_);
  return $self->{'_tree_analysis_data_id'};
}

sub all_hits {
  my $self = shift;
  $self->{'_all_hits'} = shift if(@_);
  return $self->{'_all_hits'};
}

sub method_link_type {
  my $self = shift;
  $self->{'_method_link_type'} = shift if(@_);
  return $self->{'_method_link_type'};
}

sub maximum_gap {
  my $self = shift;
  $self->{'_maximum_gap'} = shift if(@_);
  return $self->{'_maximum_gap'};
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);
  if(defined($params->{'input_dir'})) {
    $self->input_dir($params->{'input_dir'});
  }
  if(defined($params->{'output_dir'})) {
    $self->input_dir($params->{'output_dir'});
  }
  if(defined($params->{'gdb_ids'})) {
    $self->genome_db_ids($params->{'gdb_ids'});
  }
  if(defined($params->{'cutoff_score'})) {
    $self->cutoff_score($params->{'cutoff_score'});
  }
  if(defined($params->{'cutoff_evalue'})) {
    $self->cutoff_evalue($params->{'cutoff_evalue'});
  }
   if(defined($params->{'pre_map'})) { 
     $self->pre_map($params->{'pre_map'}); 
  }
  if(defined($params->{'mavid_constraints'})) {
    $self->mavid_constraints($params->{'mavid_constraints'});
  }
  if(defined($params->{'msa_method_link_species_set_id'})) {
    $self->msa_method_link_species_set_id($params->{'msa_method_link_species_set_id'});
  }
  if(defined($params->{'tree_file'})) {
    $self->tree_file($params->{'tree_file'});
  }
  if(defined($params->{'tree_analysis_data_id'})) {
    $self->tree_analysis_data_id($params->{'tree_analysis_data_id'});
  }
  if(defined($params->{'all_hits'})) {
    $self->all_hits($params->{'all_hits'});
  }
  if(defined($params->{'method_link_type'})) {
    $self->method_link_type($params->{'method_link_type'});
  }
  if(defined($params->{'maximum_gap'})) {
    $self->method_link_type($params->{'maximum_gap'});
  }
  return 1;
}

sub dumpMercatorFiles {
  my $self = shift;

#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);
  
  my $starttime = time();

  unless (defined $self->input_dir) {
    my $input_dir = $self->worker_temp_directory . "/input_dir";
    $self->input_dir($input_dir);
  }
  if (! -e $self->input_dir) {
    mkdir($self->input_dir, 0777);
  }

  my $dfa = $self->{'comparaDBA'}->get_DnaFragAdaptor;
  my $gdba = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  my $ma = $self->{'comparaDBA'}->get_MemberAdaptor;
  my $ssa = $self->{'comparaDBA'}->get_SubsetAdaptor;

  my $max_gap = $self->maximum_gap;

  foreach my $gdb_id (@{$self->genome_db_ids}) {

    my $dnafrags;

    ## Create the Chromosome file for Mercator
    my $gdb = $gdba->fetch_by_dbID($gdb_id);
    my $file = $self->input_dir . "/$gdb_id.chroms";
    open F, ">$file";
    foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($gdb)}) {
      print F $df->name . "\t" . $df->length,"\n";
      if ($max_gap and $df->coord_system_name eq "chromosome") {
        my $core_dba = $gdb->db_adaptor;
        my $coord_system_adaptor = $core_dba->get_CoordSystemAdaptor();
        my $assembly_mapper_adaptor = $core_dba->get_AssemblyMapperAdaptor();
        my $chromosome_coord_system = $coord_system_adaptor->fetch_by_name("chromosome");
        my $seq_level_coord_system = $coord_system_adaptor->fetch_sequence_level;

        my $assembly_mapper = $assembly_mapper_adaptor->fetch_by_CoordSystems(
            $chromosome_coord_system, $seq_level_coord_system);
        my @mappings = $assembly_mapper->map($df->name, 1, $df->length, 1, $chromosome_coord_system);

        my $part = 1;
        foreach my $this_mapping (@mappings) {
          next if ($this_mapping->isa("Bio::EnsEMBL::Mapper::Coordinate"));
          next if ($this_mapping->length < $max_gap);
          # print join(" :: ", $df->name, $this_mapping->length, $this_mapping->start, $this_mapping->end), "\n";
          print F $df->name . "--$part\t" . $df->length,"\n";
          $dnafrags->{$df->name}->{$this_mapping->start} = $df->name."--".$part;
          $part++;
        }
      }
    }
    close F;

    ## Create the anchor file for Mercator
    my $ss = $ssa->fetch_by_set_description("gdb:".$gdb->dbID ." ". $gdb->name . ' coding exons');
    $file = $self->input_dir . "/$gdb_id.anchors";
    open F, ">$file";
    foreach my $member (@{$ma->fetch_by_subset_id($ss->dbID)}) {
      my $strand = "+";
      $strand = "-" if ($member->chr_strand == -1);
      my $chr_name = $member->chr_name;
      if (defined($dnafrags->{$member->chr_name})) {
        foreach my $this_start (sort {$a <=> $b} keys %{$dnafrags->{$member->chr_name}}) {
          if ($this_start > $member->chr_start - 1) {
            last;
          } else {
            $chr_name = ($dnafrags->{$member->chr_name}->{$this_start} or $member->chr_name);
          }
        }
      }
      print F $member->dbID . "\t" .
        $chr_name ."\t" .
          $strand . "\t" .
            ($member->chr_start - 1) ."\t" .
              $member->chr_end ."\t1\n";
    }
    close F;
  }


  my @genome_db_ids = @{$self->genome_db_ids};

  while (my $gdb_id1 = shift @genome_db_ids) {
    foreach my $gdb_id2 (@genome_db_ids) {
      my $file = $self->input_dir . "/$gdb_id1" . "-$gdb_id2.hits";
      open F, ">$file";
      my $sql = $self->get_sql_for_peptide_hits($gdb_id1, $gdb_id2);
      my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
      my ($qmember_id,$hmember_id,$score1,$evalue1,$score2,$evalue2);
      $sth->execute($gdb_id1, $gdb_id2);
      $sth->bind_columns( \$qmember_id,\$hmember_id,\$score1,\$evalue1,\$score2,\$evalue2);
      my %pair_seen = ();
      while ($sth->fetch()) {
        next if ($pair_seen{$qmember_id . "_" . $hmember_id});
        my $score = ($score1>$score2)?$score2:$score1; ## Use smallest score
        my $evalue = ($evalue1>$evalue2)?$evalue1:$evalue2; ## Use largest e-value
        next if (defined $self->cutoff_score && $score < $self->cutoff_score);
        next if (defined $self->cutoff_evalue && $evalue > $self->cutoff_evalue);
        print F "$qmember_id\t$hmember_id\t" . int($score). "\t$evalue\n";
        $pair_seen{$qmember_id . "_" . $hmember_id} = 1;
      }
      close F;
      $sth->finish();
    }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->collection_name);}

#  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}


sub get_sql_for_peptide_hits {
  my ($self, $gdb_id1, $gdb_id2) = @_;
  my $sql;

  my $table_name1 = $self->get_table_name_from_dbID($gdb_id1);
  my $table_name2 = $self->get_table_name_from_dbID($gdb_id2);

  if ($self->all_hits) {
    ## Use all best hits
    $sql = "SELECT paf1.qmember_id, paf1.hmember_id, paf1.score, paf1.evalue, paf2.score, paf2.evalue
      FROM $table_name1 paf1, $table_name2 paf2
      WHERE paf1.qgenome_db_id = ? AND paf1.hgenome_db_id = ?
        AND paf1.qmember_id = paf2.hmember_id AND paf1.hmember_id = paf2.qmember_id
        AND (paf1.hit_rank = 1 OR paf2.hit_rank = 1)";
  } else {
    ## Use best reciprocal hits only
    $sql = "SELECT paf1.qmember_id, paf1.hmember_id, paf1.score, paf1.evalue, paf2.score, paf2.evalue
      FROM $table_name1 paf1, $table_name2 paf2
      WHERE paf1.qgenome_db_id = ? AND paf1.hgenome_db_id = ?
        AND paf1.qmember_id = paf2.hmember_id AND paf1.hmember_id = paf2.qmember_id
        AND paf1.hit_rank = 1 AND paf2.hit_rank = 1";
  }

  return $sql;
}


sub get_table_name_from_dbID {
  my ($self, $gdb_id) = @_;
  my $table_name = "peptide_align_feature";

  my $gdba = $self->{'comparaDBA'}->get_GenomeDBAdaptor;
  my $gdb = $gdba->fetch_by_dbID($gdb_id);
  return $table_name if (!$gdb);

  $table_name .= "_" . lc($gdb->name) . "_" . $gdb_id;
  $table_name =~ s/ /_/g;

  return $table_name;
}

1;
