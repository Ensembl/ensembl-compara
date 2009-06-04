package Bio::EnsEMBL::GlyphSet::Vuserdata;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet::V_density);
use EnsEMBL::Web::Text::DensityFeatureParser;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;

### Fetches userdata and munges it into a basic format 
### for rendering by the parent module

sub _init {
  my $self = shift;
  my $rtn = $self->build_tracks;
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

sub data { 
## Grabs the user data and, if relevant, passes back to VDrawable container for 'caching'
  my $self = shift;
  my $data;
  my $chr = $self->{'chr'} || $self->{'container'}{'chr'};
  my $track_id = $self->{'my_config'}->get('id');
  my ($status, $type, $id) = split('-|_', $track_id);
  return unless $status && $type && $id;

  ## TODO - show separate tracks within a file
  my @colours = qw(darkred darkblue darkgreen purple grey red blue green orange brown magenta violet darkgrey);
  unshift(@colours, 'black') if ($self->{'config'}{'display'} eq 'density_graph'); 

  my $track_width = $self->{'config'}->get_parameter( 'width') || 80;
  my $max_length = $self->{'config'}->get_parameter('container_width');
  my $bins = 150;
  my $bin_size = int($max_length/$bins); 
  my $max;
 
  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    ## Parse data and store by chromosome
    my $parser = EnsEMBL::Web::Text::DensityFeatureParser->new();
    $parser->no_of_bins($bins);
    $parser->bin_size($bin_size);
    unless ($self->{'config'}{'all_chromosome'} eq 'yes') {
      $parser->set_filter($chr);
    }

    if ($type eq 'url') {
      $parser->parse_URL( $self->my_config('source') );
    }
    else {
      my $file = new EnsEMBL::Web::TmpFile::Text( filename => $self->my_config('source') );
      my $content = $file->retrieve;
      return undef unless $content;

      $parser->init_density($content);
      $parser->parse($content, $self->my_config('format') );
    }

    ## Build initial data structure
    my $max_values = $parser->max_values();
    my @types = $parser->feature_types;
    my $sort = 0;
    foreach my $type (@types) {
      my %features = %{$parser->features_of_type($type)};
      my $count;
      foreach my $chr (keys %features) {
        my @results = @{$features{$chr}};
        my $scores = [];
        for (my $i=0; $i < $bins; $i++) {
          my $score = $results[$i];
          $scores->[$i] = $score;
        }
        $data->{$chr}{$track_id}{$type} = {'scores' => $scores, 'colour' => $colours[$count], 'sort' => $sort};
      }
      my $current_max = $max_values->{$type};
      $max = $current_max if $max < $current_max;
      $count++;
      $sort++;
    }


  }
  else {
    ## Fetch data from the userdata db, for this chr only

    my $logic_name = $self->{'my_config'}->get('logic_name');

    ## Initialise the parser and set the region!
    my $dbs = EnsEMBL::Web::DBSQL::DBConnection->new( $self->{'container'}{'web_species'} );
    my $dba = $dbs->get_DBAdaptor('userdata');
    return undef unless $dba;

    my $fa     = $dba->get_adaptor( 'DnaAlignFeature' );
    my $start = 1;
    my $end = $bin_size;
    
    my $scores;
    for (my $i = 0; $i < $bins; $i++) {
      my $slice = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr, $start, $end);
      my $features = $fa->fetch_all_by_Slice( $slice, $logic_name );
      my $count = scalar(@$features);
      $scores->[$i] = $count;
      $start += $bin_size; 
      $end   += $bin_size; 
      $max = $count if $max < $count;
    }

    $data->{$chr}{$track_id}{'dnaAlignFeature'} = {
      'scores' => $scores,
      'colour' => $colours[0],
      'sort'   => 0,
    };
  }

  ## Now scale scores to track width
  if ($max) {
    while (my ($chr, $track) = each (%$data)) {
      while (my ($track_id, $type_info) = each (%$track)) {
        while (my ($type, $info) = each(%$type_info)) {
          my $unscaled = $info->{'scores'};
          my $scaled;
          foreach (@$unscaled) {
            my $new_value = ($_/$max) * $track_width;
            push @$scaled, (($_/$max) * $track_width);
          }
          $data->{$chr}{$track_id}{$type}{'scores'} = $scaled;
        }
      }
    }
  }

  $self->{'config'}->set_parameter( 'max_value', $max );
  $self->{'config'}->set_parameter( 'bins', $bins );

  return $data;
}

1;
