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

package EnsEMBL::Web::Object;

### NAME: EnsEMBL::Web::Object
### Base class - wrapper around a Bio::EnsEMBL API object  

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION
### All Ensembl web data objects are derived from this class

use strict;

use HTML::Entities  qw(encode_entities);

use EnsEMBL::Web::DBSQL::ArchiveAdaptor;
use HTML::Entities  qw(encode_entities);
use List::Util qw(min max);

use base qw(EnsEMBL::Web::Root);

sub new {
  my ($class, $data) = @_;
  my $self = { data => $data };
  bless $self, $class;
  return $self; 
}

sub counts            { return {};        }
sub _counts           { return {};        } # Implemented in plugins
sub availability      { return {};        }
sub implausibility    { return {};        }
sub can_export        { return 0;         }
sub default_action    { return 'Summary'; }
sub __data            { return $_[0]{'data'};                  }
sub __objecttype      { return $_[0]{'data'}{'_objecttype'};   }
sub Obj               { return $_[0]{'data'}{'_object'};       } # Gets the underlying Ensembl object wrapped by the web object
sub hub               { return $_[0]{'data'}{'_hub'};          }

sub caption           { return ''; }
sub short_caption     { return ''; }

sub species           { return $_[0]->hub->species;               }
sub type              { return $_[0]->hub->type;                  }
sub action            { return $_[0]->hub->action;                }
sub function          { return $_[0]->hub->function;              }
sub script            { return $_[0]->hub->script;                }
sub species_defs      { return shift->hub->species_defs(@_);      }
sub species_path      { return shift->hub->species_path(@_);      }
sub problem           { return shift->hub->problem(@_);           }
sub param             { return shift->hub->param(@_);             }
sub user              { return shift->hub->user(@_);              }
sub database          { return shift->hub->database(@_);          }
sub get_adaptor       { return shift->hub->get_adaptor(@_);       }
sub table_info        { return shift->hub->table_info(@_);        }
sub data_species      { return shift->hub->data_species(@_);      }
sub get_imageconfig   { return shift->hub->get_imageconfig(@_);   }
sub get_db            { return shift->hub->get_db(@_);            }

sub _availability { 
  my $self = shift;
  
  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$self->species_defs->databases} };
  map { my $key =lc(substr($_,9)); $hash->{"database:$key"} = 1} @{$self->species_defs->compara_like_databases || [] };
  $hash->{'logged_in'} = 1 if $self->user;
  
  return $hash;
}

sub command {
  ## Command object attached to data object
  my $self = shift;
  $self->{'command'} = shift if (@_);
  return $self->{'command'};
}

sub highlights {
  ## The highlights array is passed between web-requests to highlight selected items (e.g. Gene around
  ## which contigview had been rendered). If any data is passed this is stored in the highlights array
  ## @return Arrayref of (unique) elements
  my $self = shift;
  
  if (!exists( $self->{'data'}{'_highlights'})) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } grep $_, map { split /\|/, $_ } $self->param('h'), $self->param('highlights');
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  if (@_) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } @{$self->{'data'}{'_highlights'}||[]}, map { split /\|/, $_ } @_;
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  return $self->{'data'}{'_highlights'};
}

sub highlights_string { 
  ## Returns the highlights area as a | separated list for passing in URLs.
  ## @return Array
  return join '|', @{$_[0]->highlights}; 
} 

sub seq_region_type_and_name {
  ## Returns the type/name of seq_region in human readable form (first letter capitalised).
  ## If the coord system type is part of the name this is dropped.
  ## @return String or Undef
  my $self = shift;
  
  if (!$self->can('seq_region_name')) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  
  my $coord = ucfirst($self->seq_region_type);
  my $name  = $self->seq_region_name;
  
  if ($name =~ /^$coord/i) {
    return $name;
  } else {
    return "$coord $name";
  }
}

sub get_cv_terms {
  my $self = shift;
  my @cv_terms = map { $_->value } @{ $self->Obj->get_all_Attributes('havana_cv') };
  return \@cv_terms;
}


sub gene_description {
  my $self = shift;
  my $gene = shift || $self->gene;
  my %description_by_type = ('bacterial_contaminant' => 'Probable bacterial contaminant');
  
  if ($gene) {
    my $desc = $gene->description || $description_by_type{$gene->biotype} || 'No description';
    return encode_entities($desc);
  } else {
    return 'No description';
  }
}

sub slice {
  my $self = shift;
  return 1 unless $self->Obj->can('feature_Slice');
  my $slice = $self->Obj->feature_Slice;
  my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
  return $flank5 || $flank3 ? $slice->expand($flank5, $flank3) : $slice;
}

sub get_slice_display_name {
  ## get full name of seq-region from which the alignment comes
  my ($self, $name) = @_;
  return $self->hub->species_defs->get_config($name, 'SPECIES_DISPLAY_NAME') || 'Ancestral sequences';
}

sub long_caption {
  my ($self, $versioned) = @_;
  
  my $dxr   = $self->Obj->can('display_xref') ? $self->Obj->display_xref : undef;
  my $label = $dxr ? ' (' . $dxr->display_id . ')' : '';

  my $name  = $self->stable_id;
  if ($versioned && $self->Obj->version) {
    $name .= '.'.$self->Obj->version;
  }
  return $name . $label;
}

sub get_earliest_archive { 
  ## Method required for ID history views, applies to several web objects
  my $self = shift;
  
  my $adaptor = EnsEMBL::Web::DBSQL::ArchiveAdaptor->new($self->hub);
  my $releases = $adaptor->fetch_releases();
  foreach my $r (@$releases){ 
    return $r->{'id'} if $r->{'online'} eq 'Y';
  }
}

sub rose_manager {
  ## Returns the ORM::Rose::Manager class for the given type
  ## @param DB name
  ## @param Manager type
  ## @return Manager Class (Static class reference) or defaults to ORM::EnsEMBL::Rose::Manager if no manager class found
  my ($self, $db, $type) = @_;

  $db   ||= '';
  $type   = $type ? "::$type" : '';

  return $self->{'_rose_managers'}{$db}{$type} ||= $self->dynamic_use_fallback($db ? "ORM::EnsEMBL::DB::${db}::Manager${type}" : (), 'ORM::EnsEMBL::Rose::Manager');
}

=head2 get_alt_alleles

 Example     : my ($stable_id,$alleles) = $gene->get_allele_info
 Description : retrieves stable id and details of alt_alleles
 Return type : list (stable_id string and arrayref of B::E::Genes)

=cut

sub get_alt_alleles {
  my $self = shift;
  my $gene = $self->type eq 'Gene' ? $self->Obj : $self->gene;
  return [] unless $gene; # eg GENSCAN is type Transcript, ->gene is undef
  my $stable_id = $gene->stable_id;
  my $alleles = [];
  if ($gene->slice->is_reference) {
    $alleles = $gene->get_all_alt_alleles;
  }
  else {
    my $adaptor = $self->hub->get_adaptor('get_AltAlleleGroupAdaptor');
    my $group = $adaptor->fetch_by_gene_id($gene->dbID);
    if ($group) {
      foreach my $alt_allele_gene (@{$group->get_all_Genes}) {
        if ($alt_allele_gene->stable_id ne $stable_id) {
          push @$alleles, $alt_allele_gene;
        }
      }
    }
  }
  return $alleles;
}

sub get_alt_allele_link {
  my ($self, $type) = @_;
  my $hub   = $self->hub;

  my @alt_alleles = @{$self->get_alt_alleles};
  return unless scalar @alt_alleles;

  my $alt_link;
  ## Are we on the reference or haplotype?
  my ($reference) = grep { $self->slice->seq_region_name eq $_ } @{$hub->species_defs->ENSEMBL_CHROMOSOMES||[]};
  if ($reference) {
    ## Link to Alt Allele page, since there could be several
    $alt_link = sprintf('View <a href="%s">alleles</a> of this gene on alternative sequences',
                                  $hub->url({'type' => 'Gene','action' => 'Alleles'}));
  }
  else {
    ## Link to reference gene
    my $ref_gene;
    foreach my $gene (@alt_alleles) {
      if (grep { $gene->seq_region_name eq $_ } @{$hub->species_defs->ENSEMBL_CHROMOSOMES||[]}) {
        $ref_gene = $gene;
        last;
      }
    }
    if ($ref_gene) {
      my $ref_location = sprintf('%s:%s-%s', $ref_gene->seq_region_name, $ref_gene->seq_region_start, $ref_gene->seq_region_end);
      my $params = {'type' => 'Gene', 'g' => $ref_gene->stable_id, 'r' => $ref_location };
      $params->{'action'} = 'Summary' if $type eq 'Location';
      $alt_link = sprintf('View this gene on the <a href="%s">primary assembly</a>.', $hub->url($params));
    }
  }
  return $alt_link;
}


## Compara data-munging methods - not tied to a specific web data object type?

sub count_alignments {
  my $self       = shift;
  my $cdb        = shift || 'DATABASE_COMPARA';
  my $species    = $self->species_defs->get_config($self->species,"SPECIES_PRODUCTION_NAME");
  my %alignments = $self->species_defs->multi($cdb, 'ALIGNMENTS');
  my $c          = { all => 0, pairwise => 0, multi => 0 };

  foreach (grep $_->{'species'}{$species}, values %alignments) {
    $c->{'all'}++ ;
    $c->{'pairwise'}++ if $_->{'class'} =~ /pairwise_alignment/ && scalar keys %{$_->{'species'}} == 2;
    $c->{'multi'}++    if $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species};
  }

  return $c;
}

sub check_for_align_in_database {
    ## Check if alignment exists in the database
    my ($self, $align, $species, $cdb) = @_;
    my @messages = ();

    if ($align) {
      my $hub           = $self->hub;
      my $species_defs  = $hub->species_defs;
      my $db_key        = $cdb =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
      my $align_details = $species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};
      #use Data::Dumper;
      #warn Dumper($align_details);
  
      if ($align_details) {
        unless (exists $align_details->{'species'}->{$species}) {
          push @messages, {'severity' => 'error', 'title' => 'Unknown alignment',
                    'message' => sprintf('<p>%s is not part of the %s alignment in the database.</p>',
                                    $species_defs->species_label($species),
                                    encode_entities($align_details->{'name'}))
                    };
        }
      }
      else {
        push @messages, {'severity' => 'error', 'title' => 'Unknown alignment', 'message' => '<p>The alignment you have selected does not exist in the current database.</p>'};
      }
    }
    else {
      push @messages, {'severity' => 'warning', 'title' => 'No alignment specified', 'message' => '<p>Please select the alignment you wish to display from the above.</p>'};
    }

    return @messages;
}

sub get_slices {
  my ($self, $args) = @_;
  my (@slices, @formatted_slices, $length);
  my $underlying_slices = !$args->{image}; # Don't get underlying slices for alignment images - they are only needed for text sequence views, and the process is slow.

  if ($args->{align}) {
    push @slices, @{$self->get_alignments($args)};
  } else {
    push @slices, $args->{slice}; # If no alignment selected then we just display the original sequence as in geneseqview
  }

  my $counter = 0;
  foreach (@slices) {
    next unless $_;

    my $name = $_->can('display_Slice_name') ? lc $_->display_Slice_name : $args->{species};

    my $cigar_line = $_->can('get_cigar_line') ? $_->get_cigar_line : "";
    #Need to change G to X if genetree glyphs are to be rendered correctly
    $cigar_line =~ s/G/X/g;

    push @formatted_slices, {
      slice             => $_,
      underlying_slices => $underlying_slices && $_->can('get_all_underlying_Slices') ? $_->get_all_underlying_Slices : [ $_ ],
      name              => $name,
      display_name      => $self->get_slice_display_name($name, $_),
      cigar_line        => $cigar_line,
    };
    if ($name eq 'Ancestral_sequences') {
      $counter++;
      my $ga_node = $formatted_slices[-1]->{underlying_slices}->[0]->{_node_in_tree};
      if ($ga_node) {
        my $removed_species = $_->{_align_slice}->{_removed_species};
        # The current slice has to be discarded if it is an ancestral node
        # that fully maps to hidden species on one of its sides
        my $c1 = scalar(grep {not $removed_species->{$_->genomic_align_group->genome_db->name} } @{$ga_node->children->[0]->get_all_leaves});
        my $c2 = scalar(grep {not $removed_species->{$_->genomic_align_group->genome_db->name} } @{$ga_node->children->[1]->get_all_leaves});
        if ($c1 and $c2) {
          $formatted_slices[-1]->{_counter_position} = $counter;
          $formatted_slices[-1]->{display_name} .= " $counter";
        } else {
          pop @formatted_slices;
        }
      }
    }

    $length ||= $_->length; # Set the slice length value for the reference slice only
  }

  return (\@formatted_slices, $length);
}

sub get_target_slice {
  my $self = shift;
  my $hub = $self->hub;
  my $align_param = $hub->get_alignment_id;
  my $target_slice;

  #target_species and target_slice_name_range may not be defined so split separately
  #target_species but not target_slice_name_range is defined for pairwise compact alignments. 
  my ($align, $target_species, $target_slice_name_range) = split '--', $align_param;
  my ($target_slice_name, $target_slice_start, $target_slice_end) = $target_slice_name_range ?
    $target_slice_name_range =~ /([\w\.]+):(\d+)-(\d+)/ : (undef, undef, undef);

  #Define target_slice
  if ($target_species && $target_slice_start) {
      my $target_slice_adaptor = $hub->database('core', $target_species)->get_SliceAdaptor;
      $target_slice = $target_slice_adaptor->fetch_by_region('toplevel', $target_slice_name, $target_slice_start, $target_slice_end);
  }

  return $target_slice;
}

sub get_alignments {
  my ($self, $args) = @_;
  my $hub = $self->hub;
  my $slice = $args->{slice};

  my $cdb = $args->{'cdb'} || 'compara';

  my ($align, $target_species, $target_slice_name_range) = split '--', ($args->{'align'} || $hub->get_alignment_id);

  my $target_slice = $self->get_target_slice;

  my $func                    = $self->{'alignments_function'} || 'get_all_Slices';
  my $compara_db              = $hub->database($cdb);
  my $as_adaptor              = $compara_db->get_adaptor('AlignSlice');
  my $mlss_adaptor            = $compara_db->get_adaptor('MethodLinkSpeciesSet');
  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($align);
  my $align_slice             = eval {$as_adaptor->fetch_by_Slice_MethodLinkSpeciesSet($args->{slice}, $method_link_species_set, 'expanded', 'restrict', $target_slice); };

  my $species = $args->{species};
  my @selected_species;

  my $viewconfig = $args->{'component'} ? $hub->get_viewconfig({'component' => $args->{'component'}, 'type' => $args->{'type'}})
                                        : $hub->viewconfig;

  my $alignments_session_data = $viewconfig  ? $viewconfig->get_alignments_selector_settings : {}; 

  if (keys %{$alignments_session_data->{$species}} && $alignments_session_data->{$species}->{'align'} == $align) {
    while (my($k,$v) = each (%{$alignments_session_data->{$species}})) {
      next unless ($k =~ /species_${align}_(.+)/ && $v eq 'yes');
      push @selected_species, $1;
    }
  }
  else {
    my $db_key    = $args->{cdb} =~ /pan_ensembl/ ? 'DATABASE_COMPARA_PAN_ENSEMBL' : 'DATABASE_COMPARA';
    my $alignment = $hub->species_defs->multi_hash->{$db_key}->{'ALIGNMENTS'}->{$align};

    @selected_species = keys %{$alignment->{'species'}};

    $_=lc for @selected_species;

    my $session_data;
    %{$session_data->{$species}} = map { sprintf('species_%s_%s', $align, lc) => 'yes' } @selected_species;
    $session_data->{$species}->{'align'} = $align;
    $viewconfig->save_alignments_selector_settings($session_data) if $viewconfig;
  }

  unshift @selected_species, lc $species unless $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'class'} =~ /pairwise/;

  $align_slice = $align_slice->sub_AlignSlice($args->{start}, $args->{end}) if $align_slice && $args->{start} && $args->{end};

  return $align_slice ? $align_slice->$func(@selected_species) : [];
}

sub get_align_blocks {
  ## Get the alignment blocks. Restrict to the region displayed.
    my ($self, $slice, $align, $cdb) = @_;

    $cdb   ||= 'compara';

    my $hub             = $self->hub;
    my $primary_species = $hub->species;
    my $compara_db      = $hub->database($cdb);
    my $gab_adaptor     = $compara_db->get_adaptor('GenomicAlignBlock');
    my $mlss_adaptor            = $compara_db->get_adaptor('MethodLinkSpeciesSet');
    my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($align);

    my $align_blocks = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, undef, undef, 'restrict');

    return $align_blocks;
}

sub get_groups {
  ## Group together the alignment blocks with the same group_id or dbID
  my ($self, $align_blocks, $is_low_coverage_species) = @_;

  my $groups;
  my $k = 0;
  foreach my $gab (@$align_blocks) {
    my $start = $gab->reference_slice_start;
    my $end = $gab->reference_slice_end;
    #next if $end < 1 || $start > $length;

    #Set dbID or original_dbID if block has been restricted
    my $dbID = $gab->dbID || $gab->original_dbID;

    #If low coverage species, group by group_id or block id ie group together the
    #fragmented genomic aligns of low coverage species in the EPO_LOW_COVEREAGE alignment
    #else group by group_id only.
    my $key;
    if ($is_low_coverage_species) {
      $key = ($gab->{group_id} || $dbID);
    } else {
      $key = ($gab->{group_id} || $k++);
    }
    push @{$groups->{$key}{'gabs'}},[$start,$gab];
  }
  return $groups;
}

sub find_is_overlapping {
  ## Find if any of the blocks overlap one another.
  my ($self, $align_blocks) = @_;

  my $found_overlap = 0;
  my $prev_end = 0;
  #order on dnafrag_start
  foreach my $gab (sort {$a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start} @$align_blocks) {
    my $ga = $gab->reference_genomic_align;
    my $ga_start = $ga->dnafrag_start;
    my $ga_end = $ga->dnafrag_end;
    if ($ga_start < $prev_end) {
      return 1;
    }
    $prev_end = $ga_end;
  }
  return 0;
}

sub get_start_end_of_slice {
  ## Get start and end of target slice for low_coverage species or non_ref slice for pairwise alignments
  ## Also returns the number of unique non-reference species
  my ($self, $gabs, $target_species) = @_;

  my ($ref_s_slice, $ref_e_slice, $non_ref_s_slice, $non_ref_e_slice);
  my $non_ref_species;
  my $non_ref_seq_region;
  my $non_ref_ga;
  my $num_species = 0;

  my %unique_species;

  foreach my $gab (@$gabs) {
    my $ref = $gab->reference_genomic_align;
    my $ref_start = $ref->dnafrag_start;
    my $ref_end = $ref->dnafrag_end;

    #find limits of start and end of reference slice
    $ref_s_slice = $ref_start if (!defined $ref_s_slice) or $ref_start < $ref_s_slice;
    $ref_e_slice = $ref_end   if (!defined $ref_e_slice) or $ref_end   > $ref_e_slice;

    #Find non-reference genomic_align and hash of unique species
    if ($target_species) {
      my $all_non_refs = $gab->get_all_non_reference_genomic_aligns;
      my $nonrefs = [ grep {$target_species eq $_->genome_db->name } @$all_non_refs ];
      $non_ref_ga = $nonrefs->[0]; #just take the first match
      foreach my $ga (@$all_non_refs) {
        my $species = $ga->genome_db->name;
        $unique_species{$species} = 1 if ($species ne $target_species);
      }
    } else {
      $non_ref_ga = $gab->get_all_non_reference_genomic_aligns->[0];
    }

    #find limits of start and end of non-reference slice
    if ($non_ref_ga) {
      my $non_ref_start = $non_ref_ga->dnafrag_start;
      my $non_ref_end = $non_ref_ga->dnafrag_end;

      $non_ref_s_slice = $non_ref_start if (!defined $non_ref_s_slice) or $non_ref_start < $non_ref_s_slice;
      $non_ref_e_slice = $non_ref_end   if (!defined $non_ref_e_slice) or $non_ref_end   > $non_ref_e_slice;
    }
  }

  $num_species = keys %unique_species;
  return ($ref_s_slice, $ref_e_slice, $non_ref_s_slice, $non_ref_e_slice, $non_ref_ga, $num_species);
}

sub build_features_into_sorted_groups {
  ## Features are grouped and rendered together
  my ($self, $groups) = @_;

  # sort contents of groups by start
  foreach my $g (values %$groups) {
    my @f = map {$_->[1]} sort { $a->[0] <=> $b->[0] } @{$g->{'gabs'}||[]};

    #slice length
    $g->{'len'} = max(map { $_->reference_slice_end   } @f) - min(map { $_->reference_slice_start } @f);
    $g->{'gabs'} = \@f;
  }

  # Sort by length
  return [ map { $_->{'gabs'} } sort { $b->{'len'} <=> $a->{'len'} } values %$groups ];
}

sub DEPRECATED {
  my @caller = caller(1);
  my $warn   = "$caller[3] is deprecated and will be removed in release 62. ";
  my $func   = shift || [split '::', $caller[3]]->[-1];
  $warn     .= "Use EnsEMBL::Web::Hub::$func instead - $caller[1] line $caller[2]\n";
  warn $warn;
}

1;
