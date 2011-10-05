package EnsEMBL::Web::Component::Variation::FlankingSequence;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Variation);

use Bio::EnsEMBL::Variation::Utils::Sequence qw(align_seqs);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $html = '';
  
  ## first check we have uniquely determined variation
  return $self->_info('A unique location can not be determined for this Variation', $object->not_unique_location) if $object->not_unique_location;
  
  ## count locations
  my $mapping_count = scalar keys %{$object->variation_feature_mapping};

  ## Add flanking sequence
  my $f_label;
  my $f_html ;

  my $status   = 'status_ambig_sequence';

  my $ambig_code = $object->vari->ambig_code;
  unless ($ambig_code) {
    $ambig_code = "[".$object->alleles."]";
  }
  
  # first determine correct SNP location 
  my %mappings = %{ $object->variation_feature_mapping }; 
  my $loc;
  if( keys %mappings == 1 ) {
    ($loc) = values %mappings;
  } else { 
    $loc = $mappings{$object->param('vf')};
  }
  
  # get a slice adaptor
  my $sa = $object->vari->adaptor->db->dnadb->get_SliceAdaptor(); 
  
  
  ## FLANKING SEQUENCE  
  my ($up_slice, $down_slice, $up_ref, $down_ref, $up_align, $down_align, $vfs, $diffs);
  
  my $flank_size = $object->param('flank_size') || 400;
  my $show_mismatches = $object->param('show_mismatches') || 1;
  my $display_type = $object->param('display_type') || 'align';
  my ($up_trimmed, $down_trimmed) = ("", "");
  my $trim_size = 500;
  
  if(defined($sa) && $mapping_count) {
    # get up slice
    $up_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $loc->{start} - $flank_size,
      $loc->{start} - 1,
      $loc->{strand}
    );
    
    # get down slice
    $down_slice = $sa->fetch_by_region(
      undef,
      $loc->{Chr},
      $loc->{end} + 1,
      $loc->{end} + $flank_size,
      $loc->{strand}
    );
    
    # switch if on reverse strand
    ($up_slice, $down_slice) = ($down_slice, $up_slice) unless $loc->{strand} == 1;
    
    $f_label = "Flanking Sequence<br/>(reference".($object->vari->{flank_flag} ? "" : " and ".$object->vari->source).")";
    
    # make HTML if we got slices OK
    if(defined($up_slice) && defined($down_slice)) {
      $f_html = uc( $up_slice->seq ) .lc( $ambig_code ).uc( $down_slice->seq );
      $f_html =~ s/(.{60})/$1\n/g;
      $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
      $f_html =~ s/\n/\n/g;
      
      $html .=  qq(
        <dl class="summary">
          <dt>$f_label</dt>
          <dd>
            <pre>$f_html</pre>
            <blockquote><em>(Variant highlighted)</em></blockquote>
          </dd>
        </dl>
      ) unless $display_type eq 'align';
    }
  }

  #  my $ambiguity_seq = $object->ambiguity_flank;
  # genomic context with ambiguities
  
  if($object->vari->{flank_flag} || !defined($up_slice) || !defined($down_slice) || !defined($sa)) {
    
    my ($up_source, $down_source) = ($object->flanking_seq("up"), $object->flanking_seq("down"));
    
    if($display_type eq 'basic') {
      
      $f_html = uc( $up_source ) .lc( $ambig_code ).uc( $down_source );
      $f_html =~ s/(.{60})/$1\n/g;
      $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
      $f_html =~ s/\n/\n/g;
      
      $f_label = "Flanking Sequence<br/>(".$object->vari->source.")";
      
      $html .=  qq(
        <dl class="summary">
          <dt>$f_label</dt>
          <dd>
            <pre>$f_html</pre>
            <blockquote><em>(Variant highlighted)</em></blockquote>
          </dd>
        </dl>
      );
      
      return $html;
    }
    
    # trim sequences if necessary
    if(length($up_source) > $trim_size) {
      $up_source = substr($up_source, length($up_source) - $trim_size, $trim_size);
      $up_trimmed = '...';
    }
    if(length($down_source) > $trim_size) {
      $down_source = substr($down_source, 0, $trim_size);
      $down_trimmed = '...';
    }
    
    # reset f_html
    $f_html = '';
    
    # get expanded (or retracted!) up and down reference sequences
    $up_slice = $up_slice->expand(length($up_source) - $up_slice->length());# if length($up_source) > $up_slice->length;
    $down_slice = $down_slice->expand(undef, length($down_source) - $down_slice->length());# if length($down_source) > $down_slice->length;
    ($up_ref, $down_ref) = ($up_slice->seq, $down_slice->seq);
    
    # do the alignments using method from variation API
    $up_align = align_seqs($up_ref, $up_source);
    $down_align = align_seqs($down_ref, $down_source);
    
    # copy aligned seqs to variables
    ($up_ref, $up_source) = @$up_align;
    ($down_ref, $down_source) = @$down_align;
    
    # replace - with * (formatting)
    $_ =~ tr/\-/\*/ for ($up_ref, $down_ref, $up_source, $down_source);
    
    # code to highlight differences between reference and source flanking sequence
    if(defined($up_slice) && defined($down_slice) && $show_mismatches eq 'yes') {
      
      # compare up seq
      for my $i(0..(length($up_ref)-1)) {
        if(substr($up_ref, $i, 1) ne substr($up_source, $i, 1)) {
          $diffs->{$i} = 1;
          
          my $letter = uc(substr($up_source, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/; # this encoding is used later to colour the sequence
          substr($up_source, $i, 1) = $letter;
          
          $letter = uc(substr($up_ref, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/;
          substr($up_ref, $i, 1) = $letter;
        }
      }
      
      my $added_length = length($up_ref.$ambig_code);
      
      # compare down seq
      for my $i(0..(length($down_ref)-1)) {
        if(substr($down_ref, $i, 1) ne substr($down_source, $i, 1)) {
          $diffs->{$i + $added_length} = 1;
          
          my $letter = uc(substr($down_source, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/;
          substr($down_source, $i, 1) = $letter;
          
          $letter = uc(substr($down_ref, $i, 1));
          $letter =~ tr/ACGTN/\!\£\$\%\@/;
          substr($down_ref, $i, 1) = $letter;
        }
      }
      
      # get VFs
      $vfs->{$_->start - 1} = $_ foreach @{$up_slice->get_all_VariationFeatures};
      $vfs->{$_->start + $added_length - 1} = $_ foreach @{$down_slice->get_all_VariationFeatures};
    }
    
    # #create complete aligned sequences with variant
    #my ($ref_seq, $source_seq, $ref_seq_final, $source_seq_final, $final_length);
    #
    #$ref_seq = $up_ref.$ambig_code.$down_ref;
    #$source_seq = $up_source.$ambig_code.$down_source;
    #
    #for my $i(0..(length($ref_seq)-1)) {
    #  
    #  if($i == length($up_ref) - 1) {
    #    $ref_seq_final .= '<span style="color:red;">'.$ambig_code.'</span>';
    #    $source_seq_final .= '<span style="color:red;">'.$ambig_code.'</span>';
    #    $i += length($ambig_code);
    #  }
    #  
    #  else {
    #    my $style;
    #    
    #    if($diffs->{$i}) {
    #      $style .= 'color:blue;';
    #    }
    #    
    #    if($vfs->{$i}) {
    #      $style .= 'background:yellow;';
    #    }
    #    
    #    if($style) {
    #      $ref_seq_final .= '<span style="'.$style.'">'.substr($ref_seq, $i, 1).'</span>';
    #      $source_seq_final .= '<span style="'.$style.'">'.substr($source_seq, $i, 1).'</span>';
    #    }
    #    else {
    #      $ref_seq_final .= substr($ref_seq, $i, 1);
    #      $source_seq_final .= substr($source_seq, $i, 1);
    #    }
    #  }
    #}
    #
    #$f_html .= $ref_seq_final."\n".$source_seq_final;
    
    my $ref_seq =
      $up_trimmed.
      uc($up_ref).
      lc($ambig_code).
      uc($down_ref).
      $down_trimmed;
      
    my $source_seq =
      $up_trimmed.
      uc($up_source).
      lc($ambig_code).
      uc($down_source).
      $down_trimmed;
    
    # now format for display
    my $width = 60;
    my $pad = 3;
    my $source_name = $object->vari->source;
    my $ref_name = 'Reference';
    my $ref_pos = $up_slice->start;
    my $source_pos = 1;
    my ($ref_pad, $source_pad);
    
    # fit onto lines of width 60bp
    while(length($ref_seq) > 0) {
      
      #my $lr = length($ref_pos) + length($ref_name);
      #my $ls = length($source_pos) + length($source_name);
      my $lr = length($ref_name);
      my $ls = length($source_name);
      
      # pad sequence names
      if($ls > $lr) {
        $ref_pad = ' ' x ($pad + ($ls - $lr));
        $source_pad .= ' ' x $pad;
      }
      else {
        $source_pad = ' ' x ($pad + ($lr - $ls));
        $ref_pad = ' ' x $pad;
      }
      
      
      # encode sequence names as ?? and ?
      $f_html .=
        #"\?\?".$ref_pad.$ref_pos.'   '.
        "\?\?".$ref_pad.'   '.
        substr($ref_seq, 0, $width)."\n".
        #'   '.($ref_pos + $width - 1)."\n".
        
        #"\?".$source_pad.$source_pos.'   '.
        "\?".$source_pad.'   '.
        substr($source_seq, 0, $width)."\n\n";
        #'   '.($source_pos + $width - 1)."\n\n";
      
      last if $width > length($ref_seq) || $width > length($source_seq);
      
      $ref_seq = substr($ref_seq, $width);
      $source_seq = substr($source_seq, $width);
      
      $ref_pos += $width;
      $source_pos += $width;
    }
    
    # colour variant red
    $f_html =~ s/(([a-z]|\/|-|\[|\])+)/'<span class="alt_allele">'.uc("$1").'<\/span>'/eg;
    
    # colour differences blue
    $f_html =~ s/([\!\£\$\%\@\*]+)/'<span style="color:blue">'.uc("$1").'<\/span>'/eg;
    
    # turn encoded bases back to original base
    $f_html =~ tr/\!\£\$\%\@\*/ACGTN\-/;
    
    # reinstate sequence names
    $f_html =~ s/\?\?/$ref_name/eg;
    $f_html =~ s/\?/$source_name/eg;
    
    $f_label = 'Flanking Sequence<br />('.$object->vari->source.' aligned to reference)';
  }
  
  my $key;
  
  if($show_mismatches eq 'yes' && $object->vari->{flank_flag}) {
    $key = ' in red, differences highlighted in blue'
  }
  
  my $warning = '';
  
  # warn if we trimmed up or down seq
  if($up_trimmed or $down_trimmed) {
    $warning = $self->_warning(
      'Flanking sequence trimmed',
      'The flanking sequence shown below has been trimmed to '.
      $trim_size.
      'bp each side of the variant position, as indicated by the \'...\' marks',
      '50%',
    );
  }
  
  $html .=  qq(
    <dl class="summary">
      <dt>$f_label</dt>
      <dd>
        $warning
        <pre>$f_html</pre>
        <blockquote><em>(Variant highlighted$key)</em></blockquote>
      </dd>
    </dl>
  );


  return $html;
}

1;
