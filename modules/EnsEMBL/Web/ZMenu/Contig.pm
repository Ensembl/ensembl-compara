# $Id$

package EnsEMBL::Web::ZMenu::Contig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object          = $self->object;
  my $threshold       = 1000100 * ($object->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $slice_name      = $object->param('region_n');
  my $db_adaptor      = $object->database('core');
  my $slice           = $db_adaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $slice_name);
  my $slice_type      = $slice->coord_system_name;
  my $top_level_slice = $slice->project('toplevel')->[0]->to_Slice;
  my $action          = $slice->length > $threshold ? 'Overview' : 'View';
  
  $self->caption($slice_name);
  
  $self->add_entry({
    label => "Center on $slice_type $slice_name",
    link  => $object->_url({ 
      type   => 'Location', 
      action => $action, 
      region => $slice_name 
    })
  });
  
  $self->add_entry({
    label => "Export $slice_type sequence/features",
    class => 'modal_link',
    link  => $object->_url({ 
      type   => 'Export',
      action => "Location/$action",
      r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  });
  
  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all || []}) {
    next if $cs->name eq $slice_type;  # don't show the slice coord system twice
    next if $cs->name eq 'chromosome'; # don't allow breaking of site by exporting all chromosome features
    
    my $path;
    eval { $path = $slice->project($cs->name); };
    
    next unless $path && scalar @$path == 1;

    my $new_slice        = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type   = $new_slice->coord_system_name;
    my $new_slice_name   = $new_slice->seq_region_name;
    my $new_slice_length = $new_slice->seq_region_length;

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';
    
    $self->add_entry({
      label => "Center on $new_slice_type $new_slice_name",
      link  => $object->_url({
        type   => 'Location', 
        action => $action, 
        region => $new_slice_name
      })
    });

    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    $top_level_slice = $new_slice->project('toplevel')->[0]->to_Slice;

    $self->add_entry({
      label => "Export $new_slice_type sequence/features",
      class => 'modal_link',
      link  => $object->_url({
        type   => 'Export',
        action => "Location/$action",
        r      => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
      })
    });
    
    if ($cs->name eq 'clone') {
      (my $short_name = $new_slice_name) =~ s/\.\d+$//;
      
      $self->add_entry({
        type  => 'EMBL',
        label => $new_slice_name,
        link  => $object->get_ExtURL('EMBL', $new_slice_name),
        extra => { external => 1 }
      });
      
      $self->add_entry({
        type  => 'EMBL (latest version)',
        label => $short_name,
        link  => $object->get_ExtURL('EMBL', $short_name),
        extra => { external => 1 }
      });
    }
  }
}

1;
