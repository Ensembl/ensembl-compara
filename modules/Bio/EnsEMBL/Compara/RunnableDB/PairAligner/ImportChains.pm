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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportChains

=head1 DESCRIPTION

Reads a Chain file and imports the data into a compara database, saving the results in the 
genomic_align_block and genomic_align tables with a given method_link_species_set_id. 
Download from:
http://hgdownload.cse.ucsc.edu/downloads.html
Choose reference species
Choose Pairwise Alignments
wget http://hgdownload.cse.ucsc.edu/goldenPath/hg19/vsSelf/hg19.hg19.all.chain.gz

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ImportChains;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing;
use Bio::EnsEMBL::Analysis::Runnable::AlignmentChains;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Utils::Exception qw(throw );

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

our @ISA = qw(Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing);

############################################################

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  $self->SUPER::fetch_input;
  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $dafa = $self->compara_dba->get_DnaAlignFeatureAdaptor;
  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  my $dfa = $self->compara_dba->get_DnaFragAdaptor;
  my $gaba = $self->compara_dba->get_GenomicAlignBlockAdaptor;
  $gaba->lazy_loading(0);

  #set default (not self alignment)
  $self->param('self_alignment', 0);

  #get ref species
  my $ref_gdb = $gdba->fetch_by_name_assembly($self->param('ref_species'));

  #get non-ref species. If self alignment, set non-ref species to be the same as ref-species
  my $non_ref_gdb;
  if (!$self->param('non_ref_species')) {
      $self->param('non_ref_species', $self->param('ref_species'));
      $self->param('self_alignment', 1);
  }
  $non_ref_gdb = $gdba->fetch_by_name_assembly($self->param('non_ref_species'));

  #get method_link_species_set of Chains, defined by output_method_link_type
  my $method = Bio::EnsEMBL::Compara::Method->new( -type => $self->param('output_method_link_type'),
                                                   -class => "GenomicAlignBlock.pairwise_alignment");

  my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -genome_dbs => ($ref_gdb->dbID == $non_ref_gdb->dbID)
                            ? [$ref_gdb]
                            : [$ref_gdb, $non_ref_gdb]
  );
        
  my $out_mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method             => $method,
        -species_set    => $species_set,
  );

  $mlssa->store($out_mlss);

  throw("No MethodLinkSpeciesSet for method_link_type". $self->param('output_method_link_type') . " and species " . $ref_gdb->name . " and " . $non_ref_gdb->name)
    if not $out_mlss;
  
  ######## needed for output####################
  $self->param('output_MethodLinkSpeciesSet', $out_mlss);

  my $ref_dnafrags = $dfa->fetch_all_by_GenomeDB_region($ref_gdb);
  foreach my $ref_dnafrag (@$ref_dnafrags) {
      ######### needed for output ######################################
      my $ucsc_name = $self->get_ucsc_name($ref_gdb->dbID, $ref_dnafrag->name);
      $self->param('query_DnaFrag_hash')->{$ucsc_name} = $ref_dnafrag if (defined $ucsc_name);
  }

  my $non_ref_dnafrags = $dfa->fetch_all_by_GenomeDB_region($non_ref_gdb);
  foreach my $non_ref_dnafrag (@$non_ref_dnafrags) {
      ######### needed for output ######################################
      my $ucsc_name = $self->get_ucsc_name($non_ref_gdb->dbID, $non_ref_dnafrag->name);
      $self->param('target_DnaFrag_hash')->{$ucsc_name} = $non_ref_dnafrag if (defined $ucsc_name);
  }

  my $features;
  my $query_slice = "";
  my $target_slices;
  @$features = [];
  @$target_slices = [];

  my %parameters = (-analysis      => $fake_analysis,
		   -features       => $features,
		   -query_slice    => $query_slice,
		   -target_slices  => $target_slices);

  my $runnable = Bio::EnsEMBL::Analysis::Runnable::AlignmentChains->new(%parameters);
  $self->param('runnable', $runnable);

  ##################################
  # read the chain file
  ##################################
  my $fh;
  open $fh, $self->param('chain_file') or throw("Could not open chainfile '" . $self->param('chain_file') . "' for reading\n");

  my $chains = $self->parse_Chain_file($fh, $self->param('seek_offset'), $self->param('num_lines'));
  close($fh);
  $runnable->output($chains);

}

sub run {
    my $self = shift;

    #print "RUNNING \n";
    my $runnable = $self->param('runnable');
    my $converted_chains = $self->convert_output($runnable->output, 0);
    $self->param('chains', $converted_chains);
    rmdir($runnable->workdir) if (defined $runnable->workdir);
}


#
#get the UCSC to Ensembl name mappings from the compara database
#
sub get_ucsc_name {
    my ($self, $genome_db_id, $ensembl_name) = @_;
    my $sql = "SELECT ucsc FROM ucsc_to_ensembl_mapping WHERE ensembl = '$ensembl_name'";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    my $ucsc_name;
    $sth->bind_columns(\$ucsc_name);
    my $ucsc_nmae = $sth->fetch();
    $sth->finish();
    
    return $ucsc_name;
}


#Taken from Analysis/Runnable/AlignmentChains.pm but with the addition of:
#$fp->group_id($data[11]); #store chain_id
#which cannot be added to the original code, because it breaks the normal pair aligner pipeline
#and uses $seek_offset and $num_lines to split the huge UCSC chain file so that this can be run by several jobs at once.
sub parse_Chain_file {
  my ($self, $fh, $seek_offset, $num_lines) = @_;

  my @chains;

  seek $fh, $seek_offset, 0;
  my $chain_cnt=0;
  my $line_cnt = 0;
  while(<$fh>) {
      last if ($line_cnt >= $num_lines);
      $line_cnt++;

    /^chain\s+(\S.+)$/ and do {
      my @data = split /\s+/, $1;
      $chain_cnt++;
      my $chain = {
        q_id     => $data[1],
        q_len    => $data[2],
        q_strand => $data[3] eq "-" ? -1 : 1,
        t_id     => $data[6],
        t_len    => $data[7],
        t_strand => $data[8] eq "-" ? -1 : 1,
        score    => $data[0],
        blocks   => [],
      };

      print "Chain $chain_cnt  $data[1] $data[0] $data[11]\n";

      #Check if chain in hash
      if (!defined $self->param('query_DnaFrag_hash')->{$data[1]}) {
	  #print "No $data[1] in hash\n";
	  next;
      }
      if (!defined $self->param('target_DnaFrag_hash')->{$data[6]}) {
	  #print "No $data[6] in hash\n";
	  next;
      }

      my ($current_q_start, $current_t_start) = ($data[4] + 1, $data[9] + 1);
      my @blocks = ([]);
      
      while(<$fh>) {
	  $line_cnt++;
        if (/^(\d+)(\s+\d+\s+\d+)?$/) {
          my ($ungapped, $rest) = ($1, $2);

          my ($current_q_end, $current_t_end) = 
              ($current_q_start + $ungapped - 1, $current_t_start + $ungapped - 1);

          push @{$blocks[-1]}, { q_start => $current_q_start,
                                 q_end   => $current_q_end,
                                 t_start => $current_t_start,
                                 t_end   => $current_t_end,
                               };
          
          if ($rest and $rest =~ /\s+(\d+)\s+(\d+)/) {
            my ($gap_q, $gap_t) = ($1, $2);
            
            $current_q_start = $current_q_end + $gap_q + 1;
            $current_t_start = $current_t_end + $gap_t + 1; 
            
            if ($gap_q != 0 and $gap_t !=0) {
              # simultaneous gap; start a new block
              push @blocks, [];
            }
          } else {
            # we just had a line on its own;
            last;
          }
        } 
        else {
          throw("Not expecting line '$_' in chain file");
        }
      }
      my $cnt2 = 0;
      my $stop = 0;
      # can now form the cigar string and flip the reverse strand co-ordinates
      foreach my $block (@blocks) {
        my @ug_feats;

	my $cnt1 = 0;
        foreach my $ug_feat (@$block) {
          if ($chain->{q_strand} < 0) {
            my ($rev_q_start, $rev_q_end) = ($ug_feat->{q_start}, $ug_feat->{q_end});
            $ug_feat->{q_start} = $chain->{q_len} - $rev_q_end + 1;
            $ug_feat->{q_end}     = $chain->{q_len} - $rev_q_start + 1;
          }
          if ($chain->{t_strand} < 0) {
            my ($rev_t_start, $rev_t_end) = ($ug_feat->{t_start}, $ug_feat->{t_end});
            $ug_feat->{t_start} = $chain->{t_len} - $rev_t_end + 1;
            $ug_feat->{t_end}   = $chain->{t_len} - $rev_t_start + 1;
          }

          #create featurepair
          my $fp = new Bio::EnsEMBL::FeaturePair->new();
          $fp->seqname($chain->{q_id});
          $fp->start($ug_feat->{q_start});
          $fp->end($ug_feat->{q_end});
          $fp->strand($chain->{q_strand});
          $fp->hseqname($chain->{t_id});
          $fp->hstart($ug_feat->{t_start});
          $fp->hend($ug_feat->{t_end});
          $fp->hstrand($chain->{t_strand});
          $fp->score($chain->{score});
        
	  $fp->group_id($data[11]); #store chain_id
	 # print "feature_pair " . $data[11] . "\n";
          push @ug_feats, $fp;
	  $cnt1++;
        }
        my $dalf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@ug_feats);
        $dalf->level_id(1);
	$cnt2++;
        push @{$chain->{blocks}}, $dalf;
      }
      push @chains, $chain->{blocks};
    }
  }
  return \@chains;
}

1;

