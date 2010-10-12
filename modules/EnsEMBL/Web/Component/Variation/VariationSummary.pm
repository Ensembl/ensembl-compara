# $Id$

package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $variation    = $object->Obj;
  my $html;
 
  ## first check we have a location
  my $unique = $object->not_unique_location;
  
  if($unique =~ /select/) {
    return $self->_info('A unique location can not be determined for this Variation', $unique);
  }
  
  ## count locations
  my $mapping_count = scalar keys %{$object->variation_feature_mapping};
  
  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH    = $species_defs->ENSEMBL_TMP_TMP;

  ## Add validation status
  my $stat;
  my @status = @{$object->status};
  
  if (@status) {
    my $snp_name = $object->name;
    
    my (@status_list, $hapmap_html);
    
    foreach my $status (@status) {
      if ($status eq 'hapmap') {
        $hapmap_html = "<b>HapMap variant</b>", $hub->get_ExtURL_link($snp_name, 'HAPMAP', $snp_name);
      } elsif ($status eq 'failed') {
        my $description = $variation->failed_description;
        return $status;
      } else {
        $status = "frequency" if $status eq 'freq';
        push @status_list, $status;
      }
    }
    
    $stat = join ', ', @status_list;
    
    if ($stat) {
      if ($stat eq 'observed' or $stat eq 'non-polymorphic') {
        $html = '<b>'.ucfirst($stat).'</b> ';
      } else {
        $stat = "Proven by <b>$stat</b> ";
      }
      $stat .= ' (<i>Feature tested and validated by a non-computational method</i>).<br /> ';
    }
    
    $stat .= $hapmap_html;
  } else { 
   $stat = 'Unknown';
  }
  
  $stat = 'Undefined' unless $stat =~ /^\w/;
  
  $html .= qq(
       <dl class="summary">
      <dt>Validation status</dt>
      <dd> $stat</dd>);
  
  ## HGVS NOTATIONS
  # skip if somatic mutation with mutation ref base different to ensembl ref base
  if (!$object->is_somatic_with_different_ref_base && $mapping_count) {
    my $sa = $variation->adaptor->db->dnadb->get_SliceAdaptor;
  
    my %mappings = %{$object->variation_feature_mapping}; 
    my $loc;
    
    if (keys %mappings == 1) {
      ($loc) = values %mappings;
    } else { 
      $loc = $mappings{$hub->param('vf')};
    }
  
    if (defined $sa) {
      # get vf object
      my $vf;
    
      foreach (@{$variation->get_all_VariationFeatures}) {
        $vf = $_ if $_->seq_region_start == $loc->{'start'} && $_->seq_region_end == $loc->{'end'} && $_->seq_region_name eq $loc->{'Chr'};
      }
    
      if (defined $vf) {
        my (%cdna_hgvs, %pep_hgvs, %by_allele, $hgvs_html, $prev_trans);
      
        # go via transcript variations (should be faster than slice)
        foreach my $tv (@{$vf->get_all_TranscriptVariations}) {
          next unless defined $tv->{'_transcript_stable_id'};
          next if $tv->{'_transcript_stable_id'} eq $prev_trans;
          
          $prev_trans = $tv->{'_transcript_stable_id'};
        
          # get HGVS notations
          %cdna_hgvs = %{$vf->get_all_hgvs_notations($tv->transcript, 'c')};
          %pep_hgvs  = %{$vf->get_all_hgvs_notations($tv->transcript, 'p')};
        
          # filter peptide ones for synonymous changes
          map { delete $pep_hgvs{$_} if $pep_hgvs{$_} =~ /p\.\=/ } keys %pep_hgvs;
        
          # group by allele
          push @{$by_allele{$_}}, $cdna_hgvs{$_} for keys %cdna_hgvs;
          push @{$by_allele{$_}}, $pep_hgvs{$_}  for keys %pep_hgvs;
        }
        
        # count alleles
        my $allele_count = scalar keys %by_allele;
      
        # make HTML
        my @temp;
        
        foreach my $a(keys %by_allele) {
          push @temp, (scalar @temp ? '<br/>' : '') . "<b>Variant allele $a</b>" if $allele_count > 1;
        
          foreach my $h (@{$by_allele{$a}}) {
            $h =~ s/ENS(...)?T\d+(\.\d+)?/'<a href="'.$hub->url({
              type => 'Transcript',
              action => $species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
              db     => 'core',
              r      => undef,
              t      => $&,
              v      => $object->name,
              source => $variation->source}).'">'.$&.'<\/a>'/eg;
      
            $h =~ s/ENS(...)?P\d+(\.\d+)?/'<a href="'.$hub->url({
              type => 'Transcript',
              action => 'ProtVariations',
              db     => 'core',
              r      => undef,
              p      => $&,
              v      => $object->name,
              source => $variation->source}).'">'.$&.'<\/a>'/eg;
          
            push @temp, $h;
          }
        }
      
        $hgvs_html = join '<br/>', @temp;
      
        $hgvs_html ||= "<h5>None</h5>";
      
        $html .= qq{<dl class="summary"><dt>HGVS names</dt><dd>$hgvs_html</dd></dl>};
      }
    }
  }

  if (!$variation->is_somatic && $mapping_count) {
    ## Add LD data  
    my $ld_html;
    my $label = 'Linkage disequilibrium data';

     ## First check that a location has been selected:
    if ($self->builder->object('Location')) { 
      if  ($species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}) {
        my %pop_names = %{$self->ld_populations($object) || {}};
        my %tag_data  = %{$object->tagged_snp || {}};
        my %ld        = (%pop_names, %tag_data);
        if  (keys %ld) {
          $ld_html = $self->link_to_ldview($object, \%ld); 
        } else {
          $ld_html = '<h5>No linkage data for this variant</h5>';
        }  
      } else {
        $ld_html = '<h5>No linkage data available for this species</h5>';
      }
    } else { ## If no location selected direct the user to pick one from the summary panel 
       $ld_html = 'You must select a location from the panel above to see Linkage disequilibrium data';
    }
    
    $html .= "<dt>$label</dt><dd>$ld_html</dd></dl>";
  }
  
  return $html;
}

sub link_to_ldview {
  ### LD
  ### Arg1        : hash ref of population data
  ### Example     : $self->link_to_ldview(\%pop_data);
  ### Description : Make links from these populations to LDView
  ### Returns  Table of HTML links to LDView

  my ($self, $pops) = @_;
  my $hub    = $self->hub;
  my $object = $self->object;
  my $count  = 0;
  
  my $output = '
    <table width="100%" border="0">
      <tr><td><b>Links to Linkage disequilibrium data per population:</b></td></tr>
      <tr>
  ';
  
  for my $pop_name (sort { $a cmp $b } keys %$pops) {
    my $tag = $pops->{$pop_name} eq 1 ? '' : ' (Tag SNP)';
    my $r   = $object->ld_location; # reset r param based on variation feature location and a default context of 20 kb
    my $url = $hub->url({ type => 'Location', action => 'LD', r => $r, v => $object->name, vf => $hub->param('vf'), pop1 => $pop_name , focus => 'variation' });
    
    $output .= "<td><a href=$url>$pop_name</a>$tag</td>";  
    $count++;
     
    if ($count == 3) {
      $count   = 0;
      $output .= '</tr><tr>';
    }
  }
  
  $output .= '
      </tr>
    </table>
  ';
  
  return $output;

}

sub ld_populations {
  ### LD
  ### Description : data structure with population id and name of pops
  ### with LD info for this SNP
  ### Returns  hashref

  my $self    = shift;
  my $object  = $self->object;
  my $pop_ids = $object->ld_pops_for_snp;
  
  return {} unless @$pop_ids;

  my %pops;
  
  foreach (@$pop_ids) {
    my $pop_obj = $object->pop_obj_from_id($_);
    $pops{$pop_obj->{$_}{'Name'}} = 1;
  }
  
  return \%pops;
}

1;
