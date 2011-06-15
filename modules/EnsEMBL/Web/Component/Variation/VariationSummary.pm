# $Id$

package EnsEMBL::Web::Component::Variation::VariationSummary;

use strict;

use Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor;

use base qw(EnsEMBL::Web::Component::Variation);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $variation    = $object->Obj;
  my $html;
 
  my $avail     = $self->object->availability;

  my ($seq_url, $gt_url, $pop_url, $geno_url, $context_url, $ld_url, $pheno_url, $phylo_url);
  $seq_url        = $hub->url({'action' => 'Sequence'});
  $context_url    = $hub->url({'action' => 'Context'});
  if ($avail->{'has_transcripts'}) {
    $gt_url   = $hub->url({'action' => 'Mappings'});
  }
  if ($avail->{'has_populations'}) {
    if ($avail->{'not_somatic'}) {
      $pop_url   = $hub->url({'action' => 'Population'});
    }
    elsif ($avail->{'is_somatic'}) {
      $pop_url  = $hub->url({'action' => 'Populations'});
    }
  }
  if ($avail->{'has_individuals'} && $avail->{'not_somatic'}) {
    $geno_url   = $hub->url({'action' => 'Individual'});
    if ($avail->{'has_ldpops'}) {
      $ld_url    = $hub->url({'action' => 'HighLD'});
    }
  }
  if ($avail->{'has_ega'}) {
    $pheno_url    = $hub->url({'action' => 'Phenotype'});
  }
  if ($avail->{'has_alignments'}) {
    $phylo_url    = $hub->url({'action' => 'Compara_Alignments'});
  }

  my @buttons = (
    {'title' => 'Sequence',             'img' => 'variation_seq',      'url' => $seq_url},
    {'title' => 'Gene/Transcript',      'img' => 'variation_gt',       'url' => $gt_url},
    {'title' => 'Population genetics',  'img' => 'variation_pop',      'url' => $pop_url},
    {'title' => 'Individual genotypes', 'img' => 'variation_geno',     'url' => $geno_url},
    {'title' => 'Genomic context',      'img' => 'variation_context',  'url' => $context_url},
    {'title' => 'Linked variations',    'img' => 'variation_ld',       'url' => $ld_url},
    {'title' => 'Phenotype data',       'img' => 'variation_pheno',    'url' => $pheno_url},
    {'title' => 'Phylogenetic context', 'img' => 'variation_phylo',    'url' => $phylo_url},
  );

  my $html = qq(
    <div class="centered">
  );
  my $i = 0;
  foreach my $button (@buttons) {
    #unless ($i > 0 && $i % 4) {
    #  $html .= qq(
    #    </div>
    #    <div class="centered">
    #  );
    #} 
    my $title = $button->{'title'};
    my $img   = $button->{'img'};
    my $url   = $button->{'url'};
    if ($url) {
      $img .= '.gif';
      $html .= qq(<a href="$url" title="$title"><img src="/img/$img" class="portal" alt="" /></a>);
    }
    else {
      $img   .= '_off.gif';
      $title .= ' (NOT AVAILABLE)';
      $html .= qq(<img src="/img/$img" class="portal" alt="" title="$title" />);
    }
    $i++;
  }
  $html .= qq(
    </div>
  );

  my $mapping_count = scalar keys %{$object->variation_feature_mapping};

  ## Add variation sets
  my $variation_sets = $object->get_formatted_variation_set_string || 'None';

  $html .= qq(<dl class="summary">
                <dt>Present in</dt>
                <dd>$variation_sets</dd>
              </dl>);

  # skip if somatic mutation with mutation ref base different to ensembl ref base
  if (!$object->is_somatic_with_different_ref_base && $mapping_count) {
    my $hgvs = $self->_hgvs_names;

    $html .= qq(<dl class="summary">
                <dt>HGVS names</dt>
                <dd>$hgvs</dd>
              </dl>);
  }

  if (!$variation->is_somatic && $mapping_count) {
    my $ld_data = $self->_ld_data;

    $html .= qq(<dl class="summary">
                <dt>Linkage disequilibrium data</dt>
                <dd>$ld_data</dd>
              </dl>);
  }

  return $html;
}

sub _hgvs_names {
  my $self = shift;
  my $object    = $self->object;
  my $hub       = $self->hub;
  my $variation = $object->Obj;
  my $html;
  
  my %mappings = %{$object->variation_feature_mapping};
  my $loc;

  if (keys %mappings == 1) {
    ($loc) = values %mappings;
  } 
  else {
    $loc = $mappings{$hub->param('vf')};
  }

  # get vf object
  my $vf;

  foreach (@{$variation->get_all_VariationFeatures}) {
    $vf = $_ if $_->seq_region_start == $loc->{'start'} && $_->seq_region_end == $loc->{'end'} && $_->seq_region_name eq $loc->{'Chr'};
  }

  if (defined $vf) {
    my (%cdna_hgvs, %pep_hgvs, %by_allele, $prev_trans);
#
#    # check if overlaps LRG
#    if($hub->param('lrg') =~ /^LRG/) {
#      my $proj = $vf->project('LRG');
#
#      if(scalar @$proj == 1) {
#        my $lrg_slice = $proj->[0]->to_Slice();
#        if($lrg_slice) {
#          my $lrg_vf = $vf->transfer($lrg_slice);
#
#          foreach my $transcript(@{$lrg_vf->feature_Slice->get_all_Transcripts}) {
#            # get HGVS notations
#            %cdna_hgvs = %{$lrg_vf->get_all_hgvs_notations($transcript, 'c')};
#            %pep_hgvs  = %{$lrg_vf->get_all_hgvs_notations($transcript, 'p')};
#
#            # filter peptide ones for synonymous changes
#            map { delete $pep_hgvs{$_} if $pep_hgvs{$_} =~ /p\.\=/ } keys %pep_hgvs;
#
#            # group by allele
#            push @{$by_allele{$_}}, $cdna_hgvs{$_} for keys %cdna_hgvs;
#            push @{$by_allele{$_}}, $pep_hgvs{$_}  for keys %pep_hgvs;
#          }
#        }
#      }
#    }

    # now get normal ones
    # go via transcript variations (should be faster than slice)
    foreach my $tv (@{$vf->get_all_TranscriptVariations}) {
      next unless defined $tv->{'_transcript_stable_id'};
      next if $tv->{'_transcript_stable_id'} eq $prev_trans;
      $prev_trans = $tv->{'_transcript_stable_id'};
      my $transcript = $tv->transcript;

      # get HGVS notations
      %cdna_hgvs = %{$vf->get_all_hgvs_notations($transcript, 'c')};
      %pep_hgvs  = %{$vf->get_all_hgvs_notations($transcript, 'p')};

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

        $h =~ s/(LRG_\d+)(_)?([t|p]\d+)?(.*)/'<a href="'.$hub->url({
            type => 'LRG',
            action => 'Variation_LRG',
            db     => 'core',
            r      => undef,
            lrgt   => "$1$2$3",
            lrg    => $1,
            v      => $object->name,
            source => $variation->source}).'">'.$&.'<\/a>'/eg;

        $h =~ s/ENS(...)?T\d+(\.\d+)?/'<a href="'.$hub->url({
            type => 'Transcript',
            action => $hub->species_defs->databases->{'DATABASE_VARIATION'}->{'#STRAINS'} > 0 ? 'Population' : 'Summary',
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

    $html = join '<br/>', @temp;

    $html = join '<br/>', @temp;

    $html ||= 'None';
  }
  return $html;
}

sub _ld_data {
  my $self = shift;
  my $hub          = $self->hub;
  my $object       = $self->object;
  my $species_defs = $hub->species_defs;
  my $variation    = $object->Obj;
  my $html;

  ## set path information for LD calculations
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::BINARY_FILE = $species_defs->ENSEMBL_CALC_GENOTYPES_FILE;
  $Bio::EnsEMBL::Variation::DBSQL::LDFeatureContainerAdaptor::TMP_PATH    = $species_defs->ENSEMBL_TMP_TMP;


   ## First check that a location has been selected:
  if ($self->builder->object('Location')) {
    if ($species_defs->databases->{'DATABASE_VARIATION'}{'DEFAULT_LD_POP'}) {

      my $pop_ids = $object->ld_pops_for_snp || [];

      my %pop_names = {};

      foreach (@$pop_ids) {
        my $pop_obj = $object->pop_obj_from_id($_);
        $pop_names{$pop_obj->{$_}{'Name'}} = 1;
      }
      my %tag_data  = %{$object->tagged_snp || {}};
      my %ld        = (%pop_names, %tag_data);
      if  (keys %ld) {
        my $count  = 0;

        $html = '<table width="100%" border="0">
            <tr>';

        for my $name (sort { $a cmp $b } keys %pop_names) {
          my $tag = $pop_names{$name} eq 1 ? '' : ' (Tag SNP)';
          ## reset r param based on variation feature location and a default context of 20 kb
          my $r   = $object->ld_location; 
          my $url = $hub->url({ type => 'Location', action => 'LD', r => $r, v => $object->name, vf => $hub->param('vf'), pop1 => $name , focus => 'variation' });

          $html .= "<td><a href=$url>$name</a>$tag</td>\n";
          $count++;

          if ($count == 3) {
            $count   = 0;
            $html .= '</tr><tr>';
          }
        }
 
        $html .= '</tr>
            </table>';

      } 
      else {
        $html = 'No linkage data for this variant';
      }      
    } 
    else {
      $html = 'No linkage data available for this species';
    }
  } 
  else { ## If no location selected direct the user to pick one from the summary panel 
     $html = 'You must select a location from the panel above to see Linkage disequilibrium data';
  }
  return $html;
}


1;
