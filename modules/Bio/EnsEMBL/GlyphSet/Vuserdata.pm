# $Id$

package Bio::EnsEMBL::GlyphSet::Vuserdata;

use strict;

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc;

use base qw(Bio::EnsEMBL::GlyphSet::V_density);

### Fetches userdata and munges it into a basic format 
### for rendering by the parent module

sub _init {
  my $self = shift;
  my $rtn  = $self->build_tracks;
  return $self->{'text_export'} && $self->can('render_text') ? $rtn : undef;
}

sub data { 
  ## Grabs the user data and, if relevant, passes back to VDrawable container for 'caching'
  
  my $self        = shift;
  my $chr         = $self->{'chr'} || $self->{'container'}{'chr'};
  my $track_id    = $self->{'my_config'}->id;
  my ($type)      = split '_', $track_id;
  my @colours     = qw(darkred darkblue darkgreen purple grey red blue green orange brown magenta violet darkgrey);
  my $track_width = $self->{'config'}->get_parameter('width') || 80;
  my $max_length  = $self->{'config'}->get_parameter('container_width');
  my $logic_name  = $self->my_config('logic_name');
  my $bins        = 150;
  my $bin_size    = int($max_length / $bins); 
  my ($max, %data);
  
  unshift @colours, 'black' if $self->{'config'}{'display'} eq 'density_graph'; 
  
  if ($logic_name) {
    my $fa    = $self->{'config'}->hub->get_adaptor('get_DnaAlignFeatureAdaptor', 'userdata', $self->{'container'}{'web_species'});
    my $start = 1;
    my $end   = $bin_size;
    my @scores;
    
    for (0..$bins) {
      my $slice    = $self->{'container'}->{'sa'}->fetch_by_region('chromosome', $chr, $start, $end); ## Fetch data from the userdata db, for this chr only
      my $features = $fa->fetch_all_by_Slice($slice, $logic_name); 
      my $count    = scalar @$features;
      
      $_  += $bin_size for $start, $end;
      $max = $count if $max < $count;
      
      push @scores, $count;
    }
    
    return unless $max;
    
    $data{$track_id}{'dnaAlignFeature'} = {
      scores => \@scores,
      colour => $colours[0],
      sort   => 0,
    };
  } else {
    ## Parse data and store by chromosome
    
    my $parser = EnsEMBL::Web::Text::FeatureParser->new($self->{'config'}->species_defs);
    
    $parser->no_of_bins($bins);
    $parser->bin_size($bin_size);
    $parser->filter($chr);# unless $self->{'config'}->get_parameter('all_chromosomes') eq 'yes';

    if ($type eq 'url') {
      my $response = EnsEMBL::Web::Tools::Misc::get_url_content($self->my_config('url'));
      my $content  = $response->{'content'};
      
      if ($content) {
        $parser->parse($content);
      } else {
        warn "!!! $response->{'error'}";
        return undef;
      }
    } else {
      my $file    = new EnsEMBL::Web::TmpFile::Text(filename => $self->my_config('file'));
      my $content = $file->retrieve;
      
      return undef unless $content;

      $parser->parse($content, $self->my_config('format'));
    }

    ## Build initial data structure
    my $max_values = $parser->max_values;
    my $sort       = 0;
    
    while (my ($name, $track) = each %{$parser->get_all_tracks}) {
      my $count;
      
      while (my ($chr, $results) = each %{$track->{'bins'}}) {
        $data{$track_id}{$name} = {
          scores => [ map $results->[$_], 0..$bins ],
          colour => $track->{'config'}{'color'} || $colours[$count],
          sort   => $sort
        };
      }
      
      $max = $max_values->{$name} if $max < $max_values->{$name};
      
      $count++ unless $track->{'config'}{'color'};
      $sort++;
    }
  }
  
  ## Now scale scores to track width
  if ($max) {
    while (my ($track_id, $type_info) = each %data) {
      $data{$track_id}{$_}{'scores'} = [ map { ($_/$max) * $track_width } @{$type_info->{$_}{'scores'}} ] for keys %$type_info;
    }
  }

  $self->{'config'}->set_parameter('max_value', $max);
  $self->{'config'}->set_parameter('bins',      $bins);
  
  return \%data;
}

1;
