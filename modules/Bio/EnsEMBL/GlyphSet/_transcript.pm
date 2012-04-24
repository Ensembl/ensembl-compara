package Bio::EnsEMBL::GlyphSet::_transcript;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_transcript);

sub features {
  my $self           = shift;
  my $slice          = $self->{'container'};
  my $db_alias       = $self->my_config('db');
  my $analyses       = $self->my_config('logic_names');
  my $display        = $self->my_config('display');
  my $selected_gene  = $self->my_config('g') || $self->core('g');
  my $selected_trans = $self->core('t')      || $self->core('pt');
  my $highlight      = $self->core('db') eq $self->my_config('db') ? $display =~ /gene/ ? 'highlight2' : 'highlight1' : undef;
  my @features;
  
  ## FIXME - this is an ugly hack!
  if ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
    @features = map @{$slice->feature_Slice->get_all_Genes($_, $db_alias) || []}, @$analyses;
  } else {
    @features = map @{$slice->get_all_Genes($_, $db_alias, 1) || []}, @$analyses;
  }
  
  if ($highlight) {
    $_->{'draw_highlight'} = $highlight for grep $_->stable_id eq $selected_gene, @features;
  }
  
  if ($display =~ /collapsed/) {
    $_->{'draw_exons'} = [ map @{$_->get_all_Exons}, @{$_->get_all_Transcripts} ] for @features;
  } elsif ($display =~ /transcript/) {
    my $coding_only = $display =~ /coding/;
    
    foreach my $gene (@features) {
      my $is_coding_check = $coding_only ? $self->is_coding_gene($gene) : 0;
      my @transcripts = @{$gene->get_all_Transcripts};
         @transcripts = grep $_->translation, @transcripts if $is_coding_check;
      
      foreach (@transcripts) {
        my $transcript_coding_start = defined $_->coding_region_start ? $_->coding_region_start : -1e6;
        my $transcript_coding_end   = defined $_->coding_region_end   ? $_->coding_region_end   : -1e6;
        my @exons;
        
        foreach (sort { $a->start <=> $b->start } grep $_, @{$_->get_all_Exons}) {
          my ($start, $end) = ($_->start, $_->end);
          my $coding_start  = $start < $transcript_coding_start ? $transcript_coding_start : $start;
          my $coding_end    = $end   > $transcript_coding_end   ? $transcript_coding_end   : $end;
          
          # The start of the transcript is before the start of the coding
          # region OR the end of the transcript is after the end of the
          # coding regions.  Non coding portions of exons, are drawn as
          # non-filled rectangles
          # Draw a non-filled rectangle around the entire exon
          if ($start < $transcript_coding_start || $end > $transcript_coding_end) {
            $_->{'draw_border'} = 1;
            push @exons, $_;
          }
          
          # Draw a filled rectangle in the coding region of the exon
          if ($coding_start <= $coding_end) {
            $_->{'draw_fill'}       = 1;
            $_->{'draw_fill_start'} = $coding_start - $start; # Calculate and draw the coding region of the exon
            $_->{'draw_fill_end'}   = $end - $coding_end;
            push @exons, $_ unless $_->{'draw_border'};
          }
        }
        
        $_->{'draw_exons'} = \@exons;
        
        if ($highlight) {
          if ($_->get_all_Attributes('ccds')->[0]) {
            $_->{'draw_highlight'} = $self->{'colours'}{'ccds_hi'} ? $self->my_colour('ccds_hi') : 'lightblue1'; # use another highlight colour if the trans has got a CCDS attrib
          } elsif ($_->stable_id eq $selected_trans) {
            $_->{'draw_highlight'} = 'highlight2';
          } else {
            $_->{'draw_highlight'} ||= $gene->{'draw_highlight'};
          }
        }
      }
      
      $gene->{'draw_transcripts'} = \@transcripts;
    }
  }
  
  return \@features;
}

sub export_feature {
  my ($self, $feature, $transcript_id, $transcript_name, $gene_id, $gene_name, $gene_type, $gene_source) = @_;
  
  return $self->_render_text($feature, 'Exon', {
    headers => [ 'gene_id', 'gene_name', 'transcript_id', 'transcript_name', 'exon_id', 'gene_type' ],
    values  => [ $gene_id, $gene_name, $transcript_id, $transcript_name, $feature->stable_id, $gene_type ]
  }, { source => $gene_source });
}

sub href {
  my ($self, $gene, $transcript) = @_;
  my $hub    = $self->{'config'}->hub;
  my $params = {
    %{$hub->multi_params},
    species    => $self->species,
    type       => $transcript ? 'Transcript' : 'Gene',
    action     => $self->my_config('zmenu') ? $self->my_config('zmenu') : $hub->action,
    g          => $gene->stable_id,
    db         => $self->my_config('db'),
    calling_sp => $hub->species,
    real_r     => $hub->param('r'),
  };

  $params->{'r'} = undef                  if $self->{'container'}{'web_species'} ne $self->species;
  $params->{'t'} = $transcript->stable_id if $transcript;

  return $self->_url($params);
}

1;
