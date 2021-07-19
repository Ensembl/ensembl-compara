=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::LRG::LRGAlign;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::LRG);


sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}


sub content {
  my $self   = shift;
  my $object = $self->object;
  my $hub    = $self->hub;
  my $html   = '';

  my $lrg         = $object->Obj;
  my $param       = $hub->param('lrg');
  my $href        = $self->hub->species_defs->ENSEMBL_EXTERNAL_URLS->{'LRG'};
     $href =~ s/###ID###/$param/;
  my @genes       = @{$lrg->get_all_Genes('LRG_import')||[]};
  my $db_entry    = $genes[0]->get_all_DBLinks('HGNC');
  my $slice       = $lrg->feature_Slice;

  my $slice_adaptor = $self->hub->database('core')->get_SliceAdaptor;
 
  my $exons = $lrg->get_all_Exons;
  my %lrg_exons_start = map { $_->start => $_->end } @{$exons};
 
  # Chr slice 
  my $chr    = $slice->seq_region_name;
  my $start  = $self->thousandify($slice->start);
  my $end    = $self->thousandify($slice->end);
  my $strand = $slice->strand < 0 ? ' reverse strand' : 'forward strand';

  
  # LRG slice    
  my $lrg_slice  = $slice_adaptor->fetch_by_region('LRG', $param);
  my $lrg_chr    = $lrg_slice->seq_region_name;
  my $lrg_start  = $self->thousandify($lrg_slice->start);
  my $lrg_end    = $self->thousandify($lrg_slice->end);
  my $lrg_strand = $lrg_slice->strand < 0 ? ' reverse strand' : 'forward strand';
  
  
  # Mappings
  my $asma = $self->hub->database('core')->get_AssemblyMapperAdaptor();
  my $csa  = $self->hub->database('core')->get_CoordSystemAdaptor();
  
  my $chr_cs = $csa->fetch_by_name('chromosome');
  my $lrg_cs = $csa->fetch_by_name('LRG');

  my $asm_mapper = $asma->fetch_by_CoordSystems( $lrg_cs, $chr_cs );

  # Map to chromosome coordinate system from contig.
  my @chr_coords =
      $asm_mapper->map( $param, $lrg_slice->start, $lrg_slice->end, $lrg_slice->strand,
      $lrg_cs );

  my $coords;
  my $gaps;
  my $ref_start;

  # Flag to know whether the LRG mapping on the chromosome is in the forward or the reverse strand.
  my $reverse = 0;
  if ($slice->strand < 0) {
    $reverse = 1;
  }
  
  # Stores genomic coordinates
  foreach my $coord (@chr_coords) {
    if ($coord->isa('Bio::EnsEMBL::Mapper::Coordinate')) {
      my $c_start = $coord->start;
      my $c_end   = $coord->end; 
      $coords->{$c_start} = $coord;
      my $ref_slice = $slice_adaptor->fetch_by_region('chromosome', $chr, $coord->start, $coord->end, $coord->strand);    
      if ($reverse) {
        if (!$ref_start) {
          $ref_start = $c_end;
        } else {
          $ref_start = $c_end if ($ref_start < $c_end);
        }
      } else {
        if (!$ref_start) {
          $ref_start = $c_start;
        } else {
          $ref_start = $c_start if ($ref_start > $c_start);
        }
      }
    }
    else {
      $gaps->{$coord->start} = $coord->end;
    }
  }
  
  # Slice order has to be changed if it is on the reverse strand
  my @keys_coord;
  if ($reverse) {
    @keys_coord = reverse sort(keys(%$coords));
  }else {
    @keys_coord = sort(keys(%$coords));
  }
  
  # Initialised the variables
  my $align_start = $lrg_start;
  $align_start =~ s/,//g;
  
  my $ref_line;
  my $align_line;
  my $lrg_line;
  my $line_count = 0;
  my @lrg_nt = split(//, $lrg_slice->seq);
  $lrg_end =~ s/,//g;
  my $max_spaces = 10;
  my $line_length = 100;
  my $spaces = '     ';
  for (my $l=0;$l<$max_spaces;$l++){
    $spaces .= ' ';
  }
  my $vars = {'ref_count'  => $ref_start,
              'lrg_count'  => $align_start,
              'ref_idx'    => 0,
              'lrg_idx'    => 0,
              'ref_start'  => $ref_start,
              'lrg_start'  => $align_start,
              'max_spaces' => 10,
              'reverse'    => $reverse,
             };
             
  my $colours_defs = $hub->species_defs->colour('protein_feature');
  
  my %colours = ('LRG insertion' => $colours_defs->{insert}->{default}, #'#0000CC',
                 'LRG deletion'  => $colours_defs->{delete}->{default}, #'#FF0000',
                 'Substitution'  => $colours_defs->{snp}->{default});   #'#00BB00');
  
  # Legend
  my $exons_highlight = qq{style="background-color:#ffebcd"};
  $html .= qq{
  <div class="_adornment_key adornment-key"><dl>
    <dt>Exons:</dt><dd><ul><li><span class="adorn-key-entry" $exons_highlight>LRG exons</span></li></ul></dd>
    <dt>Differences:</dt><dd><ul>};
  while (my ($type, $c) = each (%colours)) {
    $html .= qq{<li><span class="adorn-key-entry" style="background-color:$c;color:#FFFFFF">$type</span></li>};
  }
  $html .= qq{</ul></dd></dl></div>};


  $html .= qq{<pre style>};
  
  # Each mapped sub-slices
  foreach my $c (@keys_coord) {
    my $coord = $coords->{$c};
    my $ref_slice = $slice_adaptor->fetch_by_region('chromosome', $slice->seq_region_name, $coord->start, $coord->end, $coord->strand);    
    my $ref_seq = $ref_slice->seq;
    my @ref_nt = split(//, $ref_seq);
    my $start;
    if ($reverse) {
      $start = $ref_slice->end;
    } else {
      $start = $ref_slice->start;
    }
    $start =~ s/,//g;
    
    # LRG Deletion (<=> Genomic insertion)
    # Reverse strand
    if ($reverse) {
      if ($start < ($ref_start-$vars->{ref_idx})) {
        my $lrg_location = $align_start+$vars->{lrg_idx};
        $ref_line .= qq{</span><span id="$lrg_location"></span><span>}; # Add an anchor
      }
      while ($start < ($ref_start-$vars->{ref_idx})) {
        my $location = $ref_start-$vars->{ref_idx};
        my $colour = $colours{'LRG deletion'};
        my $gap_slice = $slice_adaptor->fetch_by_region('chromosome', $slice->seq_region_name, $location, $location, $coord->strand);
        my $gap_seq = $gap_slice->seq;
       
        my $highlight = qq{style="background-color:$colour;color:#FFFFFF"}; 
 
        $ref_line   .= qq{</span><span $highlight>$gap_seq</span><span>};
        $lrg_line   .= qq{</span><span $highlight>-</span><span>};
        $vars->{ref_idx} ++;
        $line_count ++;
      
        # Print line
        if ($line_count == $line_length) {
          (my $line,$vars,$ref_line,$lrg_line) = $self->print_line($vars,$ref_line,$lrg_line);
          $html .= $line;
          $line_count = 0;
        }
      }
    }
    # Foward strand
    else {
      if ($start > ($ref_start+$vars->{ref_idx})) {
        my $lrg_location = $align_start+$vars->{lrg_idx};
        $ref_line .= qq{</span><span id="$lrg_location"></span><span>}; # Add an anchor
      }
      while ($start > ($ref_start+$vars->{ref_idx})) {
        my $location = $ref_start+$vars->{ref_idx};
        my $colour = $colours{'LRG deletion'};
        my $gap_slice = $slice_adaptor->fetch_by_region('chromosome', $slice->seq_region_name, $location, $location, $coord->strand);
        my $gap_seq = $gap_slice->seq;
       
        my $highlight = qq{style="background-color:$colour;color:#FFFFFF"};
 
        $ref_line   .= qq{</span><span $highlight>$gap_seq</span><span>};
        $lrg_line   .= qq{</span><span $highlight>-</span><span>};
        $vars->{ref_idx} ++;
        $line_count ++;
      
        # Print line
        if ($line_count == $line_length) {
          (my $line,$vars,$ref_line,$lrg_line) = $self->print_line($vars,$ref_line,$lrg_line);
          $html .= $line;
          $line_count = 0;
        }
      }
    }
  
    
    # Browse the slice sequence
    for (my $i=0; $i<scalar(@ref_nt);$i++) {
    
      # Print line
      if ($line_count == $line_length) {
        (my $line,$vars,$ref_line,$lrg_line) = $self->print_line($vars,$ref_line,$lrg_line);
        $html .= $line;
        $line_count = 0;
      }
    
      # LRG Insertion
      my $insert_start;
      my $insert_end;
      if ($gaps->{$align_start+$vars->{lrg_idx}}) {
        my $colour = $colours{'LRG insertion'};
        my $highlight = qq{style="background-color:$colour;color:#FFFFFF"};
        my $gap_start = $align_start+$vars->{lrg_idx};
        $ref_line .= qq{</span><span id="$gap_start"></span><span>}; # Add an anchor
        while ($gaps->{$gap_start} >= $align_start+$vars->{lrg_idx}) {
          
          # Print line
          if ($line_count == $line_length) {
            (my $line,$vars,$ref_line,$lrg_line) = $self->print_line($vars,$ref_line,$lrg_line);
            $html .= $line;
            $line_count = 0;
          } 
          
          $ref_line   .= qq{</span><span $highlight>-</span><span>};
          $vars->{lrg_idx} ++;
          $line_count ++;
        }
        my $insert_seq = $lrg_slice->subseq($gap_start,$gaps->{$gap_start},$lrg_slice->strand);
        $lrg_line .= qq{</span><span $highlight>$insert_seq</span><span>};
      }
      
      # Equal the Ref (no "Diffence highlighting")
      if ($ref_nt[$i] eq $lrg_nt[$vars->{lrg_idx}]) {
        $ref_line   .= $ref_nt[$i];
        my $lrg_pos = $align_start+$vars->{lrg_idx};
        my @in_exon = grep { $lrg_exons_start{$_} >= $lrg_pos } grep { $_ <= $lrg_pos } sort(keys(%lrg_exons_start));
        my $lrg_seq = $lrg_nt[$vars->{lrg_idx}];
        $lrg_line   .= (scalar @in_exon) ? qq{<span $exons_highlight>$lrg_seq</span>} : $lrg_seq;
      }
      # LRG Substitution
      else {
        my $colour = $colours{'Substitution'};
        my $highlight = qq{style="background-color:$colour;color:#FFFFFF"};
        my $lrg_char = $lrg_nt[$vars->{lrg_idx}];
        my $lrg_location = $align_start+$vars->{lrg_idx};
        $ref_line   .= qq{</span><span id="$lrg_location" $highlight>$ref_nt[$i]</span><span>};
        $lrg_line   .= qq{</span><span $highlight>$lrg_char</span><span>};
      }
      $line_count ++;
      $vars->{lrg_idx} ++;
      $vars->{ref_idx} ++;
    }
  }
  # Print line
  if ($line_count) {
    (my $line,$vars,$ref_line,$lrg_line) = $self->print_line($vars,$ref_line,$lrg_line);
    $html .= $line;
  }
  
  $html .= qq{</pre>};
  return $html;
}


sub print_line {
  my $self     = shift;
  my $vars     = shift;
  my $ref_line = shift;
  my $lrg_line = shift;
  
  my $length_ref_count = $vars->{max_spaces}-length($vars->{ref_count})+2;
  my $length_lrg_count = $vars->{max_spaces}-length($vars->{lrg_count})+2;
  my $ref_spaces = '';
  my $lrg_spaces = '';
  for (my $j=0;$j<$length_ref_count;$j++){
    $ref_spaces .= ' ';
  }
  for (my $k=0;$k<$length_lrg_count;$k++){
    $lrg_spaces .= ' ';
  }
  my $strand = '+';
  if ($vars->{reverse}) {
    $strand = '-';
  }
  
  my $html = "Ref($strand)$ref_spaces".$vars->{ref_count}."  <span>$ref_line</span><br />LRG   $lrg_spaces".$vars->{lrg_count}."  <span>$lrg_line</span><br /><br />";
  
  if ($vars->{reverse}) {
    $vars->{ref_count} = $vars->{ref_start}-$vars->{ref_idx};
  } else {      
    $vars->{ref_count} = $vars->{ref_start}+$vars->{ref_idx};
  }
  $vars->{lrg_count} = $vars->{lrg_start}+$vars->{lrg_idx};
  
  $ref_line = '';
  $lrg_line = '';
  
  return ($html,$vars,$ref_line,$lrg_line);
}

1;
