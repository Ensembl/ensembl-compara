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

package EnsEMBL::Web::Component::Shared;

### Parent module for page components that share methods across object types 
### e.g. a table of transcripts that needs to appear on both Gene and Transcript pages

use strict;

use HTML::Entities  qw(encode_entities);
use List::MoreUtils qw(first_index);

use EnsEMBL::Web::Utils::FormatText qw(glossary_helptip pluralise);

use parent qw(EnsEMBL::Web::Component);

sub species_stats {
  my $self = shift;
  my $sd = $self->hub->species_defs;
  my $html;
  my $db_adaptor = $self->hub->database('core');
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $genome_container = $db_adaptor->get_GenomeContainer();
  my $no_stats = $genome_container->is_empty;


  $html = '<h3>Summary</h3>';

  my $cols = [
    { key => 'name', title => '', width => '30%', align => 'left' },
    { key => 'stat', title => '', width => '70%', align => 'left' },
  ];
  my $options = {'header' => 'no', 'rows' => ['bg3', 'bg1']};

  ## SUMMARY STATS
  my $summary = $self->new_table($cols, [], $options);

  my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
  if ($a_id) {
    # look for long name and accession num
    if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
      $a_id .= " ($long)";
    }
    if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
      $acc = sprintf('INSDC Assembly <a href="//www.ebi.ac.uk/ena/data/view/%s" rel="external">%s</a>', $acc, $acc);
      $a_id .= ", $acc";
    }
  }
  $summary->add_row({
      'name' => '<b>Assembly</b>',
      'stat' => $a_id.', '.$sd->ASSEMBLY_DATE
  });
  $summary->add_row({
      'name' => '<b>Base Pairs</b>',
      'stat' => $self->thousandify($genome_container->get_ref_length()),
  }) unless $no_stats;
  my $header = glossary_helptip($self->hub, 'Golden Path Length', 'Golden path length');
  $summary->add_row({
      'name' => "<b>$header</b>",
      'stat' => $self->thousandify($genome_container->get_ref_length())
  }) unless $no_stats;

  my @sources = qw(assembly annotation);
  foreach my $source (@sources) {
    my $meta_key = uc($source).'_PROVIDER_NAME';
    my $prov_name = $sd->$meta_key;
    if ($prov_name) {
      my $i = 0;
      my @prov_names  = ref $prov_name eq 'ARRAY' ? @$prov_name : ($prov_name);
      my $url_key     = uc($source).'_PROVIDER_URL';
      my $prov_url    = $sd->$url_key;
      my @prov_urls   = ref $prov_url eq 'ARRAY' ? @$prov_url : ($prov_url);
      my @providers;
      foreach my $provider (@prov_names) {
        $provider =~ s/_/ /g;
        my $prov_url = $prov_urls[$i] || $prov_urls[0];
        if ($prov_url && $provider ne 'Ensembl') {
          $prov_url = 'http://'.$prov_url unless $prov_url =~ /^http/;
          $provider = sprintf('<a href="%s">%s</a>', $prov_url, $provider);
        }
        push @providers, $provider;
        $i++;
      }
      $summary->add_row({
        'name' => sprintf('<b>%s provider</b>', ucfirst($source)),
        'stat' => join(', ', @providers), 
      });
    }
  }

  my $method  = ucfirst($sd->GENEBUILD_METHOD) || '';
  $method     =~ s/_/ /g;
  $summary->add_row({
      'name' => '<b>Annotation method</b>',
      'stat' => $method
  });
  $summary->add_row({
      'name' => '<b>Genebuild started</b>',
      'stat' => $sd->GENEBUILD_START
  });
  $summary->add_row({
      'name' => '<b>Genebuild released</b>',
      'stat' => $sd->GENEBUILD_RELEASE
  });
  $summary->add_row({
      'name' => '<b>Genebuild last updated/patched</b>',
      'stat' => $sd->GENEBUILD_LATEST
  });
  $summary->add_row({
      'name' => '<b>Database version</b>',
      'stat' => $sd->ENSEMBL_VERSION.'.'.$sd->SPECIES_RELEASE_VERSION
  });
  my $gencode = $sd->GENCODE_VERSION;
  if ($gencode) {
    $summary->add_row({
      'name' => '<b>Gencode version</b>',
      'stat' => $gencode,
    });
  }

  $html .= $summary->render;

  ## GENE COUNTS
  unless ($no_stats) {
    my $has_alt = $genome_container->get_alt_coding_count();
    if($has_alt) {
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,' (Primary assembly)','');
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,' (Alternative sequence)','a');
    } else {
      $html .= $self->_add_gene_counts($genome_container,$sd,$cols,$options,'','');
    }

    ## OTHER STATS
    my $rows = [];
    ## Prediction transcripts
    my $analysis_adaptor = $db_adaptor->get_AnalysisAdaptor();
    my $attribute_adaptor = $db_adaptor->get_AttributeAdaptor();
    my @analyses = @{ $analysis_adaptor->fetch_all_by_feature_class('PredictionTranscript') };
    foreach my $analysis (@analyses) {
      my $logic_name = $analysis->logic_name;
      my $stat = $genome_container->fetch_by_statistic(
                                      'PredictionTranscript',$logic_name); 
      push @$rows, {
        'name' => "<b>".$stat->name."</b>",
        'stat' => $self->thousandify($stat->value),
      } if $stat and $stat->name;
    }
    ## Variants
    if ($self->hub->database('variation')) {
      my @other_stats = qw(SNPCount StructuralVariation);
      foreach my $name (@other_stats) {
        my $stat = $genome_container->fetch_by_statistic($name);
        push @$rows, {
          'name' => '<b>'.$stat->name.'</b>',
          'stat' => $self->thousandify($stat->value)
        } if $stat and $stat->name;
      }
    }

    if (scalar(@$rows)) {
      $html .= '<h3>Other</h3>';
      my $other = $self->new_table($cols, $rows, $options);
      $html .= $other->render;
    }
  }

  return $html;
}

sub _add_gene_counts {
  my ($self,$genome_container,$sd,$cols,$options,$tail,$our_type) = @_;

  my @order           = qw(coding_cnt noncoding_cnt noncoding_cnt/s noncoding_cnt/l noncoding_cnt/m pseudogene_cnt transcript);
  my @suffixes        = (['','~'], ['r',' (incl ~ '.glossary_helptip($self->hub, 'readthrough', 'Readthrough').')']);
  my $glossary_lookup = {
    'coding_cnt'        => 'Protein coding',
    'noncoding_cnt/s'   => 'Small non coding gene',
    'noncoding_cnt/l'   => 'Long non coding gene',
    'pseudogene_cnt'    => 'Pseudogene',
    'transcript'        => 'Transcript',
  };

  my @data;
  foreach my $statistic (@{$genome_container->fetch_all_statistics()}) {
    my ($name,$inner,$type) = ($statistic->statistic,'','');
    if($name =~ s/^(.*?)_(r?)(a?)cnt(_(.*))?$/$1_cnt/) {
      ($inner,$type) = ($2,$3);
      $name .= "/$5" if $5;
    }

    # Check if current statistic is alt_transcript and our_type is a (alternative sequence).
    # If yes, make type to be a so that the loop won't go to next early.
    # Also, push alt_transcript to order so that the statistic will be included in the table.
    if ($name eq 'alt_transcript' && $our_type eq 'a') {
      $type = 'a';
      push @order, 'alt_transcript';
    }

    next unless $type eq $our_type;
    my $i = first_index { $name eq $_ } @order;
    next if $i == -1;
    ($data[$i]||={})->{$inner} = $self->thousandify($statistic->value);
    $data[$i]->{'_key'} = $name;
    $data[$i]->{'_name'} = $statistic->name if $inner eq '';
    $data[$i]->{'_sub'} = ($name =~ m!/!);
  }

  my $counts = $self->new_table($cols, [], $options);
  foreach my $d (@data) {
    my $value = '';
    foreach my $s (@suffixes) {
      next unless $d->{$s->[0]};
      $value .= $s->[1];
      $value =~ s/~/$d->{$s->[0]}/g;
    }
    next unless $value;
    my $class = '';
    $class = 'row-sub' if $d->{'_sub'};
    my $key = $d->{'_name'};
    $key = glossary_helptip($self->hub, "<b>$d->{'_name'}</b>", $glossary_lookup->{$d->{'_key'}});
    $counts->add_row({ name => $key, stat => $value, options => { class => $class }});
  } 
  return "<h3>Gene counts$tail</h3>".$counts->render;
}
  
sub get_matches { ## TODO - tidy this
  my ($self, $key, $caption, @keys) = @_;
  my $output_as_twocol  = $keys[-1] eq 'RenderAsTwoCol';
  my $output_as_table   = $keys[-1] eq 'RenderAsTables';
  my $show_version      = $keys[-1] eq 'show_version' ? 'show_version' : '';

  pop @keys if ($output_as_twocol || $output_as_table || $show_version) ; # if output_as_table or show_version or output_as_twocol then the last value isn't meaningful

  my $object       = $self->object;
  my $species_defs = $self->hub->species_defs;
  my $label        = $species_defs->translate($caption);
  my $obj          = $object->Obj;

  # Check cache
  if (!$object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($obj)};
    return unless @similarity_links;
    $self->_sort_similarity_links($output_as_table, $show_version, $keys[0], @similarity_links );
  }

  my @links = map { @{$object->__data->{'links'}{$_}||[]} } @keys;
  return unless @links;
  @links = $self->remove_redundant_xrefs(@links) if $keys[0] eq 'ALT_TRANS';
  return unless @links;

  my $db    = $object->get_db;
  my $entry = lc(ref $obj);
  $entry =~ s/bio::ensembl:://;

  my @rows;
  my $html = $species_defs->ENSEMBL_SITETYPE eq 'Vega' ? '' : "<p><strong>This $entry corresponds to the following database identifiers:</strong></p>";

  # in order to preserve the order, we use @links for acces to keys
  while (scalar @links) {
    my $key = $links[0][0];
    my $j   = 0;
    my $text;

    # display all other vales for the same key
    while ($j < scalar @links) {
      my ($other_key , $other_text) = @{$links[$j]};
      if ($key eq $other_key) {
        $text      .= $other_text;
        splice @links, $j, 1;
      } else {
        $j++;
      }
    }

    push @rows, { dbtype => $key, dbid => $text };
  }

  my $table;
  @rows = sort { $a->{'dbtype'} cmp $b->{'dbtype'} } @rows;

  if ($output_as_twocol) {
    $table = $self->new_twocol;
    $table->add_row("$_->{'dbtype'}:", " $_->{'dbid'}") for @rows;    
  } elsif ($output_as_table) { # if flag is on, display datatable, otherwise a simple table
    $table = $self->new_table([
        { key => 'dbtype', align => 'left', title => 'External database' },
        { key => 'dbid',   align => 'left', title => 'Database identifier' }
      ], \@rows, { data_table => 'no_sort no_col_toggle', exportable => 1 }
    );
  } else {
    $table = $self->dom->create_element('table', {'cellspacing' => '0', 'children' => [
      map {'node_name' => 'tr', 'children' => [
        {'node_name' => 'th', 'inner_HTML' => "$_->{'dbtype'}:"},
        {'node_name' => 'td', 'inner_HTML' => " $_->{'dbid'}"  }
      ]}, @rows
    ]});
  }

  return $html.$table->render;
}

sub _sort_similarity_links {
  my $self             = shift;
  my $output_as_table  = shift || 0;
  my $show_version     = shift || 0;
  my $xref_type        = shift || '';
  my @similarity_links = @_;

  my $hub              = $self->hub;
  my $object           = $self->object;
  my $database         = $hub->database;
  my $db               = $object->get_db;
  my $urls             = $hub->ExtURL;
  my $fv_type          = $hub->action eq 'Oligos' ? 'OligoFeature' : 'Xref'; # default link to featureview is to retrieve an Xref
  my (%affy, %exdb);

  # Get the list of the mapped ontologies 
  my @mapped_ontologies = @{$hub->species_defs->SPECIES_ONTOLOGIES || ['GO']};
  my $ontologies = join '|', @mapped_ontologies, 'goslim_goa';

  foreach my $type (sort {
    $b->priority        <=> $a->priority        ||
    $a->db_display_name cmp $b->db_display_name ||
    $a->display_id      cmp $b->display_id
  } @similarity_links) {
    my $link       = '';
    my $join_links = 0;
    my $externalDB = $type->database;
    my $display_id = $type->display_id;
    my $primary_id = $type->primary_id;

    # hack for LRG
    $primary_id =~ s/_g\d*$// if $externalDB eq 'ENS_LRG_gene';

    next if $type->status eq 'ORTH';                            # remove all orthologs
    next if lc $externalDB eq 'medline';                        # ditch medline entries - redundant as we also have pubmed
    next if $externalDB =~ /^flybase/i && $display_id =~ /^CG/; # ditch celera genes from FlyBase
    next if $externalDB eq 'Vega_gene';                         # remove internal links to self and transcripts
    next if $externalDB eq 'Vega_transcript';
    next if $externalDB eq 'Vega_translation';
    next if $externalDB eq 'OTTP' && $display_id =~ /^\d+$/;    # don't show vega translation internal IDs
    next if $externalDB eq 'shares_CDS_with_ENST';
    next if $externalDB =~ /^Uniprot_/;

    if ($externalDB =~ /^($ontologies)$/) {
      push @{$object->__data->{'links'}{'go'}}, $display_id;
      next;
    } elsif ($externalDB eq 'GKB') {
      my ($key, $primary_id) = split ':', $display_id;
      push @{$object->__data->{'links'}{'gkb'}->{$key}}, $type;
      next;
    }

    my $text = $display_id;

    (my $A = $externalDB) =~ s/_predicted//;

    if ($urls && $urls->is_linked($A)) {
      $type->{ID} = $primary_id;
      $link = $urls->get_url($A, $type);
      my $word = $display_id;
      $word .= " ($primary_id)" if $A eq 'MARKERSYMBOL';

      if ($link) {
        $text = qq{<a href="$link" class="constant">$word</a>};
      } else {
        $text = $word;
      }
    }
    if ($type->isa('Bio::EnsEMBL::IdentityXref')) {
      $text .= ' <span class="small"> [Target %id: ' . $type->ensembl_identity . '; Query %id: ' . $type->xref_identity . ']</span>';
      $join_links = 1;
    }

    if ($hub->species_defs->ENSEMBL_PFETCH_SERVER && $externalDB =~ /^(SWISS|SPTREMBL|LocusLink|protein_id|RefSeq|EMBL|Gene-name|Uniprot)/i && ref($object->Obj) eq 'Bio::EnsEMBL::Transcript' && $externalDB !~ /uniprot_genename/i) {
      my $seq_arg = $display_id;
      $seq_arg    = "LL_$seq_arg" if $externalDB eq 'LocusLink';

      my $url = $self->hub->url({
        type     => 'Transcript',
        action   => 'Similarity/Align',
        sequence => $seq_arg,
        extdb    => lc $externalDB
      });

      $text .= qq{ [<a href="$url">align</a>] };
    }

    $text .= sprintf ' [<a href="%s">Search GO</a>]', $urls->get_url('GOSEARCH', $primary_id) if $externalDB =~ /^(SWISS|SPTREMBL)/i; # add Search GO link;

    if ($show_version && $type->version) {
      my $version = $type->version;
      $text .= " (version $version)";
    }

    if ($type->description) {
      (my $D = $type->description) =~ s/^"(.*)"$/$1/;
      $text .= '<br />' . encode_entities($D);
      $join_links = 1;
    }

    if ($join_links) {
      $text = qq{\n <div>$text};
    } else {
      $text = qq{\n <div class="multicol">$text};
    }

    # override for Affys - we don't want to have to configure each type, and
    # this is an internal link anyway.
    if ($externalDB =~ /^AFFY_/i) {
      next if $affy{$display_id} && $exdb{$type->db_display_name}; # remove duplicates

      $text = qq{\n  <div class="multicol"> $display_id};
      $affy{$display_id}++;
      $exdb{$type->db_display_name}++;
    }

    # add link to featureview
    if ($externalDB eq 'ENS_LRG_gene') {
      my $lrg_url = $self->hub->url({
        type    => 'LRG',
        action  => 'Genome',
        lrg     => $display_id,
      });

      $text .= qq{ [<a href="$lrg_url">view all locations</a>]};
    } else {
      my $link_name = $fv_type eq 'OligoFeature' ? $display_id : $primary_id;
      my $link_type = $fv_type eq 'OligoFeature' ? $fv_type    : "${fv_type}_$externalDB";

      my $k_url = $self->hub->url({
        type   => 'Location',
        action => 'Genome',
        id     => $link_name,
        ftype  => $link_type
      });
      $text .= qq{  [<a href="$k_url">view all locations</a>]} unless $xref_type =~ /^ALT/;
    }

    $text .= '</div>';

    my $label = $type->db_display_name || $externalDB;
    $label    = 'LRG' if $externalDB eq 'ENS_LRG_gene'; 

    push @{$object->__data->{'links'}{$type->type}}, [ $label, $text ];
  }
}

sub remove_redundant_xrefs {
  my ($self, @links) = @_;
  my %priorities;

  # We can have multiple OTT/ENS xrefs but need to filter some out since there can be duplicates.
  # Therefore need to generate a data structure that has the stable ID as the key
  my %links;
  foreach (@links) {
    if ($_->[1] =~ /[t|g]=(\w+)/) {
      my $sid = $1;
      if ($sid =~ /[ENS|OTT]/) { 
        push @{$links{$sid}->{$_->[0]}}, $_->[1];
      }
    }
  }

  # There can be more than db_link type for each particular stable ID, need to order by priority
  my @priorities = ('Transcript having exact match between ENSEMBL and HAVANA',
                    'Ensembl transcript having exact match with Havana',
                    'Havana transcript having same CDS',
                    'Ensembl transcript sharing CDS with Havana',
                    'Havana transcript');

  my @new_links;
  foreach my $sid (keys %links) {
    my $wanted_link_type;
  PRIORITY:
    foreach my $link_type (@priorities) {
      foreach my $db_link_type ( keys %{$links{$sid}} ) {
        if ($db_link_type eq $link_type) {
          $wanted_link_type = $db_link_type;
          last PRIORITY;
        }
      }
    }

    return @links unless $wanted_link_type; #show something rather than nothing if we have unexpected (ie none in the above list) xref types

    #if there is only one link for a particular db_link type it's easy...
    if ( @{$links{$sid}->{$wanted_link_type}} == 1) {
      push @new_links, [ $wanted_link_type, @{$links{$sid}->{$wanted_link_type}} ];
    }
    else {
      #... otherwise differentiate between multiple xrefs of the same type if the version numbers are different
      my $max_version = 0;
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        if ( $link =~ /version (\d{1,2})/ ) {
          $max_version = $1 if $1 > $max_version;
        }
      }
      foreach my $link (@{$links{$sid}->{$wanted_link_type}}) {
        next if ($max_version && ($link !~ /version $max_version/));
        push @new_links, [ $wanted_link_type, $link ];
      }
    }
  }
  return @new_links;
}

1;
