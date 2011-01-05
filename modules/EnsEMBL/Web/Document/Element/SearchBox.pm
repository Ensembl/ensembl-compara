# $Id$

package EnsEMBL::Web::Document::Element::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
                                                                                
use base qw(EnsEMBL::Web::Document::Element);

sub default_search_code { return $_[0]->{'_default'} ||= $_[0]->species_defs->ENSEMBL_DEFAULT_SEARCHCODE || 'ensembl'; }

sub content {
  my $self       = shift;
  my $img_url    = $self->img_url;
  my $species    = $self->home_url . $self->hub->species;
  my $search_url = $species && $species ne '/' ? "$species/psychic" : '/common/psychic';
  
  my @options = (
    [ 'ensembl_all', 'Ensembl search all species' ],
    $self->species_defs->SPECIES_COMMON_NAME ? [ 'ensembl', 'Ensembl search this species' ] : (),
    [ 'ensembl_genomes', 'Ensembl genomes search'],
    [ 'vega', 'Vega search' ],
    [ 'ebi', 'EBI search' ],
    [ 'sanger', 'Sanger search' ]
  );
  
  my $search_options;
  $search_options .= qq{<dt id="se_$_->[0]"><img src="${img_url}search/$_->[0].gif" alt="$_->[1]"/>$_->[1]</dt>\n} for @options;
  
  return sprintf('
      <div id="searchPanel" class="js_panel">
        <input type="hidden" class="panel_type" value="SearchBox" />
        <form action="%s">
          <table class="search print_hide" summary="layout table">
            <tr>
              <td class="sites button"><img class="search_image" src="%ssearch/%s.gif" alt="" /><img src="%ssearch/down.gif" style="width:7px" alt="" /><input type="hidden" name="site" value="%s" /></td>
              <td><label class="hidden" for="se_q">Search terms</label><input id="se_q" type="text" name="q" /></td>
              <td class="button"><input type="image" src="%ssearch/mag.gif" alt="Search&gt;&gt;" /></td>
            </tr>
          </table>
          <dl class="site_menu" style="display: none">
            %s
          </dl>
        </form>
      </div>',
    $search_url,
    $img_url, 
    lc($self->default_search_code),
    $img_url,
    $self->default_search_code,
    $img_url,
    $search_options
  );
}

1;
