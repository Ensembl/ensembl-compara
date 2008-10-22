package Bio::EnsEMBL::GlyphSet::_das;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_generic);

use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;

use Data::Dumper;

sub _das_type {  return 'das'; }

sub features       { 
  my $self = shift;
  
  ## Fetch all the das features...
  unless( $self->cache('das_features') ) {
    # Query by slice:
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'}, 'maxbins' => $self->image_width )||{} );
  }
  
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

  my $c_f=0;
  my $c_g=0;
  for my $logic_name ( @logic_names ) {
    local $Data::Dumper::Indent = 1;    

    my $stylesheet = $data->{ $logic_name }{ 'stylesheet' } || Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new();
    push @urls, @{ $data->{ $logic_name }{ 'features_urls' } };
    push @errors, @{ $data->{ $logic_name }{ 'errors'   } };

    $c_f += @{$data->{ $logic_name }{ 'features' }};

    foreach my $f ( @{$data->{ $logic_name }{ 'features' }} ) {
      unless( exists $feature_styles{$logic_name}{ $f->type_category}{ $f->type } ) {
        my $st = $stylesheet->find_feature_glyph( $f->type_category, $f->type, 'default' );
        $feature_styles{$logic_name}{$f->type_category}{$f->type} = {
          'style'      => $st,
          'use_score'  => ($st->{'symbol'} =~ /^(histogram|tiling|lineplot|gradient)/i ? 1 : 0)
        };
        $max_height = $st->{height} if $st->{height} > $max_height;
      };
      my $fs = $feature_styles{$logic_name}{ $f->type_category}{ $f->type };
      if( $fs->{'use_score'} ) { ## These are the score based symbols
        $min_score = $f->score if $f->score < $min_score;
        $max_score = $f->score if $f->score > $max_score;
      }
## Loop through each group so we can merge this into "group-based clusters"
      my $st = $f->seq_region_strand || 0;
      $orientations{ $st }++;
      if( @{$f->groups} ) { ## Feature has groups so use them...
        foreach( @{$f->groups} ) {
          my $g  = $_->{'group_id'};
          my $ty = $_->{'group_type'};
          my $gs = $group_styles{$logic_name}{ $ty } ||= { 'style' => $stylesheet->find_group_glyph( $ty, 'default' ) };
          if( exists $groups{$logic_name}{$g}{$st} ) {
            my $t = $groups{$logic_name}{$g}{$st};
            push @{ $t->{'features'}{$f->type_category}{$f->type } }, $f;
            $t->{'start'} = $f->start if $f->start < $t->{'start'};
            $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
            $t->{'count'} ++;
          } else {
            $c_g++;
            $groups{$logic_name}{$g}{$st} = {
              'count'   => 1,
              'type'    => $ty,
              'id'      => $g,
              'label'   => $_->{'group_label'},
              'notes'   => $_->{'notes'},
              'links'   => $_->{'links'},
              'targets' => $_->{'target'},
              'features'=>{$f->type_category=>{$f->type=>[$f]}},'start'=>$f->start,'end'=>$f->end
            };
          }
        }
      } else { ## Feature doesn't have groups so fake it with the feature id as group id!
        my $g     = $fs->{'use_score'} ? 'default' : $f->display_id;
        my $label = $fs->{'use_score'} ? ''        : $f->display_label;
        my $ty = $f->type;       # & the feature type
        my $gs = $group_styles{$logic_name}{ $ty } ||= { 'style' => $stylesheet->find_group_glyph( $ty, 'default' ) };
        if( exists $groups{$logic_name}{$g}{$st} ) {
## Ignore all subsequent notes, links and targets, probably should merge arrays somehow....
          my $t = $groups{$logic_name}{$g}{$st};
          push @{ $t->{'features'}{$f->type_category}{$f->type } }, $f;
          $t->{'start'} = $f->start if $f->start < $t->{'start'};
          $t->{'end'}   = $f->end   if $f->end   > $t->{'end'};
          $t->{'count'} ++;
        } else {
          $c_g++;
          $groups{$logic_name}{$g}{$st} = {
            'count'   => 1,
            'type'    => $ty,
            'id'      => $g,
            'label'   => $label,
            'notes'   => $f->{'note'},   ## Push the features notes/links and targets on!
            'links'   => $f->{'link'},
            'targets' => $f->{'target'},
            'features'=>{$f->type_category=>{$f->type=>[$f]}},'start'=>$f->start,'end'=>$f->end
          };
        }
      }
    }
    foreach my $logic_name (keys %feature_styles) {
      foreach my $cat (keys %{$feature_styles{$logic_name}}) {
        foreach my $type (keys %{$feature_styles{$logic_name}{$cat}}) {
          my $fs = $feature_styles{$logic_name}{$cat}{$type};
          if( $fs->{use_score} ) {
            $fs->{style}{min} = $min_score unless exists $fs->{style}{min};
            $fs->{style}{max} = $max_score unless exists $fs->{style}{max};
         }
        }
      }
    }
  }  
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
  warn join "\n", @urls;
  local $Data::Dumper::Indent = 1;
  warn Dumper( \%feature_styles );
  warn Dumper( \%group_styles );
warn "MH: $max_height";
  return {
    'f_count'    => $c_f,
    'g_count'    => $c_g,
    'merge'      => 1, ## Merge all logic names into one track! note different from other systems!!
    'groups'     => \%groups,
    'f_styles'   => \%feature_styles,
    'g_styles'   => \%group_styles,
    'errors'     => \@errors,
    'urls'       => \@urls,
    'ori'        => \%orientations,
    'max_height' => $max_height
  };
}

1;
