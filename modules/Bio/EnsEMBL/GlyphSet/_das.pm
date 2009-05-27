package Bio::EnsEMBL::GlyphSet::_das;

use strict;

use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;
use Bio::EnsEMBL::ExternalData::DAS::Feature;
use POSIX qw(floor ceil);
use Data::Dumper;

use base qw(Bio::EnsEMBL::GlyphSet_generic);

sub gen_feature {
  my $self = shift;
  return Bio::EnsEMBL::ExternalData::DAS::Feature->new(shift);
}

sub features       { 
  my $self = shift;
  
  ## Fetch all the das features...
  unless( $self->cache('das_features') ) {
    # Query by slice:
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'}, 'maxbins' => $self->image_width )||{} );
  }
  $self->timer_push( 'Raw fetch of DAS features',undef,'fetch');  
  my $data = $self->cache('das_features');
  
  my @logic_names =  @{ $self->my_config('logicnames') };
  my $res = {};

  my %feature_styles = ();
  my %group_styles   = ();
  my $min_score      = 0;
  my $max_score      = 0;
  my $max_height     = 0;
  my %groups         = ();  
  my %orientations   = ();
  my @urls           = ();
  my @errors         = ();

  my $strand_flag = $self->my_config('strand');

  my $c_f=0;
  my $c_g=0;
  local $Data::Dumper::Indent = 1;    
  for my $logic_name ( @logic_names ) {

    my $stylesheet = $data->{ $logic_name }{ 'stylesheet' }{ 'object' }
      || Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new();
    for my $segment ( keys %{ $data->{ $logic_name }{ 'features' } } ) {
      
      my $f_data = $data->{ $logic_name }{ 'features' }{ $segment };
      push @urls,   $f_data->{ 'url' };
      push @errors, $f_data->{'error'};
      
      for my $f ( @{ $f_data->{'objects'} } ) {
        # Skip nonpositional features
        $f->start || $f->end || next;
        
        my $style_key = $f->type_category."\t".$f->type_id;
        unless( exists $feature_styles{$logic_name}{ $style_key } ) {
          my $st = $stylesheet->find_feature_glyph( $f->type_category, $f->type_id, 'default' );
          $feature_styles{$logic_name}{$style_key} = {
            'style'      => $st,
            'use_score'  => ($st->{'symbol'} =~ /^(histogram|tiling|lineplot|gradient)/i ? 1 : 0)
          };
          $max_height = $st->{height} if $st->{height} > $max_height;
        };
        my $fs = $feature_styles{$logic_name}{$style_key};
        next if $fs->{'style'}{'symbol'} eq 'hidden';  ## STYLE MEANS NOT DRAWN!
        $c_f ++;
        if( $fs->{'use_score'} ) { ## These are the score based symbols
          $min_score = $f->score if $f->score < $min_score;
          $max_score = $f->score if $f->score > $max_score;
        }
  ## Loop through each group so we can merge this into "group-based clusters"
        my $st = $f->seq_region_strand || 0;
        my $st_x = $strand_flag eq 'r' ? -1
                 : $strand_flag eq 'f' ?  1
                 :                       $st;
        $orientations{ $st_x }++;
        if( @{$f->groups} ) { ## Feature has groups so use them...
          foreach( @{$f->groups} ) {
            my $g  = $_->{'group_id'};
            my $ty = $_->{'group_type'};
            $group_styles{$logic_name}{ $ty } ||= { 'style' => $stylesheet->find_group_glyph( $ty, 'default' ) };
            
            if( exists $groups{$logic_name}{$g}{$st_x} ) {
              my $t = $groups{$logic_name}{$g}{$st_x};
              push @{ $t->{'features'}{$style_key} }, $f;
              $t->{'start'} = $f->start if $f->start < $t->{'start'};
              $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
              $t->{'count'} ++;
            } else {
              $c_g++;
              $groups{$logic_name}{$g}{$st_x} = {
                'strand'  => $st,
                'count'   => 1,
                'type'    => $ty,
                'id'      => $g,
                'label'   => $_->{'group_label'},
                'notes'   => $_->{'note'},
                'links'   => $_->{'link'},
                'targets' => $_->{'target'},
                'features'=>{$style_key=>[$f]},'start'=>$f->start,'end'=>$f->end,
                'fnotes'  => $f->{'note'},
                'flinks'  => $f->{'link'}
              };
            }
          }
        } else { ## Feature doesn't have groups so fake it with the feature id as group id!
          # Do not display any group glyphs for "logical" groups (score-based or unbumped)
          my $pseudogroup = ( $fs->{'use_score'} || $fs->{'style'}{'bump'} eq 'no' || $fs->{'style'}{'bump'} eq '0' );
          my $g     = $pseudogroup ? 'default' : $f->display_id;
          my $label = $pseudogroup ? ''        : $f->display_label;
          # But do for "hacked" groups (shared feature IDs). May change this behaviour later as servers really shouldn't do this
          my $ty = $f->type_id;
          $group_styles{$logic_name}{ $ty } ||= { 'style' => $pseudogroup ? $HIDDEN_GLYPH : $stylesheet->find_group_glyph( 'default', 'default' ) };
          if( exists $groups{$logic_name}{$g}{$st_x} ) {
  ## Ignore all subsequent notes, links and targets, probably should merge arrays somehow....
            my $t = $groups{$logic_name}{$g}{$st_x};
            push @{ $t->{'features'}{$style_key} }, $f;
            $t->{'start'} = $f->start if $f->start < $t->{'start'};
            $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
            $t->{'count'} ++;
          } else {
            $c_g++;
            $groups{$logic_name}{$g}{$st_x} = {
              'fake'    => 1,
              'strand'  => $st,
              'count'   => 1,
              'type'    => $ty,
              'id'      => $g,
              'label'   => $label,
              'notes'   => $f->{'note'},   ## Push the features notes/links and targets on!
              'links'   => $f->{'link'},
              'targets' => $f->{'target'},
              'features'=>{$style_key=>[$f]},'start'=>$f->start,'end'=>$f->end
            };
          }
        }
      }
    
    }
## If we used a guessed max/min make it significant to two figures!!
    if( $max_score == $min_score ) { ## If we have all "0" data adjust so we have a range
      $max_score =  0.1;
      $min_score = -0.1;
    } else {
      my $base = 10**POSIX::ceil(log($max_score-$min_score)/log(10))/100;
      $min_score = POSIX::floor( $min_score / $base ) * $base;
      $max_score = POSIX::ceil(  $max_score / $base ) * $base;
    }
    foreach my $logic_name (keys %feature_styles) {
      foreach my $style_key (keys %{$feature_styles{$logic_name}}) {
        my $fs = $feature_styles{$logic_name}{$style_key};
        if( $fs->{use_score} ) {
          $fs->{style}{min} = $min_score unless exists $fs->{style}{min};
          $fs->{style}{max} = $max_score unless exists $fs->{style}{max};
          if( $fs->{style}{min} == $fs->{style}{max} ) { ## Fudge if max=min add .1 to each so we can display it!
            $fs->{style}{max} = $fs->{style}{max} + 0.1;
            $fs->{style}{min} = $fs->{style}{min} - 0.1;
          } elsif( $fs->{style}{min} > $fs->{style}{max} ) { ## Fudge if min>max swap them... only possible in user supplied data!
            ($fs->{style}{max},$fs->{style}{min}) =
            ($fs->{style}{min},$fs->{style}{max});
          }
        }
      }
#      warn "DAS: source: $logic_name\n";
    }
  }  
  if( $self->species_defs->ENSEMBL_DEBUG_FLAGS & $self->species_defs->ENSEMBL_DEBUG_DRAWING_CODE ) {
    warn "[DAS:@logic_names]\n";
    if( @urls ) {
      warn join "\n", map( { "  $_" } @urls ),''
    } else {
      warn "  NO DAS feature requests made for this source....\n";
    }
  }
#  @errors = grep {$_} @errors;
#  warn join "\n", map( { "DAS:ERR $_" } @errors ),'' if @errors;


if(0) { 
  warn sprintf "%d features returned in %d groups", $c_f, $c_g;
  warn "Logic name           Type                 Group ID            Ori Count     Start       End Label\n";
  foreach my $l (keys %groups) {
    foreach my $g (keys %{$groups{$l}}) {
      foreach my $st (keys %{$groups{$l}{$g}}) {
        my $t = $groups{$l}{$g}{$st};
        warn sprintf "%-20.20s %-20.20s %-20.20s %2d %5d %9d %9d %s\n", $l, $t->{details}{'group_type'},$g, $st, $t->{count}, $t->{start}, $t->{end}, $t->{details}{'label'};
      }
    }
  }
  warn join "\t", "Orientations: ", sort {$a<=>$b} keys %orientations;
  local $Data::Dumper::Indent = 1;
  warn Dumper( \%feature_styles );
  warn "MH: $max_height";
}
  return {
    'f_count'    => $c_f,
    'g_count'    => $c_g,
    'merge'      => 1, ## Merge all logic names into one track! note different from other systems!!
    'groups'     => \%groups,
    'f_styles'   => \%feature_styles,
    'g_styles'   => \%group_styles,
    'errors'     => \@errors,
    'ss_errors'  => [],
    'urls'       => \@urls,
    'ori'        => \%orientations,
    'max_height' => $max_height
  };
}

sub export_feature {
  my $self = shift;
  my ($feature, $source) = @_;
  
  my $feature_id = $feature->{'feature_id'};
  my @headers = ( 'id' );
  my @values;
  
  # Split into key/value pairs on | and =
  if ($feature_id =~ /.+:.+\|.+/) {
    my @tmp = split(/\s*:\s*/, $feature_id);
    my @vals = split(/\s*\|\s*/, $tmp[1]);
    
    push @values, $tmp[0];
    
    foreach (@vals) {
      my ($header, $value) = split(/\s*=\s*/, $_);
      push @headers, $header;
      push @values, $value;
    }
  } elsif ($feature_id =~ /\d+:\d+[-,]\d+/) {
    my $groups = $feature->groups;
    
    foreach (@{$groups||[$feature]}) {
      my $display_id = $_->display_id;
      
      my ($header, $value) = $display_id =~ /:/ ? split(/:/, $display_id) : (undef, $display_id);
      
      push @headers, $header if $header;
      push @values, $value;
    }
    
    # Get rid of the 'id' entry in headers if we don't need it
    shift @headers if scalar @headers != scalar @values;
  } else {
    push @values, $feature_id;
  }
  
  return $self->_render_text($feature, 'DAS', {
    'headers' => \@headers,
    'values' => \@values
  }, { 'source' => $source });
}

1;
