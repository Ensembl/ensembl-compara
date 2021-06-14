=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Controller::Psychic;

### Psychic search - tries to guess where the user wanted to go 
### based on analysis of the search string!

use strict;
use warnings;

use URI::Escape qw(uri_escape);

use parent qw(EnsEMBL::Web::Controller);

sub process {
  my $self = shift;

  if ($self->action eq 'Location') {
    $self->psychic_gene_location;
  } else {
    $self->psychic;
  }
}

sub psychic {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $self->species_defs;
  my $site_type     = lc $species_defs->ENSEMBL_SITETYPE;
  my $script        = 'Search/Results';
  my %sp_hash       = %{$species_defs->multi_val('ENSEMBL_SPECIES_URL_MAP')||{}};
  my $dest_site     = $hub->param('site') || $site_type;
  my $index         = $hub->param('idx')  || undef;
  my $query         = $hub->param('q');
  my $sp_param      = $hub->param('species');
  my $species       = $sp_param || $hub->species;
     $species       = '' if $species eq 'Multi';

  if ($species eq 'all' && $dest_site eq 'ensembl') {
    $dest_site = 'ensembl_all';
    $species   = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  $query =~ s/^\s+//g;
  $query =~ s/\s+$//g;
  $query =~ s/\s+/ /g;

  # Remove leading/trailing double/single quotes (" / ') from query
  $query =~ s/^["|'](.*)["|']$/$1/;
  my @extra;
  push @extra,"facet_feature_type=Documentation" if $species eq 'help';
  $species = undef if $dest_site =~ /_all/ or $species eq 'help';

  return $self->redirect("//www.ebi.ac.uk/ebisearch/search.ebi?db=allebi&query=$query")  if $dest_site eq 'ebi';
  return $self->redirect("//www.sanger.ac.uk/search?db=allsanger&t=$query")              if $dest_site eq 'sanger';
  return $self->redirect("//www.ensemblgenomes.org/search/eg/$query")                    if $dest_site eq 'ensembl_genomes';

  my $extra = '';
  if(@extra) {
    $extra = join(';','',@extra);
  }

  my $url = "/Multi/Search/Results?species=$species&idx=All&q=$query$extra";
  my $site = '';

  ## Probably don't need this any more
  if ($dest_site =~ /vega/) {
    if ($site_type eq 'vega') {
      $url = "/Multi/Search/Results?species=all&idx=All&q=$query";
    } else {
      $url  = "/Multi/Search/Results?species=all&idx=All&q=$query";
      $site = '//vega.sanger.ac.uk';
    }
  } elsif ($site_type eq 'vega') {
    $url  = "/Multi/Search/Results?species=all&idx=All&q=$query";
    $site = '//www.ensembl.org'; 
  }

  my $flag = 0;
  my $index_t = '';

  #if there is a species at the beginning of the query term then make a note in case we trying to jump to another location
  my ($query_species, $query_without_species);
  foreach my $sp (sort keys %sp_hash) {
    if ( $query =~ /^\Q$sp\E\s/) {
      ($query_without_species = $query) =~ s/\Q$sp\E//;
      $query_without_species =~ s/^ //;
      $query_species = $sp;
    }
  }  

  my $species_path = $species_defs->species_path($species) || "/$species";

  ## If we have a species and a location can we jump directly to that page ?
  if ($species || $query_species ) {

    if ($query =~ /^rs\d+$/) {

      return $self->redirect($site.$hub->url({
        'species'   => $species || $query_species,
        'type'      => 'Variation',
        'action'    => 'Explore',
        'v'         => $query
      }));
    }

    my $real_chrs = $hub->species_defs->ENSEMBL_CHROMOSOMES;
    my $jump_query = $query;
    if ($query_species) {
      $jump_query = $query_without_species;
      $species_path = $species_defs->species_path($query_species);
    }

    if ($jump_query =~ s/^(chromosome)//i || $jump_query =~ s/^(chr)//i) {
      $jump_query =~ s/^ //;
      if (grep { $jump_query eq $_ } @$real_chrs) {
        $flag = $1;
        $index_t = 'Chromosome';
      }
    }
    elsif ($jump_query =~ /^(contig|clone|ultracontig|supercontig|scaffold|region)/i) {
      $jump_query =~ s/^(contig|clone|ultracontig|supercontig|scaffold|region)\s+//i;
      $index_t = 'Sequence';
      $flag = $1;
    }
 
    ## match any of the following:
    if ($jump_query =~ /^\s*([-\.\w]+)[:]/i ) {
    #using core api to return location value (see perl documentation for core to see the available combination)
    # don't get an adaptor as we may not have a core db in our species (eg Multi on grch37).
      my ($seq_region_name, $start, $end, $strand) = Bio::EnsEMBL::DBSQL::SliceAdaptor::parse_location_to_values(undef,$jump_query);

      $seq_region_name =~ s/chr//;
      $seq_region_name =~ s/ //g;
      $start = $self->evaluate_bp($start);
      $end   = $self->evaluate_bp($end);
      ($end, $start) = ($start, $end) if $end < $start;

      my $script = 'Location/View';
      $script    = 'Location/Overview' if $end - $start > 1000000;


      if ($index_t eq 'Chromosome') {
        $url  = "$species_path/Location/Chromosome?r=$seq_region_name";
        $flag = 1;
      } else {
        $url  = $self->escaped_url("$species_path/$script?r=%s", $seq_region_name . ($start && $end ? ":$start-$end" : ''));
        $flag = 1;
      }
    }
    else {
      if ($index_t eq 'Chromosome') {
        $jump_query =~ s/ //g;
        $url  = "$species_path/Location/Chromosome?r=$jump_query";
        $flag = 1;
      } elsif ($index_t eq 'Sequence') {
        $jump_query =~ s/ //g;
        $url  = "$species_path/Location/View?region=$jump_query";
        $flag = 1;
      }
    }

    ## other pairs of identifiers
    if ($jump_query =~ /\.\./ && !$flag) {
      ## str.string..str.string
      ## str.string-str.string
      $jump_query =~ /([\w|\.]*\w)(\.\.)(\w[\w|\.]*)/;
      $url   = $self->escaped_url("$species_path/jump_to_contig?type1=all;type2=all;anchor1=%s;anchor2=%s", $1, $3); # TODO - get rid of jump_to_contig
      $flag  = 1;
    }
  }
  elsif ($query =~ /([\w|_|-|\.]+):([\w|_|-|\.]+):(\d+):(\d+):?(\d?)$/) {
    ## Coordinate format assembly:region:start:end:strand

    my ($assembly, $seq_region_name, $start, $end) = ($1, $2, $3, $4);

    my %assemblies = $hub->species_defs->multiX('ASSEMBLIES');
    my $release = $hub->species_defs->ENSEMBL_VERSION;
    $species_path = '';
    while (my($sp, $hash) = each (%assemblies)) {
      next unless $hash->{$release} =~ /$assembly/i;
      $species_path = $sp;
      last;
    }
    ## Default to primary species if we can't find this assembly
    $species_path = $hub->species_defs->ENSEMBL_PRIMARY_SPECIES unless $species_path;

    if ($species_path) {
      $seq_region_name =~ s/chr//;
      $seq_region_name =~ s/ //g;
      $start = $self->evaluate_bp($start);
      $end   = $self->evaluate_bp($end);
      ($end, $start) = ($start, $end) if $end < $start;

      my $script = 'Location/View';
      $script    = 'Location/Overview' if $end - $start > 1000000;

      $url  = $self->escaped_url("/$species_path/$script?r=%s", $seq_region_name . ($start && $end ? ":$start-$end" : ''));
      $flag = 1;
    }
  }

  # Match HGVS identifier
  # HGVS transcript
  if ($query =~ /^NM_\d+\.\d+\:[c]\.(\d+|\*|\-|\+)/) {
    # if matches then assume its human
    my $db_adaptor       = $hub->database('variation','Homo_sapiens');
    my $variation_adaptor = $db_adaptor->get_VariationAdaptor;
    if (defined $variation_adaptor){
      my $variant = $variation_adaptor->fetch_by_name($query);
      if (defined $variant){
        my $variant_name = $variant->name();
        $flag  = 1;
        return $self->redirect($site.$hub->url({
          'species'   => 'human',
          'type'      => 'Variation',
          'action'    => 'Explore',
          'v'         => $variant_name
          }));
        }
      }
  }

 # HGVS protein
 if ($query =~ /^NP_\d+\.\d+\:[p]\.[A-Z][a-z]{0,2}[\W\-]{0,1}[0-9]|^NP_\d+\.\d+\:[p]\.Met/) {
   # if matches then assume its human
   my $db_adaptor       = $hub->database('variation','Homo_sapiens');
   my $variation_adaptor = $db_adaptor->get_VariationAdaptor;
   if (defined $variation_adaptor){
     my $variant = $variation_adaptor->fetch_by_name($query);
     if (defined $variant){
       my $variant_name = $variant->name();
       $flag  = 1;
       return $self->redirect($site.$hub->url({
         'species'   => 'human',
         'type'      => 'Variation',
         'action'    => 'Explore',
         'v'         => $variant_name
         }));
       }
     }
  }

  if (!$flag) {
    if($query =~ /^\s*([A-Z]{40,})\s*$/i) {
      # BLAST
      $url = $self->escaped_url('/Tools/Blast?query_sequence=%s', $1);
    } else {
      if ($self->species_defs->ENSEMBL_SOLR_ENDPOINT) { ## Can't search across strains without SOLR
        my $coll = $species_defs->get_config($species,'STRAIN_GROUP');
        $species_path = "/$coll" if $coll;
      }
      $url = $self->escaped_url(($species eq 'ALL' || !$species ? '/Multi' : $species_path) . "/$script?species=%s;idx=%s;q=%s", $species || 'all', $index, $query);
    }
  }

  # Hack to get facets through to search. Psychic will be rewritten soon
  # so we shouldn't need this hack, longterm.
  if($url =~ m!/Search/!) {
    my @params = grep {$_ ne 'q'} $hub->param();
    $url .= ($url =~ /\?/ ? ';' : '?');
    $url .= join(";",map {; "$_=".$hub->param($_) } @params).$extra;
  }

  $self->redirect($site . $url);
}

sub psychic_gene_location {
  my $self    = shift;
  my $hub     = $self->hub;
  my $query   = $hub->param('q');
  my $adaptor = $hub->get_adaptor('get_GeneAdaptor', $hub->param('db'));
  my $gene    = $adaptor->fetch_by_stable_id($query) || $adaptor->fetch_by_display_label($query);
  my $url;
  
  if ($gene) {
    $url = $hub->url({
      %{$hub->multi_params(0)},
      type   => 'Location',
      action => 'View',
      g      => $gene->stable_id
    });
  } else {
    $url = $hub->referer->{'absolute_url'};
    
    $hub->session->set_record_data({
      type     => 'message',
      function => '_warning',
      code     => 'location_search',
      message  => 'The gene you searched for could not be found.'
    });
    $hub->session->store_records;
  }
  
  $self->redirect($url);
}

sub escaped_url {
  my ($self, $template, @array) = @_;
  return sprintf $template, map uri_escape($_), @array;
}

1;
