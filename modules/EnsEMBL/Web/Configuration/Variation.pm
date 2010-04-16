package EnsEMBL::Web::Configuration::Variation;

use strict;

use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::Configuration);

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub configurator   { return $_[0]->_configurator;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub set_default_action {
  my $self = shift;
  
  if (!ref $self->object){
    $self->{'_data'}->{'default'} = 'Summary';
    return;
  }
  
  my $x = $self->object->availability || {};
  
  if ($x->{'variation'}) {
    $self->{'_data'}->{'default'} = 'Summary';
  }
}

sub availability {
  my $self = shift;
  my $hub = $self->model->hub;

  if (!$self->{'_availability'}) {
    my $availability = $self->default_availability;
    my $var = $self->model->api_object('Variation');;

    if ($var->isa('Bio::EnsEMBL::Variation::Variation')) {
      my $counts = $self->counts;

      if ($var->failed_description) {
        $availability->{'unmapped'} = 1;
      } else {
        $availability->{'variation'} = 1;
      }

      $availability->{"has_$_"} = $counts->{$_} for qw(transcripts populations individuals ega alignments);
    }

    $self->{'_availability'} = $availability;
  }

  return $self->{'_availability'};
}

sub counts {
  my $self = shift;
  my $hub = $self->model->hub;
  my $var = $self->model->api_object('Variation');;

  return {} unless $var->isa('Bio::EnsEMBL::Variation::Variation');
  my $key = '::Counts::Variation::'.
            $hub->species           .'::'.
            $hub->core_param('vdb') .'::'.
            $hub->core_param('v')   .'::';

  my $counts = $self->{'_counts'};
  $counts ||= $hub->cache->get($key) if $hub->cache;

  unless ($counts) {
    $counts = {};
    $counts->{'transcripts'} = $self->count_transcripts;
    $counts->{'populations'} = $self->count_populations;
    $counts->{'individuals'} = $self->count_individuals;
    $counts->{'ega'}         = $self->count_ega;
    $counts->{'alignments'}  = $self->count_alignments->{'multi'};

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
    $self->{'_counts'} = $counts;
  }

  return $counts;
}

sub count_ega {
  my $self = shift;
  my @ega_links = @{$self->model->object('Variation')->get_external_data};
  my $counts = scalar @ega_links || 0;
  return $counts;
}

sub count_transcripts {
  my $self = shift;
  my %mappings = %{ $self->model->object('Variation')->variation_feature_mapping };
  my $counts = 0;

  foreach my $varif_id (keys %mappings) {
    next unless ($varif_id  eq $self->model->hub->param('vf'));
    my @transcript_variation_data = @{ $mappings{$varif_id}{transcript_vari} };
    $counts = scalar @transcript_variation_data;
  }

  return $counts;
}

sub count_populations {
  my $self = shift;
  my $counts = scalar(keys %{$self->model->object('Variation')->freqs}) || 0;
  return $counts;
}

sub count_individuals {
  my $self = shift;
  my $dbh  = $self->model->hub->database('variation')->get_VariationAdaptor->dbc->db_handle;
  my $var  = $self->model->api_object('Variation');
  
  my ($multibp_samples) = $dbh->selectrow_array('
    select count(distinct sample_id)
    from individual_genotype_multiple_bp
    where variation_id=?',
    {}, $var->dbID
  );

  return $multibp_samples if $multibp_samples;

  my %sample_ids_for_variation;

  foreach my $vf (@{$var->get_all_VariationFeatures}) {
    my ($seq_region_id, $snp_pos) = ($vf->slice->get_seq_region_id, $vf->seq_region_start);

    # grab data from compressed genotype table
    # genotypes column consists of "triples" of the alleles followed by a 2-byte gap to the next snp
    my $data = $dbh->selectall_arrayref('
      select sample_id, seq_region_id, seq_region_start, seq_region_end, seq_region_strand, genotypes
      from compressed_genotype_single_bp
      where seq_region_id = ? and seq_region_start <= ? and seq_region_end >= ? and seq_region_start >= ?',
      {}, $seq_region_id, $snp_pos, $snp_pos, $snp_pos - 1e5
    );

    foreach my $row (@$data) {
      my ($sample_id, $x, $slice_start, $slice_end, $st, $genotypes) = @$row;
      my @genotypes = unpack '(aan)*', $genotypes;
      my $pos = $slice_start;
      
      while (my ($a1, $a2, $gap) = splice @genotypes, 0, 3) {
        next if $gap == -1; # '2 snps in same location' so can skip rest of loop - don't think this works as ffff == 65535 not -1!

        if ($pos == $snp_pos) {
          $sample_ids_for_variation{$sample_id} = 1;
          last; # We can skip out of this now don't need to walk along data anymore
        }

        $pos += $gap + 1;
      }
    }
  }

  return scalar keys %sample_ids_for_variation;
}

sub short_caption {
  my $self = shift;
  my $label = $self->model->object('Variation')->name;
  if( length($label)>30) {
    return "Var: $label";
  } else {
    return "Variation: $label";
  }
}

sub caption {
 my $self = shift; 
 my $caption = 'Variation: '.$self->model->object('Variation')->name;

 return $caption;
}


sub populate_tree {
  my $self = shift;

  $self->create_node('Summary', 'Summary',
    [qw(
      summary  EnsEMBL::Web::Component::Variation::VariationSummary
      flanking EnsEMBL::Web::Component::Variation::FlankingSequence
    )],
    { 'availability' => 'variation', 'concise' => 'Variation summary' }
  );
  
  $self->create_node('Mappings', 'Gene/Transcript  ([[counts::transcripts]])',
    [qw( summary EnsEMBL::Web::Component::Variation::Mappings )],
    { 'availability' => 'variation has_transcripts', 'concise' => 'Gene/Transcript' }
  );
  
  $self->create_node('Population', 'Population genetics ([[counts::populations]])',
    [qw( summary EnsEMBL::Web::Component::Variation::PopulationGenotypes )],
    { 'availability' => 'variation has_populations', 'concise' => 'Population genotypes and allele frequencies' }
  );
  
  $self->create_node('Individual', 'Individual genotypes ([[counts::individuals]])',
    [qw( summary EnsEMBL::Web::Component::Variation::IndividualGenotypes )],
    { 'availability' => 'variation has_individuals', 'concise' => 'Individual genotypes' }
  );
  
  $self->create_node('Context', 'Context',
    [qw( summary EnsEMBL::Web::Component::Variation::Context )],
    { 'availability' => 'variation', 'concise' => 'Context' }
  );
  
  $self->create_node('Phenotype', 'Phenotype Data ([[counts::ega]])',
    [qw( summary EnsEMBL::Web::Component::Variation::Phenotype )],
    { 'availability' => 'variation has_ega', 'concise' => 'Phenotype Data' }
  );
  
  $self->create_node('Compara_Alignments', 'Phylogenetic Context ([[counts::alignments]])',
    [qw(
      selector EnsEMBL::Web::Component::Compara_AlignSliceSelector
      summary  EnsEMBL::Web::Component::Variation::Compara_Alignments
    )],
    { 'availability' => 'variation database:compara has_alignments', 'concise' => 'Evolutionary or Phylogenetic Context' }
  );

  # External Data tree, including non-positional DAS sources
  my $external = $self->create_node('ExternalData', 'External Data',
    [qw( external EnsEMBL::Web::Component::Variation::ExternalData )],
    { 'availability' => 'variation' }
  );

}

sub user_populate_tree {
  my $self = shift;
  
  my $object = $self->object;
  
  return unless $object && ref $object;
  
  my $all_das    = $ENSEMBL_WEB_REGISTRY->get_all_das;
  my $vc         = $object->get_viewconfig(undef, 'ExternalData');
  my @active_das = grep { $vc->get($_) eq 'yes' && $all_das->{$_} } $vc->options;
  my $ext_node   = $self->tree->get_node('ExternalData');
  
  for my $logic_name (sort { lc($all_das->{$a}->caption) cmp lc($all_das->{$b}->caption) } @active_das) {
    my $source = $all_das->{$logic_name};
    
    $ext_node->append($self->create_subnode("ExternalData/$logic_name", $source->caption,
      [qw( textdas EnsEMBL::Web::Component::Variation::TextDAS )],
      {
        'availability' => 'variation', 
        'concise'      => $source->caption, 
        'caption'      => $source->caption, 
        'full_caption' => $source->label
      }
    ));	 
  }
}


1;
