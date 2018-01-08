=head1 LICENSE

# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Analysis::Runnable::AlignmentChains - 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

# Let the code begin...

package Bio::EnsEMBL::Analysis::Runnable::AlignmentChains;

use warnings ;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Argument qw( rearrange );

use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::DnaDnaAlignFeature;


@ISA = qw(Bio::EnsEMBL::Analysis::Runnable);

sub new {
  my ($class,@args) = @_;

  my $self = $class->SUPER::new(@args);
  
  my ($features, 
      $query_slice,
      $query_nib_dir,
      $target_slices,
      $target_nib_dir,
      $min_chain_score,
      $linear_gap,
      $fa_to_nib,
      $lav_to_axt,
      $axt_chain,

      ) = rearrange([qw(FEATURES
                        QUERY_SLICE
                        QUERY_NIB_DIR
                        TARGET_SLICES
                        TARGET_NIB_DIR
                        MIN_CHAIN_SCORE
                        LINEAR_GAP
                        FATONIB
                        LAVTOAXT
                        AXTCHAIN
                                )],
                    @args);

  throw("You must supply a reference to an array of features with -features\n") 
      if not defined $features;
  throw("You must supply a query sequence\n") 
      if not defined $query_slice;
  throw("You must supply a hash ref of target sequences with -target_slices")
      if not defined $target_slices;

  $self->faToNib($fa_to_nib) if defined $fa_to_nib;
  $self->lavToAxt($lav_to_axt) if defined $lav_to_axt;
  $self->axtChain($axt_chain) if defined $axt_chain;

  $self->query_nib_dir($query_nib_dir) if defined $query_nib_dir;
  $self->target_nib_dir($target_nib_dir) if defined $target_nib_dir;

  $self->query_slice($query_slice);
  $self->target_slices($target_slices);
  $self->min_chain_score($min_chain_score) if defined $min_chain_score;
  $self->linear_gap($linear_gap) if defined $linear_gap;
  $self->features($features);

  return $self;
}





=head2 run

  Title   : run
  Usage   : $self->run()
  Function: 
  Returns : none
  Args    : 

=cut

sub run {
  my ($self) = @_;

  my $query_name = $self->query_slice->seq_region_name;

  my $work_dir = $self->workdir . "/$query_name.$$.AxtChain";
  my $lav_file = "$work_dir/$query_name.lav";
  my $axt_file = "$work_dir/$query_name.axt";
  my $chain_file = "$work_dir/$query_name.chain";
  my (@nib_files, $query_nib_dir, $target_nib_dir);

  mkdir $work_dir;

  my $fh;

  #################################
  # write the query in nib format 
  # for use by lavToAxt;
  #################################
  if ($self->query_nib_dir) {
    if (not -d $self->query_nib_dir) {
      throw("Could not fine query nib file directory:" . $self->query_nib_dir);
    } else {
      $query_nib_dir = $self->query_nib_dir;
    }
  } else { 
    $query_nib_dir = "$work_dir/query_nib";
    mkdir $query_nib_dir;

    my $seqio = Bio::SeqIO->new(-format => 'fasta',
                                -file   => ">$query_nib_dir/$query_name.fa");   

    # prevent extensive disconnections when fetching sequence length etc.
    my $disco = $self->query_slice->adaptor()->dbc->disconnect_when_inactive(); 
    $self->query_slice->adaptor()->dbc->disconnect_when_inactive(0);  

    $seqio->write_seq($self->query_slice); 

    $self->query_slice->adaptor()->dbc->disconnect_when_inactive($disco);  

    $seqio->close;
    
    system($self->faToNib, "$query_nib_dir/$query_name.fa", "$query_nib_dir/$query_name.nib") 
        and throw("Could not convert fasta file $query_nib_dir/$query_name.fa to nib");
    unlink "$query_nib_dir/$query_name.fa";
    push @nib_files, "$query_nib_dir/$query_name.nib";
  }  
  
  #################################
  # write the targets in nib format 
  # for use by lavToAxt;
  #################################  
  if ($self->target_nib_dir) {
    if (not -d $self->target_nib_dir) {
      throw("Could not fine target nib file directory:" . $self->target_nib_dir);
    } else {
      $target_nib_dir = $self->target_nib_dir;
    }
  } else {
    $target_nib_dir =  "$work_dir/target_nib";
    mkdir $target_nib_dir;

    foreach my $nm (keys %{$self->target_slices}) {
      my $target = $self->target_slices->{$nm};
      my $target_name = $target->seq_region_name;
      
      my $seqio =  Bio::SeqIO->new(-format => 'fasta',
                                -file   => ">$target_nib_dir/$target_name.fa");
      $seqio->write_seq($target);
      $seqio->close; 
      
      system($self->faToNib, "$target_nib_dir/$target_name.fa", "$target_nib_dir/$target_name.nib") 
          and throw("Could not convert fasta file $target_nib_dir/$target_name.fa to nib");
      unlink "$target_nib_dir/$target_name.fa";
      push @nib_files, "$target_nib_dir/$target_name.nib";
    }
  }  
  
  ##############################
  # write features in lav format
  ############################## 
  open $fh, ">$lav_file" or 
      throw("could not open lav file '$lav_file' for writing\n");
  $self->write_lav($fh);
  close($fh);

  ##############################
  # convert the lav file to axt
  ##############################
  system($self->lavToAxt, $lav_file, $query_nib_dir, $target_nib_dir, $axt_file)
      and throw("Could not convert $lav_file to Axt format\n");
  unlink $lav_file;

  ##################################
  # convert the lav file to axtChain
  ##################################
  my $min_parameter = "-minScore=";
  if (defined $self->min_chain_score) {
    $min_parameter .= $self->min_chain_score;
  } else {
    # default to the built-in default
    $min_parameter .= 1000;
  }

  #need to specify linearGap for axtChain
  my $linearGap_parameter = "-linearGap=";

  if (defined $self->linear_gap) {
    $linearGap_parameter .= $self->linear_gap;
  } else {
    # default to medium
    $linearGap_parameter .= "medium";
  }

  system($self->axtChain, $min_parameter, $linearGap_parameter, $axt_file, $query_nib_dir, $target_nib_dir, $chain_file)
        and throw("Something went wrong with axtChain\n");

#  system($self->axtChain, $min_parameter, $axt_file, $query_nib_dir, $target_nib_dir, $chain_file)
#        and throw("Something went wrong with axtChain\n");

  unlink $axt_file;

  ##################################
  # read the chain file
  ##################################
  open $fh, $chain_file or throw("Could not open chainfile '$chain_file' for reading\n");
  my $chains = $self->parse_Chain_file($fh);
  close($fh);

  $self->output($chains);  
  unlink $chain_file, @nib_files;
  
  rmdir $query_nib_dir if not $self->query_nib_dir;
  rmdir $target_nib_dir if not $self->target_nib_dir;
  rmdir $work_dir;

  return 1;
}


#####################################################

sub write_lav {  
  my ($self, $fh) = @_;

  my (%features);  
  foreach my $feat (sort {$a->start <=> $b->start} @{$self->features}) {
    my $strand = $feat->strand;
    my $hstrand = $feat->hstrand;
    if ($strand == -1) {
      $strand  *= -1;
      $hstrand *= -1;
    }
    push @{$features{$feat->hseqname}{$strand}{$hstrand}}, $feat;
  }
  
  my $query_length = $self->query_slice->length;
  my $query_name   = $self->query_slice->seq_region_name;
  
  foreach my $target (sort keys %features) {

    print $fh "#:lav\n";
    print $fh "d {\n   \"generated by Runnable/AxtFilter.pm\"\n}\n";

    foreach my $qstrand (keys %{$features{$target}}) {
      foreach my $tstrand (keys %{$features{$target}{$qstrand}}) {
        
        my $query_strand = ($qstrand == 1) ? 0 : 1;
        my $target_strand = ($tstrand == 1) ? 0 : 1;
        
        my $target_length = $self->target_slices->{$target}->length;

        print $fh "#:lav\n";
        print $fh "s {\n";
        print $fh "   \"$query_name\" 1 $query_length $query_strand 1\n";
        print $fh "   \"$target\" 1 $target_length $target_strand 1\n";
        print $fh "}\n";
        
        print $fh "h {\n";
        print $fh "   \">$query_name";
        if ($query_strand) {
          print $fh " (reverse complement)";
        }
        print $fh "\"\n   \">$target";
        if ($target_strand) {
          print $fh " (reverse complement)";
        }
        print $fh "\"\n}\n";
	
        foreach my $reg (@{$features{$target}{$qstrand}{$tstrand}}) {
          my $qstart = $query_strand ?  $query_length - $reg->end + 1 : $reg->start; 
          my $qend = $query_strand ?  $query_length - $reg->start + 1 : $reg->end; 
          my $tstart = $target_strand ? $target_length - $reg->hend + 1 : $reg->hstart; 
          my $tend = $target_strand ? $target_length - $reg->hstart + 1 : $reg->hend; 
          
          my $score = defined($reg->score) ? $reg->score : 100;
          my $percent_id = defined($reg->percent_id) ? $reg->percent_id : 100;

          printf $fh "a {\n   s %d\n", $score;
          print $fh "   b $qstart $tstart\n"; 
          print $fh "   e $qend $tend\n";
          
          my @ug_feats = $reg->ungapped_features;
          if ($qstrand == -1) {
            @ug_feats = sort { $b->start <=> $a->start } @ug_feats;
          } else {
            @ug_feats = sort { $a->start <=> $b->start } @ug_feats;
          }

          foreach my $seg (@ug_feats) {
            my $qstartl = $query_strand ?  $query_length - $seg->end + 1 : $seg->start; 
            my $qendl = $query_strand ?  $query_length - $seg->start + 1 : $seg->end; 
            
            my $tstartl = $target_strand ? $target_length - $seg->hend + 1 : $seg->hstart; 
            my $tendl = $target_strand ? $target_length - $seg->hstart + 1 : $seg->hend; 
            
            printf $fh "   l $qstartl $tstartl $qendl $tendl %d\n", $percent_id;
            
          }
          print $fh "}\n";
        }
        
        print $fh "x {\n   n 0\n}\n"; 
      }
    }
    print $fh "m {\n   n 0\n}\n#:eof\n";
  }
}

##############################################################

sub parse_Chain_file {
  my ($self, $fh) = @_;

  my @chains;

  while(<$fh>) {
    
    /^chain\s+(\S.+)$/ and do {
      my @data = split /\s+/, $1;

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

      my ($current_q_start, $current_t_start) = ($data[4] + 1, $data[9] + 1);
      my @blocks = ([]);
      
      while(<$fh>) {
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

      # can now form the cigar string and flip the reverse strand co-ordinates
      foreach my $block (@blocks) {
        my @ug_feats;

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
        
          push @ug_feats, $fp;
        }

        my $dalf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@ug_feats);
        $dalf->level_id(1);
       
        push @{$chain->{blocks}}, $dalf;
      }

      push @chains, $chain->{blocks};
    }
  }

  return \@chains;
}



#####################
# instance vars
#####################

sub query_slice {
  my ($self, $slice) = @_;
  
  if (defined $slice) {
    $self->{_query_slice} = $slice;
  }
  return $self->{_query_slice};
}

sub target_slices {
  my ($self, $hash_ref) = @_;
  
  if (defined $hash_ref) {
    $self->{_target_slices_hashref} = $hash_ref;
  }
  return $self->{_target_slices_hashref};
}

sub query_nib_dir {
  my ($self, $val) = @_;
  
  if (defined $val) {
    $self->{_query_nib_dir} = $val;
  }
  return $self->{_query_nib_dir};
}

sub target_nib_dir {
  my ($self, $val) = @_;
  
  if (defined $val) {
    $self->{_target_nib_dir} = $val;
  }
  return $self->{_target_nib_dir};
}

sub features {
  my ($self, $features) = @_;

  if (defined $features) {
    $self->{_features} = $features;
  }

  return $self->{_features};
}

sub min_chain_score {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_min_chain_score} = $val;
  }

  if (not exists $self->{_min_chain_score}) {
    return undef;
  } else {
    return $self->{_min_chain_score};
  }
}

sub linear_gap {
  my ($self, $val) = @_;

  if (defined $val) {
    $self->{_linear_gap} = $val;
  }

  if (not exists $self->{_linear_gap}) {
    return undef;
  } else {
    return $self->{_linear_gap};
  }
}


##############
#### programs
##############

sub faToNib {
  my ($self,$arg) = @_;
  
  if (defined($arg)) {
    $self->{'_faToNib'} = $arg;
  }

  return $self->{'_faToNib'};
}


sub lavToAxt {
  my ($self,$arg) = @_;
  
  if (defined($arg)) {
    $self->{'_lavToAxt'} = $arg;
  }

  return $self->{'_lavToAxt'};
}


sub axtChain {
  my ($self,$arg) = @_;
  
  if (defined($arg)) {
    $self->{'_axtChain'} = $arg;
  }
  
  return $self->{'_axtChain'};
}



1;
