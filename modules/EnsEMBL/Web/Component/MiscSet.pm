package EnsEMBL::Web::Component::MiscSet;

use EnsEMBL::Web::Component;
our @ISA = qw( EnsEMBL::Web::Component);
use strict;
use warnings;
no warnings "uninitialized";

sub spreadsheet_miscset_set {
  my( $panel, $object ) = @_;
  return _spreadsheet_miscset( $panel, $object, $object->seq_region_name );
}

sub spreadsheet_miscset_slice {
  my( $panel, $object ) = @_;
  return _spreadsheet_miscset( $panel, $object, $object->seq_region_name, $object->seq_region_start, $object->seq_region_end );
}

sub spreadsheet_miscset_all {
  my( $panel, $object ) = @_;
  return _spreadsheet_miscset( $panel, $object );
}

sub _spreadsheet_miscset {
  my( $panel, $object, $sr, $start, $end ) = @_;
  $panel->add_columns(
    { 'key' => 'sr',     'title' => 'SeqRegion' },
    { 'key' => 'start',  'title' => 'Start'     },
    { 'key' => 'end',    'title' => 'End'       },
    { 'key' => 'name',   'title' => 'Name'      },
    { 'key' => 'well',   'title' => 'Well name' },
    { 'key' => 'sanger', 'title' => 'Sanger'    },
    { 'key' => 'embl',   'title' => 'EMBL Acc'  },
    { 'key' => 'fish',   'title' => 'FISH'      },
    { 'key' => 'centre', 'title' => 'Centre'    },
    { 'key' => 'status', 'title' => 'State',    },
  );
  my @regions = ();
  if( $sr ) {
    my $temp_sr;
    if( defined($start) ) {
      $temp_sr = $object->database('core')->get_SliceAdaptor->fetch_by_region(undef,$sr,$start,$end);
    } else {
      $temp_sr = $object->database('core')->get_SliceAdaptor->fetch_by_region(undef,$sr);
    } 
    push @regions, $temp_sr;
  } else {
    foreach my $srname ( @{ $object->species_defs->ENSEMBL_CHROMOSOMES } ) {
      my $temp_sr = $object->database('core')->get_SliceAdaptor->fetch_by_region(undef,$srname);
      push @regions, $temp_sr;
    }
  }
  foreach my $region ( @regions ) {
    foreach my $entry ( sort { $a->start <=> $b->start }
      @{$object->database('core')->get_MiscFeatureAdaptor->fetch_all_by_Slice_and_set_code(
        $region, $object->misc_set_code)} ) {
      my $name = $entry->get_scalar_attribute( 'clone_name' );
      my $well = $entry->get_scalar_attribute( 'name' );
      unless( $name ) {
        $name = $well;
        $well = $entry->get_scalar_attribute('location');
      }
      $panel->add_row( {
        'sr'     => $entry->seq_region_name,
        'start'  => $entry->seq_region_start,
        'end'    => $entry->seq_region_end,
        'well'   => join(';',@{$entry->get_all_attribute_values('well_name')} ),
        'sanger' => join(';',@{$entry->get_all_attribute_values('synonym')},@{$entry->get_all_attribute_values('sanger_project')} ),
        'embl'   => join(';',@{$entry->get_all_attribute_values('embl_acc')} ),
        'name'   => join(';',@{$entry->get_all_attribute_values('clone_name')},@{$entry->get_all_attribute_values('name')} ),
        'fish'   => $entry->get_scalar_attribute( 'fish' ),
        'centre' => $entry->get_scalar_attribute( 'org' ),
        'status' => $entry->get_scalar_attribute( 'state' ),
# 'method' => $entry->get_scalar_attribute( 'method' )       || "@{[$entry->get_scalar_attribute('start_pos')]}:@{[$entry->get_scalar_attribute('end_pos')]}",
# 'notes'  => $entry->get_scalar_attribute('mismatch')
      } );
    }
  }
}

sub spreadsheet_miscset_genes {
  my( $panel, $object ) = @_;
  my $offset = $object->seq_region_start + 1;
  $panel->add_columns(
    { 'key' => 'sr',     'title' => 'SeqRegion ' },
    { 'key' => 'start',  'title' => 'Start'      },
    { 'key' => 'end',    'title' => 'End'        },
    { 'key' => 'ens',    'title' => 'Ensembl ID' },
    { 'key' => 'db',     'title' => 'DB'         },
    { 'key' => 'name',   'title' => 'Name'       },
  );
  my $slice = $object->database('core')->get_SliceAdaptor->fetch_by_region(undef,
    $object->seq_region_name,
    $object->seq_region_start,
    $object->seq_region_end );
  foreach ( sort { $a->seq_region_start <=> $b->seq_region_start } map { @{$slice->get_all_Genes( $_ )||[]} } qw(ensembl havana ensembl_havana_gene)  ) {
    $panel->add_row( {
      'sr'    => $_->seq_region_name,
      'start' => $_->seq_region_start,
      'end'   => $_->seq_region_end,
      'ens'   => $_->stable_id,
      'db'    => $_->external_db || '-',
      'name'  => $_->external_name || '-novel-'
    });
  }
}

1;
