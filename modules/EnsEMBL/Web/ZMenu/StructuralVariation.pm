package EnsEMBL::Web::ZMenu::StructuralVariation;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift; 
  my $hub  = $self->hub;
  my $v_id = $hub->param('sv');
  
  return unless $v_id;
  
  my $db_adaptor      = $hub->database('variation');
  my $var_adaptor     = $db_adaptor->get_StructuralVariation;
  my $variation       = $var_adaptor->fetch_by_name($v_id); 
  my $svf_adaptor     = $db_adaptor->get_StructuralVariationFeatureAdaptor;
  my $svf             = $svf_adaptor->fetch_all_by_StructuralVariation($variation);
  my $max_length      = ($hub->species_defs->ENSEMBL_GENOME_SIZE || 1) * 1e6; 
  my $class            = $variation->var_class;
  my $vstatus         = $variation->get_all_validation_states;
  my $pubmed_link     = '';
  my $location_link;
  my $feature;
  my $study_name;
  my $description;
  my $study_url;
  my $study = $variation->study;
  
  if (defined($study)) {
    $study_name   = $study->name;
    $description = $study->description;
    $study_url   = $study->url; 
  }

  if (scalar @$svf == 1) {
    $feature = $svf->[0];
  } else {
    foreach (@$svf) {
      $feature = $_ if $_->dbID eq $hub->param('svf');
    }
  }
  
  my $start      = $feature->start;
  my $end        = $feature->end;
  my $seq_region = $feature->seq_region_name;
  my $position   = "$seq_region:$start";
  my $length     = $end - $start;
  
  if ($end < $start) {
    $position = "$seq_region: between $end &amp; $start";
  } elsif ($end > $start) {
    $position = "$seq_region:$start-$end";
  }
  
  if (! $description) {
    $description = $variation->source_description;
  }
  
  if ($length > $max_length) {  
    $location_link = $hub->url({
      type     => 'Location',
      action   => 'Overview',
      r        => $seq_region . ':' . $start . '-' . $end,
      cytoview => 'variation_feature_structural=normal',
    });
  } else {
    $location_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $seq_region . ':' . $start . '-' . $end,
    });
  }
  
  if ($description =~/PMID/) {
    my @description_string = split (':', $description);
    my $pubmed_id = pop @description_string;
    $pubmed_id =~ s/\s+.+//g;
    $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);  
  }    

  my $ssvs   = $self->object->supporting_sv;
  my @allele_types;
  foreach my $ssv (@$ssvs) {
    my $a_type = $ssv->var_class;
    
    next if (grep {$a_type eq $_} @allele_types);
    push @allele_types, $a_type;
  }
  @allele_types = sort(@allele_types);

  my $sv_caption = 'Structural variation: ';
  if ($class eq 'CNV_PROBE') {
    $sv_caption = 'CNV probe: ';
  }
  $self->caption($sv_caption . $v_id);

  $self->add_entry({
    label_html => $v_id.' properties',
    link       => $hub->url({
      type     => 'StructuralVariation',
      action   => 'Summary',
      sv       => $v_id,
    })
  });

  $self->add_entry({
    type  => 'Source',
    label => $variation->source,
  });
  
  
  if (defined($study_name)) {
    $self->add_entry({
      type  => 'Study',
      label => $study_name,
      link  => $study_url, 
    });
  }

  $self->add_entry({
    type  => 'Description',
    label => $description,
    link  => $pubmed_link, 
  });

  $self->add_entry({
    type  => 'Class',
    label => $class,
  });

  if (scalar(@allele_types)) {
    my $s = (scalar(@allele_types) > 1) ? 's' : '';
    $self->add_entry({
      type  => "Allele type$s",
      label => join(', ',@allele_types),
    });
  }

  if (scalar(@$vstatus) and $vstatus->[0]) {
    $self->add_entry({
      type  => 'Validation',
      label => join(',',@$vstatus),
    });    
  }

  $self->add_entry({
    type  => 'Location',
    label => $position,
    link  => $location_link,
  });
}
1;
