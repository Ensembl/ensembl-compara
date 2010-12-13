# $Id$

package EnsEMBL::Web::ImageConfig::Vertical;

## Alternative configuration for karyotype used in BlastView
use strict;

use EnsEMBL::Web::DBSQL::DBConnection;

# use EnsEMBL::Web::Tools::Misc qw(style_by_filesize); # DO NOT UNCOMMENT OR DELETE THIS LINE - It can cause circular references.

use base qw(EnsEMBL::Web::ImageConfig);

# We load less data on vertical drawing code, as it shows regions 
# at a much smaller scale. We also need to distinguish between
# density features, rendered as separate tracks, and pointers,
# which are part of the karyotype track
sub load_user_tracks {
  my ($self, $session) = @_;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  my %types = (upload => 'filename', url => 'url');
  my $user  = $self->hub->user;
  my $width = $self->get_parameter('all_chromosomes') eq 'yes' ? 10 : 60;
  my (@user_tracks, %user_sources);
  
  my @density_renderers = (
    'off',             'Off',
    'density_line',    'Density plot - line graph',
    'density_bar',     'Density plot - filled bar chart',
    'density_outline', 'Density plot - outline bar chart',
  );
  
  my @all_renderers = @density_renderers;
  
  if (ref($self) !~ /mapview/) {
    push @all_renderers, (
      'highlight_lharrow',  'Arrow on lefthand side',
      'highlight_rharrow',  'Arrow on righthand side',
      'highlight_bowtie',   'Arrows on both sides',
      'highlight_wideline', 'Line',
      'highlight_widebox',  'Box',
    );
  }
  
  foreach my $type (keys %types) {
    my @tracks = $session->get_data(type => $type);
    my $field  = $types{$type};
    
    foreach my $track (@tracks) {
      push @user_tracks, {
        id      => "temp-$type-$track->{'code'}", 
        species => $track->{'species'},
        source  => $track->{$field},
        format  => $track->{'format'},
        render  => EnsEMBL::Web::Tools::Misc::style_by_filesize($track->{'filesize'}),
        name    => $track->{'name'} || $track->{$field}
      };
    }
  }

  # Add saved tracks, if any
  if ($user) {
    foreach my $entry ($user->uploads) {
      next unless  $entry->species eq $self->{'species'};
      
      foreach my $analysis (split /, /, $entry->analyses) {
        $user_sources{$analysis} = {
          id          => $analysis,
          source_name => $entry->name,
          source_type => 'user',
          filesize    => $entry->filesize,
          species     => $entry->species,
          assembly    => $entry->assembly,
        };
        
        $self->_compare_assemblies($entry, $session);
      }
    }
    
    if (keys %user_sources) {
      my $dbs = new EnsEMBL::Web::DBSQL::DBConnection($self->{'species'});
      my $dba = $dbs->get_DBAdaptor('userdata');
      my $ana = $dba->get_adaptor('Analysis');

      while (my ($logic_name, $source) = each (%user_sources)) {
        my $analysis = $ana->fetch_by_logic_name($logic_name);
        
        next unless $analysis;

        push @user_tracks, {
          id          => $source->{'id'}, 
          species     => $source->{'species'},
          name        => $analysis->display_label,
          logic_name  => $logic_name,
          description => $analysis->description,
          style       => $analysis->web_data,
          render      => EnsEMBL::Web::Tools::Misc::style_by_filesize($source->{'filesize'})
        };
      }
    }
  }
  
  # Now add these tracks to the menu
  foreach my $entry (@user_tracks) {
    if ($entry->{'species'} eq $self->{'species'}) {
      my $settings = {
        id          => $entry->{'id'},
        source      => $entry->{'source'},
        format      => $entry->{'format'},
        glyphset    => 'Vuserdata',
        colourset   => 'densities',
        maxmin      =>  1,
        logic_name  => $entry->{'logic_name'},
        caption     => $entry->{'name'},
        description => $entry->{'description'},
        display     => 'off',
        style       => $entry->{'style'},
        width       => $width,
        strand      => 'b'
      };
      
      $settings->{'renderers'} = $entry->{'render'} eq 'density' ? \@density_renderers : \@all_renderers;
      
      $menu->append($self->create_track($entry->{'id'}, $entry->{'name'}, $settings));
    }
  }
}

1;
