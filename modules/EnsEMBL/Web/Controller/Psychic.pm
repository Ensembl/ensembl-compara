# $Id$

package EnsEMBL::Web::Controller::Psychic;

### Prints the main web page - header, footer, navigation etc, and non dynamically loaded content.
### Deals with Command modules if required.

use strict;

use Apache2::RequestUtil;
use CGI;
use URI::Escape qw(uri_escape);

use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Controller);

sub new {
  my $class          = shift;
  my $r              = shift || Apache2::RequestUtil->can('request') ? Apache2::RequestUtil->request : undef;
  my $session_cookie = ref $_[0] eq 'HASH' ? undef : shift;
  my $args           = shift || {};
  my $input          = new CGI;
  
  my $hub = new EnsEMBL::Web::Hub({
    apache_handle  => $r,
    input          => $input,
    session_cookie => $session_cookie
  });
  
  my $self = {
    r     => $r,
    input => $input,
    hub   => $hub,
    %$args
  };
  
  bless $self, $class;
  
  if ($hub->action eq 'Location') {
    $self->psychic_location;
  } else {
    $self->psychic;
  }
  
  return $self;
}

sub feature_map {
  return {
    gene         => 'Gene',
    affyprobe    => 'OligoProbe',
    oliogprobe   => 'OligoProbe',
    affy         => 'OligoProbe',
    oligo        => 'OligoProbe',
    snp          => 'SNP',
    variaton     => 'SNP',
    chr          => 'Chromosome',
    clone        => 'Sequence',
    contig       => 'Sequence',
    chromosome   => 'Chromosome',
    supercontig  => 'Sequence',
    region       => 'Sequence',
    sequence     => 'Sequence',
    disease      => 'Gene',
    domain       => 'Domain',
    peptide      => 'Gene',
    transcript   => 'Gene',
    gene         => 'Gene',
    translation  => 'Gene',
    cdna         => 'GenomicAlignment',
    mrna         => 'GenomicAlignment',
    protein      => 'GenomicAlignment',
    domain       => 'Domain',
    marker       => 'Marker',
    family       => 'Family',
  };
}

sub psychic {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $site_type     = lc $species_defs->ENSEMBL_SITETYPE;
  my $script        = $species_defs->ENSEMBL_SEARCH;
  my %sp_hash       = %{$species_defs->ENSEMBL_SPECIES_ALIASES};
  my $dest_site     = $hub->param('site') || $site_type;
  my $index         = $hub->param('idx')  || undef;
  my $query         = $hub->param('q');
  my $sp_param      = $hub->param('species');
  my $species       = $sp_param || ($hub->species !~ /^(common|multi)$/i ? $hub->species : undef);
  my $query_species = 0;
  my ($url, $site);
  
  if ($species eq 'all' && $dest_site eq 'ensembl') {
    $dest_site = 'ensembl_all';
    $species   = $species_defs->ENSEMBL_PRIMARY_SPECIES;
  }

  $query =~ s/^\s+//g;
  $query =~ s/\s+$//g;
  $query =~ s/\s+/ /g;
  $query =~ s/^(\S+?)(\d+)(\.\d*)?/$1.sprintf("%011d",$2)/eg if $query =~ /^ENS|OTT/ && $query !~ /[ENSFM|ENSSNP]/; # Make sure we've eleven digits

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
  
  ## Let us parse the first string to see if it is the name of a species or one of its aliases
  
  $query .= ' ';

  foreach my $sp (sort keys %sp_hash) {
    if (lc(substr $query, 0, length($sp) + 1) eq lc "$sp ") {
      $species       = $sp_hash{$sp};
      $query         = substr $query, length($sp) + 1;
      $query_species = 1;
    }
  }

  chop $query;
  
  my $species_path = $species_defs->species_path($species) || "/$species";
  
  return $hub->redirect("$species_path/Info/Index") if $query_species && !length $query && ($sp_param eq $species || !$sp_param);
  
  ## Now we look to see if we can find a feature in the next part
  ## of the search string - if so use that as the provisional name
  ## of the index

  my $flag = 0;
  my $index_t;

  if ($query =~ /^(\w+)\b/) {
    $index_t = $self->feature_map->{lc $1};
    $query   =~ s/^\w+\W*// if $index_t;
  } elsif ($query =~ s/^(chromosome)//i || $query =~ s/^(chr)//i) {
    $index_t = 'Chromosome';
  } elsif ($query =~ /^(contig|clone|supercontig|region)/i) {
    $index_t = 'Sequence';
  }

  $index = $index_t if $index_t;

  ## We have a species so we can see if we can generate a link

  if ($species) {
    if (!$query) { ## nothing to search for
      $flag = 1;
    } elsif ($index eq 'Sequence' || $index eq 'Chromosome' || !$index) {
      ## match any of the following:
      if ($query =~ /^\s*([-\.\w]+)[: ]([\d\.]+?[MKG]?)( |-|\.\.|,)([\d\.]+?[MKG]?)$/i || $query =~ /^\s*([-\.\w]+)[: ]([\d,]+[MKG]?)( |\.\.|-)([\d,]+[MKG]?)$/i) {
        my ($seq_region_name, $start, $end) = ($1, $2, $4);
        
        $seq_region_name =~ s/chr//;
        $start = $self->evaluate_bp($start);
        $end   = $self->evaluate_bp($end);
        
        ($end, $start) = ($start, $end) if $end < $start;
        
        my $script = 'Location/View';
        $script    = 'Location/Overview' if $end - $start > 1000000;
        
        if ($index eq 'Chromosome') {
          $url  = "$species_path/Location/Chromosome?r=$seq_region_name";
          $flag = 1;
        } else {
          $url  = $self->escaped_url("$species_path/$script?r=%s", $seq_region_name . ($start && $end ? ":$start-$end" : ''));
          $flag = 1;
        }
      } else {
        if ($index eq 'Chromosome') {
          $url  = "$species_path/Location/Chromosome?r=$query";
          $flag = 1;
        } elsif ($index eq 'Sequence') {
          $url  = "$species_path/Location/View?r=$query";
          $flag = 1;
        }
      }
    }
    
    ## other pairs of identifiers
    if ($query =~ /\.\./ && !$flag) {
      ## str.string..str.string
      ## str.string-str.string
      $query =~ /([\w|\.]*\w)(\.\.)(\w[\w|\.]*)/;
      $url   = $self->escaped_url("$species_path/jump_to_contig?type1=all;type2=all;anchor1=%s;anchor2=%s", $1, $3);
      $flag  = 1;
    }
  } else {
    $url = "/$script?species=;idx=;q=";
  }

  if (!$flag) {
    $url = 
      $query =~ /^BLA_\w+$/               ? $self->escaped_url('/Multi/blastview/%s', $query) :                                                                 ## Blast ticket
      $query =~ /^\s*([ACGT]{20,})\s*$/i  ? $self->escaped_url('/Multi/blastview?species=%s;_query_sequence=%s;query=dna;database=dna', $species, $1) :         ## BLAST seq search
      $query =~ /^\s*([A-Z]{20,})\s*$/i   ? $self->escaped_url('/Multi/blastview?species=%s;_query_sequence=%s;query=peptide;database=peptide', $species, $1) : ## BLAST seq search
      $self->escaped_url(($species eq 'ALL' || !$species ? '/Multi' : $species_path) . "/$script?species=%s;idx=%s;q=%s", $species || 'all', $index, $query);
  }
  
  $hub->redirect($site . $url);
}

sub psychic_location {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $query         = $hub->param('q');
  my $url;
  
  if ($query =~ /^\w+:(\d+)-(\d+)(:-?1)?$/) {
    my $action = $hub->referer->{'ENSEMBL_ACTION'};
    
    $url = $hub->url({
      %{$hub->multi_params(0)},
      type   => 'Location',
      action => $action eq 'Overview' || $2 - $1 > 1000000 ? 'Overview' : $action,
      r      => $query
    });
  } else {
    my $gene_adaptor = $hub->get_adaptor('get_GeneAdaptor');
    my $gene         = $gene_adaptor->fetch_by_display_label($query) || $gene_adaptor->fetch_by_stable_id($query);
    
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
  }
  
  $hub->redirect($url);
}

sub escaped_url {
  my ($self, $template, @array) = @_;
  return sprintf $template, map uri_escape($_), @array;
}

1;