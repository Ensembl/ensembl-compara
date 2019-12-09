=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Production::Analysis::AlignmentChains

=cut

package Bio::EnsEMBL::Compara::Production::Analysis::AlignmentChains;

use warnings ;
use strict;

use Bio::SeqIO;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::DnaDnaAlignFeature;

use base ('Bio::EnsEMBL::Compara::RunnableDB::PairAligner::AlignmentProcessing');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },

        'min_chain_score'   => 1000,
        'linear_gap'        => 'medium',
    };
}


sub run_chains {
  my ($self) = @_;

  $self->cleanup_worker_temp_directory;
  my $workdir = $self->worker_temp_directory;

  my $query_name = $self->param('query_dnafrag')->name;

  my $work_dir = $workdir . "/$query_name.$$.AxtChain";
  my $lav_file = "$work_dir/$query_name.lav";
  my $axt_file = "$work_dir/$query_name.axt";
  my $chain_file = "$work_dir/$query_name.chain";
  my (@nib_files, $query_nib_dir, $target_nib_dir);

  mkdir $work_dir;

  #################################
  # write the query in nib format 
  # for use by lavToAxt;
  #################################
  if ($self->param('query_nib_dir')) {
    $query_nib_dir = $self->param('query_nib_dir');
    if (not -d $query_nib_dir) {
      throw("Could not find query nib file directory:" . $query_nib_dir);
    }
  } else { 
    $query_nib_dir = "$work_dir/query_nib";
    mkdir $query_nib_dir;

    my $seqio = Bio::SeqIO->new(-format => 'fasta',
                                -file   => ">$query_nib_dir/$query_name.fa");   

    # prevent extensive disconnections when fetching sequence length etc.
    my $query_slice = $self->param('query_slice');
    $query_slice->adaptor()->dbc->prevent_disconnect( sub {

    $seqio->write_seq($query_slice); 

    } );

    $seqio->close;
    
    $self->run_command([$self->param_required('faToNib_exe'), "$query_nib_dir/$query_name.fa", "$query_nib_dir/$query_name.nib"], { die_on_failure => 1 });
    push @nib_files, "$query_nib_dir/$query_name.nib";
  }  
  
  #################################
  # write the targets in nib format 
  # for use by lavToAxt;
  #################################  
  if ($self->param('target_nib_dir')) {
    $target_nib_dir = $self->param('target_nib_dir');
    if (not -d $target_nib_dir) {
      throw("Could not fine target nib file directory:" . $target_nib_dir);
    } else {
    }
  } else {
    $target_nib_dir =  "$work_dir/target_nib";
    mkdir $target_nib_dir;

    my $target_slices = $self->param('target_slices');
    foreach my $nm (keys %{$target_slices}) {
      my $target = $target_slices->{$nm};
      my $target_name = $target->seq_region_name;
      
      my $seqio =  Bio::SeqIO->new(-format => 'fasta',
                                -file   => ">$target_nib_dir/$target_name.fa");
      $seqio->write_seq($target);
      $seqio->close; 
      
      $self->run_command([$self->param_required('faToNib_exe'), "$target_nib_dir/$target_name.fa", "$target_nib_dir/$target_name.nib"], { die_on_failure => 1 });
      push @nib_files, "$target_nib_dir/$target_name.nib";
    }
  }  
  
  ##############################
  # write features in lav format
  ############################## 
  open my $fh, '>', $lav_file or
      throw("could not open lav file '$lav_file' for writing\n");
  $self->write_lav($fh);
  close($fh);

  ##############################
  # convert the lav file to axt
  ##############################
  $self->run_command([$self->param_required('lavToAxt_exe'), $lav_file, $query_nib_dir, $target_nib_dir, $axt_file], { die_on_failure => 1 });

  ##################################
  # convert the lav file to axtChain
  ##################################
  my $min_parameter = '-minScore=' . $self->param_required('min_chain_score');
  #need to specify linearGap for axtChain
  my $linearGap_parameter = '-linearGap=' . $self->param_required('linear_gap');

  $self->run_command([$self->param_required('axtChain_exe'), $min_parameter, $linearGap_parameter, $axt_file, $query_nib_dir, $target_nib_dir, $chain_file], { die_on_failure => 1 });

  ##################################
  # read the chain file
  ##################################
  open $fh, '<', $chain_file or throw("Could not open chainfile '$chain_file' for reading\n");
  my $chains = $self->parse_Chain_file($fh);
  close($fh);

  return $chains;
}


#####################################################

sub write_lav {  
  my ($self, $fh) = @_;

  my (%features);  
  foreach my $feat (sort {$a->start <=> $b->start} @{$self->param('features')}) {
    my $strand = $feat->strand;
    my $hstrand = $feat->hstrand;
    if ($strand == -1) {
      $strand  *= -1;
      $hstrand *= -1;
    }
    push @{$features{$feat->hseqname}{$strand}{$hstrand}}, $feat;
  }
  
  my $query_length = $self->param('query_dnafrag')->length;
  my $query_name   = $self->param('query_dnafrag')->name;
  
  foreach my $target (sort keys %features) {

    print $fh "#:lav\n";
    print $fh "d {\n   \"generated by Runnable/AxtFilter.pm\"\n}\n";

    foreach my $qstrand (keys %{$features{$target}}) {
      foreach my $tstrand (keys %{$features{$target}{$qstrand}}) {
        
        my $query_strand = ($qstrand == 1) ? 0 : 1;
        my $target_strand = ($tstrand == 1) ? 0 : 1;
        
        my $target_length = $self->param('target_dnafrags')->{$target}->length;

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

        my $dalf = new Bio::EnsEMBL::DnaDnaAlignFeature(-features => \@ug_feats, -align_type => 'ensembl');
        $dalf->level_id(1);
       
        push @{$chain->{blocks}}, $dalf;
      }

      push @chains, $chain->{blocks};
    }
  }

  return \@chains;
}


1;
