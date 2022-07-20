=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Object::Export;

### NAME: EnsEMBL::Web::Object::Export
### Wrapper around a dynamically generated Bio::EnsEMBL data object  

### STATUS: At Risk

### DESCRIPTION
### An 'empty' wrapper object with on-the-fly creation of 
### data objects that are to be exported

use strict;

use Data::Dumper;
use Bio::AlignIO;
use IO::String;

use EnsEMBL::Web::Component::Compara_Alignments;
use EnsEMBL::Web::Document::Table;
use EnsEMBL::Web::SeqDumper;

use base qw(EnsEMBL::Web::Object);

sub caption                { return 'Export Data';                                                      }
sub get_location_object    { return $_[0]->{'_location'} ||= $_[0]->hub->core_object('location');       }
sub get_all_transcripts    { return $_[0]->hub->core_object('gene')->Obj->get_all_Transcripts || []; }
sub check_slice            { return shift->get_location_object->check_slice(@_);                        }
sub get_ld_values          { return shift->get_location_object->get_ld_values(@_);                      }
sub get_pop_name           { return shift->get_location_object->pop_name_from_id(@_);                   }
sub get_samples            { return shift->get_object->get_samples(@_);                                 }
sub get_genetic_variations { return shift->get_object->get_genetic_variations(@_);                      }
sub stable_id              { return shift->get_object->stable_id;                                       }
sub availability           { return shift->get_object->availability;                                    }

sub dbs {
  my $self = shift;
  my $species_defs = $self->species_defs;
  my @dbs = ('core');
  push @dbs, 'vega'          if $species_defs->databases->{'DATABASE_VEGA'};
  push @dbs, 'otherfeatures' if $species_defs->databases->{'DATABASE_OTHERFEATURES'};
  push @dbs, 'vega_update'   if $species_defs->databases->{'DATABASE_VEGA_UPDATE'};
  return \@dbs;
}

sub gene_source {
  my $self = shift;
  my ($g,$db) = @_;
  my $source;
  if ($self->species_defs->ENSEMBL_SITETYPE eq 'Vega') {
    $source = $g->analysis->display_label;
  }
  else {
    $source = $db eq 'vega' ? 'Vega' : 'Ensembl';
  }
  return $source;
}

sub slice {
  my $self     = shift;
  my $location = $self->get_location_object;
  my $hub = $self->hub;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;
  
  if ($location) {
     my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
     my $slice = $location->slice;     
     $slice = $slice->invert if ($hub->param('strand') eq '-1');

     if ($flank5 || $flank3) {
        $slice = $slice->expand($flank5, $flank3);
     }

     return $slice; 
   }
   
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
        [ 'gtf',  'GTF (Gene Transfer Format)' ],
        [ 'gff',  'GFF (Generic Feature Format)' ],
        [ 'gff3', 'GFF3 (Generic Feature Format Version 3)' ],
      ],
      params => [
        [ 'similarity', 'Similarity features' ],
        [ 'repeat',     'Repeat features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'variation',  'Variation features' ],
        [ 'probe',      'Probe features' ],
        [ 'gene',       'Gene information' ],
        [ 'transcript', 'Transcripts' ],
        [ 'exon',       'Exons' ],
        [ 'intron',     'Introns' ],
        [ 'cds',        'Coding sequences' ]
      ]
    },
    bed => {
      label => 'Bed Format',
      formats => [
        [ 'bed',  'BED Format' ],
      ],
      params => [
        [ 'variation',  'Variation features' ],
        [ 'probe',      'Probe features' ],
        [ 'gene',       'Gene information' ],
        [ 'repeat',     'Repeat features' ],
        [ 'similarity', 'Similarity features' ],
        [ 'genscan',    'Prediction features (genscan)' ],
        [ 'userdata',  'Uploaded Data' ],
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
    },
  };

  if ($self->function eq 'Location') {
    $self->__data->{'config'}{'fasta'} = {
      label => 'FASTA sequence',
      formats => [
        [ 'fasta', 'FASTA sequence' ]
      ],
      params => []
    };
  }

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

sub params :lvalue {$_[0]->{'params'};  }
sub string { return shift->output('string', @_); }
sub html   { return shift->output('html',   @_); }
sub image_width { return shift->hub->image_width; }
sub _warning { return shift->_info_panel('warning', @_ ); } # Error message, but not fatal

sub html_format { return $_[0]->hub->param('_format') ne "TextGz"; }

sub _info_panel {
  my ($self, $class, $caption, $desc, $width, $id) = @_;
  
  return $self->html_format ? sprintf(
    '<div%s style="width:%s" class="%s"><h3>%s</h3><div class="error-pad">%s</div></div>',
    $id ? qq{ id="$id"} : '',
    $width || $self->image_width . 'px', 
    $class, 
    $caption, 
    $desc
  ) : '';
}

sub output {
  my ($self, $key, $string) = @_;
  $self->{$key} .= "$string\r\n" if defined $string;
  return $self->{$key};
}

#function to get location, gene, transcript or LRG object for the export data.
sub get_object {
  my $self  = shift;
  my $hub   = $self->hub;
  
  if($hub->function eq 'Transcript') {
    return $self->hub->core_object('transcript');
  }elsif ($hub->function eq 'Gene') {
    return $self->hub->core_object('gene');
  }elsif ($hub->function eq 'LRG') {
    return $self->hub->core_object('lrg');
  }elsif ($hub->function eq 'Variation') {
    return $self->hub->core_object('variation');
  }else {
    return $self->hub->core_object('location');
  }
}

sub process {  
  my $self           = shift;
  my $custom_outputs = shift || {};

  my $hub            = $self->hub;  
  my $o              = $hub->param('output');
  my $strand         = $hub->param('strand');

  my $object         = $self->get_object;
  my @inputs         = ($hub->function eq 'Gene' || $hub->function eq 'LRG') ? $object->get_all_transcripts : @_;  
  @inputs            = [$object] if($hub->function eq 'Transcript');  

  my $slice          = $object->slice('expand');
  $slice             = $self->slice if($slice == 1);

  my $feature_strand = $slice->strand;

  $strand            = undef unless $strand == 1 || $strand == -1; # Feature strand will be correct automatically
  $slice             = $slice->invert if $strand && $strand != $feature_strand;
  my $params         = { feature_strand => $feature_strand };
  my $html_format    = $self->html_format;

  if ($slice->length > 5000000) {
    my $error = 'The region selected is too large to export. Please select a region of less than 5Mb.';
    
    $self->string($html_format ? $self->_warning('Region too large', "<p>$error</p>") : $error);    
  } else {
    my $outputs = {
      fasta     => sub { return $self->fasta(@inputs);  },
      csv       => sub { return $self->features('csv'); },
      tab       => sub { return $self->features('tab'); },
      bed       => sub { return $self->bed;    },
      gtf       => sub { return $self->features('gtf'); },
      psl       => sub { return $self->psl_features;    },
      gff       => sub { return $self->features('gff'); },
      gff3      => sub { return $self->gff3_features;   },
      embl      => sub { return $self->flat('embl');    },
      genbank   => sub { return $self->flat('genbank'); },
      alignment => sub { return $self->alignment;       },
      phyloxml  => sub { return $self->phyloxml('compara');},
      phylopan  => sub { return $self->phyloxml('compara_pan_ensembl');},
      orthoxml  => sub { return $self->orthoxml('compara');},
      orthopan  => sub { return $self->orthoxml('compara_pan_ensembl');},
      %$custom_outputs
    };

    if ($outputs->{$o}) {
      map { $params->{$_} = 1 if $_ } $hub->param('param');
      map { $params->{'misc_set'}->{$_} = 1 if $_ } $hub->param('misc_set'); 
      $self->params = $params;
      my $access_info = 'referer=';
      if ($hub->referer->{'absolute_url'}) {
        $hub->referer->{'absolute_url'} =~ m/^http(s)?\:\/\/([^\/]+)/;
        my $referer = $2;
        if ($hub->species_defs->ENSEMBL_SERVERNAME eq $referer) {
          $access_info .= "same--$referer"
        }
        else {
          $access_info .= "different--$referer"
        }
      }
      else {
        $access_info .= 'notfound--notfound'
      }

      warn "ExporterEvent--$access_info--" . join('-', ($o, $hub->param('_format'))) . '-' . join(',',sort keys %$params);
      $outputs->{$o}();
    }
  }
  
  my $string = $self->string;
  my $html   = $self->html; # contains html tags
  
  if ($html_format) {
    $string = "<pre>$string</pre>" if $string;
  } else {    
    if($o ne "phyloxml" && $o ne "phylopan" && $o ne "orthoxml" && $o ne "orthopan"){
      s/<.*?>//g for $string, $html; # Strip html tags;
    }
    $string .= "\r\n" if $string && $html;
  }
  
  return ($string . $html) || 'No data available';
}

sub fasta {
  my ($self, $trans_objects) = @_;

  my $hub             = $self->hub;
  my $object          = $self->get_object;
  my $object_id       = ($hub->function eq 'Gene' || $hub->function eq 'LRG') ? $object->stable_id : '';
  my $slice           = $object->slice('expand');
  $slice              = $self->slice if($slice == 1);
  my $strand          = $hub->param('strand');
  if(($strand ne 1) && ($strand ne -1)) {$strand = $slice->strand;}
  if($strand != $slice->strand){ $slice=$slice->invert; }
  my $params          = $self->params;
  my $genomic         = $hub->param('genomic');
  my $seq_region_name = $object->seq_region_name;
  my $seq_region_type = $object->seq_region_type;
  my $slice_name      = $slice->name;
  my $slice_length    = $slice->length;
  my $fasta;
  if (scalar keys %$params) {
    my $intron_id;
    
    my $output = {
      cdna    => sub {
                      my ($t, $id, $type) = @_;
                      my $full_id = $t->display_id;
                      $full_id .= '.'.$t->version if $t->version;
                      $id = "$full_id $id" unless $id eq $full_id;
                      [[ "$id cdna:$type", $t->spliced_seq ]] },
      coding  => sub { my ($t, $id, $type) = @_; [[ "$id cds:$type", $t->translateable_seq ]] },
      peptide => sub { my ($t, $id, $type) = @_; eval { [[ "$id peptide: " . $t->translation->stable_id . " pep:$type", $t->translate->seq ]] }},
      utr3    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr3:$type", $t->three_prime_utr->seq ]] }},
      utr5    => sub { my ($t, $id, $type) = @_; eval { [[ "$id utr5:$type", $t->five_prime_utr->seq ]] }},
      exon    => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id " . $_->stable_id . " exon:$type", $_->seq->seq ]} @{$t->get_all_Exons} ] }},
      intron  => sub { my ($t, $id, $type) = @_; eval { [ map {[ "$id intron " . $intron_id++ . ":$type", $_->seq ]} @{$t->get_all_Introns} ] }}
    };


    
    foreach (@$trans_objects) {
      my $transcript = $_->Obj;
      my $id    = ($object_id ? "$object_id:" : '') . $transcript->stable_id;
      $id      .= '.'.$transcript->version if $transcript->version;
      my $type  = $transcript->isa('Bio::EnsEMBL::PredictionTranscript') ? $transcript->analysis->logic_name : $transcript->biotype;
      
      $intron_id = 1;
      
      foreach (sort keys %$params) {      
        my $o = $output->{$_}($transcript, $id, $type) if exists $output->{$_};
        
        next unless ref $o eq 'ARRAY';
        
        foreach (@$o) {
          $self->string(">$_->[0]");
          $self->string($fasta) while $fasta = substr $_->[1], 0, 60, '';
        }
      }
      
      $self->string('');
    }
  }

  if (defined $genomic && $genomic ne 'off') {
    my $masking = $genomic eq 'soft_masked' ? 1 : $genomic eq 'hard_masked' ? 0 : undef;
    my ($seq, $start, $end, $flank_slice);

    if ($genomic =~ /flanking/) {      
      for (5, 3) {
        if ($genomic =~ /$_/) {
          if ($strand == $params->{'feature_strand'}) {
            ($start, $end) = $_ == 3 ? ($slice_length - $hub->param('flank3_display') + 1, $slice_length) : (1, $hub->param('flank5_display'));
          } else {
            ($start, $end) = $_ == 5 ? ($slice_length - $hub->param('flank5_display') + 1, $slice_length) : (1, $hub->param('flank3_display'));
          }
          
          $flank_slice = $slice->sub_Slice($start, $end);
          
          if ($flank_slice) {
            $seq  = $flank_slice->seq;
            
            $self->string(">$_' Flanking sequence " . $flank_slice->name);
            $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
          }
        }
      }
    } else {
      $seq = defined $masking ? $slice->get_repeatmasked_seq(undef, $masking)->seq : $slice->seq;
      $self->string(">$seq_region_name dna:$seq_region_type $slice_name");
      $self->string($fasta) while $fasta = substr $seq, 0, 60, '';
    }
  }
}

sub flat {
  my $self          = shift;
  my $format        = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $slice         = $self->slice;
  my $params        = $self->params;
  my $plist         = $species_defs->ANNOTATION_PROVIDER_NAME;
  my $vega_db       = $hub->database('vega');
  my $estgene_db    = $hub->database('otherfeatures');
  my $dumper_params = {};
  
  # Check where the data came from.
  if ($plist) {
    my $purls         = $species_defs->ANNOTATION_PROVIDER_URL;
    my @providers     = ref $plist eq 'ARRAY' ? @$plist : ($plist);
    my @providers_url = ref $purls eq 'ARRAY' ? @$purls : ($purls);
    my @list;

    foreach my $ds (@providers) {
      my $purl = shift @providers_url;
      
      $ds .= " ( $purl )" if $purl;
      
      push @list, $ds;
    }
    
    $dumper_params->{'_data_source'} = join ', ' , @list;
  }

  my $seq_dumper = EnsEMBL::Web::SeqDumper->new(undef, $dumper_params);

  foreach (qw( genscan similarity gene repeat variation contig marker )) {
    $seq_dumper->disable_feature_type($_) unless $params->{$_};
  }

  if ($params->{'vegagene'} && $vega_db) {
    $seq_dumper->enable_feature_type('vegagene');
    $seq_dumper->attach_database('vega', $vega_db);
  }
  
  if ($params->{'estgene'} && $estgene_db) {
    $seq_dumper->enable_feature_type('estgene');
    $seq_dumper->attach_database('estgene', $estgene_db);
  }
  
  $self->string($seq_dumper->dump($slice, $format));
}

sub alignment {
  my $self = shift;
  my $hub  = $self->hub;
  
  # Nasty hack to link export to the view config for alignments. Eww.
  $hub->get_viewconfig({component => 'Compara_Alignments', type => $hub->type, cache => 1});
  
  $self->{'alignments_function'} = 'get_SimpleAlign';
  
  my $alignments = $self->get_alignments({
                              'slice' => $self->slice,
                              'align' => $hub->param('align'), 
                              'species' => $hub->species
                          });
  my $export;

  my $align_io = Bio::AlignIO->newFh(
    -fh     => IO::String->new($export),
    -format => $hub->param('format')
  );

  print $align_io $alignments;
  
  $self->string($export);
}

sub features {
  my $self          = shift;
  my $format        = shift;
  my $slice         = $self->slice;
  my $params        = $self->params;
  my @common_fields = qw(seqname source feature start end score strand frame);
  my @extra_fields  = $format eq 'gtf' ? qw(gene_id transcript_id) : qw(hid hstart hend genscan gene_id transcript_id exon_id gene_type variation_name probe_name);  
  my $availability  = $self->availability;
  
  $self->{'config'} = {
    extra_fields  => \@extra_fields,
    format        => $format,
    delim         => $format eq 'csv' ? ',' : "\t"
  };
  
  if ($format ne 'bed'){$self->string(join $self->{'config'}->{'delim'}, @common_fields, @extra_fields) unless $format eq 'gff';}
  
  if ($params->{'similarity'}) {
    foreach (@{$slice->get_all_SimilarityFeatures}) {
      $self->feature('similarity', $_, { 
        hid    => $_->hseqname, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'repeat'}) {
    foreach (@{$slice->get_all_RepeatFeatures}) {
      $self->feature('repeat', $_, { 
        hid    => $_->repeat_consensus->name, 
        hstart => $_->hstart, 
        hend   => $_->hend 
      });
    }
  }
  
  if ($params->{'genscan'}) {
    foreach my $t (@{$slice->get_all_PredictionTranscripts}) {
      foreach my $e (@{$t->get_all_Exons}) {
        $self->feature('pred.trans.', $e, { genscan => $t->stable_id });
      }
    }
  }
  
  if ($params->{'variation'} && $self->database('variation')) {
    my $vdb = $self->database('variation'); 
    my $vf_adaptor = $vdb->get_VariationFeatureAdaptor;     
    foreach (@{$vf_adaptor->fetch_all_by_Slice($slice)}) {
      $self->feature('variation', $_, { variation_name => $_->variation_name });	    
    }
  }

  if($params->{'probe'} && $availability->{'database:funcgen'}) {
    my $fg_db = $self->database('funcgen'); 
    my $probe_feature_adaptor = $fg_db->get_ProbeFeatureAdaptor;     
    my @probe_features = @{$probe_feature_adaptor->fetch_all_by_Slice($slice)};
    
    foreach my $pf(@probe_features){
      my $probe_details = $pf->probe->get_all_complete_names();
      my @probes = split(/:/,@$probe_details[0]);
      $self->feature('ProbeFeature', $pf, { probe_name => @probes[1] },{ source => @probes[0]});
    }
  }
  
  if ($params->{'gene'}) {
    my $dbs = $self->dbs;
    foreach my $db (@{$dbs}) {
      foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
        my $source = $self->gene_source($g,$db);
        foreach my $t (@{$g->get_all_Transcripts}) {
          my $g_stable_id = $g->stable_id;
          $g_stable_id .= '.'.$g->version if $g->version;
          my $t_stable_id = $t->stable_id;
          $t_stable_id .= '.'.$t->version if $t->version;
          foreach my $e (@{$t->get_all_Exons}) {
            $self->feature('gene', $e, { 
               exon_id       => $e->stable_id, 
               transcript_id => $t_stable_id, 
               gene_id       => $g_stable_id, 
               gene_type     => $g->biotype
            }, { source => $source });
          }
        }
      }
    }
  }
 
  $self->misc_sets(keys %{$params->{'misc_set'}}) if $params->{'misc_set'};
}

sub bed {
  my $self   = shift;
  my $hub    = $self->hub;
  
  my $object = $self->get_object;  
  my $slice  = $object->slice('expand');
  $slice     = $self->slice if($slice == 1);
  
  my $params = $self->params;
  my ($output,$title);

  $self->{'config'} = {   
    format => 'bed',
    delim  => "\t"
  };
  
  my $config = $self->{'config'}; 
  my (%vals, @column, $trackname);

  my $types_to_print = {};
  foreach my $bed_option (@{ $self->config->{'bed'}->{'params'}}){
    my ($bed_option_key,$bed_option_desc) = @$bed_option;
    next unless $params->{$bed_option_key};
    $types_to_print->{$bed_option_key} = $bed_option_desc;
    $params->{$bed_option_key} = 0;
  }
  foreach my $type(keys %$types_to_print){
    $params->{$type} = 1;
    my $backup = $self->{'string'};
    $self->string(sprintf('track name=%s description="%s"',$type,$types_to_print->{$type}));
    my $length = length $self->{'string'};
    $self->features('bed');
    $params->{$type} = 0;
    if($length == length $self->{'string'}){$self->{'string'}=$backup;}
    else{
      $self->string("");
    }
  }
  
  #get data from files user uploaded if any and display   
  if($params->{'userdata'}){
       my @fs = $self->get_user_data('BED');

       #displaying Uploaded data
       foreach my $f (@fs)
       {        
         if(!$trackname || $trackname ne $f->{'trackname'})
         {
           $self->string(join $self->{'config'}->{'delim'});
           $trackname = $f->{'trackname'};
           $title = qq{Browser position chr$f->{'seqname'}: $f->{'start'}-$f->{'end'} };
           $self->string(join $self->{'config'}->{'delim'}, $title);
              
           if($params->{'description'}){
             $self->string(sprintf("track name=%s description=%s useScore=%s color=%s",
               $trackname,$f->{'description'},$f->{'usescore'},$f->{'color'}));
           }
         }
         $f->{strand} = ($f->{strand} eq -1) ? '-' : '+';
         $self->string(join("\t",map {$f->{$_}} qw/seqname start end bedname score strand thick_start thick_end item_color BlockCount BlockSizes BlockStart/));
       }
   }
}

sub get_user_data {
  my $self = shift; 
  my $format = shift;
  
  my $hub  = $self->hub;
  my $user = $hub->user;
  my (@fs, $class, $start, $end, $seqname);
  
  my @user_file = $hub->session->get_data('type' => 'upload');

  foreach my $row (@user_file) {
     next unless ($row->{'code'} && $row->{'format'} eq $format);
     my $file = "upload_$row->{'code'}";
     my $name = $row->{'name'};
     my $data = $hub->fetch_userdata_by_id($file);     
  
     if (my $parser = $data->{'parser'}) {
       foreach my $type (keys %{$parser->{'tracks'}}) {
         my $features = $parser->fetch_features_by_tracktype($type);
         ## Convert each feature into a proper API object
         foreach (@$features) {
           my $ddaf = Bio::EnsEMBL::DnaDnaAlignFeature->new($_->cigar_string);
           $ddaf->species($hub->species);
           $ddaf->start($_->rawstart);
           $ddaf->end($_->rawend);
           $ddaf->strand($_->strand);
           $ddaf->seqname($_->seqname);
           $ddaf->score($_->score);
           $ddaf->extra_data($_->external_data);
           $ddaf->{'bedname'} = $_->id;
           $ddaf->{'trackname'} = $type;
           $ddaf->{'description'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'name'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'name'} : '';
           $ddaf->{'usescore'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'useScore'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'useScore'} : '';
           $ddaf->{'color'} = exists($parser->{'tracks'}->{$type}->{'config'}->{'color'}) ? $parser->{'tracks'}->{$type}->{'config'}->{'color'} : '';
           push @fs, $ddaf;
         }
       }
     }
     elsif ($data->{'features'}) {
       push @fs, @{$data->{'features'}};
     }
   }
   return @fs;
}

sub psl_features {
  my $self = shift;
}

sub gff3_features {
  my $self         = shift;
  my $slice        = $self->slice;
  my $params       = $self->params;
  my $species_defs = $self->hub->species_defs;
  
  # Always use the forward strand, else CDS coordinates are incorrect (Bio::EnsEMBL::Exon->coding_region_start and _end return coords for forward strand only. Thanks, Core API team.)
  $slice = $slice->invert if $slice->strand < 0;
  
  $self->{'config'} = {
    format             => 'gff3',
    delim              => "\t",
    ordered_attributes => {},
    feature_order      => {},
    feature_type_count => 0,
  };

  my ($g_id, $t_id);
  my $dbs = $self->dbs;
  my $div = $self->hub->species_defs->EG_DIVISION; 
  foreach my $db (@{$dbs}) {
    foreach my $g (@{$slice->get_all_Genes(undef, $db)}) {
      my $properties = { source => $self->gene_source($g,$db) };

      if ($params->{'gene'}) {
        $g_id = $g->stable_id;
        $g_id .= '.'.$g->version if $g->version;
        my $g_name = ($div && $g->display_xref) ? $g->display_xref->display_id : $g_id;
        $self->feature('gene', $g, { ID => $g_id, Name => $g_name, biotype => $g->biotype }, $properties);
      }

      foreach my $t (@{$g->get_all_Transcripts}) {
        if ($params->{'transcript'}) {
          $t_id = $t->stable_id;
          $t_id .= '.'.$t->version if $t->version;
          my $t_name = ($div && $t->display_xref) ? $t->display_xref->display_id : $t_id;
          $self->feature('transcript', $t, { ID => $t_id, Parent => $g_id, Name => $t_name, biotype => $t->biotype }, $properties);
        }

        if ($params->{'intron'}) {
          for my $intron (@{$t->get_all_Introns}){
            next unless $intron->length;
            $self->feature('intron', $intron, { Parent => $t_id, Name => $self->id_counter('intron') }, $properties);
          }
        }

        if ($params->{'exon'} || $params->{'cds'}) {
          foreach my $cds (@{$t->get_all_CDS||[]}) {
            $self->feature('CDS', $cds, { Parent => $t_id, Name => $t->translation->stable_id }, $properties);
          }
        }

        if ($params->{'exon'}) {
          foreach my $e (@{$t->get_all_Exons}) {
            $self->feature('exon', $e, { Parent => $t_id, Name => $e->stable_id }, $properties);
          }
        }
      }
    }
  }
  
  my %order = reverse %{$self->{'config'}->{'feature_order'}};
  
  $self->string('##gff-version 3');
  $self->string(sprintf('##sequence-region %s 1 %d', $slice->seq_region_name, $slice->seq_region_length));
  $self->string('');
  $self->string($self->output($order{$_})) for sort { $a <=> $b } keys %order;
}

sub feature {
  my ($self, $type, $feature, $attributes, $properties) = @_;
  my $config = $self->{'config'};
  my $format = $config->{'format'};
  
  my (%vals, @mapping_result);
  
  if ($feature->can('seq_region_name')) {
    %vals = (
      seqid  => $feature->seq_region_name,
      start  => $feature->seq_region_start,
      end    => $feature->seq_region_end,
      strand => $feature->seq_region_strand
    );
  } else {
    %vals = (
      seqid  => $feature->can('entire_seq') && $feature->entire_seq ? $feature->entire_seq->name : $feature->can('seqname') ? $feature->seqname : undef,
      start  => $feature->can('start')  ? $feature->start  : undef,
      end    => $feature->can('end')    ? $feature->end    : undef,
      strand => $feature->can('strand') ? $feature->strand : undef
    );
  }   
  if($format eq 'bed'){
    @mapping_result = qw(seqid start end name score strand);
    # move coords into zero-based start
    $vals{'start'} = $vals{'start'} - 1 if defined $vals{'start'};
    $vals{'name'} = $feature->display_id;
  }
  else {
    @mapping_result = qw(seqid source type start end score strand phase);
  }
  my $source = $feature->can('source_tag') ? $feature->source_tag  : $feature->can('source') ? $feature->source : 'Ensembl';
  if (ref($source) eq 'Bio::EnsEMBL::Variation::Source') {
    $source = $source->name;
  }
  %vals = (%vals, (
     type   => $type || ($feature->can('primary_tag') ? $feature->primary_tag : 'sequence_feature'),
     source => $source,
     score  => $feature->can('score') ? $feature->score : '.',
     phase  => '.'
   ));   
  if($format eq 'bed' && $vals{'score'} eq '.'){$vals{'score'}='0';}
  
  # Overwrite values where passed in
  foreach (keys %$properties) {
    $vals{$_} = $properties->{$_} if defined $properties->{$_};
  }
 
  if ($vals{'strand'} == 1) {
    $vals{'strand'} = '+';
    if ($feature->can('phase')) {
      ## Stricter rules for GFF3
      if ($format eq 'gff3') {
        if ($vals{'type'} eq 'CDS') {
          $vals{'phase'} = $feature->phase;
          ## -1 is not a valid value for a CDS phase!
          $vals{'phase'} = 0 if $vals{'phase'} == -1; 
        }
        else {
          $vals{'phase'} = '.';
        }
      }
      else {
        $vals{'phase'}  = $feature->phase;
      }
    }
  } elsif ($vals{'strand'} == -1) {
    $vals{'strand'} = '-';
    if ($feature->can('end_phase')) {
      ## Stricter rules for GFF3
      if ($format eq 'gff3') {
        if ($vals{'type'} eq 'CDS') {
          $vals{'phase'} = $feature->end_phase;
        }
        else {
          $vals{'phase'} = '.';
        }
      }
      else {
        $vals{'phase'}  = $feature->end_phase;
      }
    }
    ## Hack for API bug - -1 is not a valid value for phase!
    $vals{'phase'} = 0 if (defined($vals{'phase'}) && $vals{'phase'} == -1); 
  }
  
  $vals{'strand'} = '.' unless defined $vals{'strand'};
  $vals{'seqid'}  ||= 'SEQ';
  
  my @results = map { $vals{$_} =~ s/ /_/g; $vals{$_} } @mapping_result;

  if ($format eq 'gff') {
    push @results, join ';', map { defined $attributes->{$_} ? "$_=$attributes->{$_}" : () } @{$config->{'extra_fields'}};
  } elsif ($config->{'format'} eq 'gff3') {
    push @results, join ';', map { "$_=" . $self->escape_attribute($attributes->{$_}) } $self->order_attributes($type, $attributes);
  } elsif($format ne 'bed'){
    push @results, map { $attributes->{$_} } @{$config->{'extra_fields'}};
  }
  
  if ($format eq 'gff3') {
    $config->{'feature_order'}->{$type} ||= ++$config->{'feature_type_count'};
    $self->output($type, join "\t", @results);
  } else {
    $self->string(join $config->{'delim'}, @results);
  }
}

sub misc_sets {
  my $self      = shift;
  my $hub       = $self->hub;
  my $slice     = $self->slice;
  my $sets      = $hub->species_defs->databases->{'DATABASE_CORE'}->{'tables'}->{'misc_feature'}->{'sets'};
  my @misc_sets = sort { $sets->{$a}->{'name'} cmp $sets->{$b}->{'name'} } @_;
  my $region    = $slice->seq_region_name;
  my $start     = $slice->start;
  my $end       = $slice->end;
  my $db        = $hub->database('core');
  my $delim     = $self->{'config'}->{'delim'};
  my ($header, $table, @sets);
  
  my $header_map = {
    _gene   => { 
      title   => "Genes in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Ensembl ID', 'DB', 'Name' ]
    },
    default => {
      title   => "Features in set %s in Chromosome $region $start - $end",
      columns => [ 'SeqRegion', 'Start', 'End', 'Name', 'Well name', 'Sanger', 'EMBL Acc', 'FISH', 'Centre', 'State' ]
    }
  };
  
  foreach (@misc_sets, '_gene') {
    $header = $header_map->{$_} || $header_map->{'default'};
    $table  = EnsEMBL::Web::Document::Table->new if $self->html_format;
    
    $self->html(sprintf "<h2>$header->{'title'}</h2>", $sets->{$_}->{'name'});
    
    if ($table) {
      $table->add_columns(map {{ title => $_, align => 'left' }} @{$header->{'columns'}});
    } else {
      $self->html(join $delim, @{$header->{'columns'}});
    }
    
    @sets = $_ eq '_gene' ? $self->misc_set_genes : $self->misc_set($_, $sets->{$_}->{'name'}, $db);
  
    if (scalar @sets) {
      foreach (@sets) {
        if ($table) {
          $table->add_row($_);
        } else {
          $self->html(join $delim, @$_);
        }
      }
      
      $self->html($table->render) if $table;
    } else {
      $self->html('No data available');
    }
  
    $self->html('<br /><br />');
  }
}

sub misc_set {
  my ($self, $misc_set, $name, $db) = @_;
  my $adaptor;
  my @rows;

  eval {
    $adaptor = $db->get_MiscSetAdaptor->fetch_by_code($misc_set);
  };
  
  if ($adaptor) {    
    foreach (sort { $a->start <=> $b->start } @{$db->get_MiscFeatureAdaptor->fetch_all_by_Slice_and_set_code($self->slice, $adaptor->code)}) {
      push @rows, [
        $_->seq_region_name,
        $_->seq_region_start,
        $_->seq_region_end,
        join (';', @{$_->get_all_attribute_values('clone_name')}, @{$_->get_all_attribute_values('name')}),
        join (';', @{$_->get_all_attribute_values('well_name')}),
        join (';', @{$_->get_all_attribute_values('synonym')},    @{$_->get_all_attribute_values('sanger_project')}),
        join (';', @{$_->get_all_attribute_values('embl_acc')}),
        $_->get_scalar_attribute('fish'),
        $_->get_scalar_attribute('org'),
        $_->get_scalar_attribute('state')
      ];
    }
  }
  
  return @rows;
}

sub misc_set_genes {
  my $self  = shift;
  my $slice = $self->slice;
  my @rows;
  
  foreach (sort { $a->seq_region_start <=> $b->seq_region_start } map @{$slice->get_all_Genes($_) || []}, qw(ensembl havana ensembl_havana_gene)) {
    push @rows, [
      $_->seq_region_name,
      $_->seq_region_start,
      $_->seq_region_end,
      $_->stable_id,
      $_->external_db   || '-',
      $_->external_name || '-novel-'
    ];
  }
  
  return @rows;
}

# Orders attributes - predefined array first, then all other keys in alphabetical order
# Also strip any attributes for which we have keys but no values
sub order_attributes {
  my ($self, $key, $attrs) = @_;
  my $attributes = $self->{'config'}->{'ordered_attributes'};
  
  return @{$attributes->{$key}} if $key && $attributes->{$key}; # Reduce the work done
  
  my $i          = 1;
  my %predefined = map { $_ => $i++ } qw(ID Name Alias Parent Target Gap Derives_from Note Dbxref Ontology_term);
  my %order      = map { defined $attrs->{$_} ? ($predefined{$_} || $i++ => $_) : () } sort keys %$attrs;
  my @rtn        = map { $order{$_} } sort { $a <=> $b } keys %order;
  
  @{$attributes->{$key}} = @rtn if $key;
  
  return @rtn;
}

sub id_counter {
  my ($self, $type) = @_;
  return sprintf '%s%05d', $type, ++$self->{'id_counter'}->{$type};
}

sub escape {
  my ($self, $string, $match) = @_;
  
  return '' unless defined $string;
  
  $match ||= '([^a-zA-Z0-9.:^*$@!+_?-|])';
  $string  =~ s/$match/sprintf("%%%02x",ord($1))/eg;
  
  return $string;
}

# Can take array, will return comma separated string if this is the case
sub escape_attribute {
  my $self = shift;
  my $attr = shift;
  
  return '' unless defined $attr;
  
  my $match = '([,=;\t])';
  
  $attr = ref $attr eq 'ARRAY' ? join ',', map { $_ ? $self->escape($_, $match) : () } @$attr : $self->escape($attr, $match);
  
  return $attr;
}

1;
