# $Id$

package EnsEMBL::Web::Document::Element::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
                                                                                
use base qw(EnsEMBL::Web::Document::Element);

sub default_search_code { return $_[0]->{'_default'} ||= $_[0]->species_defs->ENSEMBL_DEFAULT_SEARCHCODE || 'ensembl'; }

sub search_options {
  return (
    ## search_key         Dropdown label                  Input value
    $_[0]->hub->species ?
    [ 'ensembl',          'Ensembl search this species',  'Search '.$_[0]->species_defs->SPECIES_COMMON_NAME  ] : (),
    [ 'ensembl_all',      'Ensembl search all species',   'Search all species'                                ],
    [ 'ensembl_genomes',  'Ensembl genomes search',       'Search Ensembl genomes'                            ],
    [ 'vega',             'Vega search',                  'Search vega'                                       ],
    [ 'ebi',              'EBI search',                   'Search EBI'                                        ],
    [ 'sanger',           'Sanger search',                'Search Sanger'                                     ]
  );
}

sub content {
  my $self            = shift;
  my $img_url         = $self->img_url;
  my $species         = $self->home_url . $self->hub->species;
  my $search_url      = $species && $species ne '/' ? "$species/psychic" : '/common/psychic';
  my @options         = $self->search_options;
  my $search_code     = lc($self->default_search_code);
     $search_code     = grep({$_[0] eq $search_code} @options) ? $search_code : $options[0][0];
  my $search_options  = join '', map qq(<div id="se_$_->[0]"><img src="${img_url}search/$_->[0].gif" alt="$_->[1]"/>$_->[1]<input type="hidden" value="$_->[2]&hellip;"></div>\n), @options;
  my ($search_label)  = map {$_->[0] eq $search_code ? "$_->[2]&hellip;" : ()} @options;

  return qq(
    <div id="searchPanel" class="js_panel">
      <input type="hidden" class="panel_type" value="SearchBox" />
      <form action="$search_url">
        <div class="search print_hide">
          <div class="sites button"><img class="search_image" src="${img_url}search/${search_code}.gif" alt="" /><img src="${img_url}search/down.gif" style="width:7px" alt="" /><input type="hidden" name="site" value="$search_code" /></div>
          <div><label class="hidden" for="se_q">Search terms</label><input class="inactive" id="se_q" type="text" name="q" value="$search_label" /></div>
          <div class="button"><input type="image" src="${img_url}16/search.png" alt="Search&gt;&gt;" /></div>
        </div>
        <div class="site_menu hidden">
          $search_options
        </div>
      </form>
    </div>)
  ;
}

1;
