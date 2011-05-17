# $Id$

package EnsEMBL::Web::Controller::Psychic;

### Psychic search - tries to guess where the user wanted to go 
### based on analysis of the search string!

use strict;

use Apache2::RequestUtil;
use CGI;
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;

#use Data::Dumper;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class = shift;
  my $r     = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $args  = shift || {};
  my $input = new CGI;
  
  my $hub = new EnsEMBL::Web::Hub({
    apache_handle  => $r,
    input          => $input,
    session_cookie => $args->{'session_cookie'}
  });
  
  my $self = {
    r     => $r,
    input => $input,
    hub   => $hub,
    %$args
  };
  
  bless $self, $class;
  
  if ($hub->action eq 'Location') {
    $self->psychic_gene_location;
  } else {
    $self->psychic;
  }
  
  return $self;
}

sub psychic {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $site_type     = lc $species_defs->ENSEMBL_SITETYPE;
  my $script        = 'Search/Results';
  my %sp_hash          = %{$species_defs->ENSEMBL_SPECIES_ALIASES};
  my $dest_site     = $hub->param('site') || $site_type;
  my $index         = $hub->param('idx')  || undef;
  my $query         = $hub->param('q');
  my $sp_param      = $hub->param('species');
  my $species       = $sp_param || ($hub->species !~ /^(common|multi)$/i ? $hub->species : undef);
  my ($url, $site);

  if ($species eq 'all' && $dest_site eq 'ensembl') {
    $dest_site = 'ensembl_all';
    $species   = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  $query =~ s/^\s+//g;
  $query =~ s/\s+$//g;
  $query =~ s/\s+/ /g;

  $species = undef if $dest_site =~ /_all/;

  return $hub->redirect("http://www.ebi.ac.uk/ebisearch/search.ebi?db=allebi&query=$query")                          if $dest_site eq 'ebi';
  return $hub->redirect("http://www.sanger.ac.uk/search?db=allsanger&t=$query")                                      if $dest_site eq 'sanger';
  return $hub->redirect("http://www.ensemblgenomes.org/search?site=ensembl&q=$query&site=&x=0&y=0&genomic_unit=all") if $dest_site eq 'ensembl_genomes';

  if ($dest_site =~ /vega/) {
    if ($site_type eq 'vega') {
      $url = "/Multi/Search/Results?species=all&idx=All&q=$query";
    } else {
      $url  = "/Multi/Search/Results?species=all&idx=All&q=$query";
      $site = 'http://vega.sanger.ac.uk';
    }
  } elsif ($site_type eq 'vega') {
    $url  = "/Multi/Search/Results?species=all&idx=All&q=$query";
    $site = 'http://www.ensembl.org'; 
  } else {
    $url = "/Multi/Search/Results?species=$species&idx=All&q=$query";
  }

  my $flag = 0;
  my $index_t;

  #if there is a species at the beginning of the query term then make a note in case we trying to jump to another location
  my ($query_species, $query_without_species);
  foreach my $sp (sort keys %sp_hash) {
    if ( $query =~ /^$sp /) {
      ($query_without_species = $query) =~ s/$sp//;
      $query_without_species =~ s/^ //;
      $query_species = $sp;
    }
  }

  my $species_path = $species_defs->species_path($species) || "/$species";

  ## If we have a species and a location can we jump directly to that page ?
  if ($species || $query_species ) {
    my $jump_query = $query;
    if ($query_species) {
      $jump_query = $query_without_species;
      $species_path = $species_defs->species_path($query_species);
    }

    if ($jump_query =~ s/^(chromosome)//i || $jump_query =~ s/^(chr)//i) {
      $flag = $1;
      $index_t = 'Chromosome';
    }
    elsif ($jump_query =~ s/^(contig|clone|supercontig|scaffold|region)//i) {
      $index_t = 'Sequence';
      $flag = $1;
    }

    ## match any of the following:
    if ($jump_query =~ /^\s*([-\.\w]+)[: ]([\d\.]+?[MKG]?)( |-|\.\.|,)([\d\.]+?[MKG]?)$/i || $jump_query =~ /^\s*([-\.\w]+)[: ]([\d,]+[MKG]?)( |\.\.|-)([\d,]+[MKG]?)$/i) {
      my ($seq_region_name, $start, $end) = ($1, $2, $4);

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
      $url   = $self->escaped_url("$species_path/jump_to_contig?type1=all;type2=all;anchor1=%s;anchor2=%s", $1, $3);
      $flag  = 1;
    }
  }

  if (!$flag) {
    $url = 
      $query =~ /^BLA_\w+$/               ? $self->escaped_url('/Multi/blastview/%s', $query) :                                                                 ## Blast ticket
      $query =~ /^\s*([ACGT]{20,})\s*$/i  ? $self->escaped_url('/Multi/blastview?species=%s;_query_sequence=%s;query=dna;database=dna', $species, $1) :         ## BLAST seq search
      $query =~ /^\s*([A-Z]{20,})\s*$/i   ? $self->escaped_url('/Multi/blastview?species=%s;_query_sequence=%s;query=peptide;database=peptide', $species, $1) : ## BLAST seq search
      $self->escaped_url(($species eq 'ALL' || !$species ? '/Multi' : $species_path) . "/$script?species=%s;idx=%s;q=%s", $species || 'all', $index, $query);    # everything else!
  }

  $hub->redirect($site . $url);
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
    
    $hub->session->add_data(
      type     => 'message',
      function => '_warning',
      code     => 'location_search',
      message  => 'The gene you searched for could not be found.'
    );
  }
  
  $hub->redirect($url);
}

sub escaped_url {
  my ($self, $template, @array) = @_;
  return sprintf $template, map uri_escape($_), @array;
}

1;
