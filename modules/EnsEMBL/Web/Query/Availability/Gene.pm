=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Query::Availability::Gene;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::Availability);

our $VERSION = 1;

sub precache {
  return {
    'av-gene' => {
      loop => ['species','genes'],
      args => {
        type => "core",
      }
    },
  }
}

sub fixup {
  my ($self) = @_;

  $self->fixup_gene('gene','species','type');
  $self->SUPER::fixup();
}

sub _count_go {
  my ($self,$args,$out) = @_;

  my $go_name;
  foreach my $transcript (@{$args->{'gene'}->get_all_Transcripts}) {
    my $dbc = $self->database_dbc($args->{'species'},$args->{'type'});
    my $tl_dbID = $transcript->translation ? $transcript->translation->dbID : undef;

    # First get the available ontologies
    my $ontologies = $self->sd_config($args,'SPECIES_ONTOLOGIES');
    if(@{$ontologies||[]}) {
      my $ontologies_list = sprintf(" in ('%s') ",join("','",@$ontologies));
      $ontologies_list = " ='$ontologies->[0]'" if @$ontologies == 1;

      my $sql = qq{
        SELECT distinct(dbprimary_acc)
            FROM object_xref ox, xref x, external_db edb
            WHERE ox.xref_id = x.xref_id
            AND x.external_db_id = edb.external_db_id
            AND edb.db_name $ontologies_list
            AND ((ox.ensembl_object_type = 'Translation' AND ox.ensembl_id = ?)
            OR   (ox.ensembl_object_type = 'Transcript'  AND ox.ensembl_id = ?))};

      # Count the ontology terms mapped to the translation
      my $sth = $dbc->prepare($sql);
      $sth->execute($tl_dbID, $transcript->dbID);
      foreach ( @{$sth->fetchall_arrayref} ) {
        $go_name .= '"'.$_->[0].'",';
      }
    }
  }
  return unless $go_name;
  $go_name =~ s/,$//g;

  my $goadaptor = $self->database_dbc($args->{'species'},'go');

  my $go_sql = qq{SELECT o.ontology_id,COUNT(*) FROM term t1  JOIN closure ON (t1.term_id=closure.child_term_id)  JOIN term t2 ON (closure.parent_term_id=t2.term_id) JOIN ontology o ON (t1.ontology_id=o.ontology_id)  WHERE t1.accession IN ($go_name)  AND t2.is_root=1  AND t1.ontology_id=t2.ontology_id GROUP BY o.namespace};

  my $sth = $goadaptor->prepare($go_sql);
  $sth->execute();

  my %clusters = $self->multiX('ONTOLOGIES');
  $out->{"has_go_$_"} = 0 for(keys %clusters);

  foreach (@{$sth->fetchall_arrayref}) {
    my $goid = $_->[0];
    if ( exists $clusters{$goid} ) {
      $out->{"has_go_$goid"} = $_->[1];
    }
  }
}

sub _count_xrefs {
  my ($self,$args) = @_;

  my $dbc = $self->database_dbc($args->{'species'},$args->{'type'});
  # xrefs on the gene
  my $xrefs_c = 0;
  my $sql = '
    SELECT x.display_label, edb.db_name, edb.status
      FROM gene g, object_xref ox, xref x, external_db edb
     WHERE g.gene_id = ox.ensembl_id
       AND ox.xref_id = x.xref_id
       AND x.external_db_id = edb.external_db_id
       AND ox.ensembl_object_type = "Gene"
       AND g.gene_id = ?';

  my $sth = $dbc->prepare($sql);
  $sth->execute($args->{'gene'}->dbID);
  while (my ($label,$db_name,$status) = $sth->fetchrow_array) {
    #these filters are taken directly from Component::_sort_similarity_links
    #code duplication needs removing, and some of these may well not be needed any more
    next if ($status eq 'ORTH');                        # remove all orthologs
    next if (lc($db_name) eq 'medline');                # ditch medline entries - redundant as we also have pubmed
    next if ($db_name =~ /^flybase/i && $args->{'type'} =~ /^CG/ ); # Ditch celera genes from FlyBase
    next if ($db_name eq 'Vega_gene');                  # remove internal links to self and transcripts
    next if ($db_name eq 'Vega_transcript');
    next if ($db_name eq 'Vega_translation');
    next if ($db_name eq 'GO');
    next if ($db_name eq 'OTTP') && $label =~ /^\d+$/; #ignore xrefs to vega translation_ids
    next if ($db_name =~ /ENSG|OTTG/);
    $xrefs_c++;
  }
  return $xrefs_c;
}

sub _get_xref_available {
  my ($self,$args) = @_;

  return 1 if $self->_count_xrefs($args) > 0;
  my @transcripts = @{$args->{'gene'}->get_all_Transcripts};
  foreach my $transcript (@transcripts) {
    my $db_links;
    eval { $db_links = $transcript->get_all_DBLinks; };
    foreach my $link (@{$db_links||[]}) {
      return 1 if $link->type eq 'MISC';
      return 1 if $link->type eq 'LIT';
    }
  }
  return 0;
}

sub _get_phenotype {
  my ($self,$args) = @_;

  my $pfa = $self->phenotype_feature_adaptor($args);
  my $phen_count = $pfa->count_all_by_Gene($args->{'gene'});
  return $phen_count if $phen_count;
  return 0;
}

sub _get_alt_alleles {
  my ($self,$args) = @_;

  if($args->{'gene'}->slice->is_reference) {
    return $args->{'gene'}->get_all_alt_alleles;
  } else {
    my $aaga = $self->alt_allele_group_adaptor($args);
    my $group = $aaga->fetch_by_gene_id($args->{'gene'}->dbID);
    return [] unless $group;
    my $stable_id = $args->{'gene'}->stable_id;
    return [grep { $_->stable_id ne $stable_id } @{$group->get_all_Genes}];
  }
}

sub _count_alignments {
  my ($self,$args) = @_;

  my $c = { all => 0, pairwise => 0, multi => 0, patch => 0 };
  my %alignments = $self->sd_multi($args,'DATABASE_COMPARA','ALIGNMENTS');
  my $species = $self->sd_config($args,"SPECIES_PRODUCTION_NAME");
  foreach (grep $_->{'species'}{$species}, values %alignments) {
    $c->{'all'}++ ;
    $c->{'pairwise'}++ if $_->{'class'} =~ /pairwise_alignment/ && scalar keys %{$_->{'species'}} == 2;
    $c->{'multi'}++    if $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species};
  }
  return $c;
}

sub _counts {
  my ($self,$args,$member,$panmember) = @_;

  my $out = {
    transcripts => scalar @{$args->{'gene'}->get_all_Transcripts},
    exons => scalar @{$args->{'gene'}->get_all_Exons},
    similarity_matches => $self->_get_xref_available($args),
    operons => 0,
    alt_alleles => scalar @{$self->_get_alt_alleles($args)},
  };
  if($args->{'gene'}->feature_Slice->can('get_all_Operons')) {
    $out->{'operons'} = scalar @{$args->{'gene'}->feature_Slice->get_all_Operons};
  }
  $out->{'structural_variation'} = 0;
  if($self->variation_db_adaptor($args)) {
    $out->{'structural_variation'} =
      $self->table_info($args,'structural_variation','variation')->{'rows'};
    $out->{'phenotpyes'} = $self->_get_phenotype($args);
  }
  if($member) {
    $out->{'orthologs'} = $member->number_of_orthologues;

    $out->{'strain_orthologs'} =  $self->sd_config($args,'RELATED_TAXON') ? $member->number_of_orthologues($self->sd_config($args,'RELATED_TAXON')) : 0;
    $out->{'paralogs'} = $member->number_of_paralogues;
    $out->{'strain_paralogs'} =  $self->sd_config($args,'RELATED_TAXON') ? $member->number_of_paralogues($self->sd_config($args,'RELATED_TAXON')) : 0;
    $out->{'families'} = $member->number_of_families;
  }
  my $alignments = $self->_count_alignments($args);
  $out->{'alignments'} = $alignments->{'all'} if $args->{'type'} eq 'core';
  $out->{'pairwise_alignments'} =
    $alignments->{'pairwise'} + $alignments->{'patch'};
  if($panmember) {
    $out->{'orthologs_pan'} = $panmember->number_of_orthologues;
    $out->{'paralogs_pan'} = $panmember->number_of_paralogues;
    $out->{'families_pan'} = $panmember->number_of_families;
  }

  return $out;
}

sub get {
  my ($self,$args) = @_;

  my $ad = $self->source('Adaptors');
  my $out = $self->super_availability($args);

  my $member = $self->compara_member($args) if $out->{'database:compara'};
  my $panmember = $self->pancompara_member($args) if $out->{'database:compara_pan_ensembl'};
  my $counts = $self->_counts($args,$member,$panmember);

  $out->{'counts'} = $counts;
  $out->{'history'} =
    0+!!($self->table_info($args,'stable_id_event')->{'rows'});
  $out->{'gene'} = 1;
  $out->{'core'} = $args->{'type'} eq 'core';
  $out->{'has_gene_tree'} = $member ? $member->has_GeneTree : 0;
  $out->{'can_r2r'} = $self->sd_config($args,'R2R_BIN');
  if($self->sd_config($args,'RELATED_TAXON')) { #gene tree availability check for strain
    $out->{'has_strain_gene_tree'} = $member ? $member->has_GeneTree($self->sd_config($args,'RELATED_TAXON')) : 0; #TODO: replace hardcoded species
  }  

  if($out->{'can_r2r'}) {
    my $canon = $args->{'gene'}->canonical_transcript;
    $out->{'has_2ndary'} = 0;
    $out->{'has_2ndary_cons'} = 0;
    if($canon and @{$canon->get_all_Attributes('ncRNA')}) {
      $out->{'has_2ndary'} = 1;
    }
    if($out->{'has_gene_tree'}) {
      my $tree = $self->default_gene_tree($args,$member);
      if($tree and $tree->get_tagvalue('ss_cons')) {
        $out->{'has_2ndary_cons'} = 1;
        $out->{'has_2ndary'} = 1;
      }
    }
  }
  $out->{'alt_allele'} = $self->table_info($args,'alt_allele')->{'rows'};
  if($self->regulation_db_adaptor($args)) {
    $out->{'regulation'} =
      0+!!($self->table_info($args,'feature_set','funcgen')->{'rows'});
  }
  $out->{'regulation'} ||= '';
  $out->{'has_species_tree'} = $member ? $member->has_GeneGainLossTree : 0;
  $out->{'family'} = !!$counts->{'families'};
  $out->{'family_count'} = $counts->{'families'};
  $out->{'not_rnaseq'} = $args->{'type'} ne 'rnaseq';
  for (qw(
    transcripts alignments paralogs strain_paralogs orthologs strain_orthologs similarity_matches
    operons structural_variation pairwise_alignments
  )) {
    $out->{"has_$_"} = $counts->{$_};
  }

  $self->_count_go($args, $out);
  $out->{'multiple_transcripts'} = ($counts->{'transcripts'}>1);
  $out->{'not_patch'} = 0+!($args->{'gene'}->stable_id =~ /^ASMPATCH/);
  $out->{'has_alt_alleles'} = 0+!!(@{$self->_get_alt_alleles($args)});
  $out->{'not_human'} = 0+($args->{'species'} ne 'Homo_sapiens');
  if($self->variation_db_adaptor($args)) {
    $out->{'has_phenotypes'} = $self->_get_phenotype($args);
  }
  if($out->{'database:compara_pan_ensembl'} && $self->pancompara_db_adaptor) {
    $out->{'family_pan_ensembl'} = !!$counts->{'families_pan'};
    $out->{'has_gene_tree_pan'} =
      $panmember ? $panmember->has_GeneTree : 0;
    for (qw(alignments_pan paralogs_pan orthologs_pan)) {
      $out->{"has_$_"} = $counts->{$_};
    }
  }

  return [$out];
}

1;
