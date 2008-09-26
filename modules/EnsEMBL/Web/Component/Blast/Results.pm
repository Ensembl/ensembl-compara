package EnsEMBL::Web::Component::Blast::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use EnsEMBL::Web::Document::SpreadSheet;
use EnsEMBL::Web::Form;
use Data::Dumper;
use CGI qw(escapeHTML);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  my $html = qq(<h2>$sitename Blast Results</h2>);

  my ($species, $alignments) = $object->retrieve_data;

  if (ref($alignments) eq 'ARRAY' && scalar(@$alignments) > 0) {
    ## Display alignments in various ways!

    ## Summary
    (my $species_name = $species) =~ s/_/ /g;
    $html .= "<h3>Displaying unnamed sequence alignments vs $species_name LATESTGP database</h3>";

    ## Karyotype (if available)
    $html .= "<h3>Alignment location vs karyotype</h3>";
    if ($object->species_defs->get_config($species, 'ENSEMBL_CHROMOSOMES')) {
      $html .= _draw_karyotype($object, $species, $alignments);
    }
    else {
      $html .= '<p>Sorry, this species has not been assembled into chromosomes</p>';
    }

    ## Alignment image
    $html .= "<h3>Alignment locations vs query</h3>";
    $html .= _draw_alignment($object, $species, $alignments);

    ## Alignment table
    $html .= "<h3>Alignment summary</h3>";
    $html .= _display_alignment_table($object, $species, $alignments);
  }
  else {
    ## Show error message
    $html .= "<p>Sorry, no alignments found.</p>";  
  }
  return $html;
}

sub _draw_karyotype {
  my ($object, $species, $alignments) = @_;

  return "[KARYOTYPE GOES HERE!]"; ## Placeholder until drawing code fixed!
  my $config_name = 'Vkaryotype';
  my $config = $object->get_userconfig($config_name);
  my $image    = $object->new_karyotype_image();

  ## Create highlights - arrows and outline box
  my %highlights1 = ('style' => 'rharrow');
  my %highlights2 = ('style' => 'outbox');

  my @colours = qw( gold orange chocolate firebrick darkred );

  # Create per-hit glyphs
  my @glyphs;
  my $first=1;
  foreach( @$alignments ){
    my( $hit, $hsp ) = @{$_};
    my $gh        = $hsp->genomic_hit;
    my $chr       = $gh->seq_region_name;
    my $chr_start = $gh->seq_region_start;
    my $chr_end   = $gh->seq_region_end;
    my $caption   = "Alignment vs ". $hsp->hit->seq_id;
    my $score     = $hsp->score;
    my $pct_id    = $hsp->percent_identity;
    my $colour_id = int( ($pct_id-1)/20 );
    my $colour    = @colours[ $colour_id ];

    $highlights1{$chr} ||= [];
    push( @{$highlights1{$chr}}, $config );

    if( $first ){
      $first = 0;
      $highlights2{$chr} ||= [];
      push ( @{$highlights2{$chr}}, { start => $chr_start,
                                      end   => $chr_end,
                                      score => $score,
                                      col   => $colour } );
    }

  }

  $image->image_name = "blast";
  $image->imagemap = 'yes';
  my $pointers = [\%highlights1, \%highlights2];
  $image->karyotype( $object, $pointers, $config_name );

  return $image->render;
}

sub _draw_alignment {
  my ($object, $species, $alignments) = @_;
  return "<p>ALIGNMENT IMAGE GOES HERE</p>";
  # See &draw_hsp_vs_query in perl/multi/blastview
}

sub _display_alignment_table {
  my ($object, $species, $alignments) = @_;
  my $html = qq(<p class="space-below">Select rows to include in table, and type of sort (Use the 'ctrl' key to select multiples) [Refresh display]</p>);

  ## Do options table -----------------------------------
  ## TODO: move to ViewConfig
  my @view_types = qw( query subject );
  my %coords = reverse %{$object->fetch_coord_systems};
  my $toplevel = $coords{1};
  my @coord_systems = sort { $coords{$a} <=> $coords{$b} } values %coords;
  push @view_types, @coord_systems, qw(stats sort_by);

  my $opt_table = EnsEMBL::Web::Document::SpreadSheet->new();
  my $width = int(100 / scalar(@view_types));

  my ($selector, $type);
  my @stat_types = qw(score evalue pvalue identity length);
  my %lookup = (
    'evalue'    => 'E-val',
    'pvalue'    => 'P-val',
    'identity'  => '%ID',
  );
  foreach $type (@view_types) {
    $opt_table->add_columns( {'key' => $type, 'title' => ucfirst($type), 'width' => $width.'%', 'align' => 'left'} );
    my $widget = qq(<select name="view_$type" multiple="multiple" size="3">\n");
    if ($type eq 'sort_by') { 
      my @sort_types = @view_types;
      pop @sort_types;
      push @sort_types, @stat_types;
      foreach my $T (@sort_types) {
        my $text = $lookup{$T} || ucfirst($T);
        $widget .= '<option value="'.$T.'_asc">&lt;'."$text</option>\n";
        $widget .= '<option value="'.$T.'_dsc">&gt;'."$text</option>\n";
      }
    }
    else {
      $widget .= qq(<option value="off">_off_</option>\n);
      if ($type eq 'stats') {
        foreach my $S (@stat_types) {
          my $text = $lookup{$S} || ucfirst($S);
          $widget .= qq(<option value="$S">$text</option>\n);
        }
      }
      else {
        $widget .= qq(<option value="name">Name</option>
<option value="start">Start</option>
<option value="end">End</option>
<option value="orientation">Ori</option>
);
      }
    }
    $widget .= "</select>\n";
    $selector->{$type} = $widget;
  }
  $opt_table->add_row($selector);

  $html .= $opt_table->render; 

  $html .= '<p style="margin-bottom:1em">&nbsp;</p>';

  ## Do actual results table! --------------------------------------------------
  my @sorted = scalar(@$alignments) > 1 ? @{$object->sort_table_values($alignments, \@coord_systems)} : @$alignments;
  
  my @display_types; ## only show the requested columns
  foreach $type (@view_types) {
    next if $type eq 'sort_by';
    next if $object->param('view_'.$type) eq 'off';
    push @display_types, $type;
  }

  my $result_table = EnsEMBL::Web::Document::SpreadSheet->new(); 
  $width = int( 100 / (scalar(@display_types)+1) );
  $result_table->add_columns( {'key' => 'links', 'title' => 'Links', 'width' => $width.'%', 'align' => 'left'} );

  foreach $type (@display_types) {
    $result_table->add_columns( {'key' => $type, 'title' => ucfirst($type), 'width' => $width.'%', 'align' => 'left'} );
  }

  ## Finally, the results!
  foreach my $A (@$alignments) {
    my ($hit, $hsp) = @$A;
    next unless $hit && $hsp;
    my $align_info = _munge_alignment($hsp, \@coord_systems, \@stat_types);
    warn "************ INFO: ", Dumper($align_info);
    my $result_row;

    my @align_parameters = (
      'ticket='.$object->param('ticket'),
      'run_id='.$object->param('run_id'),
      'hit_id='.$hit->token,
      'hsp_id='.$hsp->token,
    );
    my $parameter_string = 'species='.$species.';';
    $parameter_string .= join(';', @align_parameters);

    my $location_parameters = sprintf('r=%s:%s-%s', $align_info->{'generic'}->{'name'},
        $align_info->{'generic'}->{'start'}, $align_info->{'generic'}->{'end'},
    );

    $result_row->{'links'} = sprintf(qq(<a href="%s" style="text-decoration:none;" title="Alignment">[A]</a> 
<a href="%s" style="text-decoration:none;" title="Query Sequence">[S]</a> 
<a href="%s" style="text-decoration:none;" title="Genome Sequence">[G]</a> 
<a href="%s" style="text-decoration:none;" title="Region in Detail">[R]</a>),
    '/Blast/Alignment?display=align;'.$parameter_string, 
    '/Blast/Alignment?display=query;'.$parameter_string, 
    '/Blast/Alignment?display=genomic;'.$parameter_string,
    '/'.$species.'/Location/View?'.$location_parameters,
    );

    foreach $type (@display_types) {
      my $cell_data = '';
      if ($type eq 'stats') {
        foreach my $S (@stat_types) {
          my $V = $align_info->{$S};
          next unless $V;
          $cell_data .= $V.' ';
        }
      }
      elsif ($type eq 'query') {
        $cell_data = sprintf(qq(%s %s %s),
          '1', '100', '+',
        );
      }
      else {
        my $info = $align_info->{$type};
        if ($type eq 'chromosome') {
          $cell_data = sprintf(qq(<a href="/%s/Location/Chromosome?%s">Chr %s</a> %s %s),
                $species, $location_parameters, $info->{'generic'}->{'name'}, 
                $align_info->{'generic'}->{'start'}, $align_info->{'generic'}->{'end'},
          );
        }
        else {
          $cell_data = sprintf(qq(%s %s %s),
                $info->{'name'}, $info->{'start'}, $info->{'end'}
          );
        }
      }
      $result_row->{$type} = $cell_data;
    }
    $result_table->add_row($result_row);
  }

  $html .= $result_table->render; 
}

sub _munge_alignment {
### Helper method to get useable information for displaying in alignments table
  my ($hsp, $coord_systems, $stat_types) = @_;
warn "*** HSP ".Dumper($hsp);
  my $info;
  warn "*** MUNGING DATA";
  my $gh = $hsp->genomic_hit;
  warn "*** GENOMIC HIT $gh (generic)";
  if ($gh) {
    my $context = 2000;
    $info->{'generic'}->{'name'}  = $gh->seq_region_name;
    $info->{'generic'}->{'start'} = $gh->start - $context;
    $info->{'generic'}->{'end'}   = $gh->end + $context;
  }
  foreach my $C (@$coord_systems) {
    warn "*** Getting data for coord_system $C";
    $gh = $hsp->genomic_hit($C);
    warn "*** GENOMIC HIT $gh";
    next if !$gh;
    $info->{$C}->{'name'} = $gh->seq_region_name;
    $info->{$C}->{'start'} = $gh->start;
    $info->{$C}->{'end'} = $gh->end;
    $info->{$C}->{'orientation'} = $gh->start < 0 ? '-' : '+';
    warn Dumper($info->{$C});
  }
  foreach my $S (@$stat_types) {
    my $method = $S;
    $method = 'percent_identity' if $method eq 'identity';
    $info->{$S} = $hsp->$method || 'N/A';
  }
  return $info;
}

1;
