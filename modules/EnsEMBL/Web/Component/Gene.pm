package EnsEMBL::Web::Component::Gene;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Component::Slice;
use EnsEMBL::Web::RegObj;

use EnsEMBL::Web::Form;

use Data::Dumper;
use Bio::AlignIO;
use Bio::EnsEMBL::Variation::Utils::Sequence qw(ambiguity_code);
use IO::String;
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Component);
our %do_not_copy = map {$_,1} qw(species type view db transcript gene);

=pod

sub user_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $uri  = CGI::escape($ENV{'REQUEST_URI'});
  my $html;
  my $stable_id = $object->stable_id;
  my @annotations = $user->annotations;
  if ($#annotations > -1) {
    $html .= "<ul>";
    foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
      warn "CREATED AT: " . $annotation->created_at;
      if ($annotation->stable_id eq $stable_id) {
        $html .= "<li>";
        $html .= "<b>" . $annotation->title . "</b><br />";
        $html .= $annotation->annotation;
        $html .= "<br /><a href='/common/user/annotation?dataview=edit;url=$uri;id=" . $annotation->id . ";stable_id=$stable_id'>Edit</a>";
        $html .= " &middot; <a href='/common/user/annotation?dataview=delete;url=$uri;id=" . $annotation->id . "'>Delete</a>";
        $html .= "</li>";
      }
    }
    $html .= "</ul>";
  }

  $html .= "<a href='/common/user/annotation?url=" . $uri . ";stable_id=" . $stable_id . "'>Add new note</a>";

  $panel->add_row('Your notes', $html);

}

sub group_notes {
  my( $panel, $object ) = @_;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my @groups = $user->groups;
  my $uri = CGI::escape($ENV{'REQUEST_URI'});
  my $stable_id = $object->stable_id;
  my $html;
  my $found = 0;
  my %included_annotations = ();
  foreach my $annotation ($user->annotations) {
    if ($annotation->stable_id eq $stable_id) {
      $included_annotations{$annotation->id} = "yes";
    }
  }
  foreach my $group (@groups) {
    my $title_added = 0;
    my $group_annotations = 0;
    my @annotations = $group->annotations;
    foreach my $annotation (@annotations) {
      if ($annotation->stable_id eq $stable_id) {
        $group_annotations = 1;
      }
    }
    if ($group_annotations) {
      if (!$title_added) {
        $html .= "<h4>" . $group->name . "</h4>";
        $title_added = 1;
      }
      $html .= "<ul>";
      foreach my $annotation (sort { $a->created_at cmp $b->created_at } @annotations) {
        if (!$included_annotations{$annotation->id}) {
          $found = 1;
          $html .= "<li>";
          $html .= "<b>" . $annotation->title . "</b><br />";
          $html .= $annotation->annotation;
          $html .= "</li>";
          $included_annotations{$annotation->id} = "yes";
        }
      }
      $html .= "</ul>";
    }
  }
  if ($found) {
    $panel->add_row('Group notes', $html);
  }
}

=cut

sub email_URL {
    my $email = shift;
    return qq(&lt;<a href='mailto:$email'>$email</a>&gt;) if $email;
}

sub EC_URL {
  my( $self,$string ) = @_;
  my $URL_string= $string;
  $URL_string=~s/-/\?/g;
  return $self->object->get_ExtURL_link( "EC $string", 'EC_PATHWAY', $URL_string );
}

sub get_sequence_data {
  my $self = shift;
  my ($slices, $config) = @_;

  my @sequence;
  my @markup;

  foreach my $sl (@$slices) {
    my $mk = {};
    my $slice = $sl->{'slice'};
    
    push (@sequence, [ map {{'letter' => $_ }} split (//, uc $slice->seq) ]);
    
    $config->{'length'} ||= $slice->length;
    
    # Get variations
    if ($config->{'snp_display'}) {
      my $snps = [];
      my $u_snps = {};
    
      eval {
        $snps = $slice->get_all_VariationFeatures();
      };
        
      if (scalar @$snps) {
        if ($config->{'line_numbering'} eq 'slice') {
          foreach my $u_slice (@{$sl->{'underlying_slices'}}) {
            next if ($u_slice->seq_region_name eq 'GAP');
            
            if (!$u_slice->adaptor) {
              my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($sl->{'species'}, $config->{'db'}, 'slice');
              $u_slice->adaptor($slice_adaptor);
            }
           
            eval {
              $u_snps->{$_->variation_name} = $_ for (@{$u_slice->get_all_VariationFeatures});
            };
          }
        }
      }
      
      # Put deletes second, so that they will overwrite the markup of other variations in the same location
      my @ordered_snps = map { $_->[1] } sort { $a->[0] <=> $b->[0] } map { [ $_->end < $_->start ? 1 : 0, $_ ] } @$snps;
      
      for my $snp (@ordered_snps) {
        my $alleles = $snp->allele_string;
      
        # If gene is reverse strand we need to reverse parts of allele, i.e AGT/- should become TGA/-
        if ($slice->strand < 0) {
          my @al = split(/\//, $alleles);
          
          $alleles = '';
          $alleles .= reverse($_) . '/' for @al;
          $alleles =~ s/\/$//;
        }
      
        # if snp is on reverse strand - flip the bases
        $alleles =~ tr/ACGTacgt/TGCAtgca/ if $snp->strand < 0;
        
        my $start = $snp->start-1;
        my $end = $snp->end-1;
        my $snp_type = 'snp';
        my $snp_start;
        
        if (scalar keys %$u_snps) {
          # Species comparisons with line numbering relative to slice - get the start of the variation on the underlying slice
          $snp_start = $u_snps->{$snp->variation_name}->seq_region_start;
        } elsif ($config->{'line_numbering'} eq 'slice') {
          # No species comparison - get the start of the variation on the slice
          $snp_start = $snp->seq_region_start;
        } else {
          # Line numbering is relative to the sequence
          $snp_start = $snp->start;
        }
        
        if ($end < $start) {
          $start = $snp->end-1;
          $end = $snp->start-1;
          $snp_type = 'delete';
          $snp_start--;
        }
        
        # Add the chromosome number for the link text if we're doing species comparisons.
        $snp_start = $u_snps->{$snp->variation_name}->seq_region_name . ":$snp_start" if scalar keys %$u_snps;
        
        for ($start..$end) {
          $mk->{$_}->{'variations'} = $snp_type;
          $mk->{$_}->{'alleles'} .= ($mk->{$_}->{'alleles'} ? '; ' : '') . $alleles;
        }
        
        $mk->{$start}->{'link_text'} = "$snp_start:$alleles";
        $mk->{$start}->{'v'} = $snp->variation_name;
        $mk->{$start}->{'vf'} = $snp->dbID;
        $mk->{$start}->{'species'} = $sl->{'species'};
      }
    }
    
    # Get exons
    if ($config->{'exon_display'}) {
      my $exontype = $config->{'exon_display'};
      my @exons;
      
      my ($slice_start, $slice_end, $slice_length) = ($slice->start, $slice->end, $slice->length);
      
      if ($exontype eq 'Ab-initio') {      
        @exons = ( 
          grep { $_->seq_region_start <= $slice_end && $_->seq_region_end >= $slice_start }
          map { @{$_->get_all_Exons } }
          @{$slice->get_all_PredictionTranscripts} 
        );
      } elsif ($exontype eq 'vega' || $exontype eq 'est') {      
        @exons = map { @{$_->get_all_Exons } } @{$slice->get_all_Genes('', $exontype)};
      } else {
        @exons = map { @{$_->get_all_Exons } } @{$slice->get_all_Genes};
      }
      
      if ($config->{'exon_ori'} eq 'fwd') {
        @exons = grep { $_->seq_region_strand > 0 } @exons; # Only fwd exons
      } elsif ($config->{'exon_ori'} eq 'rev') {
        @exons = grep { $_->seq_region_strand < 0 } @exons; # Only rev exons
      }
      
      my @all_exons = map {[ $config->{'comparison'} ? 'compara_other' : 'other', $_ ]} @exons;
      
      if ($config->{'exon_features'}) {
        push (@all_exons, [ 'gene', $_ ]) for @{$config->{'exon_features'}};
        $config->{'gene_exon_type'} = $config->{'exon_features'}->[0]->isa('Bio::EnsEMBL::Exon') ? 'exons' : 'features';
      }
  
      foreach (@all_exons) {
        my $type = $_->[0];
        my $exon = $_->[1];
        
        # skip the features that were cut off by applying flanking sequence parameters
        next if $exon->seq_region_start < $slice_start || $exon->seq_region_end > $slice_end;
        
        my $start = $exon->start - ($type eq 'gene' ? $slice_start : 1);
        my $end = $exon->end - ($type eq 'gene' ? $slice_start : 1);
        
        if ($exon->strand < 0) {
          ($start, $end) = ($slice_length - $end - 1, $slice_length - $start - 1);
        }
        
        for ($start..$end) {
          last if $_ >= $config->{'length'};
          
          push (@{$mk->{$_}->{'exon_type'}}, $type);          
          $mk->{$_}->{'exons'} .= ($mk->{$_}->{'exons'} ? '; ' : '') . $exon->stable_id if ($exon->can('stable_id'));
        }
      }
    }
    
    # Get codons
    if ($config->{'codons_display'}) {
      my @transcripts = map { @{$_->get_all_Transcripts } } @{$slice->get_all_Genes};
      my $slice_length = $slice->length;
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
        foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          next if (!defined($t->translation));
          
          my @codons = map {{ start => $_->start, end => $_->end, label => 'START' }} @{$t->translation->all_start_codon_mappings || []}; # START codons
          push (@codons, map {{ start => $_->start, end => $_->end, label => 'STOP' }} @{$t->translation->all_end_codon_mappings || []}); # STOP codons
          
          foreach my $c (@codons) {
            my ($start, $end) = ($c->{'start'}, $c->{'end'});
  
            ($start, $end) = ($slice_length - $end, $slice_length - $start) if ($t->strand < 0);
              
            next if ($end < 1 || $start > $slice_length);
            
            $start = 1 unless $start > 0;
            $end = $slice_length unless $end < $slice_length;
            
            for ($start-1..$end-1) {
              $mk->{$_}->{'codons'} .= ($mk->{$_}->{'codons'} ? '; ' : '') . sprintf("$c->{'label'}(%s)", $t->stable_id);
            }
          }
        }
      } else { # Normal Slice
        foreach my $t (grep {$_->coding_region_start < $slice_length && $_->coding_region_end > 0 } @transcripts) {
          my ($start, $end) = ($t->coding_region_start, $t->coding_region_end);
          
          $start = 1 if ($start < 1);
          $end = $slice_length if ($end > $slice_length);
  	      
  	      # START codons
  	      for ($start-1..$start+1) { 
    	      $mk->{$_}->{'codons'} .= ($mk->{$_}->{'codons'} ? '; ' : '') . sprintf("START(%s)", $t->stable_id);
  	      }
  	      
  	      # STOP codons
  	      for ($end-3..$end-1) {
  	        $mk->{$_}->{'codons'} .= ($mk->{$_}->{'codons'} ? '; ' : '') . sprintf("STOP(%s)", $t->stable_id);
  	      }
        }
      }
    }
    
    push (@markup, $mk);
  }
  
  return (\@sequence, \@markup);
}

sub markup_comparisons {
  my $self = shift;
  my ($seq, $data, $config) = @_;

  my $length_species = length $config->{'species'};
  my $max_length = $length_species;

  my $sp = 0;
  
  foreach (@{$config->{'slices'}}) {
    my $slice = $_->{'slice'};
    my $species = $_->{'species'};

    $config->{'species_order'}->{$species} = $sp++;
    
    next if $species eq $config->{'species'};
    
    my $length = length $species;
    my $length_diff = $length - $length_species;
    my $padded_species = $species;

    if ($length > $max_length) {
      $max_length = $length;
      $config->{'species_padding'} = ' ' x $length_diff;
    } elsif ($length < $max_length) {
      $padded_species .= ' ' x ($max_length - $length);
    }
    $config->{'padded_species'}->{$species} = $padded_species;
  }
  
  $config->{'padded_species'}->{$config->{'species'}} = "$config->{'species'}$config->{'species_padding'}";
  
  $config->{'v_space'} = "\n";
}

sub markup_conservation {
  my $self = shift;
  my ($sequence, $data, $config) = @_;

  # Regions where more than 50% of bps match considered `conserved`
  my $cons_threshold = int((scalar(@{$config->{'slices'}}) + 1) / 2);
  
  my @conservation;
  my $conserved = 0;
  
  foreach (@{$config->{'slices'}}) {
    # Get conservation scores for each basepair in the alignment.
    # In future the conservation scores will come out of a database and this will be removed
    my $idx = 0;
    
    $conservation[$idx++]->{uc $_}++ for (split(//, $_->{'slice'}->seq));
  }
  
  # Now for each bp in the alignment identify the nucleotides with scores above the threshold.
  # In theory the data should come from a database. 
  foreach my $nt (@conservation) {
    $nt->{'S'} = join('', grep {$_ ne '~' && $nt->{$_} > $cons_threshold} keys(%{$nt}));
    $nt->{'S'} =~ s/[-.N]//; # here we remove different representations of nucleotides from  gaps and undefined regions : 
  }

  foreach my $seq (@$sequence) {    
    my $f = 0;
    my $ms = 0;
    my $i = 0;
    my @csrv;

    foreach my $sym (map { $_->{'letter'} } @$seq) {
      if (uc $sym eq $conservation[$i++]->{'S'}) {
        if ($f == 0) {
           $f = 1;
           $ms = $i;
        }
      } elsif ($f == 1) {
        $f = 0;
        push @csrv, [$ms-1, $i-2];
      }
    }
    
    if ($f == 1) { 
      push @csrv, [$ms-1, $i-1];
    }
    
    foreach my $c (@csrv) {
      $seq->[$_]->{'background-color'} = $config->{'colours'}->{'conservation'} for ($c->[0]..$c->[1]);
    }
    
    $conserved = 1 if scalar @csrv;
  }
  
  if ($conserved) {
    $config->{'key'} .= sprintf (
      $config->{'key_template'}, 
      "background-color:$config->{'colours'}->{'conservation'};", 
      "Location of conserved regions (where >50% of bases in alignments match)"
    );
  }
}

sub markup_codons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($codons, $i);

  foreach my $data (@$markup) {
    foreach (sort {$a <=> $b} keys %$data) {
      if ($data->{$_}->{'codons'}) {
        $sequence->[$i]->[$_]->{'background-color'} = $config->{'colours'}->{'codonutr'};
        $sequence->[$i]->[$_]->{'title'} .= ($sequence->[$i]->[$_]->{'title'} ? '; ' : '') . $data->{$_}->{'codons'} if $config->{'title_display'};
      }
  
      $codons = 1;
    }
    
    $i++;
  }

  $config->{'key'} .= sprintf ($config->{'key_template'}, "background-color:$config->{'colours'}->{'codonutr'};", "Location of START/STOP codons") if ($codons);
}

sub markup_exons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my $exon_types = {};
  
  my $style = {
    other => { 'background-color' => $config->{'colours'}->{'exon_other'} },
    gene  => { 'color' => $config->{'colours'}->{'exon_gene'}, 'font-weight' => 'bold' },
    compara_other => { 'color' => $config->{'colours'}->{'exon2'} }
  };

  my $i = 0;
  
  foreach my $data (@$markup) {
    foreach (sort {$a <=> $b} keys %$data) {
      if ($data->{$_}->{'exons'}) {
        $sequence->[$i]->[$_]->{'title'} .= ($sequence->[$i]->[$_]->{'title'} ? '; ' : '') . $data->{$_}->{'exons'} if $config->{'title_display'};
        
        foreach my $type (@{$data->{$_}->{'exon_type'}}) {
          foreach my $s (keys %{$style->{$type}}) {
            $sequence->[$i]->[$_]->{$s} = $style->{$type}->{$s};
          }
  
          $exon_types->{$type} = 1;
        }
      }
    }
    
    $i++;
  }

  if ($exon_types->{'gene'}) {
    $config->{'key'} .= sprintf (
      $config->{'key_template'},
      join( ';', map {"$_:$style->{'gene'}->{$_}"} keys %{$style->{'gene'}} ), "Location of $config->{'gene_name'} $config->{'gene_exon_type'}" );
  }

  for my $type ('other', 'compara_other') {
    if ($exon_types->{$type}) {
      my $selected = ucfirst $config->{'exon_display'};
      $selected = $config->{'site_type'} if $selected eq 'Core';
  
      $config->{'key'} .= sprintf(
        $config->{'key_template'},
        join( ';', map {"$_:$style->{$type}->{$_}"} keys %{$style->{$type}} ), "Location of $selected exons" );
    }
  }
}

sub markup_variation {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($snps, $deletes);
  my $i = 0;

  my $style = {
    'snp'     => $config->{'colours'}->{'snp_default'},
    'snpexon' => $config->{'colours'}->{'snpexon'},
    'delete'  => $config->{'colours'}->{'snp_gene_delete'}
  };

  foreach my $data (@$markup) {
    foreach (sort {$a <=> $b} keys %$data) {
      my $mk = $data->{$_};
      my $seq = $sequence->[$i];
      
      if ($mk->{'variations'}) {
        my $ambiguity = ambiguity_code($mk->{'alleles'});
  
        $seq->[$_]->{'letter'} = $ambiguity if $ambiguity;
        $seq->[$_]->{'title'} .= ($seq->[$_]->{'title'} ? '; ' : '') . $mk->{'alleles'} if $config->{'title_display'};
        
        $seq->[$_]->{'background-color'} = $style->{$mk->{'variations'}};
        
        if ($config->{'snp_display'} eq 'snp_link' && $mk->{'link_text'}) {          
          $seq->[$_]->{'post'} = qq{ <a href="/$mk->{'species'}/Variation/Summary?v=$mk->{'v'};vf=$mk->{'vf'};vdb=variation">$mk->{'link_text'}</a>;};
        }
  
        $snps = 1 if $mk->{'variations'} eq 'snp';
        $deletes = 1 if $mk->{'variations'} eq 'delete';
      }
    }
    
    $i++;
  }

  $config->{'key'} .= sprintf ($config->{'key_template'}, "background-color:$style->{'snp'};", "Location of SNPs") if ($snps);
  $config->{'key'} .= sprintf ($config->{'key_template'}, "background-color:$style->{'delete'};", "Location of deletions") if ($deletes);
}

sub markup_line_numbers {
  my $self = shift;
  my ($sequence, $config) = @_;
  
  $config->{'species_order'}->{$config->{'species'}} = 0 unless $config->{'species_order'};
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $slice = $sl->{'slice'};
    my $species = $sl->{'species'};
    
    my @numbering;
    my $align_slice = 0;
    my $species_seq = $sequence->[$config->{'species_order'}->{$species}];
    
    if ($config->{'line_numbering'} eq 'slice') {
      my $start_pos = 0;
      
      if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
       $align_slice = 1;
      
        # Get the data for all underlying slices
        foreach (@{$sl->{'underlying_slices'}}) {
          my $ostrand = $_->strand;
          
          if ($_->seq_region_name ne 'GAP') {
            push (@numbering, {
              dir => $ostrand,
              start_pos => $start_pos,
              start => $ostrand > 0 ? $_->start : $_->end,
              end => $ostrand > 0 ? $_->end : $_->start,
              chromosome => $_->seq_region_name . ':'
            });
          }
          
          $start_pos += length $_->seq;
        }
      } else {
        # Get the data for the slice
        my $ostrand = $slice->strand;
        
        @numbering = ({ 
          dir => $ostrand,  
          start => $ostrand > 0 ? $slice->start : $slice->end,
          end => $ostrand > 0 ? $slice->end : $slice->start,
          chromosome => $slice->seq_region_name . ':'
        });
      }
    } else {
      # Line numbers are relative to the sequence (start at 1)
      @numbering = ({ 
        dir => 1,  
        start => 1,
        end => $config->{'length'},
        chromosome => ''
      });
    }
    
    my $data = shift @numbering;
    
    my $s = 0;
    my $e = $config->{'wrap'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = scalar @{$sequence->[0]} + $config->{'wrap'};
    
    while ($e < $loop_end) {
      $start = '';
      $end = '';
      
      # Comparison species
      if ($align_slice && $species ne $config->{'species'}) {
        my $seq_length;
        my $segment;
        
        # Build a segment containing the current line of sequence
        for ($s..$e) {
          # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
          if ($species_seq->[$_]) {
            $seq_length++ if $species_seq->[$_]->{'letter'} ne '.';
            $segment .= $species_seq->[$_]->{'letter'};
          }
        }
    
        my $last_bp_pos = 0;
        
        while ($segment =~ m/[AGCT]/g) {
          $last_bp_pos = pos $segment;
        }
        
        # Get the data from the next slice if we have passed the end of the current one
        if (scalar @numbering && $e >= $numbering[0]->{'start_pos'}) {
          $data = shift @numbering;
          
          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }
        
        $s = $e + 1;
        
        if ($seq_length) {
          # For AlignSlice display the position of the last meaningful bp
          (undef, $end) = $slice->get_original_seq_region_position($s + $last_bp_pos - $config->{'wrap'});
          
          $start = $row_start;
        }
      } else { # Single species, or the reference species for a comparison
        $end = $e < scalar @{$sequence->[0]} ? $row_start + ($data->{'dir'} * $config->{'wrap'}) - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start;
      }
      
      my $ch = $start ? ($config->{'comparison'} && $data->{'chromosome'}) : '';
      
      push (@{$config->{'line_numbers'}->{$config->{'species_order'}->{$species}}}, [ "$ch$start", "$ch$end" ]);
      
      # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
      $row_start = $end + $data->{'dir'} if $end;
      
      # Increase padding amount if required
      $config->{'max_number_length'} = length "$ch$start" if length "$ch$start" > $config->{'max_number_length'};
      
      $e += $config->{'wrap'};
    }
  }
  
  if ($config->{'line_numbering'} eq 'slice' && $config->{'align'}) {
    $config->{'key'} .= qq{ NOTE: For secondary species we display the coordinates of the first and the last mapped (i.e A,T,G,C or N) basepairs of each line};
  }
}

sub build_sequence {
  my $self = shift;
  my ($sequence, $config) = @_;
  
  my $line_numbers = $config->{'line_numbers'};
  my $html; 
  my @output;
  my $s = 0;

  foreach my $lines (@$sequence) {
    my ($row, $title, $previous_title, $new_line_title, $style, $previous_style, $new_line_style, $pre, $post);
    my ($count, $i);
    
    foreach my $seq (@$lines) {
      $previous_title = $title;
      $title = $seq->{'title'} ? qq(title="$seq->{'title'}") : '';
      
      my $new_style = '';
      $previous_style = $style;
  
      if ($seq->{'background-color'}) {
        $new_style .= "background-color:$seq->{'background-color'};";
      } elsif ($style =~ /background-color/) {
        $new_style .= "background-color:auto;";
      }
  
      if ($seq->{'color'}) {
        $new_style .= "color:$seq->{'color'};";
      } elsif ($style =~ /(?<!background-)color:/) {
        $new_style .= "color:auto;";
      }
  
      if ($seq->{'font-weight'}) {
        $new_style .= "font-weight:$seq->{'font-weight'};";
      }
  
      $style = qq(style="$new_style") if ($new_style);
  
      $post .= $seq->{'post'};
  
      if ($i == 0) {
        $row .= "<span $style $title>";
      } elsif ($style ne $previous_style || $title ne $previous_title) {
        $row .= "</span><span $style $title>";
      }
  
      $row .= $seq->{'letter'};
  
      $count++;
      $i++;
  
      if ($count == $config->{'wrap'} || $i == scalar @$lines) {        
        if ($i == $config->{'wrap'}) {
          $row = "$row</span>";
        } else {
          $row = "<span $new_line_style $new_line_title>$row</span>";
        }
        
        if ($config->{'comparison'}) {
          $pre = ($config->{'padded_species'}->{scalar {reverse %{$config->{'species_order'}}}->{$s}} || $config->{'species'}) . '  ';
        }
         
        push (@{$output[$s]}, { line => $row, length => $count, pre => $pre, post => $post });
  
        $new_line_style = $style || $previous_style;
        $new_line_title = $title || $previous_title;
        $count = 0;
        $row = '';
        $pre = '';
        $post = '';
      }
    }
    
    $s++;
  }

  my $length = scalar @{$output[0]} - 1;

  for my $x (0..$length) {
    my $y = 0;
    
    foreach (@output) {
      my $line = $_->[$x]->{'line'};
      my $num = shift @{$line_numbers->{$y}};
      
      if ($config->{'number'}) {
        my $padding = ' ' x ($config->{'max_number_length'} - length $num->[0]);
        $line = $config->{'h_space'} . sprintf("%6s ", "$padding$num->[0]") . $line;
      }
      
      if ($x == $length && ($config->{'end_number'} || $_->[$x]->{'post'})) {
        $line .= ' ' x ($config->{'wrap'} - $_->[$x]->{'length'});
      }
      
      if ($config->{'end_number'}) {
        my $padding = ' ' x ($config->{'max_number_length'} - length $num->[1]);
        $line .= $config->{'h_space'} . sprintf(" %6s", "$padding$num->[1]");
      }
      
      $line = "$_->[$x]->{'pre'}$line" if $_->[$x]->{'pre'};
      $line .= $_->[$x]->{'post'} if $_->[$x]->{'post'};      
      
      $html .= "$line\n";
      $y++;
    }
    
    $html .= $config->{'v_space'};
  }
  
  $config->{'html_template'} ||= qq{<pre>%s</pre>};
  
  # Can't use sprintf because it throws the error 'Argument isn't numeric' for compara alignments when 
  # conservation is turned on, even though IT'S NOT MEANT TO BE NUMERIC. Stupid sprintf.
  $config->{'html_template'} =~ s/%s/$html/;

  return $config->{'html_template'};
}

1;
