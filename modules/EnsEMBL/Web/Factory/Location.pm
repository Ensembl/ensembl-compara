package EnsEMBL::Web::Factory::Location;

use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use CGI qw(escapeHTML);
use POSIX qw(floor ceil);

use Bio::EnsEMBL::Feature;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Proxy::Object;

use base qw(EnsEMBL::Web::Factory);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  $self->__set_species;
  
  return $self;
}

sub __species       :lvalue { $_[0]->__data->{'__location'}{'species'}; }
sub __species_hash  :lvalue { $_[0]->__data->{'__location'}{$_[0]->__data->{'__location'}{'species'}}; }
sub __level         :lvalue { $_[0]->__species_hash->{'level'}; }
sub __golden_path   :lvalue { $_[0]->__species_hash->{'golden_path'}; }
sub __coord_systems :lvalue { $_[0]->__species_hash->{'coord_systems'}; }

sub __set_species {
  my ($self, $species, $golden_path, $level) = @_;
  
  $species     ||= $self->species;
  $golden_path ||= $self->species_defs->get_config($species, 'ENSEMBL_GOLDEN_PATH');
  $golden_path ||= $self->species_defs->get_config($species, 'ASSEMBLY_NAME');
  
  $self->__species = $species; # to store co-ordinate system information
  $self->__species_hash ||= {};

  unless (exists $self->__species_hash->{'golden_path'} && $self->__golden_path eq $golden_path) {
    $self->__golden_path = $golden_path;
    
    $self->__coord_systems = [
      grep { !$_->version || $_->version eq $self->__golden_path } @{$self->_coord_system_adaptor->fetch_all}
    ];
    
    $self->__level = undef; # clear current level if changing golden path
  }
  
  return if $self->__level;
  
  my %T = map { $_, 1 } @{$self->__coord_systems||[]};
  
  $level = undef unless $T{$level};
  $level ||= 'toplevel';
  
  $self->__level ||= $level;
}

sub createObjects {
  my $self = shift;
  
  return $self->_create_object_from_core
    if   $self->core_objects->location
     && !$self->core_objects->location->isa('EnsEMBL::Web::Fake')
     && !$self->core_objects->gene;

  $self->get_databases($self->__gene_databases, 'compara', 'blast');
  
  my $database = $self->database('core');
  
  return $self->problem('Fatal', 'Database Error', 'Could not connect to the core database.') unless $database;
  
  # First lets try and locate the slice
  my ($location, $temp_id);
  
  my $strand     = $self->param('strand')    || $self->param('seq_region_strand') || 1;
  
  my $seq_region = $self->param('region')    || $self->param('contig')     ||
                   $self->param('clone')     || $self->param('seqregion')  ||
                   $self->param('chr')       || $self->param('seq_region_name');
                   
  my $start      = $self->param('vc_start')  || $self->param('chr_start')  ||
                   $self->param('wvc_start') || $self->param('fpos_start') ||
                   $self->param('start');
                   
  my $end        = $self->param('vc_end')    || $self->param('chr_end')    ||
                   $self->param('wvc_end')   || $self->param('fpos_end')   ||
                   $self->param('end');
                   
  if (defined $self->param('r') && !$self->core_objects->gene && !$self->core_objects->variation) {
    ($seq_region, $start, $end) = $self->param('r') =~ /^([-\w\.]+):(-?[\.\w,]+)-([\.\w,]+)$/;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
  } 

  if (defined $self->param('l')) { 
    ($seq_region, $start, $end) = $self->param('l') =~ /^([-\w\.]+):(-?[\.\w,]+)-([\.\w,]+)$/;
    $start = $self->evaluate_bp($start);
    $end   = $self->evaluate_bp($end);
  } 

  $start = $self->evaluate_bp($start) if defined $start;
  $end   = $self->evaluate_bp($end)   if defined $end;
  
  if (defined $self->param('c')) {
    my ($cp, $t_strand);
    
    ($seq_region, $cp, $t_strand) = $self->param('c') =~ /^([-\w\.]+):(-?[.\w,]+)(:-?1)?$/;
    $cp = $self->evaluate_bp($cp);
    
    my $w = $self->evaluate_bp($self->param('w'));
    
    $start = $cp - ($w-1)/2;
    $end   = $cp + ($w-1)/2;
    
    $strand = $t_strand eq ':-1' ? -1 : 1 if $t_strand;
  }
  
  if (defined $self->param('centrepoint')) {
    my $cp = $self->evaluate_bp($self->param('centrepoint'));
    my $w  = $self->evaluate_bp($self->param('width'));
    $start = $cp - ($w-1)/2;
    $end   = $cp + ($w-1)/2;
  }

  my $temp_1_id = $self->param('anchor1');
  my $ftype_1   = $self->param('type1');
  my $temp_2_id = $self->param('anchor2');
  my $ftype_2   = $self->param('type2');
  my @anchorview;

  push @anchorview, [ $self->param('type1'), $self->param('anchor1') ] if $self->param('anchor1') && $self->param('type1');
  push @anchorview, [ $self->param('type2'), $self->param('anchor2') ] if $self->param('anchor2') && $self->param('type2');
  
  if (@anchorview) {
    foreach my $O (@anchorview) {
      $location = undef;
      
      my ($ftype, $temp_id) = @$O;
      
      $location = $self->_location_from_Gene($temp_id)                if $ftype eq 'gene' || $ftype eq 'all';
      $location = $self->_location_from_Transcript($temp_id)          if !$location && ($ftype eq 'transcript' || $ftype eq 'all');
      $location = $self->_location_from_Peptide($temp_id)             if !$location && ($ftype eq 'peptide' || $ftype eq 'all');
      $location = $self->_location_from_Marker($temp_id, $seq_region) if !$location && $ftype eq 'marker';
      $location = $self->_location_from_Band($temp_id, $seq_region)   if !$location && $ftype eq 'band';
      $location = $self->_location_from_MiscFeature($temp_id)         if !$location && ($ftype eq 'misc_feature' || $ftype eq 'all');
      $location = $self->_location_from_SeqRegion($temp_id)           if !$location && ($ftype eq 'region' || $ftype eq 'all');
      $location = $self->_location_from_MiscFeature($temp_id)         if !$location && $ftype eq 'region';
      
      $location ||= $self->_location_from_SeqRegion($seq_region, $temp_id, $temp_id);
      
      $self->DataObjects($location) if $location;
    }
    
    $self->merge if $self->DataObjects;
  } else {
    if (!defined $start && ($temp_id = $self->param('geneid') || $self->param('gene'))) {
      $location = $self->_location_from_Gene($temp_id);
    } elsif ($temp_id = $self->param('transid') || $self->param('trans') || $self->param('transcript')) {
      $location = $self->_location_from_Transcript($temp_id);
    } elsif ($temp_id = $self->param('exonid') || $self->param('exon')) {  
      $location = $self->_location_from_Exon($temp_id); 
    } elsif ($temp_id = $self->param('peptide') || $self->param('pepid') || $self->param('peptideid') || $self->param('translation')) {
      $location = $self->_location_from_Peptide($temp_id);
    } elsif ($temp_id = $self->param('mapfrag') || $self->param('miscfeature') || $self->param('misc_feature')) {
      $location = $self->_location_from_MiscFeature($temp_id);
    } elsif ($temp_id = $self->param('marker')) { 
      $location = $self->_location_from_Marker($temp_id, $seq_region);
    } elsif ($temp_id = $self->param('band')) { 
      $location = $self->_location_from_Band($temp_id, $seq_region);
    } elsif (!$start && ($temp_id = $self->param('snp') || $self->param('variation'))) { 
      $location = $self->_location_from_Variation( $temp_id, $seq_region );
    } else {
      if ($self->param('click_to_move_window.x')) {
        $location = $self->_location_from_SeqRegion($seq_region, $start, $end);
        
        if ($location) {
          $location->setCentrePoint(floor(
            ($self->param('click_to_move_window.x') - $self->param('vc_left')) / 
            ($self->param('vc_pix') || 1) * $self->param('tvc_length')
          ));
        }
      } elsif ($self->param('click_to_move_chr.x')) { # Chromosome click
        $location = $self->_location_from_SeqRegion($seq_region);
        
        if ($location) { 
          $location->setCentrePoint(floor(
            ($self->param('click_to_move_chr.x') - $self->param('chr_left')) /
            ($self->param('chr_pix') || 1) * $self->param('chr_len')
          ));
        }
      } elsif ($temp_id = $self->param('click.x') + $self->param('vclick.y')) {
        $location = $self->_location_from_SeqRegion($seq_region);
        if ($location) { 
          $location->setCentrePoint(floor(
            $self->param('seq_region_left') +
            ($temp_id - $self->param('click_left') + 0.5) /
            ($self->param('click_right') - $self->param('click_left') + 1) *
            ($self->param('seq_region_right') - $self->param('seq_region_left') + 1)
          ), $self->param('seq_region_width'));
        }
      } elsif ($seq_region) { # SeqRegion
        $location = $self->_location_from_SeqRegion($seq_region, $start, $end, $strand);
      }
    }
    
    if ($location) {
      $self->DataObjects($location);
    } elsif ($self->core_objects->location) {
      $self->_create_object_from_core;
    }
  }
}

#------------------- Location by feature type ------------------------------

sub __gene_databases {
  my $self = shift;
  return map { lc(substr $_, 9) } @{$self->species_defs->core_like_databases||[]}
}

sub _location_from_RegFeature {
  my ($self, $id) = @_;
  $self->problem('fatal', 'Unknown regulatory', $self->_help("Could not find regulatory feature $id"));
   return undef; 
 }

sub _location_from_Gene {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $TS;
  
  foreach my $db (@dbs) {
    eval {
      my $TF = $self->_gene_adaptor($db)->fetch_by_stable_id($id);
      $TS = $self->_slice_adaptor->fetch_by_Feature($TF) if $TF;
    };
    
    if ($TS) {
      $self->param('db', $db);
      return $self->_create_from_slice('Gene', $id, $self->expand($TS), $id);
    }
  }
  
  foreach my $db (@dbs) {
    my $genes = $self->_gene_adaptor($db)->fetch_all_by_external_name($id);
    
    if (@$genes) {
      $TS = $self->_slice_adaptor->fetch_by_Feature($genes->[0]);
      
      if ($TS) {
        $self->param('db', $db);
        return $self->_create_from_slice('Gene', $genes->[0]->stable_id, $self->expand($TS), $id);
      }
    }
  }
  
  $self->problem('fatal', 'Unknown gene', $self->_help("Could not find gene $id"));
  
  return undef;
}

sub _location_from_Transcript {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $TS;
  
  foreach my $db (@dbs) {
    eval {
      my $TF = $self->_transcript_adaptor($db)->fetch_by_stable_id($id);
      $TS = $self->_slice_adaptor->fetch_by_Feature($TF) if $TF;
    };
    
    if ($TS) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $id, $self->expand($TS), $id);
    }
  }
  
  foreach my $db (@dbs) {
    my $features = $self->_transcript_adaptor($db)->fetch_all_by_external_name($id);
    
    if (@$features) {
      $TS = $self->_slice_adaptor->fetch_by_Feature($features->[0]);
      
      if ($TS) {
        $self->param('db', $db);
        return $self->_create_from_slice('Transcript', $features->[0]->stable_id, $self->expand($TS), $id);
      }
    }
  }
  
  foreach my $db (@dbs) {
    eval {
      my $TF = $self->_predtranscript_adaptor( $db )->fetch_by_stable_id($id);
      $TS = $self->_slice_adaptor->fetch_by_Feature($TF);
    };
    
    if ($TS) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $id, $self->expand($TS), $id);
    }
  }

  $self->problem('fatal', 'Unknown transcript', $self->_help("Could not find transcript $id"));
  
  return undef;
}

sub _location_from_Exon {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $TS;
  
  foreach my $db (@dbs) {
    eval {
      my $TF = $self->_exon_adaptor($db)->fetch_by_stable_id($id);
      $TS = $self->_slice_adaptor->fetch_by_Feature($TF) if $TF;
    };
    
    if ($TS) {
      $self->param('db', $db);
      return $self->_create_from_slice('Exon', $id, $self->expand($TS), $id);
    }
  }
  
  $self->problem('fatal', 'Unknown exon', $self->_help("Could not find exon $id"));
  
  return undef;
}

sub _location_from_Peptide {
  my ($self, $id) = @_;
  
  my @dbs = $self->__gene_databases;
  my $TS;
  
  foreach my $db (@dbs) {
    my $TF;
    
    eval {
      $TF = $self->_transcript_adaptor($db)->fetch_by_translation_stable_id($id);
      $TS = $self->_slice_adaptor->fetch_by_Feature($TF) if $TF;
    };
    
    if ($TS) {
      $self->param('db', $db);
      return $self->_create_from_slice('Transcript', $TF->stable_id, $self->expand($TS), $id);
    }
  }
  
  foreach my $db (@dbs) {
    my @features = grep { $_->translation } @{$self->_transcript_adaptor($db)->fetch_all_by_external_name($id)};
    
    if (@features) {
      $TS = $self->_slice_adaptor->fetch_by_Feature($features[0]);
      
      if ($TS) {
        $self->param('db', $db);
        return $self->_create_from_slice( 'Transcript', $features[0]->stable_id, $self->expand($TS), $id);
      }
    }
  }
  
  $self->problem('fatal', 'Unknown peptide', $self->_help("Could not find peptide $id"));
  
  return undef;
}

sub _location_from_MiscFeature {
  my ($self, $id) = @_;
  my $TS;
  
  foreach my $type (qw( name embl_acc synonym clone_name sanger_project well_name clonename )) {
    eval { $TS = $self->_slice_adaptor->fetch_by_misc_feature_attribute($type, $id); };
    return $self->_create_from_slice('MiscFeature', $id, $self->expand($TS)) if $TS;
  }
  
  $self->problem('fatal', 'Unknown misc feature', $self->_help("Could not find misc feature $id"));
  
  return undef;
}

sub _location_from_Band {
  my ($self, $id, $chr) = @_;
  my $TS;
  
  eval { $TS= $self->_slice_adaptor->fetch_by_chr_band($chr, $id); };
  $self->problem('fatal', 'Unknown band', $self->_help("Could not find karyotype band $id on chromosome $chr")) if $@;
  
  return $self->_create_from_slice('Band', $id, $self->expand($TS), "$chr $id");

}

sub _location_from_Variation {
  my ($self, $id) = @_;
  
  my $v;
  
  eval {
    $v = $self->_variation_adaptor->fetch_by_name($id);
  };
  
  if ($@ || !$v) {
    $self->problem('fatal', 'Invalid SNP ID', $self->_help("SNP $id cannot be located within Ensembl"));
    return;
  }
  
  foreach my $vf (@{$self->_variation_feature_adaptor->fetch_all_by_Variation($v)}) {
    if ($vf->seq_region_name) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region(undef, $vf->seq_region_name, $vf->seq_region_start, $vf->seq_region_end); };
      return $self->_create_from_slice('SNP', $id, $self->expand($TS)) if $TS;
    }
  }
  
  $self->problem('fatal', 'Non-mapped SNP', $self->_help("SNP $id is in Ensembl, but not mapped to the current assembly"));
}

sub _location_from_Marker {
  my ($self, $id, $chr) = @_;
  
  my $mr;
  
  eval {
    $mr = $self->_marker_adaptor->fetch_all_by_synonym($id);
  };
  
  if ($@) {
    $self->problem('fatal', 'Invalid Marker ID', $self->_help("Marker $id cannot be located within Ensembl"));
    return;
  }
  
  my $region;
  
  foreach my $marker_obj (@{$self->_marker_adaptor->fetch_all_by_synonym($id)}) {
    my $mfeats = $marker_obj->get_all_MarkerFeatures;
    
    if (@$mfeats) {
      foreach my $mf (@$mfeats) {
        my $TS = $self->_slice_adaptor->fetch_by_Feature($mf);
        my $projection = $TS->project($self->__level);
        
        next unless @$projection;
        
        my $projslice = shift @$projection;  # take first element of projection
        $region = $projslice->to_Slice->seq_region_name;
        
        return $self->_create_from_slice('Marker', $mf->display_id, $self->expand($TS)) if $region eq $chr || !$chr;
      }
    }
  }
  
  if ($region) {
    $self->problem('fatal', 'Marker not found on Chromosome', $self->_help("Marker $id is not mapped to chromosome $chr"));
  } else {
    $self->problem('fatal', 'Marker not found on assembly', $self->_help("Marker $id is not mapped to the current assembly"));
  }
  
  return undef;
}

sub _location_from_SeqRegion {
  my ($self, $chr, $start, $end, $strand, $keep_slice) = @_;

  if (defined $start) {
    $start = floor($start);
    $end   = $start unless defined $end;
    $end   = floor($end);
    $end   = 1 if $end < 1;
    $strand ||= 1;
    $start = 1 if $start < 1; # Truncate slice to start of seq region
    ($start, $end) = ($end, $start) if $start > $end;

    foreach my $system (@{$self->__coord_systems}) {
      my $slice;
      eval { $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand); };

      warn $@ and next if $@;

      if ($slice) {
        if ($start > $slice->seq_region_length || $end > $slice->seq_region_length) {
          $start = $slice->seq_region_length if $start > $slice->seq_region_length;
          $end   = $slice->seq_region_length if $end   > $slice->seq_region_length;
          
          $slice = $self->_slice_adaptor->fetch_by_region($system->name, $chr, $start, $end, $strand);
        }
        
        return $self->_create_from_slice($system->name, "$chr $start-$end ($strand)", $slice, undef, undef, $keep_slice);
      }
    }
    
    $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr: $start - $end on the current assembly."));
    
    return undef;
  } else {
    foreach my $system (@{$self->__coord_systems}) {
      my $TS;
      eval { $TS = $self->_slice_adaptor->fetch_by_region($system->name, $chr); };
      
      next if $@;
      
      return $self->_create_from_slice($system->name , $chr, $self->expand($TS), '', $chr, $keep_slice) if $TS;
    }
    
    my $action = $ENV{'ENSEMBL_ACTION'};
    
    if ($chr) {
      $self->problem('fatal', 'Locate error', $self->_help("Cannot locate region $chr on the current assembly."));
    } elsif ($action && $action eq 'Genome' && $self->species_defs->ENSEMBL_CHROMOSOMES) {
      # Create a slice of the first chromosome to force this page to work
      my @chrs = @{$self->species_defs->ENSEMBL_CHROMOSOMES};
      my $TS = $self->_slice_adaptor->fetch_by_region('chromosome', $chrs[0]) if scalar @chrs;
      
      return $self->_create_from_slice('chromosome', $chrs[0], $self->expand($TS), '', $chrs[0], $keep_slice) if $TS;
    } else {
      # Might need factoring out if we use other methods to get a location (e.g. marker)
      $self->problem('fatal', 'Please enter a location', $self->_help('A location is required to build this page'));
    }
    
    return undef;
  }
}

sub expand {
  my ($self, $slice) = @_;
  return $slice->expand($self->param('context'), $self->param('context'));
}

#----------------- Create objects ----------------------------------------------

sub fastCreateObjects {
  my $self = shift;
  
  # Only takes one set of parameters, and this has additional useful information included
  # /Homo_sapiens/fragment/contigviewbottom?l=chr:st-end;strand=1;type=chromosome
  $self->get_databases($self->__gene_databases, 'compara', 'blast');
    
  if ($self->param('l') =~ /^([-\w\.]+):(-?\d+)-(\d+)$/) {
    eval {
      my $seq_region        = $1;
      my $start             = $2;
      my $end               = $3;
      my $strand            = $self->param('strand') || 1;
      my $seq_region_type   = $self->param('type');
      my $seq_region_length = $self->param('srlen');
      
      my $slice = $self->_slice_adaptor->fetch_by_region(undef, $seq_region, $start, $end, $strand);
      
      my $data = EnsEMBL::Web::Proxy::Object->new('Location', {
        type               => 'Location',
        real_species       => $self->__species,
        name               => $seq_region,
        seq_region_name    => $seq_region,
        seq_region_type    => $slice->coord_system->name,
        seq_region_start   => $start,
        seq_region_end     => $end,
        seq_region_strand  => $strand,
        raw_feature_strand => $strand,
        seq_region_length  => $slice->seq_region_length
      }, $self->__data);
      
      $data->attach_slice($slice);
      $self->DataObjects($data);
    };
  }
}

sub _create_object_from_core {
  my $self = shift;
  
  my $l = $self->core_objects->location;
  my $data = undef;

  ## Map old assembly to the current one, if 'ass' param is there
  if (my $ass = $self->param('a')) {
    $self->delete_param('a');
    
    return $self->_map_assembly(
           $l->seq_region_name,
           $l->start,
           $l->end,
           1,
           $ass,
    );
  }
  
  if ($l->isa('EnsEMBL::Web::Fake')) {
    $data = EnsEMBL::Web::Proxy::Object->new('Location', { 
      type         => 'Genome', 
      real_species => $self->__species 
    }, $self->__data);
  } else {
    $data = EnsEMBL::Web::Proxy::Object->new('Location', {
      type               => 'Location',
      real_species       => $self->__species,
      name               => $l->seq_region_name,
      seq_region_name    => $l->seq_region_name,
      seq_region_start   => $l->start,
      seq_region_end     => $l->end,
      seq_region_strand  => 1,
      seq_region_type    => $l->coord_system->name,
      raw_feature_strand => 1,
      seq_region_length  => $l->seq_region_length
    }, $self->__data);
    
    $data->attach_slice($l);
  }

  $self->DataObjects($data);
  
  return 'from core';
}

sub _create_from_slice {
  my ($self, $type, $id, $slice, $synonym, $real_chr, $keep_slice) = @_;
  
  return $self->problem('fatal', 'Ensembl Error', "Cannot create slice - $type $id does not exist") unless $slice;
  
  my $projection = $slice->project($self->__level);
  
  return $self->problem('fatal', 'Cannot map slice', 'must all be in gaps') unless @$projection;
  
  my $projslice = shift @$projection; # take first element
  
  my $start  = $projslice->[2]->start;
  my $end    = $projslice->[2]->end;
  my $region = $projslice->[2]->seq_region_name;
  
  # take all other elements in case something has gone wrong
  foreach (@$projection) {
    return $self->problem('fatal', 'Slice does not map to single ' . $self->__level, 'end and start on different seq regions') unless $_->[2]->seq_region_name eq $region;
    
    $start = $_->[2]->start if $_->[2]->start < $start;
    $end   = $_->[2]->end   if $_->[2]->end   > $end;
  }
  
  my $TS = $projslice->[2];
  
  if ($TS->seq_region_name ne $real_chr) {
    my $feat = new Bio::EnsEMBL::Feature(
      -start  => 1, 
      -end    => $TS->length, 
      -strand => 1, 
      -slice  => $TS 
    );
    
    my $altlocs = $feat->get_all_alt_locations(1) || [];
    
    foreach my $f (@$altlocs) {
      if ($f->seq_region_name eq $real_chr) {
        $TS = $f->{'slice'} if $f->seq_region_name;
        last;
      }
    }
  }
  
  my $transcript = $self->core_objects->transcript;
  my $gene       = $self->core_objects->gene;
  my $db         = $self->core_objects->{'parameters'}{'db'};
  my $tid        = $transcript ? $transcript->stable_id : undef;
  my $gid        = $gene ? $gene->stable_id : undef;
  
  if ($type eq 'Transcript') {
    $tid = $id;
    $gid = undef;
    $db  = $self->param('db');
  } elsif ($type eq 'Gene') {
    $tid = undef;
    $gid = $id;
    $db  = $self->param('db');
  } elsif ($gene && $gene->seq_region_name ne $TS->seq_region_name) {
    $tid = undef;
    $gid = undef;
  }
  
  my $pars = {
    %{$self->multi_params},
    r     => $TS->seq_region_name . ":$start-$end",
    t     => $tid, 
    g     => $gid, 
    db    => $db
  };
  
  return $self->problem('redirect', $self->_url($pars));
}

sub merge {
  my $self = shift;
  
  my ($chr, $start, $end, $species, $type, $strand, $srlen);
  
  foreach my $o (@{$self->DataObjects||[]}) {
    next unless $o;
    
    $species ||= $o->real_species;
    $chr     ||= $o->seq_region_name;
    $type    ||= $o->seq_region_type;
    $strand  ||= $o->seq_region_strand;
    $start   ||= $o->seq_region_start;
    $end     ||= $o->seq_region_end;
    $srlen   ||= $o->seq_region_length;
    
    return $self->problem('multi_chromosome', 'Not on same seq region', 'Not all features on same seq region') if $chr ne $o->seq_region_name || $species ne $o->species;
    
    $start = $o->seq_region_start if $o->seq_region_start < $start;
    $end   = $o->seq_region_end   if $o->seq_region_end   > $end;
  }
  
  $start -= $self->param('upstream')   || 0;
  $end   += $self->param('downstream') || 0;
  
  $self->clearDataObjects;
  
  $self->DataObjects(EnsEMBL::Web::Proxy::Object->new('Location', {
    type              => 'merge',
    name              => 'merge',
    real_species      => $species,
    seq_region_name   => $chr,
    seq_region_type   => $type,
    seq_region_start  => floor($start),
    seq_region_end    => ceil($end),
    seq_region_strand => $strand,
    highlights        => join('|', $self->param('h'), $self->param('highlights')),
    seq_region_length => $srlen
  }, $self->__data));
}

#------------------------------------------------------------------------------


sub _help {
  my ($self, $string) = @_;
  
  my %sample = %{$self->species_defs->SAMPLE_DATA||{}};
  my $assembly_level = scalar(@{$self->species_defs->ENSEMBL_CHROMOSOMES||[]}) ? 'chromosomal' : 'scaffold';
  my $help_text = $string ? sprintf('<p>%s</p>', escapeHTML($string)) : '';
  my $url = $self->_url({ '__clear' => 1, 'action' => 'View', 'r' => $sample{'LOCATION_PARAM'} });
  
  $help_text .= sprintf('
    <p>
      A location is required to build this page. For example, %s coordinates:
    </p>
    <blockquote class="space-below">
      <a href="%s">%s</a>
    </blockquote>',
    $assembly_level,
    escapeHTML($url),
    escapeHTML($self->species_defs->ENSEMBL_BASE_URL . $url)
  );
  
  if (scalar(@{$self->species_defs->ENSEMBL_CHROMOSOMES})) {
    my $url = $self->_url({ '__clear' => 1, 'action' => 'Genome' });
    
    $help_text .= sprintf('
      <p class="space-below">
        You can also browse this genome via its <a href="%s">karyotype</a>
      </p>', 
      escapeHTML($url)
    );
  }
  
  return $help_text;
}

sub _variation_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'variation'} ||=
    $self->database('variation',$self->__species)->get_VariationAdaptor;
}
sub _variation_feature_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'variation_feature'} ||=
    $self->database('variation',$self->__species)->get_VariationFeatureAdaptor;
}
sub _coord_system_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'coord_system'} ||=
    $self->database('core',$self->__species)->get_CoordSystemAdaptor;
}
sub _slice_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'slice'} ||=
    $self->database('core',$self->__species)->get_SliceAdaptor;
}
sub _gene_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"gene_$db"} ||=
    $self->database($db,$self->__species)->get_GeneAdaptor;
}
sub _predtranscript_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"predtranscript_$db"} ||=
    $self->database($db,$self->__species)->get_PredictionTranscriptAdaptor;
}
sub _transcript_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"transcript_$db"} ||=
    $self->database($db,$self->__species)->get_TranscriptAdaptor;
}
sub _exon_adaptor {
  my $self = shift;
  my $db   = shift || 'core';
  return $self->__species_hash->{'adaptors'}{"exon_$db"} ||=
    $self->database($db,$self->__species)->get_ExonAdaptor;
}
sub _marker_adaptor {
  my $self = shift;
  return $self->__species_hash->{'adaptors'}{'marker'} ||=
    $self->database('core',$self->__species)->get_MarkerAdaptor;
}


#------------------------------------------------------------------------------


sub _map_assembly {
  my ($self, $seq_region, $start, $end, $strand, $ass) = @_;

  ## Check if we have this assembly in the list
  ## Get chromosome:XXXX->chromosome:CURRENT_ASSEMBLY  mappings
  my %params = map {
                 $_ => $self->{'data'}{'_input'}->param($_)
               } $self->{'data'}{'_input'}->param;

  my %mappings = map {
                   reverse (/^chromosome:(.+)#chromosome:(.+)$/)
                 } @{ $self->species_defs->ASSEMBLY_MAPPINGS };

  my @mappings = keys %mappings;
  
  ## Check if requested assembly is in %mappings
  if ( grep { uc($_) eq uc($ass) } @mappings ) {
    my $old_slice = $self->_slice_adaptor->fetch_by_region(
      'chromosome',
      $seq_region,
      $start, $end, $strand,
      $ass
    );

    my $segments = $old_slice->project('chromosome', $self->species_defs->ASSEMBLY_NAME);

    if (@$segments == 1) {
      
      my $new_slice = shift(@$segments)->to_Slice;
      
      $self->session->add_data(
        type     => 'message',
        function => '_info',
        code     => 'new_coordinates',
        message  => "Your request for $seq_region:$start-$end in <b>$ass</b> has been mapped to the new <b>"  .
                     $self->species_defs->ASSEMBLY_NAME . "</b> coordinates $seq_region:". $new_slice->start ."-". $new_slice->end,
      );
      
      %params = (
        %params,
        r => "$seq_region:". $new_slice->start .'-'. $new_slice->end,
      );
      
      return $self->problem('redirect', $self->_url(\%params));
      
    } elsif (@$segments) {
      
      my $message;

      my $new_start = $segments->[0]->to_Slice->start;
      my $new_end   = $segments->[0]->to_Slice->end;
      my $prev_end  = 0;
      my $count     = @$segments;
      
      foreach my $segment (@$segments) {
        my $new_slice = $segment->to_Slice;
        $new_start    = $new_slice->start if $new_slice->start < $new_start;
        $new_end      = $new_slice->end   if $new_slice->end   > $new_end;
        
        my %new_params = (
          %params,
          r => "$seq_region:". $new_slice->start .'-'. $new_slice->end . '<br />',
        );
        
        if ($prev_end && ($old_slice->start + $segment->from_start - $prev_end > 2)) {
          $message .= ($prev_end + 1) .'-'. ($old_slice->start + $segment->from_start - 2) .
                      ' - GAP <br />'; 
        }
        
        $prev_end = $old_slice->start + $segment->from_end - 1;
        $message .= ($old_slice->start + $segment->from_start - 1) .'-'. ($old_slice->start + $segment->from_end - 1) .
                    ' projects to <a href="'. $self->_url(\%new_params) .'">' .
                    $new_slice->start . ' - ' . $new_slice->end . '</a><br />'; 
      }

      $self->session->add_data(
        type     => 'message',
        function => '_info',
        code     => 'several_new_coordinates',
        message  => "Your request for $seq_region:$start-$end in <b>$ass</b> has been mapped to $count locations within new <b>" .
                    $self->species_defs->ASSEMBLY_NAME . "</b> coordinates " .
                    "$seq_region:$new_start-$new_end <br />" .
                    "<strong>Mapped segments:</strong> <br />" . $message,
      );

      %params = (
        %params,
        r => "$seq_region:$new_start-$new_end",
      );      

      return $self->problem('redirect', $self->_url(\%params));
      
    } else {
        $self->session->add_data(
          type     => 'message',
          function => '_info',
          code     => 'no_mappings_for_assembly',
          message  => "No changes in coordinates of this slice since <b>$ass</b>",
        );
    }
    
    return $self->problem('redirect', $self->_url(\%params));
    
  } elsif (@mappings) {
    ## Assembly is not recognised among list of possible ones
    ## Put warning message and redirect
    $self->session->add_data(
      type     => 'message',
      function => '_warning',
      code     => 'assembly_not_recognised',
      message  => "Sorry, assembly <b><i>$ass</i></b> was not recognised, we currently map " .
                  (scalar(@mappings) > 1
                   ? join(' and ', reverse (pop @mappings,  join(', ', @mappings))) . ' assemblies only'
                   : "@mappings assembly only"),
    );
    return $self->problem('redirect', $self->_url(\%params));
  } else {
    ## We do not have any assemblies to map
    $self->session->add_data(
      type     => 'message',
      function => '_warning',
      code     => 'no_assemblies',
      message  => "Sorry we currently don't have any other assemblies to map",
    );
    return $self->problem('redirect', $self->_url(\%params));
  }
  
}


#sub _map_assembly {
#  my ($self, $seq_region, $start, $end, $strand, $ass) = @_;
#
#  ## Check if we have this assembly in the list
#  ## Get chromosome:XXXX->chromosome:CURRENT_ASSEMBLY  mappings
#  warn "checking compatability for give assembly: $ass";
#  my %params = map {
#                 $_ => $self->{'data'}{'_input'}->param($_)
#               } $self->{'data'}{'_input'}->param;
#
#  my %mappings = map {
#                   reverse (/^chromosome:(.+)#chromosome:(.+)$/)
#                 } @{ $self->species_defs->ASSEMBLY_MAPPINGS };
#
#  my @mappings = keys %mappings;
#  
#  ## Check if requested assembly is in %mappings
#  if ( grep { uc($_) eq uc($ass) } @mappings ) {
#    my $csa    = $self->database('core', $self->species)->get_CoordSystemAdaptor;
#    my $ama    = $self->database('core', $self->species)->get_AssemblyMapperAdaptor;
#    my $old_cs = $csa->fetch_by_name('chromosome', $ass);
#    my $new_cs = $csa->fetch_by_name('chromosome', $self->species_defs->ASSEMBLY_NAME);
#    my $mapper = $ama->fetch_by_CoordSystems($old_cs, $new_cs);      
#
#    my @coords = $mapper->map($seq_region, $start, $end, $strand, $old_cs);
#    
#    if (@coords == 1) {
#      
#      my ($c) = @coords;
#      
#      $self->session->add_data(
#        type     => 'message',
#        function => '_info',
#        code     => 'new_coordinates',
#        message  => "Your request for $seq_region:$start-$end in <b>$ass</b> has been mapped to the new <b>"  .
#                     $self->species_defs->ASSEMBLY_NAME . "</b> coordinates $seq_region:". $c->start ."-". $c->end,
#      );
#      
#      %params = (
#        %params,
#        r => "$seq_region:". $c->start .'-'. $c->end,
#      );
#      
#      return $self->problem('redirect', $self->_url(\%params));
#      
#    } elsif (@coords) {
#      
#      my $message;
#
#      my $new_start = $coords[0]->start;
#      my $new_end   = $coords[0]->end;
#      my $count     = @coords;
#      
#      foreach my $c (@coords) {
#        $new_start = $c->start if $c->start < $new_start;
#        $new_end = $c->end if $c->end > $new_end;
#        warn Dumper($c);
#        if (ref($c) =~ /Gap/) {
#          $message .= 'GAP: '. $c->start . ' - ' . $c->end . '<br />'; 
#        } else {
#          my %new_params = (
#            %params,
#            r => "$seq_region:". $c->start .'-'. $c->end . '<br />',
#          );
#          $message .= 'New coordinates: <a href="'. $self->_url(\%new_params) .'">'. $c->start . ' - ' . $c->end . '</a><br />'; 
#        }
#      }
#
#      $self->session->add_data(
#        type     => 'message',
#        function => '_info',
#        code     => 'several_new_coordinates',
#        message  => "Your request for $seq_region:$start-$end in <b>$ass</b> has been mapped to $count locations within new <b>" .
#                    $self->species_defs->ASSEMBLY_NAME . "</b> coordinates " .
#                    "$seq_region:$new_start-$new_end <br />" .
#                    "<strong>Mapped segments:</strong> <br />" . $message,
#      );
#
#      %params = (
#        %params,
#        r => "$seq_region:$new_start-$new_end",
#      );      
#
#      return $self->problem('redirect', $self->_url(\%params));
#      
#    } else {
#        $self->session->add_data(
#          type     => 'message',
#          function => '_info',
#          code     => 'no_mappings_for_assembly',
#          message  => "No changes in coordinates of this slice since <b>$ass</b>",
#        );
#    }
#    
#    return $self->problem('redirect', $self->_url(\%params));
#    
#  } elsif (@mappings) {
#    ## Assembly is not recognised among list of possible ones
#    ## Put warning message and redirect
#    warn "Assembly $ass is not regognized";
#    $self->session->add_data(
#      type     => 'message',
#      function => '_warning',
#      code     => 'assembly_not_recognised',
#      message  => "Sorry, assembly <b><i>$ass</i></b> was not recognised, we currently map " .
#                  (scalar(@mappings) > 1
#                   ? join(' and ', reverse (pop @mappings,  join(', ', @mappings))) . ' assemblies only'
#                   : "@mappings assembly only"),
#    );
#    return $self->problem('redirect', $self->_url(\%params));
#  } else {
#    ## We do not have any assemblies to map
#    $self->session->add_data(
#      type     => 'message',
#      function => '_warning',
#      code     => 'no_assemblies',
#      message  => "Sorry we currently don't have any other assemblies to map",
#    );
#    return $self->problem('redirect', $self->_url(\%params));
#  }
#  
#}


1;
  
