package EnsEMBL::Web::Component;

use strict;
use Data::Dumper;
use EnsEMBL::Web::File::Text;
use Exporter;
use CGI qw(escape);
use EnsEMBL::Web::Document::SpreadSheet;
use Text::Wrap qw(wrap);

use base qw(EnsEMBL::Web::Root Exporter);
our @EXPORT_OK = qw(cache cache_print);
our @EXPORT    = @EXPORT_OK;

sub _error {
  my($self,$caption,$desc,$width) = @_;
  return sprintf '<div style="width:%s" class="error"><h3>%s</h3><div class="error-pad">%s</div></div>', 
    $width || $self->image_width.'px', $caption, $desc;
}
sub _warning {
  my($self,$caption,$desc,$width) = @_;
  return sprintf '<div style="width:%s" class="warning"><h3>%s</h3><div class="error-pad">%s</div></div>', 
    $width || $self->image_width.'px', $caption, $desc;
}
sub _info {
  my($self,$caption,$desc,$width) = @_;
  return sprintf '<div style="width:%s" class="info"><h3>%s</h3><div class="error-pad">%s</div></div>', 
    $width || $self->image_width.'px', $caption, $desc;
}

sub image_width {
  my $self = shift;

  return $ENV{'ENSEMBL_IMAGE_WIDTH'};
}
sub new {
  my( $class, $object ) = shift;
  my $self = {
    'object' => shift,
  };
  bless $self,$class;
  $self->_init();
  return $self;
}

sub object {
  my $self = shift;
  $self->{'object'} = shift if @_;
  return $self->{'object'};
}

sub cacheable {
  my $self = shift;
  $self->{'cacheable'} = shift if @_;
  return $self->{'cacheable'};
}

sub ajaxable {
  my $self = shift;
  $self->{'ajaxable'} = shift if @_;
  return $self->{'ajaxable'};
}

sub configurable {
  my $self = shift;
  $self->{'configurable'} = shift if @_;
  return $self->{'configurable'};
}

sub cache_key {
  return undef;
}

sub _init {
  return;
}

sub caption {
  return undef;
}
sub cache {
  my( $panel, $obj, $type, $name ) = @_;
  my $cache = new EnsEMBL::Web::File::Text( $obj->species_defs );
  $cache->set_cache_filename( $type, $name );
  return $cache;
}

sub cache_print {
  my( $cache, $string_ref ) =@_;
  $cache->print( $$string_ref ) if $string_ref;
}

sub site_name {
  my $self = shift;
  our $sitename = $SiteDefs::ENSEMBL_SITETYPE eq 'EnsEMBL' ? 'Ensembl' : $SiteDefs::ENSEMBL_SITETYPE;
  return $sitename;
}

sub _matches {
  my(  $self, $key, $caption, @keys ) = @_;
  my $object = $self->object;
  my $label    = $object->species_defs->translate( $caption );
  my $obj     = $object->Obj;

  # Check cache
  unless ($object->__data->{'links'}){
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    return unless (@similarity_links);
    $self->_sort_similarity_links( @similarity_links);
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;

  my $db = $object->get_db();
  my $entry = $object->gene_type || 'Ensembl';

  # add table call here
  my $html;
  if ($object->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $html = qq(<p></p>);
  }
  else {
    $html = qq(<p><strong>This $entry entry corresponds to the following database identifiers:</strong></p>);
  }
  $html .= qq(<table cellpadding="4">);
  if( $keys[0] eq 'ALT_TRANS' ) {
      @links = $self->remove_redundant_xrefs(@links);
  }
  my $old_key = '';
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if( $key ne $old_key ) {
      if($old_key eq "GO") {
        $html .= qq(<div class="small">GO mapping is inherited from swissprot/sptrembl</div>);
      }
      if( $old_key ne '' ) {
        $html .= qq(</td></tr>);
      }
      $html .= qq(<tr><th style="white-space: nowrap; padding-right: 1em">$key:</th><td>);
      $old_key = $key;
    }
    $html .= $text;
  }
  $html .= qq(</td></tr></table>);

  return $html;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $object           = $self->object;
  my @similarity_links = @_;
  my $database = $object->database;
  my $db       = $object->get_db() ;
  my $urls     = $object->ExtURL;
  my @links ;

  #default link to featureview is to retrieve an Xref
  my $fv_type = $object->action eq 'Oligos' ? 'OligoProbe' : 'Xref';

  my (%affy, %exdb);
  # @ice names
  foreach my $type (sort {
    $b->priority        <=> $a->priority ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links ) {
    my $link = "";
    my $join_links = 0;
    my $externalDB = $type->database();
    my $display_id = $type->display_id();
    my $primary_id = $type->primary_id();
    next if ($type->status() eq 'ORTH');               # remove all orthologs
    next if lc($externalDB) eq "medline";              # ditch medline entries - redundant as we also have pubmed
    next if ($externalDB =~ /^flybase/i && $display_id =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if $externalDB eq "Vega_gene";                # remove internal links to self and transcripts
    next if $externalDB eq "Vega_transcript";
    next if $externalDB eq "Vega_translation";
    next if ($externalDB eq 'OTTP') && $display_id =~ /^\d+$/; #don't show vega translation internal IDs
    if( $externalDB eq "GO" ){
      push @{$object->__data->{'links'}{'go'}} , $display_id;
      next;
    } elsif ($externalDB eq "GKB") {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}} , $type ;
      next;
    }
    my $text = $display_id;
    (my $A = $externalDB ) =~ s/_predicted//;
    if( $urls and $urls->is_linked( $A ) ) {
      my $link;
      $link = $urls->get_url( $A, $primary_id );

      my $word = $display_id;
      if( $A eq 'MARKERSYMBOL' ) {
        $word = "$display_id ($primary_id)";
      }
      if( $link ) {
        $text = qq(<a href="$link">$word</a>);
      } else {
        $text = qq($word);
      }
    }
    if( $type->isa('Bio::EnsEMBL::IdentityXref') ) {
      $text .=' <span class="small"> [Target %id: '.$type->target_identity().'; Query %id: '.$type->query_identity().']</span>';
      $join_links = 1;
    }
    if( ( $object->species_defs->ENSEMBL_PFETCH_SERVER ) &&
      ( $externalDB =~/^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i ) ) {
      my $seq_arg = $display_id;
      $seq_arg = "LL_$seq_arg" if $externalDB eq "LocusLink";
      $text .= sprintf( ' [<a href="/%s/Transcript/Similarity/Align?t=%s;sequence=%s;db=%s">align</a>] ',
                  $object->species, $object->stable_id, $seq_arg, $db );
    }
    if($externalDB =~/^(SWISS|SPTREMBL)/i) { # add Search GO link
      $text .= ' [<a href="'.$urls->get_url('GOSEARCH',$primary_id).'">Search GO</a>]';
    }
    if( $type->description ) {
      ( my $D = $type->description ) =~ s/^"(.*)"$/$1/;
      $text .= "<br />".CGI::escapeHTML($D);
      $join_links = 1;
    }
    if( $join_links  ) {
      $text = qq(\n <div>$text);
    } else {
      $text = qq(\n <div class="multicol">$text);
    }
    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if( $externalDB =~ /^AFFY_/i) {
      next if ($affy{$display_id} && $exdb{$type->db_display_name}); ## remove duplicates
      $text = "\n".'  <div class="multicol"> '.$display_id;
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    #add link to featureview
    my $link_name = ($fv_type eq 'OligoProbe') ? $display_id : $primary_id;
    my $link_type = ($fv_type eq 'OligoProbe') ? $fv_type : $fv_type . "_$externalDB";
    my $k_url = $object->_url({
	'type'   => 'Location',
	'action' => 'Genome',
	'id'     => $link_name,
	'ftype'  => $link_type,
    });
    $text .= "  [<a href=$k_url>view all locations</a>]";

    $text .= '</div>';
    push @{$object->__data->{'links'}{$type->type}}, [ $type->db_display_name || $externalDB, $text ] ;
  }
}


sub remove_redundant_xrefs {
  my ($self,@links) = @_;
  my %priorities;
  foreach my $link (@links) {
    my ( $key, $text ) = @$link;
    if ($text =~ />OTT|>ENST/) {
      $priorities{$key} = $text;
    }
  }
  foreach my $type (
    'Transcript having exact match between ENSEMBL and HAVANA',
    'Ensembl transcript having exact match with Havana',
    'Havana transcript having same CDS',
    'Ensembl transcript sharing CDS with Havana',
    'Havana transcripts') {
    if ($priorities{$type}) {
      my @munged_links;
      $munged_links[0] = [ $type, $priorities{$type} ];
      return @munged_links;;
    }
  }
  return @links;
}

sub _warn_block {
### Simple subroutine to dump a formatted "warn" block to the error logs - useful when debugging complex
### data structures etc... 
### output looks like:
###
###  ###########################
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  # TEXT. TEXT. TEXT. TEXT. #
###  # TEXT. TEXT. TEXT. TEXT. #
###  #                         #
###  ###########################
###

  my $self = shift;

  my $width       = 128;
  my $border_char = '#';
  my $template = sprintf "%s %%-%d.%ds %s\n", $border_char, $width-4,$width-4, $border_char;
  my $line     = $border_char x $width;
  warn "\n";
  warn "$line\n";
  $Text::Wrap::columns = $width-4;
  foreach my $l (@_) {
    warn sprintf $template;
    my $lines = wrap( "","", $l );
    foreach ( split /\n/, $lines ) { 
      warn sprintf $template, $_;
    }
  }
  warn sprintf $template;
  warn "$line\n";
  warn "\n";
}


sub markup_exons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my $exon_types = {};
  
  my $style = {
    exon0 => { 'color' => $config->{'colours'}->{'exon0'} },
    exon1 => { 'color' => $config->{'colours'}->{'exon1'} },
    exon2 => { 'color' => $config->{'colours'}->{'exon2'} },
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

  if ($config->{'key'}) {
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
}

sub markup_codons {
  my $self = shift;
  my ($sequence, $markup, $config) = @_;

  my ($codons, $i);

  foreach my $data (@$markup) {
    foreach (sort {$a <=> $b} keys %$data) {
      if ($data->{$_}->{'codons'}) {
        $sequence->[$i]->[$_]->{'background-color'} = $config->{'colours'}->{"codon$data->{$_}->{'bg'}"} || $config->{'colours'}->{'codonutr'};
        $sequence->[$i]->[$_]->{'title'} .= ($sequence->[$i]->[$_]->{'title'} ? '; ' : '') . $data->{$_}->{'codons'} if $config->{'title_display'};
      }
  
      $codons = 1;
    }
    
    $i++;
  }

  $config->{'key'} .= sprintf ($config->{'key_template'}, "background-color:$config->{'colours'}->{'codonutr'};", "Location of START/STOP codons") if ($codons && $config->{'key'});
}

sub markup_line_numbers {
  my $self = shift;
  my ($sequence, $config) = @_;
 
  # Incremented when name changes 
  my $n = 0;

  # If we only have only one species, $config->{'seq_order'} won't exist yet (it's created in markup_comparisons)
  $config->{'seq_order'} = [ $config->{'species'} ] unless $config->{'seq_order'};
  
  foreach my $sl (@{$config->{'slices'}}) {
    my $slice = $sl->{'slice'};
    my $name = $sl->{'name'};
    
    my @numbering;
    my $align_slice = 0;

    # DANGER, WILL ROBINSON! This assumes that the order of the slices is the same as the order
    # of the species when displayed on the page. Which it is...for now.
    $n++ if ($name && $name ne $config->{'seq_order'}->[$n]);

    my $seq = $sequence->[$n];
    
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
            
            # Padding to go before the chromosome
            $config->{'padding'}->{'pre_number'} = length $_->seq_region_name if length $_->seq_region_name > $config->{'padding'}->{'pre_number'};
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
    
    my $data = shift @numbering unless ($config->{'numbering'} && !$config->{'numbering'}->[$n]);
    
    my $s = 0;
    my $e = $config->{'wrap'} - 1;
    
    my $row_start = $data->{'start'};
    my ($start, $end);
    
    # One line longer than the sequence so we get the last line's numbers generated in the loop
    my $loop_end = $config->{'length'} + $config->{'wrap'};
    
    while ($e < $loop_end) {
      $start = '';
      $end = '';
      
      # Comparison species
      if ($align_slice) {
        my $seq_length;
        my $segment;
        
        # Build a segment containing the current line of sequence
        for ($s..$e) {
          # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
          if ($seq->[$_]) {
            $seq_length++ if $seq->[$_]->{'letter'} ne '.';
            $segment .= $seq->[$_]->{'letter'};
          }
        }
    
        my $first_bp_pos = 0;
        my $last_bp_pos = 0;

        while ($segment =~ /\w/g) {
          $last_bp_pos = pos $segment;
          $first_bp_pos ||= $last_bp_pos; # Set the first position on the first match only
        }
        
        # Get the data from the next slice if we have passed the end of the current one
        if (scalar @numbering && $e >= $numbering[0]->{'start_pos'}) {
          $data = shift @numbering;
          
          # Only set $row_start if the line begins with a .
          # If it does not, the previous slice ends mid-line, so we just carry on with it's start number
          $row_start = $data->{'start'} if $segment =~ /^\./;
        }
        
        if ($seq_length && $last_bp_pos) {
          # This is NOT necessarily the same as $end + $data->{'dir'}, as bits of sequence could be hidden
          (undef, $row_start) = $slice->get_original_seq_region_position($s + $first_bp_pos);

          $start = $row_start;

          # For AlignSlice display the position of the last meaningful bp
          (undef, $end) = $slice->get_original_seq_region_position($e + 1 + $last_bp_pos - $config->{'wrap'});
        }

        $s = $e + 1;
      } elsif ($config->{'numbering'}) { # Transcript sequence
        my $seq_length = 0;
        my $segment = '';
        
        for ($s..$e) {
          # Check the array element exists - must be done so we don't create new elements and mess up the padding at the end of the last line
          if ($sequence->[$n]->[$_]) {
            $seq_length++ if $sequence->[$n]->[$_]->{'letter'} =~ /\w/;
            $segment .= $sequence->[$n]->[$_]->{'letter'};
          }
        }
        
        $end = $e < $config->{'length'} ? $row_start + $seq_length - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start if $seq_length;
        
        # If the line starts -- or -= it is at the end of a protein section, so take one off the line number
        $start-- if ($start > $data->{'start'} && $segment =~ /^-\W/);
        
        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $start && $end;
        
        # Remove the line number if the sequence doesn't start at the beginning of the line
        $start = '' if $segment =~ /^\./;
        
        $s = $e + 1;
      } else { # Single species
        $end = $e < $data->{'end'} ? $row_start + ($data->{'dir'} * $config->{'wrap'}) - $data->{'dir'} : $data->{'end'};
        
        $start = $row_start;

        # Next line starts at current end + 1 for forward strand, or - 1 for reverse strand
        $row_start = $end + $data->{'dir'} if $end;
      }
      
      my $ch = $start ? ($config->{'comparison'} && $data->{'chromosome'}) : '';   

      push (@{$config->{'line_numbers'}->{$n}}, { start => $start, end => $end, pre => $ch });

      # Increase padding amount if required
      $config->{'padding'}->{'number'} = length $start if length $start > $config->{'padding'}->{'number'};
      
      $e += $config->{'wrap'};
    }
  }
 
  $config->{'padding'}->{'pre_number'}++ if $config->{'padding'}->{'pre_number'}; # Compensate for the : after the chromosome
 
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
      } elsif ($config->{'maintain_colour'} && $style =~ /(?<!background-)color:(.+);/) {
        $new_style .= "color:$1;";
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
          if (scalar keys %{$config->{'padded_species'}}) {
            $pre = $config->{'padded_species'}->{$config->{'seq_order'}->[$s]} || $config->{'species'};
          } else {
            $pre = $config->{'species'};
          }

          $pre .= '  ';
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
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $num->{'pre'});
        my $pad2 = ' ' x ($config->{'padding'}->{'number'} - length $num->{'start'});

        $line = $config->{'h_space'} . sprintf("%6s ", "$pad1$num->{'pre'}$pad2$num->{'start'}") . $line;
      }
      
      if ($x == $length && ($config->{'end_number'} || $_->[$x]->{'post'})) {
        $line .= ' ' x ($config->{'wrap'} - $_->[$x]->{'length'});
      }
      
      if ($config->{'end_number'}) {
        my $pad1 = ' ' x ($config->{'padding'}->{'pre_number'} - length $num->{'pre'});
        my $pad2 = ' ' x ($config->{'padding'}->{'number'} - length $num->{'end'});

        $line .= $config->{'h_space'} . sprintf(" %6s", "$pad1$num->{'pre'}$pad2$num->{'end'}");
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
