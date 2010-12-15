# $Id$

package EnsEMBL::Web::Object::Export;

### NAME: EnsEMBL::Web::Object::Export
### Wrapper around a dynamically generated Bio::EnsEMBL data object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### An 'empty' wrapper object with on-the-fly creation of 
### data objects that are to be exported

use strict;

use base qw(EnsEMBL::Web::Object);

sub caption             { return 'Export Data';                                                      }
sub get_location_object { return $_[0]->{'_location'} ||= $_[0]->hub->core_objects->{'location'};    }
sub get_all_transcripts { return $_[0]->hub->core_objects->{'gene'}->Obj->get_all_Transcripts || []; }
sub check_slice         { return shift->get_location_object->check_slice(@_);                        }
sub get_ld_values       { return shift->get_location_object->get_ld_values(@_);                      }

sub slice {
  my $self     = shift;
  my $location = $self->get_location_object;
  
  return $location->slice if $location;
  
  my $hub = $self->hub;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;
  
  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }
  
  return $lrg_slice;
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
        [ 'gtf',  'Gene Transfer Format (GTF)' ],
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
        [ 'cds',        'Coding sequences' ]
      ]
    },
#     bed => {
#       label => 'Bed Format',
#       formats => [
#         [ 'bed',  'BED Format' ],
#       ],
#       params => [
#         [ 'userdata',  'Uploaded Data' ],
#         [ 'description', 'Track name & Description' ],
#       ]
#     },
#     PSL => {
#       label => 'PSL Format',
#       formats => [
#         [ 'PSL',  'PSL Format' ],
#       ],
#       params => [
#           [ 'name',  'Bed Line Name' ],
#         ]
#     },
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
    $options->{'translation'} = 1 if $_->translation;
    $options->{'three'}       = 1 if $_->three_prime_utr;
    $options->{'five'}        = 1 if $_->five_prime_utr;
    
    last if $options->{'translation'} && $options->{'three'} && $options->{'five'};
  }
  
  $self->__data->{'config'}->{'fasta'}->{'params'} = [
    [ 'cdna',    'cDNA'                                        ],
    [ 'coding',  'Coding sequence',  $options->{'translation'} ],
    [ 'peptide', 'Peptide sequence', $options->{'translation'} ],
    [ 'utr5',    "5' UTR",           $options->{'five'}        ],
    [ 'utr3',    "3' UTR",           $options->{'three'}       ],
    [ 'exon',    'Exons'                                       ],
    [ 'intron',  'Introns'                                     ]
  ];
}

1;
