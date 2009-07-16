package EnsEMBL::Web::Object::Export;

use strict;

use CGI qw(unescape);

use base 'EnsEMBL::Web::Object';

sub caption {
  return 'Export Data';
}

sub slice {
  my $self = shift;
  
  $self->{'_slice'} ||= $self->core_objects->location;
  
  return $self->{'_slice'};
}

sub get_all_transcripts {
  my $self = shift;
  
  return EnsEMBL::Web::Proxy::Object->new('Gene', $self->core_objects->gene, $self->__data)->get_all_transcripts || [];
}

sub get_location_object {
  my $self = shift;
  
  if (!$self->{'_location'}) {
    my $l = $self->slice;
    
    $self->{'_location'} = EnsEMBL::Web::Proxy::Object->new('Location', {
      type               => 'Location',
      real_species       => $self->__data->{'__location'}{'species'},
      name               => $l->seq_region_name,
      seq_region_name    => $l->seq_region_name,
      seq_region_start   => $l->start,
      seq_region_end     => $l->end,
      seq_region_strand  => 1,
      seq_region_type    => $l->coord_system->name,
      raw_feature_strand => 1,
      seq_region_length  => $l->seq_region_length,
    }, $self->__data);
    
    $self->{'_location'}->attach_slice($l);
  }
  
  return $self->{'_location'};
}

sub check_slice {
  my $self = shift;
  
  return $self->get_location_object->check_slice(@_);
}

sub get_ld_values {
  my $self = shift;
  
  return $self->get_location_object->get_ld_values(@_);
}

sub config {
  my $self = shift;
  
  $self->__data->{'config'} = {
    fasta => {
      label => 'FASTA sequence',
      formats => [
        [ 'fasta', 'FASTA sequence' ]
      ],
      params => [
        [ 'cdna',    'cDNA' ],
        [ 'coding',  'Coding sequence' ],
        [ 'peptide', 'Peptide sequence' ],
        [ 'utr5',    "5' UTR" ],
        [ 'utr3',    "3' UTR" ],
        [ 'exon',    'Exons' ],
        [ 'intron',  'Introns' ]
      ]
    },
    features => {
      label => 'Feature File',
      formats => [
        [ 'csv',  'CSV (Comma separated values)' ],
        [ 'tab',  'Tab separated values' ],
        [ 'gff',  'Generic Feature Format' ],
        [ 'gff3', 'Generic Feature Format Version 3' ],
      ],
      params => [
        [ 'similarity', 'Similarity features' ],
        [ 'repeat',     'Repeat features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'variation',  'Variation features' ],
        [ 'gene',       'Gene information' ],
        [ 'transcript', 'Transcripts' ],
        [ 'exon',       'Exons' ],
        [ 'intron',     'Introns' ],
        [ 'cds',        'Coding sequences' ],
      ]
    },
    flat => {
      label => 'Flat File',
      formats => [
        [ 'embl',    'EMBL' ],
        [ 'genbank', 'GenBank' ]
      ],
      params => [
        [ 'similarity', 'Similarity features' ],
        [ 'repeat',     'Repeat features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'contig',     'Contig Information' ],
        [ 'variation',  'Variation features' ],
        [ 'marker',     'Marker features' ],
        [ 'gene',       'Gene Information' ],
        [ 'vegagene',   'Vega Gene Information' ],
        [ 'estgene',    'EST Gene Information' ]
      ]
    },
    pip => {
      label => 'PIP (%age identity plot)',
      formats => [
        [ 'pipmaker', 'Pipmaker / zPicture format' ],
        [ 'vista',    'Vista Format' ]
      ]
    }
  };
  
  my $func = sprintf 'modify_%s_options', lc $self->function;
  $self->$func if $self->can($func);
  
  return $self->__data->{'config'};
}

sub modify_location_options {
  my $self = shift;
  
  my $misc_sets = $self->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'} || {};
  my @misc_set_params = map [ "miscset_$_", $misc_sets->{$_}->{'name'} ], keys %$misc_sets;
  
  $self->__data->{'config'}->{'fasta'}->{'params'} = [];
  push @{$self->__data->{'config'}->{'features'}->{'params'}}, @misc_set_params;
  
}

sub modify_gene_options {
  my $self = shift;
  
  my $options = { translation => 0, three => 0, five => 0 };
  
  foreach (@{$self->get_all_transcripts}) {
    $options->{'translation'} = 1 if $_->Obj->translation;
    $options->{'three'}       = 1 if $_->Obj->three_prime_utr;
    $options->{'five'}        = 1 if $_->Obj->five_prime_utr;
    
    last if $options->{'translation'} && $options->{'three'} && $options->{'five'};
  }
  
  $self->__data->{'config'}->{'fasta'}->{'params'} = [
    [ 'cdna',    'cDNA' ],
    [ 'coding',  'Coding sequence',  $options->{'translation'} ],
    [ 'peptide', 'Peptide sequence', $options->{'translation'} ],
    [ 'utr5',    "5' UTR",           $options->{'five'} ],
    [ 'utr3',    "3' UTR",           $options->{'three'} ],
    [ 'exon',    'Exons' ],
    [ 'intron',  'Introns' ]
  ];
}

1;
